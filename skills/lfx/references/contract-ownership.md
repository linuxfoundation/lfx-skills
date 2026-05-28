<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Contract Ownership

Use this reference when an agent needs a contract, payload, subject, chart
surface, integration detail, or other owned implementation truth from another
repo. The owner repo and files listed here are the starting point. Do not infer
these details from central skill prose.

After identifying an owner here:

1. Ensure the repo exists at `$LFX_DEV_ROOT/<repo>`. If it is missing, clone
   the `GitHub:` URL from `repo-map.md` into the workspace root.
2. Read the owner repo's `CLAUDE.md` or equivalent local setup.
3. Read the owner files listed below.
4. Report the exact owner file read. If the path is absent, report a
   repo-readiness gap instead of substituting central guidance.

`docs/agent-guidance/` is transitional. Use it only where this reference or
`repo-map.md` explicitly lists it.

## Service-Owned Contract Docs

These are the repo-owned contract and implementation-truth docs most often read
by agents working from another repo.

| Owner | Owned surface | Where to read |
| --- | --- | --- |
| `lfx-v2-project-service` | Project resource API, project FGA emissions, project index documents | `docs/fga-contract.md`, `docs/indexer-contract.md` |
| `lfx-v2-committee-service` | Committee, committee-member, invite, application, committee-link, and committee-document contracts, FGA emissions, index documents | `docs/fga-contract.md`, `docs/indexer-contract.md`, `docs/invite-application-flows.md` |
| `lfx-v2-meeting-service` | Meeting API, ITX/Zoom proxy behavior, event sync, FGA emissions, index documents, meeting-service chart behavior | `docs/fga-contract.md`, `docs/indexer-contract.md`, `docs/event-processing.md`, `docs/itx-proxy-implementation.md`, `docs/tracing.md`, `docs/api-contracts.md`, `docs/api-contracts/*.md`, `docs/service-helm-chart.md` |
| `lfx-v2-mailing-list-service` | Mailing-list API, ITX proxy behavior, v1 datastream processing, FGA emissions, index documents, mailing-list-service chart behavior | `docs/api-endpoints.md`, `docs/fga-contract.md`, `docs/indexer-contract.md`, `docs/event-processing.md`, `docs/service-helm-chart.md` |
| `lfx-v2-voting-service` | Voting API, ITX proxy behavior, event processing, FGA emissions, index documents, voting-service chart behavior | `docs/api-contracts.md`, `docs/event-processing.md`, `docs/fga-contract.md`, `docs/glossary.md`, `docs/indexer-contract.md`, `docs/itx-proxy-implementation.md`, `docs/service-helm-chart.md` |
| `lfx-v2-survey-service` | Survey API, ITX proxy behavior, event processing, FGA emissions, index documents, survey-service chart behavior | `docs/fga-contract.md`, `docs/indexer-contract.md`, `docs/event-processing.md`, `docs/itx-proxy-implementation.md`, `docs/api-contracts.md`, `docs/api-contracts/*.md`, `docs/service-helm-chart.md` |
| `lfx-v2-member-service` | Membership reads, Salesforce/NATS integration, project ID mapping, Salesforce cache behavior, member-service chart behavior | `docs/agent-guidance/salesforce-integration.md`, `docs/agent-guidance/salesforce-cache.md`, `.claude/skills/member-service-dev/references/nats-messaging.md`, `docs/service-helm-chart.md` |
| `lfx-v2-email-service` | Transactional email NATS contract, public email payloads, email engagement tracking, SES/SQS event handling, email-service chart behavior | `docs/email-service-contract.md`, `docs/email-engagement-tracking.md`, `docs/service-helm-chart.md` |
| `lfx-v2-newsletter-service` | Newsletter HTTP API, draft persistence, sent-state transition, recipient resolution, open tracking, analytics, newsletter-service chart behavior | `docs/newsletter-service-contract.md`, `docs/recipient-resolution.md`, `docs/service-helm-chart.md` |
| `lfx-v2-auth-service` | Auth/profile runtime behavior, identity/profile service contracts, profile events, auth-service chart behavior | `docs/email_lookups.md`, `docs/email_verification.md`, `docs/identity_linking.md`, `docs/impersonation.md`, `docs/password_management.md`, `docs/user_emails.md`, `docs/user_metadata.md`, `docs/username_lookups.md`, `docs/profile-events.md`, `docs/indexer-contract.md`, `docs/service-helm-chart.md` |
| `lfx-v2-access-check` | HTTP access-check API wrapper and access-check chart behavior | `docs/access-check-contract.md`, `docs/service-helm-chart.md` |
| `lfx-v2-query-service` | Query API, OpenSearch reads, indexed data types, resource catalog | `docs/query-service-contract.md`, `docs/indexed-data-types.md`, `docs/resource-catalog.md` |
| `lfx-v2-indexer-service` | Generic indexer envelope, OpenSearch document writes, index event consumption | `docs/indexer-contract.md`, `docs/client-guide.md`, `.claude/rules/indexer-contract.md` |
| `lfx-v2-fga-sync` | Generic FGA envelope, tuple sync, protected types, cache, access-check semantics | `docs/fga-sync-contract.md`, `docs/fga-protected-types.md`, `docs/client-guide.md`, `docs/fga-catalog.md` |
| `lfx-v2-helm` | Shared platform chart, local platform setup, service chart conventions, OpenFGA model | `docs/platform-chart.md`, `docs/local-platform-getting-started.md`, `docs/service-chart-patterns.md`, `docs/openfga.md`, `PERMISSIONS.md`, `charts/lfx-platform/templates/openfga/model.yaml` |
| `lfx-v2-argocd` | Deployed environment values, chart pins, image tags, ApplicationSets, ExternalSecret manifests | `CLAUDE.md`, `apps/<env>/`, `values/`, `custom-resources/`, `docs/agent-guidance/` while migration is in progress |
| `lfx-v2-invite-service` | Invite-service skeleton/readiness handoff. Live invite/application implementation belongs to `lfx-v2-committee-service` until this repo has real service code. | `CLAUDE.md`, `docs/agent-guidance/platform-readiness-handoff.md`, `docs/agent-guidance/new-service-readiness.md`, `.claude/skills/invite-service-readiness/SKILL.md` |
| `lfx-v2-persona-service` | Persona/navigation summary contract, user-involvement reads, CDP/Snowflake cache behavior, persona-service chart behavior | `CLAUDE.md`, `ARCHITECTURE.md`, `docs/agent-guidance/nats-messaging.md`, `docs/service-helm-chart.md` |
| `lfx-v1-sync-helper` | v1/v2 ID mapping service, WAL/Dynamo stream replication, Meltano backfills, and v1 bridge research | `AGENTS.md`, `README.md`, `cmd/lfx-v1-sync-helper/README.md`, `research/` |

## Cross-Cutting Ownership

| Owned truth | Owner | Where to read |
| --- | --- | --- |
| Repo work mode, local context order, review gate | Owning repo | `CLAUDE.md` |
| Repo-local coding conventions | Owning service/app repo | `.claude/skills/<short-repo-name>-dev/`, `.claude/rules/`, or repo-local skill named in `CLAUDE.md` |
| Self Serve Angular/BFF/shared-package work | `lfx-self-serve` | `CLAUDE.md`, `.claude/skills/self-serve-dev/SKILL.md`, `.claude/skills/preflight/SKILL.md`, `.claude/rules/`, `docs/architecture/`, `docs/reviews/` |
| Resource-specific FGA emissions | Owning resource or wrapper service | `docs/fga-contract.md` |
| Generic FGA envelope, tuple sync, cache, and NATS access-check semantics | `lfx-v2-fga-sync` | `docs/fga-sync-contract.md`, `docs/fga-protected-types.md`, `docs/client-guide.md`, `docs/fga-catalog.md` |
| OpenFGA authorization model | `lfx-v2-helm` | `charts/lfx-platform/templates/openfga/model.yaml`, `docs/openfga.md` |
| Endpoint authorization rules | Owning service/app repo | `charts/<repo-name>/templates/ruleset.yaml` |
| Resource-specific index documents and index events | Owning resource or wrapper service | `docs/indexer-contract.md` |
| Generic indexer envelope, OpenSearch document writes, and index event consumption | `lfx-v2-indexer-service` | `docs/indexer-contract.md`, `docs/client-guide.md`, `.claude/rules/indexer-contract.md` |
| Query API and OpenSearch read behavior | `lfx-v2-query-service` | `docs/query-service-contract.md`, `docs/indexed-data-types.md`, `docs/resource-catalog.md` |
| Access-check HTTP API and service chart behavior | `lfx-v2-access-check` | `docs/access-check-contract.md`, `docs/service-helm-chart.md` |
| Auth/profile runtime behavior and profile events | `lfx-v2-auth-service` | `docs/email_lookups.md`, `docs/email_verification.md`, `docs/identity_linking.md`, `docs/impersonation.md`, `docs/password_management.md`, `docs/user_emails.md`, `docs/user_metadata.md`, `docs/username_lookups.md`, `docs/profile-events.md`, `docs/service-helm-chart.md` |
| Auth0 tenant control plane | `auth0-terraform` | Terraform/OpenTofu resources in that repo |
| ITX wrapper plumbing and v1 ID mapping client behavior | Owning wrapper service plus central ITX skill | Wrapper repo `docs/itx-proxy-implementation.md`, `docs/event-processing.md`, `docs/api-contracts.md`, `docs/api-contracts/*.md`, and `/lfx-skills:lfx-itx-integration` |
| v1 bridge, WAL/Dynamo stream replication, and `lfx.lookup_v1_mapping` server | `lfx-v1-sync-helper` | `AGENTS.md`, `README.md`, `cmd/lfx-v1-sync-helper/README.md`, `research/`, and repo-local code |
| Service-local Helm chart templates/defaults | Owning service/app repo | `charts/<repo-name>/` |
| Shared platform chart, platform dependencies, local stack, and shared chart conventions | `lfx-v2-helm` | `charts/lfx-platform/`, `docs/platform-chart.md`, `docs/local-platform-getting-started.md`, `docs/service-chart-patterns.md` |
| Deployed environment state, values, pins, image tags, previews, and ExternalSecret manifests | `lfx-v2-argocd` | `CLAUDE.md`, `apps/<env>/`, `values/`, `custom-resources/`, `docs/agent-guidance/` while migration is in progress |
| Local fixture load/reset behavior | `lfx-v2-mockdata` | `CLAUDE.md`, `.claude/skills/load-mock-data/SKILL.md`, `README.md`, `Makefile`, `playbooks/`, `scripts/setup-env.sh`, `scripts/reset-data.sh`, `scripts/mock-heimdall-jwt.sh` |
| Invite-service readiness handoff | `lfx-v2-invite-service` | `CLAUDE.md`, `docs/agent-guidance/platform-readiness-handoff.md`, `docs/agent-guidance/new-service-readiness.md`, `.claude/skills/invite-service-readiness/SKILL.md` |
| Member Salesforce integration and cache behavior | `lfx-v2-member-service` | `CLAUDE.md`, `docs/agent-guidance/salesforce-integration.md`, `docs/agent-guidance/salesforce-cache.md` |
| Transactional email delivery and email engagement tracking | `lfx-v2-email-service` | `CLAUDE.md`, `docs/email-service-contract.md`, `docs/email-engagement-tracking.md` |
| Newsletter API, recipient resolution, and email-service group handoff | `lfx-v2-newsletter-service` | `CLAUDE.md`, `docs/newsletter-service-contract.md`, `docs/recipient-resolution.md` |
| Persona/navigation summary behavior | `lfx-v2-persona-service` | `CLAUDE.md`, `ARCHITECTURE.md`, `docs/agent-guidance/nats-messaging.md`, `docs/service-helm-chart.md` |
