---
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
name: lfx-itx-integration
description: >
  Central explainer for how LFX V2 wrapper services integrate with ITX (the
  Linux Foundation IT backend) and with the legacy v1 system. Covers OAuth2
  M2M to ITX via private key JWT assertion, v2 UUID to v1 Salesforce ID
  mapping via the NATS request/reply subject `lfx.lookup_v1_mapping`, v1 to
  v2 event sync via NATS JetStream KV bucket watchers, and the canonical
  `ITX_*` environment variable contract. Fires on prompts like "ITX",
  "OAuth2 M2M to ITX", "ID mapping v1 v2", "Salesforce SFID mapping",
  "v1 KV event sync", "lfx.lookup_v1_mapping", "ITX_CLIENT_ID",
  "ITX_CLIENT_PRIVATE_KEY", "ITX_AUDIENCE", "ITX_BASE_URL",
  "JetStream KV watcher", "v1 to v2 sync", "wrapper service ITX", "private
  key JWT assertion", "id mapper", "v1-objects bucket", "EVENT_STREAM_NAME",
  "EVENT_CONSUMER_NAME". Read-only; routes implementation work to the owning
  wrapper repo.
allowed-tools: Read, Glob, Grep
---

# LFX ITX Integration

Cross-cutting explainer for how LFX V2 wrapper services talk to ITX (the
Linux Foundation IT backend) and to the legacy v1 system. The one place that
holds the canonical OAuth2 M2M flow, the `lfx.lookup_v1_mapping` ID-mapping
protocol, the JetStream KV v1-to-v2 sync pattern, and the `ITX_*` environment
variable contract. Read-only; routes implementation work to the owning
wrapper repo.

Does not replace `/lfx-skills:lfx` (topology router),
`/lfx-skills:lfx-platform-architecture` (platform composition and wrapper
service shape), each wrapper's local `CLAUDE.md`, top-level contract docs, or
repo-local `<short-repo-name>-dev` skill. It is the shared ITX baseline those
services no longer need to restate.

## When to invoke

Invoke this skill when work touches an ITX wrapper service and the question
is about the wrapper integration plumbing rather than service-specific
business logic. Concretely:

- The repo is one of `lfx-v2-voting-service`, `lfx-v2-meeting-service`,
  `lfx-v2-mailing-list-service`, or `lfx-v2-survey-service`, AND
- The task touches OAuth2 M2M to ITX, the `ITX_*` env vars, ID mapping
  via NATS, or v1 to v2 event sync via JetStream KV.

Do **not** invoke for:

- Native resource services (`lfx-v2-project-service`,
  `lfx-v2-committee-service`). They do not call ITX and they own their data
  in their own KV buckets.
- Non-ITX wrappers. `lfx-v2-mailing-list-service` is dual-source: its ID
  mapping and v1 KV sync follow the patterns here, but the Groups.io HTTP
  client itself is documented in the mailing-list repo, not here.
- Per-service ITX endpoint logic, payload shapes, converters, or KV key
  prefixes for service-specific event types. Those stay in the wrapper's
  own `docs/`.

## Wrapper service classification

| Service | ITX role | v1 KV sync | ID mapping |
| --- | --- | --- | --- |
| `lfx-v2-voting-service` | ITX voting proxy | yes | yes |
| `lfx-v2-meeting-service` | ITX Zoom proxy plus past-meeting summaries | yes | yes (optional) |
| `lfx-v2-mailing-list-service` | Groups.io / ITX proxy | yes (datastream) | yes (NATS translator) |
| `lfx-v2-survey-service` | ITX survey-monkey proxy | yes | yes |

For reusable wrapper architecture (translation flow, source-of-truth boundary,
and platform publishing on writes), use `/lfx-skills:lfx-platform-architecture`.
This skill covers only the ITX-specific plumbing on top of that service class.

## OAuth2 M2M to ITX

ITX accepts an OAuth2 Machine-to-Machine token issued via Auth0's
**private key JWT assertion** grant. The wrapper service signs a short-lived
JWT with its RSA private key; Auth0 verifies the signature against the
client's registered JWKS and returns an access token; the wrapper sends that
access token as a `Bearer` credential on every ITX HTTP call.

### Flow

1. Wrapper builds a JWT with `iss` and `sub` set to `ITX_CLIENT_ID`, `aud`
   set to the Auth0 `oauth/token` endpoint at `ITX_AUTH0_DOMAIN`, signed
   with `ITX_CLIENT_PRIVATE_KEY` (RSA, PEM, no passphrase).
2. Wrapper POSTs that assertion to `https://{ITX_AUTH0_DOMAIN}/oauth/token`
   with `grant_type=client_credentials`,
   `client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer`,
   and `audience=ITX_AUDIENCE`.
3. Auth0 returns a short-lived access token. The wrapper caches it and
   refreshes it before expiry.
4. Wrapper calls `ITX_BASE_URL`-rooted endpoints with
   `Authorization: Bearer <access-token>`.

### Why private key JWT instead of a client secret

The platform standardized on private key JWT for ITX. The old central
references to `ITX_CLIENT_SECRET` are stale; do not introduce a client
secret variable when scaffolding a new ITX wrapper.

### Per-service implementations

ITX HTTP clients live in `internal/infrastructure/proxy/` in every wrapper.
Token caching and renewal behavior is shared by convention. Existing wrapper
implementations such as
`lfx-v2-voting-service/internal/infrastructure/proxy/` can be used as living
examples, but service-specific endpoint behavior stays in the owning wrapper
repo.

## ID mapping (v2 UUID to v1 SFID)

Some ITX endpoints and most v1 events are keyed on legacy Salesforce IDs
(SFIDs), while LFX V2 APIs are keyed on UUIDs. The wrapper translates IDs
in both directions through the platform's shared **v1-sync-helper** service
over NATS request/reply.

### Subject

```text
lfx.lookup_v1_mapping
```

This subject is the canonical contract for v1/v2 ID translation across the
platform. All four ITX wrappers use it. Do not invent service-specific
mapping subjects.

### Request key format

The request payload is a single key string. The response is the mapped ID.

| Direction | Request key | Response |
| --- | --- | --- |
| Project v2 to v1 | `project.uid.<v2-uuid>` | v1 SFID |
| Project v1 to v2 | `project.sfid.<v1-sfid>` | v2 UUID |
| Committee v2 to v1 | `committee.uid.<v2-uuid>` | `projectSFID:committeeSFID` (compound) |
| Committee v1 to v2 | `committee.sfid.<v1-sfid>` | v2 UUID |

The committee compound response (`projectSFID:committeeSFID`) is produced by
the v1-sync-helper for ITX endpoints that key committees inside a project
scope. Wrapper repos own whether they forward the compound value unchanged or
split it for a service-specific ITX endpoint.

Per-service mappers may add additional keys for service-specific resource
types (for example, mailing-list-service publishes its translator port in
`lfx-v2-mailing-list-service/internal/domain/port/translator.go`). The
subject stays the same; only the key namespace expands.

### Implementation

Per-wrapper code lives in `internal/infrastructure/idmapper/` (voting,
meeting, survey) or `internal/infrastructure/nats/translator.go`
(mailing-list). Existing implementations such as
`lfx-v2-voting-service/internal/infrastructure/idmapper/nats_mapper.go` are
living examples, not owners of the reusable mapping pattern.

### Disabling for local dev

Set `ID_MAPPING_DISABLED=true` to use a no-op mapper that passes IDs through
unchanged. The wrapper continues to run without NATS in that mode.

## v1 to v2 event sync (JetStream KV watcher)

Wrappers that need real-time v1 data (votes, meetings, survey responses,
mailing-list members) consume a NATS **JetStream KV bucket** written by the
v1-sync-helper from the legacy DynamoDB. Each wrapper runs one durable
consumer that filters the bucket subject by key prefix and transforms each
v1 payload into v2 indexer and FGA-sync messages.

### Bucket and subject

| Item | Value |
| --- | --- |
| KV bucket | `v1-objects` |
| JetStream stream | `KV_v1-objects` (default `EVENT_STREAM_NAME`) |
| Subject filter root | `$KV.v1-objects.>` (default `EVENT_FILTER_SUBJECT`) |

### Durable consumer naming

Each wrapper runs its own durable consumer so it can checkpoint and replay
independently. Name convention:

```text
<service-name>-kv-consumer
```

Concretely: `voting-service-kv-consumer`, `meeting-service-kv-consumer`,
`survey-service-kv-consumer`. The mailing-list service runs its v1 stream
processors under per-handler names (`datastream_service_handler`, etc.) and
follows the same one-consumer-per-instance rule.

### Redelivery and ack

Defaults shared across wrappers:

| Variable | Default |
| --- | --- |
| `EVENT_MAX_DELIVER` | `3` |
| `EVENT_ACK_WAIT` | `30s` |
| `EVENT_MAX_ACK_PENDING` | `1000` |

After `EVENT_MAX_DELIVER` failed attempts a message is parked. Wrappers
should not silently swallow handler errors; ID-mapping failures are a
documented exception (log a warning and skip setting the v2 reference, but
keep processing the event).

### Key prefix conventions

The KV bucket holds many v1 object types under prefixes like
`itx-meetings`, `itx-registrants`, `itx-surveys`, `itx-survey-responses`,
`itx-votes`. Each wrapper subscribes to the prefixes for its own resource
types. Per-service prefix lists live in each wrapper's
`docs/event-processing.md`; do not centralize them here.

### Disabling for local dev

Set `EVENT_PROCESSING_ENABLED=false` (`EVENTING_ENABLED=false` in
mailing-list-service) to run the wrapper without NATS.

## ITX environment variables (canonical contract)

| Variable | Required | Description |
| --- | --- | --- |
| `ITX_BASE_URL` | yes | ITX HTTP API base URL. Dev: `https://api.dev.itx.linuxfoundation.org/`. Prod: `https://api.itx.linuxfoundation.org/`. |
| `ITX_CLIENT_ID` | yes | OAuth2 client ID registered with Auth0 for the wrapper. |
| `ITX_CLIENT_PRIVATE_KEY` | yes | RSA private key in raw PEM format (not base64) used to sign the Auth0 client assertion. Load from file with `export ITX_CLIENT_PRIVATE_KEY="$(cat path/to/private.key)"`. |
| `ITX_AUTH0_DOMAIN` | yes | Auth0 tenant for OAuth2 M2M. Dev: `linuxfoundation-dev.auth0.com`. |
| `ITX_AUDIENCE` | yes | Auth0 API audience for ITX. Matches `ITX_BASE_URL` (trailing slash included). |
| `NATS_URL` | conditional | Required when `ID_MAPPING_DISABLED=false` or event processing is enabled. |
| `ID_MAPPING_DISABLED` | no | `true` skips NATS ID mapping; defaults to `false` in prod, `true` in `.env.example` for local dev. |
| `EVENT_PROCESSING_ENABLED` | no | Defaults `true` in prod; set `false` for local dev without NATS. Mailing-list uses `EVENTING_ENABLED`. |
| `EVENT_CONSUMER_NAME` | no | Durable consumer name; defaults to `<service-name>-kv-consumer`. |
| `EVENT_STREAM_NAME` | no | JetStream stream; defaults to `KV_v1-objects`. |
| `EVENT_FILTER_SUBJECT` | no | NATS subject filter; defaults to `$KV.v1-objects.>`. |
| `EVENT_MAX_DELIVER` | no | Defaults to `3`. |
| `EVENT_ACK_WAIT` | no | Defaults to `30s`. |
| `EVENT_MAX_ACK_PENDING` | no | Defaults to `1000`. |
| `LOG_LEVEL` | no | `debug|info|warn|error`. Default `info` (debug in `.env.example`). |
| `LOG_ADD_SOURCE` | no | Add source file and line to log output. Default `true`. |
| `JWT_AUTH_DISABLED_MOCK_LOCAL_PRINCIPAL` | no | Local-dev only. Any non-empty string disables Heimdall JWT validation and uses the value as the mock principal. |

Per-wrapper extras (Heimdall `JWKS_URL`, mailing-list `AUTH_SOURCE`,
`REPOSITORY_SOURCE`, `GROUPSIO_SOURCE`, `TRANSLATOR_SOURCE`, mailing-list
`NATS_TIMEOUT`/`NATS_MAX_RECONNECT`/`NATS_RECONNECT_WAIT`, meeting-service
`LFX_ENVIRONMENT`) live in the wrapper's README and `.env.example`.

### Credential sourcing

For local dev, `ITX_CLIENT_ID` and `ITX_CLIENT_PRIVATE_KEY` come from 1Password
under the **LFX V2** vault. The exact note name differs per service: voting
uses **LFX V2 Voting Service Env Vars**; meeting, mailing-list, and survey
use **LFX Platform Chart Values Secrets - Local Development**. For deployed
environments, secrets come from ExternalSecrets in `lfx-v2-argocd` and are a
DevOps/CloudOps handoff.

## Per-wrapper specifics

For per-service ITX quirks, payload shapes, endpoint catalogs, converters,
and event handler sets, read the wrapper's own docs.

| Wrapper | ITX-specific docs |
| --- | --- |
| `lfx-v2-voting-service` | `docs/api-contracts.md`, `docs/event-processing.md`, `docs/itx-proxy-implementation.md` |
| `lfx-v2-meeting-service` | `docs/api-contracts.md`, `docs/api-contracts/*.md`, `docs/itx-proxy-implementation.md`, `docs/event-processing.md` |
| `lfx-v2-mailing-list-service` | `docs/api-endpoints.md`, `docs/indexer-contract.md`, `docs/fga-contract.md`, plus the Groups.io sections in `CLAUDE.md` |
| `lfx-v2-survey-service` | `docs/api-contracts.md`, `docs/api-contracts/*.md`, `docs/itx-proxy-implementation.md`, `docs/event-processing.md`, plus survey-monkey notes in the repo `README.md` |

Each wrapper's `docs/event-processing.md` lists the exact v1 event types it
handles, the v2 indexer and FGA envelope shapes it emits, and any
service-specific conversion logic (RRULE expansion in meeting-service,
ranked-choice aggregation in voting-service, response correlation in
survey-service, committee-association proxying in mailing-list-service).

## What this skill is not

- Not a wrapper-service template. Reusable wrapper service shape lives in
  `/lfx-skills:lfx-platform-architecture`.
- Not a NATS subject catalog. Subject lists per wrapper live in each wrapper's
  repo-named dev skill, such as `.claude/skills/voting-service-dev/references/nats-messaging.md`.
- Not the indexer or FGA contract. Those live in `lfx-v2-indexer-service`
  and `lfx-v2-fga-sync` agent-guidance docs.
- Not a deployment guide. Helm chart, ExternalSecret, and Argo wiring live
  in the wrapper's `charts/`, in `lfx-v2-helm`, and in `lfx-v2-argocd`.
- Not a per-service ITX endpoint reference. Read each wrapper's own
  `docs/api-*.md` for that.

## Handoff boundary

Once routed to the right wrapper repo, stop using this skill as an
implementation guide. The wrapper's local `CLAUDE.md`, `docs/`, and
repo-local skills control detail.
