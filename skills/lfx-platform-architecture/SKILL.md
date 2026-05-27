---
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
name: lfx-platform-architecture
description: >
  Central explainer for how the LFX V2 platform composes Goa, NATS, KV, FGA,
  the indexer, the query service, Heimdall, and OpenFGA. Use when classifying
  a service (native vs wrapper vs proxy), tracing request, write, read, or
  access-check flows, deciding NATS subject and KV bucket names, or
  coordinating a new FGA type across the OpenFGA model and Heimdall rulesets.
  Fires on prompts like "how does FGA flow", "where does the indexer fit",
  "what's the platform shape", "Heimdall vs FGA", "what owns the OpenFGA
  model", "what's a native vs wrapper service", "where do NATS subjects come
  from", "explain the V2 platform topology", "how does access-check work",
  "which service publishes index messages".
allowed-tools: Read, Glob, Grep
---

# LFX Platform Architecture

Cross-cutting architecture explainer for the LFX V2 platform. The one place
that holds the composition of the V2 pieces and the cross-repo coordination
rules for FGA. Read-only; routes implementation work to the owning repos.

Does not replace `/lfx` (topology router), per-repo `CLAUDE.md`, or the
canonical contract docs owned by each platform repo. Use it to understand
the shape; then hand off.

## When to invoke

- The user asks how the V2 pieces fit together (Goa, NATS, KV, FGA, indexer,
  query, Heimdall, OpenFGA, OpenSearch, auth, access-check).
- The user needs the service taxonomy: is this a native service, a wrapper,
  or a proxy/consumer, and which template to follow.
- The user is tracing a request, write, read, or access-check flow before
  designing a change.
- The user is about to add or change an OpenFGA type or relation and needs
  the coordination order between `lfx-v2-helm` (model) and the owning
  service (ruleset, emitted access data).
- The user is naming new NATS subjects or KV buckets and needs the platform
  convention.
- The user wants to know which repo owns which canonical contract.

If the task is single-repo and the answer is in a repo-local doc, do not
invoke this skill; defer to that repo's `CLAUDE.md` and `docs/agent-guidance/`.

## Service taxonomy

V2 services fall into three classes. Classify before reaching for a template.

**Native resource service.** Owns its data in NATS JetStream KV buckets.
Exposes full CRUD via a Goa HTTP API. Publishes both an indexer message and
an FGA-sync access message on every write. Examples: `lfx-v2-project-service`
(canonical template), `lfx-v2-committee-service`. Template doc:
`lfx-v2-project-service/docs/agent-guidance/native-template.md`.

**Wrapper resource service.** Owns no data of its own. Proxies an external
system (ITX, Groups.io, Zoom) for all data operations and translates between
the LFX Self-Service API and the external system's API. Still publishes
indexer and FGA-sync messages on writes. Examples: `lfx-v2-voting-service`
(canonical template), `lfx-v2-meeting-service`, `lfx-v2-mailing-list-service`,
`lfx-v2-survey-service`. Template doc:
`lfx-v2-voting-service/docs/agent-guidance/wrapper-template.md`.

**Proxy or consumer service.** Owns no resource data and publishes no
indexer or FGA-sync messages. Thin HTTP-to-NATS wrapper around platform
plumbing, with a bespoke contract. Examples: `lfx-v2-access-check` (HTTP
Goa wrapper over fga-sync NATS), `lfx-v2-auth-service` (NATS RPC over Auth0
and Authelia). Each owns its contract under its own `docs/agent-guidance/`.

| Scenario | Class | Start from |
| --- | --- | --- |
| New service stores its own resource data | Native | `lfx-v2-project-service` |
| New service wraps an external system | Wrapper | `lfx-v2-voting-service` |
| New thin platform-plumbing service | Proxy/consumer | `lfx-v2-access-check` or `lfx-v2-auth-service` |

## Platform shape

The V2 platform is a Goa-on-NATS mesh fronted by Heimdall, authorized by
OpenFGA, indexed into OpenSearch, and read through query-service.

```text
Browser
  -> lfx-self-serve Angular SSR
  -> lfx-self-serve Express BFF
       |
       v
Gateway API + Traefik
  -> Heimdall (authn + openfga_check authz per route)
       |
       v
+----------------------+    +-------------------+    +-------------------+
| Resource services    |    | query-service     |    | access-check      |
| (Goa + NATS, native  |    | (HTTP read API    |    | (HTTP wrapper     |
| or wrapper)          |    | over OpenSearch)  |    | over fga-sync)    |
+----------+-----------+    +---------+---------+    +---------+---------+
           |                          |                        |
           v                          v                        v
  NATS subjects + KV          OpenSearch index         OpenFGA tuples
  lfx.index.*    --> indexer-service  --> OpenSearch
  lfx.fga-sync.* --> fga-sync         --> OpenFGA
  lfx.access_check.request --> fga-sync (cached check)
```

Auth and profile live alongside the data path:

- `lfx-v2-auth-service` is the NATS RPC abstraction over Auth0 and Authelia
  for identity, profile, and impersonation.
- `auth0-terraform` owns Auth0 tenant configuration (clients, audiences,
  grants, Actions, connections).

### Write flow

1. HTTP request hits Heimdall via Gateway API and the service's `HTTPRoute`.
2. Heimdall runs `oidc` authentication, then `openfga_check` against the
   relation and object configured in the service's `ruleset.yaml`.
3. Goa handler validates and dispatches to the service layer.
4. Native services persist to JetStream KV with optimistic locking via the KV
   revision. Wrapper services persist by calling the external API and storing
   only an ID mapping locally.
5. Service publishes concurrently:
   - `lfx.index.{resource_type}` indexer envelope to `indexer-service` for
     OpenSearch indexing.
   - `lfx.fga-sync.update_access` or `lfx.fga-sync.delete_access` generic
     access envelope to `fga-sync` when the resource has its own FGA type.

### Read flow

1. Self Serve or another consumer calls `query-service` at
   `/query/resources?type=...` (the platform read aggregator over
   OpenSearch).
2. `query-service` issues a batch FGA check via NATS to `fga-sync` on
   `lfx.access_check.request` and drops unauthorized resources.
3. Direct GETs on a single resource go straight to the owning service. The
   gateway runs `openfga_check` per the service ruleset; no aggregator step.
4. Missing or stale resources usually mean one of: indexer not consuming,
   indexer envelope wrong, fga-sync tuples missing, or OpenFGA model wrong.

### Access-check flow

1. Caller (query-service or `lfx-v2-access-check`) publishes a batched
   request on `lfx.access_check.request` with a request token.
2. `fga-sync` checks its JetStream KV cache first; on miss it asks OpenFGA
   directly and writes the result back to the cache.
3. Reply ordering is not guaranteed. Always match results on the request
   token.

## NATS subject and KV naming

These rules apply uniformly across V2 Go services. Per-service subjects and
KV bucket names live in each service's local `docs/agent-guidance/nats-messaging.md`.

### Subject conventions

- No environment prefix. Subjects are identical in all environments.
- Subject constants live in a shared package (`pkg/constants/`) and are
  imported by both publisher and subscriber. Never hardcode subject strings.
- Patterns:

| Pattern | Purpose |
| --- | --- |
| `lfx.index.{resource_type}` | Publish to indexer-service for OpenSearch indexing. |
| `lfx.v1.index.{resource_type}` | Legacy v1 indexer path. |
| `lfx.fga-sync.update_access` | Publish generic access update to fga-sync. |
| `lfx.fga-sync.delete_access` | Publish generic access delete to fga-sync. |
| `lfx.fga-sync.member_put` | Add a per-user relation via fga-sync. |
| `lfx.fga-sync.member_remove` | Remove a per-user relation via fga-sync. |
| `lfx.access_check.request` | Batched access check (cached). |
| `lfx.access_check.read_tuples` | Read tuples for a user + object_type. |
| `lfx.{service-api}.{operation}` | Service-to-service request/reply RPC. |
| `lfx.{object_type}.{action}` | Domain event emitted by indexer after a write. |

All subscriptions, including request/reply handlers, use queue groups so a
single instance handles each message when scaled horizontally.

### KV bucket conventions

- Plural snake_case (`projects`, `committees`, `meeting_registrants`).
- No environment prefix.
- One service owns each bucket; no cross-service writes. Cross-service reads
  go through NATS request/reply RPC instead of direct KV access.
- Native services initialize their buckets at startup; the Helm chart's
  `nats-kv-buckets.yaml` declares them with `helm.sh/resource-policy: keep`.

The platform-wide canonical reference for these rules is
`lfx-v2-project-service/docs/agent-guidance/nats-messaging.md`. Read it
before defining new subjects or buckets.

## Heimdall coordination

Adding or changing an OpenFGA type or relation always touches at least two
repos. The model lives in the platform chart; the ruleset that calls
`openfga_check` lives in each service chart; the emitted access data lives
in the owning resource service code.

| Layer | Owner repo | File |
| --- | --- | --- |
| OpenFGA authorization model | `lfx-v2-helm` | `charts/lfx-platform/templates/openfga/model.yaml` |
| Per-service Heimdall ruleset (`openfga_check` rules per endpoint) | Owning service | `charts/<service>/templates/ruleset.yaml` |
| Emitted access data (FGA envelope on `lfx.fga-sync.*`) | Owning resource service | service publisher code |
| Generic tuple-write handler, cache, access-check semantics | `lfx-v2-fga-sync` | handlers in that repo |

### Ordering when adding a new FGA type or relation

1. Edit `lfx-v2-helm/charts/lfx-platform/templates/openfga/model.yaml`. Add
   the new type or relation, including any inheritance and the
   `@fgadoc:jtbd` annotation.
2. Update the owning service's emitted access envelope so its `relations`
   and `references` use the new shape.
3. Update the owning service's `charts/<service>/templates/ruleset.yaml`:
   each affected Goa endpoint needs an `openfga_check` rule with the right
   `relation` and `object` (pulled from URL captures or request body).
4. Update the per-service `docs/fga-contract.md` if present.
5. Ship the model change and the service changes in coordinated PRs so
   Heimdall does not authorize against a relation that has not landed in
   the model yet.

`lfx-v2-fga-sync` should not need code changes for a new type. Its handlers
are generic. If you find yourself adding a type-specific handler in
`lfx-v2-fga-sync`, the design is drifting; revisit the envelope instead.

## Canonical contract pointers

This skill is intentionally a pointer, not a copy. Each contract is owned by
exactly one repo. Read the owner doc before changing the contract shape.

| Concern | Owning repo and doc |
| --- | --- |
| Generic FGA envelope, tuple format, member operations, cache, access-check semantics | `lfx-v2-fga-sync/docs/agent-guidance/fga-patterns.md` |
| Indexer envelope, OpenSearch document shape, event emission, client guide | `lfx-v2-indexer-service/docs/agent-guidance/indexer-patterns.md` |
| Query-service contract: `/query/resources`, pagination, CEL caveats, access filtering | `lfx-v2-query-service/docs/agent-guidance/query-service-patterns.md` |
| Native resource-service template: file structure, optimistic locking via KV revision, write flow | `lfx-v2-project-service/docs/agent-guidance/native-template.md` |
| Wrapper resource-service template: translation flow, ID mapping, cross-cutting requirements | `lfx-v2-voting-service/docs/agent-guidance/wrapper-template.md` |
| Canonical NATS subject and KV conventions | `lfx-v2-project-service/docs/agent-guidance/nats-messaging.md` |
| Goa API design template for native services | `lfx-v2-project-service/docs/agent-guidance/goa-patterns.md` |
| Cross-service Helm chart conventions (HTTPRoute, RuleSet, ExternalSecret, KV) | `lfx-v2-helm/docs/agent-guidance/service-chart-patterns.md` |
| Shared platform chart and OpenFGA model | `lfx-v2-helm/docs/agent-guidance/platform-chart.md` |
| Access-check HTTP contract | `lfx-v2-access-check` repo (`docs/agent-guidance/`) |
| Identity, profile, impersonation NATS RPC | `lfx-v2-auth-service` repo (`docs/agent-guidance/`) |

Resolve cross-repo paths from `~/lfx/<repo>/<path>` or via `Glob` if the
workspace root differs. Never assume a relative `../../<repo>/` layout.

## What this skill is not

- Not an implementation recipe. Do not copy contract content from the
  owning repos into this skill or restate it here. Point and stop.
- Not a deployment routing skill. Use `lfx-dev/skills/lfx/references/deployment-routing.md`
  for chart, ApplicationSet, Argo, ExternalSecret, and Auth0 routing.
- Not a repo-map. Use `lfx-dev/skills/lfx/references/repo-map.md` and
  `routing-playbook.md` for primary and peer repo selection.
- Not a per-service convention skill (logger, pagination, error handling,
  request context). Those land in repo-local guidance.
- Not an ITX-integration skill (OAuth2 M2M, ID mapping, v1 KV sync). That
  lives with the wrapper services that use ITX.

## Handoff

Once the agent knows the service class, the right flow, the relevant NATS
subject family, and the contract owner, switch to the owning repo's
`CLAUDE.md` and `docs/agent-guidance/`. The implementation truth lives
there.
