---
name: lfx-platform-architecture
description: >
  Central explainer for how the LFX V2 platform components compose: Self Serve,
  Goa services, NATS, JetStream KV, fga-sync, OpenFGA, indexer-service,
  OpenSearch, query-service, access-check, Heimdall, Gateway API, Auth0, Helm,
  and ArgoCD. Use when tracing platform write, read, access-check,
  authorization, indexing, deployment, service-classification, or cross-repo
  ownership flows. Fires on prompts like "how does FGA flow", "where does the
  indexer fit", "what's the platform shape", "native service", "wrapper
  service", "new V2 service", "Heimdall vs FGA", "what owns the OpenFGA
  model", "how does query-service read resources", "how does access-check
  work", "which repo owns deployed values", or "which service consumes index
  messages". Do not use for V2 Go service coding conventions; the owning
  repo's path-scoped `<short-repo-name>-dev` skill should attach after routing.
allowed-tools: Read, Glob, Grep
---

<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# LFX Platform Architecture

Cross-cutting architecture explainer for how the LFX V2 platform fits together.
Use this skill to understand component relationships, V2 service classes, and
cross-repo ownership before handing implementation work to the owning repo.

Clean split:

- `/lfx-skills:lfx-platform-architecture`: platform composition, V2 service
  classes, cross-service responsibilities, and handoff points.
- Owning repo path-scoped `<short-repo-name>-dev` skill: Go coding conventions
  such as generated-code boundaries, logging, errors, request context, tests,
  formatting, and linting.
- Owning repos: concrete implementation truth, contracts, subjects, payloads,
  chart values, and domain behavior.

## When to invoke

- The user asks how platform pieces fit together.
- The user is tracing a request, write, read, authorization, access-check, or
  indexing flow.
- The user is classifying a V2 service as native, wrapper, proxy/consumer, or
  platform.
- The user is starting a new V2 service or deciding which repo owns a NATS
  subject family, KV bucket, indexer contract, FGA contract, query behavior,
  chart template, or deployed value.
- The user is changing an OpenFGA type or relation and needs the repo
  coordination order.
- The user is deciding which repo owns a platform contract.
- The user is routing deployment, chart, values, Auth0, ExternalSecret, or
  ApplicationSet work.

If the task is about coding inside an individual V2 Go service, first route to
the owning repo. The repo-local path-scoped `<short-repo-name>-dev` skill should
attach on relevant Go/service paths, alongside the repo-owned top-level `docs/`
files named by that repo's `CLAUDE.md`.

## Platform shape

The V2 platform is a Goa-on-NATS service mesh fronted by Heimdall, authorized by
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
| V2 Go services       |    | query-service     |    | access-check      |
| (Goa + NATS/KV,      |    | (HTTP read API    |    | (HTTP wrapper     |
| platform contracts)  |    | over OpenSearch)  |    | over fga-sync)    |
+----------+-----------+    +---------+---------+    +---------+---------+
           |                          |                        |
           v                          v                        v
  NATS subjects + KV          OpenSearch index         OpenFGA tuples
  lfx.index.*    -> indexer-service -> OpenSearch
  lfx.fga-sync.* -> fga-sync        -> OpenFGA
  lfx.access_check.request -> fga-sync (cached check)
```

Auth and deployment sit alongside the data path:

- `lfx-v2-auth-service` is the NATS RPC abstraction over Auth0 and Authelia
  for identity, profile, and impersonation behavior.
- `auth0-terraform` owns Auth0 tenant configuration.
- `lfx-v2-helm` owns the shared platform chart and OpenFGA model template.
- `lfx-v2-argocd` owns deployed values, chart pins, image tags,
  ApplicationSets, previews, and promotion.

## Service classes

Classify before choosing a work plan. The class determines which
responsibilities exist and which repo-local docs should be present.

| Class | Quick sense | Living examples |
| --- | --- | --- |
| Native resource service | Owns its data in NATS JetStream KV and exposes full CRUD through a Goa API. | `lfx-v2-project-service`, `lfx-v2-committee-service` |
| Wrapper resource service | Exposes LFX V2 APIs while an external system remains the source of truth. | `lfx-v2-voting-service`, `lfx-v2-meeting-service`, `lfx-v2-mailing-list-service`, `lfx-v2-survey-service` |
| Supporting application service | Owns feature-specific behavior or state that is not a generic V2 resource contract. | `lfx-v2-email-service`, `lfx-v2-newsletter-service` |
| Proxy or consumer service | Thin HTTP or NATS facade over platform plumbing. Does not own a resource type. | `lfx-v2-access-check`, `lfx-v2-auth-service`, `lfx-v2-persona-service` |
| Platform service | Provides shared platform capability consumed by other services. | `lfx-v2-indexer-service`, `lfx-v2-fga-sync`, `lfx-v2-query-service` |

Living examples are examples, not central owners of implementation truth.
Concrete behavior belongs in the repo that owns the code.

## Native resource services

A native resource service owns resource state directly in NATS JetStream KV.

Typical responsibilities:

- Goa HTTP API for resource reads and writes.
- One or more service-owned KV buckets.
- Optimistic concurrency for mutable resources when backed by KV revisions.
- Indexer publication for queryable resources.
- FGA publication for resources with their own access model.
- Service-owned chart templates and Heimdall `RuleSet` entries for routes.
- Health endpoints and graceful shutdown.

Native local docs should identify owned KV buckets, request/reply subjects,
indexed resource types, FGA object types, and any deviations from the usual
CRUD, optimistic-locking, or health/readiness shape.

## Wrapper resource services

A wrapper resource service exposes an LFX V2 API while another system remains
the source of truth.

Typical responsibilities:

- Goa HTTP API shaped for LFX V2 consumers.
- Translation between LFX V2 payloads and upstream payloads.
- Outbound auth to the upstream system.
- v2-to-v1 ID mapping when upstream resources use legacy Salesforce IDs.
- Indexer and FGA publication after successful upstream writes when the
  resource is queryable or access-controlled.
- Local KV only for mapping or cache needs, not as the resource source of
  truth.

Wrapper local docs should identify upstream ownership, LFX V2 to upstream field
mappings, ID mapping requirements, local caches, emitted indexer/FGA messages,
and upstream pagination, versioning, retry, or error quirks.

For ITX-specific plumbing such as OAuth2 M2M, `lfx.lookup_v1_mapping`, v1 KV
sync, and `ITX_*` environment variables, use
`/lfx-skills:lfx-itx-integration`.

## Supporting application services

Supporting application services own feature-specific behavior that participates
in the platform but is not a generic resource service.

Typical responsibilities:

- A small explicit public API, either HTTP or NATS request/reply.
- Service-owned state only when the feature needs it, such as Postgres rows or
  NATS KV tracking records.
- Clear local docs for the owned contract, consumed peer contracts, chart
  values, and deployment handoffs.
- No default assumption of Goa, indexer publishing, or FGA tuple emission.

Examples:

- `lfx-v2-email-service` owns transactional email request/reply and engagement
  tracking. It does not render templates or publish indexer/FGA messages.
- `lfx-v2-newsletter-service` owns newsletter drafts, sent state, recipient
  resolution orchestration, open tracking, and analytics. It consumes
  query-service and email-service contracts.

## Proxy, consumer, and platform services

Proxy and consumer services do not own resource data and usually do not publish
indexer or FGA messages.

Architecture expectations:

- Keep the public or RPC surface small and explicit.
- Document the owned contract locally.
- Route tuple semantics, index document semantics, query behavior, identity
  provider behavior, or deployment values to the repo that owns them.
- Avoid applying native or wrapper resource-service assumptions unless the repo
  actually has those surfaces.

Examples:

- `lfx-v2-access-check` owns the HTTP access-check API. FGA tuple semantics
  live in `lfx-v2-fga-sync`.
- `lfx-v2-auth-service` owns auth/profile NATS RPCs. Auth0 tenant resources
  live in `auth0-terraform`.
- `lfx-v2-persona-service` aggregates persona summaries. It does not own KV
  resource state, indexer emission, or FGA emission.
- `lfx-v2-indexer-service`, `lfx-v2-fga-sync`, and `lfx-v2-query-service` own
  platform contracts consumed by resource services.

## Write flow

1. HTTP request hits Gateway API and Traefik.
2. Heimdall authenticates through OIDC and authorizes through `openfga_check`
   rules in the service chart.
3. The owning service validates and performs the write.
4. The owning service publishes platform messages as required by its resource
   contract:
   - index messages to `indexer-service`
   - access messages to `fga-sync`
5. `indexer-service` writes OpenSearch documents and emits domain events after
   successful indexing.
6. `fga-sync` writes or deletes OpenFGA tuples and updates its cache.

Service-class responsibilities live in this skill. Go coding conventions live
in the owning service repo's path-scoped `<short-repo-name>-dev` skill.

## Read flow

1. Self Serve or another consumer calls `query-service` for indexed reads.
2. `query-service` reads OpenSearch.
3. `query-service` asks `fga-sync` for batched access checks over NATS.
4. `query-service` removes unauthorized resources before returning results.
5. Direct single-resource GETs go to the owning service and are authorized by
   Heimdall route rules.

Common failure owners:

- Missing document: owning service publish path or `indexer-service`.
- Missing access: owning service access emission, `fga-sync`, or OpenFGA model.
- Resource visible in API but absent from search: indexer or query-service path.
- Resource searchable but unauthorized: FGA tuple or access-check path.

## Access-check flow

1. Caller publishes a batched request on `lfx.access_check.request`.
2. `fga-sync` checks its JetStream KV cache first.
3. On cache miss, `fga-sync` calls OpenFGA and writes the result back to cache.
4. Caller matches replies by request token, not by reply order.

The generic access-check and tuple contracts live in `lfx-v2-fga-sync`.
The HTTP wrapper over access checks lives in `lfx-v2-access-check`.

## OpenFGA and Heimdall coordination

Adding or changing an OpenFGA type or relation touches multiple repos.

| Layer | Owner repo | File or surface |
| --- | --- | --- |
| OpenFGA authorization model | `lfx-v2-helm` | `charts/lfx-platform/templates/openfga/model.yaml` |
| Endpoint authorization rules | Owning service repo | `charts/<service>/templates/ruleset.yaml` |
| Emitted access data | Owning service repo | service publisher code and local contract docs |
| Generic tuple handling and access checks | `lfx-v2-fga-sync` | handlers and `docs/fga-sync-contract.md` |
| Deployed values and promotion | `lfx-v2-argocd` | values, ApplicationSets, chart pins |

Coordination order:

1. Update the OpenFGA model in `lfx-v2-helm`.
2. Update the owning service's emitted access envelope.
3. Update the owning service's Heimdall ruleset.
4. Update the owning service's local FGA contract docs.
5. Coordinate rollout with `lfx-v2-argocd` if deployed values or chart pins are
   part of the change.

`lfx-v2-fga-sync` should not need type-specific code for a new resource type.
If it does, the envelope design is drifting.

## Contract owners

| Concern | Owning repo |
| --- | --- |
| Product app, Angular SSR, Express BFF, shared package | `lfx-self-serve` |
| FGA tuple envelope, cache, access-check semantics | `lfx-v2-fga-sync` |
| Indexer envelope, OpenSearch document writes, indexing events | `lfx-v2-indexer-service` |
| Query API, OpenSearch read behavior, CEL, access filtering | `lfx-v2-query-service` |
| Access-check HTTP API | `lfx-v2-access-check` |
| Auth/profile/identity NATS RPC | `lfx-v2-auth-service` |
| Shared local platform chart and OpenFGA model | `lfx-v2-helm` |
| Deployed values, chart pins, image tags, ApplicationSets | `lfx-v2-argocd` |
| Local fixture loading and reset | `lfx-v2-mockdata` |
| Auth0 tenant control plane | `auth0-terraform` |

Use `/lfx-skills:lfx` and its repo map when deciding the primary repo for an
actual edit.

## Cross-service handoff points

Read the owning repo before changing a contract shape. For exact current owner
files, use `/lfx-skills:lfx` and `references/contract-ownership.md`; this skill
keeps only the architectural ownership split.

| Concern | Owning repo |
| --- | --- |
| FGA envelope, tuple format, member operations, cache, access-check semantics | `lfx-v2-fga-sync` |
| Indexer envelope, OpenSearch document shape, event emission | `lfx-v2-indexer-service` |
| Query API, pagination over OpenSearch, filters, CEL, access filtering | `lfx-v2-query-service` |
| Cross-service Helm chart conventions | `lfx-v2-helm` |
| Shared platform chart and OpenFGA model | `lfx-v2-helm` |
| Deployed environment values, chart pins, image tags, ApplicationSets | `lfx-v2-argocd` |

## Chart and deployment ownership

- Service-local chart templates and defaults belong to the service repo.
- Shared local platform composition and the OpenFGA model belong to
  `lfx-v2-helm`.
- Deployed environment values, chart pins, image tags, ExternalSecrets, and
  promotion state belong to `lfx-v2-argocd`.

## Data privacy across the platform

Every V2 service that touches user identity (member, committee, project,
meeting, mailing-list, voting, survey, invite, auth, persona) must follow the
plugin-wide data-privacy rules in
[`../lfx/references/data-privacy.md`](../lfx/references/data-privacy.md).

Platform-shape implications to keep in mind when generating code or reviewing
a service's flow:

- **KV writes** (native and wrapper resource services): persist only fields
  the resource contract owns. Do not stash extra user identifiers "for
  convenience."
- **Indexer envelopes and OpenSearch documents**: index only fields the
  resource contract exposes for search. Emails, phone numbers, and precise
  addresses generally do not belong in search documents.
- **FGA tuples**: use structural IDs (resource UID, user UID, project UID),
  never raw emails or personal names, as tuple `user`/`object` values.
- **Application logs**: default is no PII. Correlate on request ID,
  correlation ID, trace ID, or a **non-user resource UID that does not
  reference a natural person** (project UID, meeting UID, committee UID,
  mailing-list UID, etc.). User-linked UIDs (user UID, member UID,
  persona UID, LFID, Auth0 `sub`) are linked pseudonyms and are not safe
  to log raw. **Resource UIDs that reference a person or the person's
  financial relationship — invoice UID, subscription UID, order UID,
  membership UID — are also linked pseudonyms per
  [`../lfx/references/data-privacy.md`](../lfx/references/data-privacy.md)
  and MUST NOT be logged raw either; treat them like user UIDs.** When a
  user-linked correlator is truly needed, emit a service-specific
  **keyed-HMAC pseudonym** (plain `sha256(email)` is banned — see
  `data-privacy.md`, "Logging exception"). The narrow audit-log
  exception, also documented in `data-privacy.md`, applies only to a
  dedicated audit-log code path.
- **Error responses, tracing spans, metrics tags**: no PII, no audit
  exception. These sinks are excluded from the audit exception by the
  canonical rule.
- **Wrapper services**: an upstream system may return more PII than the LFX
  V2 API needs. Strip fields not part of the LFX V2 contract before
  publishing to indexer/FGA or persisting to a local cache.

## What this skill is not

- Not a V2 Go coding rulebook. Repo-local path-scoped `<short-repo-name>-dev`
  skills control coding conventions when Go or service files are edited.
- Not a repo-local contract. Read the owning repo's `CLAUDE.md`,
  top-level `docs/` contract files, and only use `docs/agent-guidance/` where
  the `/lfx-skills:lfx` repo map explicitly lists it as a transitional owner
  path.
- Not an ITX integration guide. Use `/lfx-skills:lfx-itx-integration`.
- Not a Self Serve implementation guide. Use `lfx-self-serve`.

## Handoff

After the platform flow and owners are clear, switch to the owning repo. The
owning repo's local instructions, top-level `docs/` contract files, and
path-scoped `<short-repo-name>-dev` skill control implementation.
