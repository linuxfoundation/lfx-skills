<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# LFX V2 Topology (Routing-Level)

This file is a routing-level surface map. Use it when the routing question is
"which surfaces does this task touch" and you only need the owner repo per
surface.

For cross-cutting platform architecture (composition, service classes, write
flow, read flow, access-check flow, Heimdall coordination, and contract
owners), use the `/lfx-skills:lfx-platform-architecture` skill. For Go coding
conventions, rely on the owning repo's path-scoped `<short-repo-name>-dev`
skill after routing.

After choosing surfaces here, hand off to `repo-map.md` or `routing-playbook.md`
for primary and peer repo selection.

## Main surfaces

| Surface | Role | Implementation truth |
| --- | --- | --- |
| Self Serve / LFX One | Angular 20 SSR app, Express BFF, and `@lfx-one/shared` | `lfx-self-serve` |
| V2 resource services | Goa HTTP APIs, domain storage/proxy logic, NATS/KV, indexer emission, FGA emission | Owning `lfx-v2-*-service` repo |
| Query service | Search/read aggregation over OpenSearch with access filtering | `lfx-v2-query-service` |
| Indexer service | Consumes index messages and writes OpenSearch documents | `lfx-v2-indexer-service` |
| FGA sync | Consumes access messages and writes/reads/checks OpenFGA tuples | `lfx-v2-fga-sync` |
| Access check | HTTP Goa wrapper around NATS/OpenFGA access checks | `lfx-v2-access-check` |
| Auth service | Identity/profile/auth abstraction over platform identity providers | `lfx-v2-auth-service` |
| Auth0 tenant configuration | Auth0 clients, API audiences, grants, Actions, token exchange, connections, and OpenTofu workflow | `auth0-terraform` |
| Local/shared platform | Umbrella chart, local stack, OpenFGA model, Gateway, Heimdall, NATS, OpenSearch, OpenFGA topology | `lfx-v2-helm` |
| GitOps rollout | Environment values, chart pins, image tags, ApplicationSets, previews, promotion | `lfx-v2-argocd` |
| Mock data | Local fixture loading and reset tooling through APIs, NATS requests, and NATS KV writes | `lfx-v2-mockdata` |

## Legacy naming

Old chart and Argo names may still say `lfx-v2-ui`. Self Serve implementation
knowledge routes to `lfx-self-serve`; the legacy name is a deployment
artifact, not a separate skills target.
