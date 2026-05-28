<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Repo Map

Map version: `2026-05-28.1`

This is the agent-facing ownership and classifier index for the `/lfx` skill and `lfx-claude`. Use it to match task language to the owning repo, decide which peers may matter, then hand off to repo-local setup. It is not an implementation guide and should not duplicate repo-owned rules.

## How to Use This Map

1. Match the user's nouns against the "route when the task mentions" phrases.
2. Pick the repo that owns the code, contract, chart layer, deployment layer, or product surface being changed.
3. Add default peers only when their contracts, consumers, platform behavior, or deployment state are relevant.
4. If a required repo is not present at the workspace root, clone its `GitHub:` URL into `$LFX_DEV_ROOT/<Path>`.
5. Once routed, stop using this central map for implementation detail. The primary repo's local setup owns the detailed work plan. For cross-repo contract ownership, read `contract-ownership.md`, then the owner repo's `CLAUDE.md` and the top-level `docs/` contract files it names.

## Ownership Model

Ownership means "the repo whose code, contract, deployment layer, or docs own the implementation truth." Peer repos may still need to be read when the owning repo emits data, consumes data, or changes deployment behavior.

After choosing a primary repo, hand off to that repo's local setup:

- `CLAUDE.md` owns the repo work mode, review gate, and local context order.
- Top-level `docs/` files own contracts, subjects, payloads, chart handoffs, integration details, deployment surfaces, and other repo-owned truth that agents from other repos may need. Stable examples include `docs/fga-contract.md`, `docs/indexer-contract.md`, `docs/fga-sync-contract.md`, `docs/query-service-contract.md`, and `docs/service-chart-patterns.md`.
- `.claude/rules/`, `.claude/skills/`, hooks, architecture docs, review docs, contracts, and KBs own implementation and review detail.
- If a repo lacks a `CLAUDE.md` or equivalent local setup, treat that as a repo-readiness gap. Do not fill the gap by growing central implementation instructions.
- Central reviewer-agent prompt files may name repo-specific docs to read, but repo-specific findings must come from the owning repo's local setup and contracts.

`docs/agent-guidance/` is a transitional location from the fan-out pass. Use it
only when a repo entry below explicitly lists it. Otherwise, prefer the
top-level `docs/` contract files named by `CLAUDE.md`.

The `GitHub:` field is the clone/read fallback when the `Path:` directory is
missing locally. Clone into the workspace root using the `Path:` value as the
directory name. If the clone fails because of auth, network, or missing access,
report the repo as blocked rather than substituting central guidance for local
source truth.

Native resource services usually own their domain model, Goa API, NATS/KV storage, indexer messages, FGA messages, service-local chart templates, and contract docs. Wrapper services usually own proxy behavior, external-system mapping, v1 event sync, and emitted index/FGA data. Platform consumers own the generic indexing, query, and FGA mechanics.

For deployment, deployed app/service repos generally own their own Helm chart under `charts/<repo-name>/`. Route service-local chart templates and defaults to the owning app/service repo. Route only shared platform chart composition and OpenFGA model topology to `lfx-v2-helm`, and deployed environment values or pins to `lfx-v2-argocd`.

For a contract, payload, subject, chart surface, deployment handoff, or
integration detail owned by another repo, use `contract-ownership.md` after
this map identifies the likely owner or peers.

## Repo Classifier

### `lfx-self-serve`

- Path: `lfx-self-serve`
- GitHub: https://github.com/linuxfoundation/lfx-self-serve
- Owns: LFX One / Self Serve Angular app, Express BFF, `@lfx-one/shared`, Self Serve setup, preflight, review lifecycle, review KB, product routes, user-facing workflows, and app-owned chart behavior.
- Local entrypoints: `CLAUDE.md`, `.claude/skills/self-serve-dev/SKILL.md`, `.claude/skills/preflight/SKILL.md`, `.claude/skills/lfx-review-pr/SKILL.md`, `.claude/skills/lfx-self-serve-pr-readiness/SKILL.md`, `.claude/rules/`, `docs/architecture/`, `docs/reviews/`, and service chart under `charts/lfx-self-serve/`.
- Route when the task mentions: Self Serve, LFX One, Angular app, Express BFF, shared package, meetings UI, committees UI, dashboard UI, PCC, Admin Mode, persona UI, persona-based navigation UI, persona product consumption, L2 navigation.
- Default peers: `lfx-v2-query-service`, `lfx-v2-fga-sync`
- Handoff: Start in `lfx-self-serve` because local setup owns Angular, BFF, shared-package, review lifecycle, and app-chart detail.
- Notes: Canonical Self Serve / LFX One implementation owner. Legacy `lfx-v2-ui` names are deployment or chart names, not a separate implementation target.

### `lfx-v2-project-service`

- Path: `lfx-v2-project-service`
- GitHub: https://github.com/linuxfoundation/lfx-v2-project-service
- Owns: Project resource API, project RPC subjects, NATS/KV storage, project model contracts, project indexer messages, project FGA messages, and service-local chart templates/defaults.
- Local entrypoints: `CLAUDE.md`, service chart under `charts/lfx-v2-project-service/`, and local conventions under `.claude/skills/project-service-dev/`. Contract docs are listed in `contract-ownership.md`.
- Route when the task mentions: project API, projects, project field, project resource, project RPC, project NATS KV.
- Default peers: `lfx-v2-indexer-service`, `lfx-v2-fga-sync`, `lfx-v2-query-service`, `lfx-self-serve`
- Handoff: Start in project-service because it owns project resource contracts and emitted platform data.

### `lfx-v2-committee-service`

- Path: `lfx-v2-committee-service`
- GitHub: https://github.com/linuxfoundation/lfx-v2-committee-service
- Owns: Committee, committee-member, invite, application, and committee-link resource APIs and contracts, plus emitted indexer/FGA data and service-local chart templates/defaults.
- Local entrypoints: `CLAUDE.md`, service chart under `charts/lfx-v2-committee-service/`, and local conventions under `.claude/skills/committee-service-dev/`. Contract docs are listed in `contract-ownership.md`.
- Route when the task mentions: committee, committees, invite, application, committee member, committee link.
- Default peers: `lfx-v2-indexer-service`, `lfx-v2-fga-sync`, `lfx-v2-query-service`, `lfx-self-serve`
- Handoff: Start in committee-service because it owns committee, committee-member, invite, application, and link contracts. If local Claude setup is missing, treat that as repo-readiness work.

### `lfx-v2-meeting-service`

- Path: `lfx-v2-meeting-service`
- GitHub: https://github.com/linuxfoundation/lfx-v2-meeting-service
- Owns: Meeting API, ITX/Zoom proxy behavior, v1 event sync, meeting indexer/FGA data, external-system mapping, and service-local chart templates/defaults.
- Local entrypoints: `CLAUDE.md`, service chart under `charts/lfx-v2-meeting-service/`, and local conventions under `.claude/skills/meeting-service-dev/`. Contract and ITX docs are listed in `contract-ownership.md`.
- Route when the task mentions: meeting, meetings, calendar, Zoom, ITX meeting, meeting event sync.
- Default peers: `lfx-v2-query-service`, `lfx-v2-fga-sync`, `lfx-self-serve`
- Handoff: Start in meeting-service because it owns meeting APIs, proxy behavior, external-system mapping, and event sync.

### `lfx-v2-mailing-list-service`

- Path: `lfx-v2-mailing-list-service`
- GitHub: https://github.com/linuxfoundation/lfx-v2-mailing-list-service
- Owns: Mailing-list API, Groups.io/ITX proxy behavior, v1 stream processors, mailing-list indexer/FGA data, external-system mapping, and service-local chart templates/defaults.
- Local entrypoints: `CLAUDE.md`, service chart under `charts/lfx-v2-mailing-list-service/`, and local conventions under `.claude/skills/mailing-list-service-dev/`. Contract and event docs are listed in `contract-ownership.md`.
- Route when the task mentions: mailing list, mailing lists, Groups.io, mailing list event sync.
- Default peers: `lfx-v2-query-service`, `lfx-v2-fga-sync`, `lfx-self-serve`
- Handoff: Start in mailing-list-service because it owns mailing-list APIs, proxy behavior, external-system mapping, and event sync.

### `lfx-v2-voting-service`

- Path: `lfx-v2-voting-service`
- GitHub: https://github.com/linuxfoundation/lfx-v2-voting-service
- Owns: Voting API, ITX proxy behavior, voting event processing, voting indexer/FGA data, external-system mapping, and service-local chart templates/defaults.
- Local entrypoints: `CLAUDE.md`, service chart under `charts/lfx-v2-voting-service/`, and local conventions under `.claude/skills/voting-service-dev/`. Contract and ITX docs are listed in `contract-ownership.md`.
- Route when the task mentions: vote, voting, poll, polls, voting event sync.
- Default peers: `lfx-v2-query-service`, `lfx-v2-fga-sync`, `lfx-self-serve`
- Handoff: Start in voting-service because it owns voting APIs, proxy behavior, external-system mapping, and event processing.

### `lfx-v2-survey-service`

- Path: `lfx-v2-survey-service`
- GitHub: https://github.com/linuxfoundation/lfx-v2-survey-service
- Owns: Survey API, ITX proxy behavior, survey event processing, survey indexer/FGA data, external-system mapping, and service-local chart templates/defaults.
- Local entrypoints: `CLAUDE.md`, service chart under `charts/lfx-v2-survey-service/`, and local conventions under `.claude/skills/survey-service-dev/`. Contract and ITX docs are listed in `contract-ownership.md`.
- Route when the task mentions: survey, surveys, NPS, survey event sync.
- Default peers: `lfx-v2-query-service`, `lfx-v2-fga-sync`, `lfx-self-serve`
- Handoff: Start in survey-service because it owns survey APIs, proxy behavior, external-system mapping, and event processing.

### `lfx-v2-member-service`

- Path: `lfx-v2-member-service`
- GitHub: https://github.com/linuxfoundation/lfx-v2-member-service
- Owns: Membership reads, Salesforce/NATS integration, project ID mapping, membership-facing service behavior, and service-local chart templates/defaults when present.
- Local entrypoints: `CLAUDE.md` and local conventions under `.claude/skills/member-service-dev/`. Membership, Salesforce, NATS, and chart docs are listed in `contract-ownership.md`.
- Route when the task mentions: member, membership, Salesforce, project ID mapping.
- Default peers: `lfx-self-serve`
- Handoff: Start in member-service because it owns membership reads and Salesforce mapping.

### `lfx-v2-email-service`

- Path: `lfx-v2-email-service`
- GitHub: https://github.com/linuxfoundation/lfx-v2-email-service
- Owns: Transactional email NATS request/reply contract, public email-service `pkg/api` payloads, pre-rendered SMTP/SES delivery, email engagement tracking records in NATS KV, SES/SQS engagement event handling, and service-local chart templates/defaults.
- Local entrypoints: `CLAUDE.md`, service chart under `charts/lfx-v2-email-service/`, local conventions under `.claude/skills/email-service-dev/`, and contract docs listed in `contract-ownership.md`.
- Route when the task mentions: email service, transactional email, send email NATS subject, `lfx.email-service.*`, SES delivery, SES engagement events, email open/delivery/bounce/complaint tracking, email tracking KV, email group analytics.
- Default peers: `lfx-v2-newsletter-service`, `lfx-self-serve`
- Handoff: Start in email-service because it owns the email NATS contract, SMTP delivery behavior, engagement tracking records, and service-local chart surfaces.

### `lfx-v2-newsletter-service`

- Path: `lfx-v2-newsletter-service`
- GitHub: https://github.com/linuxfoundation/lfx-v2-newsletter-service
- Owns: Newsletter HTTP API, draft persistence, draft-to-sent state transition, recipient preview/count behavior, local open tracking, newsletter analytics, Postgres schema, query-service recipient-resolution client, email-service `groupId` handoff, and service-local chart templates/defaults.
- Local entrypoints: `CLAUDE.md`, service chart under `charts/lfx-v2-newsletter-service/`, local conventions under `.claude/skills/newsletter-service-dev/`, and contract docs listed in `contract-ownership.md`.
- Route when the task mentions: newsletter, newsletters, newsletter draft, newsletter send, newsletter recipients, recipient-count, newsletter analytics, newsletter opens, email-service groupId handoff.
- Default peers: `lfx-v2-query-service`, `lfx-v2-committee-service`, `lfx-v2-email-service`, `lfx-self-serve`
- Handoff: Start in newsletter-service because it owns newsletter persistence, API behavior, recipient resolution orchestration, analytics, and chart surfaces. Add query-service or committee-service only when the task changes upstream recipient lookup or indexed committee-member data.

### `lfx-v2-persona-service`

- Path: `lfx-v2-persona-service`
- GitHub: https://github.com/linuxfoundation/lfx-v2-persona-service
- Owns: Persona/navigation summary contract for user involvement, persona read behavior, and service-local chart templates/defaults when present.
- Local entrypoints: `CLAUDE.md`, `ARCHITECTURE.md`, and `docs/agent-guidance/*.md`. Persona docs are listed in `contract-ownership.md`.
- Route when the task mentions: persona, personas, navigation summary, involvement.
- Default peers: `lfx-self-serve`
- Handoff: Start in persona-service because it owns persona and navigation summary contracts.

### `lfx-v2-invite-service`

- Path: `lfx-v2-invite-service`
- GitHub: https://github.com/linuxfoundation/lfx-v2-invite-service
- Owns: Skeleton/status ownership only until substantial invite-service code exists. Live invite and application behavior currently belongs to `lfx-v2-committee-service`.
- Local entrypoints: `CLAUDE.md` and local readiness workflow under `.claude/skills/invite-service-readiness/`. Readiness docs are listed in `contract-ownership.md`.
- Route when the task mentions: invite service skeleton, invite service readiness, standalone invite service status.
- Default peers: `lfx-v2-committee-service`
- Handoff: Route standalone invite-service readiness work here. Route live invite/application API implementation to committee-service unless this repo has since grown real service code.

### `lfx-v2-auth-service`

- Path: `lfx-v2-auth-service`
- GitHub: https://github.com/linuxfoundation/lfx-v2-auth-service
- Owns: Runtime auth/profile abstraction over Auth0/Authelia, local auth behavior, identity/profile service contracts, impersonation service behavior, Auth0 runtime integration, and service-local chart templates/defaults.
- Local entrypoints: `CLAUDE.md`, service chart under `charts/lfx-v2-auth-service/`, and local conventions under `.claude/skills/auth-service-dev/`. Auth/profile docs are listed in `contract-ownership.md`.
- Route when the task mentions: auth runtime, profile API, identity service, Authelia runtime integration, Auth0 runtime integration, impersonation service behavior, user/profile service contract.
- Default peers: `lfx-self-serve`
- Handoff: Start in auth-service because it owns identity/profile runtime behavior and impersonation service contracts. Add `auth0-terraform` only when the change requires Auth0 tenant resources such as clients, audiences, grants, scopes, Actions, token exchange configuration, or connections.
- Notes: Plain Auth0 tenant/client/grant/action work routes to `auth0-terraform`, not here. Deployed `AUTH0_*` values and secret references route to `lfx-v2-argocd`; secret values and rotation are a DevOps/CloudOps handoff.

### `auth0-terraform`

- Path: `auth0-terraform`
- GitHub: https://github.com/linuxfoundation/auth0-terraform
- Owns: Auth0 tenant configuration for Linux Foundation SSO: Auth0 clients/applications, resource servers/API audiences, client grants/scopes, Actions and custom token-exchange actions, Auth0 connections, DB connection scripts, tenant settings, log streams, and OpenTofu plan/apply/import workflow for those Auth0 resources. Also owns the Intercom JWT custom-claim Action.
- Route when the task mentions: Auth0 tenant config, Auth0 client/application setup, callback URL, logout URL, Auth0 API audience, Auth0 resource server, Auth0 scope, client grant, Auth0 Action, custom token exchange, LFX V2 API audience, LFX V2 Auth Service Auth0 client, LFX One Auth0 client, Profile Auth0 client, passwordless email connection, username/password connection, social or enterprise connection config, Auth0 Terraform, OpenTofu for Auth0, Intercom JWT claim, Intercom custom_claims Action, Intercom identity verification JWT.
- Default peers: `lfx-v2-auth-service`, `lfx-v2-argocd`
- Handoff: Start in `auth0-terraform` when the implementation truth is an Auth0 resource in Terraform/OpenTofu. Add auth-service for runtime auth/profile behavior, and add ArgoCD for deployed environment values, secret references, or application wiring. For app-side Intercom work in a consuming app, use the central `/lfx-skills:lfx-intercom` skill.
- Notes: This repo configures Auth0 resources; it does not own app auth behavior, service chart defaults, deployed overlays, ExternalSecret references, or secret values. Do not ask for or print Auth0 client secrets or private keys. Secret value/source/rotation work is a DevOps/CloudOps handoff through the `lfx-secrets-management` flow; deployed `AUTH0_*` env wiring remains an `lfx-v2-argocd` concern.

### `identity-cookie-helper`

- Path: `identity-cookie-helper`
- GitHub: https://github.com/linuxfoundation/identity-cookie-helper
- Owns: Auth0-to-Intercom OAuth2 bridge, identify-page rendering, route-specific CSP, and Intercom Admin hostname allow-list coordination.
- Route when the task mentions: identity-cookie-helper, Intercom identity bridge, identify page, Intercom CSP, Intercom hostname allow-list, Auth0-to-Intercom bridge.
- Default peers: `auth0-terraform`, `lfx-v2-argocd`
- Handoff: Start in `identity-cookie-helper` for bridge runtime behavior. Add `auth0-terraform` for Auth0 control-plane claims and `lfx-v2-argocd` for deployed values or ExternalSecret references.

### Intercom integration (cross-repo)

Intercom is split across four boundaries; route the task to the boundary that owns the change:

- **Auth0 control plane** -> `auth0-terraform` owns the `custom_claims` Action that emits the `http://lfx.dev/claims/intercom` JWT. See `auth0-terraform/docs/agent-guidance/intercom-auth0-claims.md` for mechanics and the `/auth0-intercom-claim` skill for the workflow.
- **Identity bridge** -> `identity-cookie-helper` owns the Auth0-to-Intercom OAuth2 bridge, identify-page rendering, route-specific CSP, and Intercom Admin hostname allow-list coordination. See `identity-cookie-helper/docs/agent-guidance/intercom-identity-bridge.md` and the `/intercom-identity-bridge` skill.
- **App-side integration** -> use the retained central `/lfx-skills:lfx-intercom` skill for the Intercom workflow. The consuming app repo still owns the actual integration code and framework-specific implementation. Current active consumers: `insights` (Nuxt/Vue 3), `crowd.dev` (Vite/Vue 3). Historical Angular consumers: Mentorship, Crowdfunding, PCC. Self Serve is not currently an Intercom consumer.
- **Deployed values** -> `lfx-v2-argocd` owns `AUTH0_*`, `INTERCOM_APP_ID`, and ExternalSecret references under `values/{env}/` and `custom-resources/<app>/`. See `lfx-v2-argocd/docs/agent-guidance/auth0-intercom-deployed-values.md`.

Route phrases: Intercom, Intercom identity verification, Intercom JWT, identity-cookie-helper, intercom-app, identify page, Intercom CSP, Intercom hostname allow-list.

### `lfx-v2-query-service`

- Path: `lfx-v2-query-service`
- GitHub: https://github.com/linuxfoundation/lfx-v2-query-service
- Owns: Search/read aggregation API, OpenSearch query behavior, pagination/filter/sort semantics, count behavior, access filtering, generic resource reads, and query-service chart templates/defaults.
- Local entrypoints: `CLAUDE.md`, service chart under `charts/lfx-v2-query-service/`, and local conventions under `.claude/skills/query-service-dev/`. Query contract docs are listed in `contract-ownership.md`.
- Route when the task mentions: query, search, resources, OpenSearch, pagination, filter, filters, access filtering.
- Default peers: `lfx-v2-indexer-service`, `lfx-v2-fga-sync`
- Handoff: Start in query-service because it owns generic search, read, pagination, and access-filtering behavior.

### `lfx-v2-indexer-service`

- Path: `lfx-v2-indexer-service`
- GitHub: https://github.com/linuxfoundation/lfx-v2-indexer-service
- Owns: Index event consumption, OpenSearch document writes, domain event emission from platform indexing, generic indexing behavior, and indexer-service chart templates/defaults.
- Local entrypoints: `CLAUDE.md`, service chart under `charts/lfx-v2-indexer-service/`, `.claude/rules/indexer-contract.md`, and local conventions under `.claude/skills/indexer-service-dev/`. Indexer contract docs are listed in `contract-ownership.md`.
- Route when the task mentions: indexer, indexing, search document, OpenSearch document, index event.
- Default peers: `lfx-v2-query-service`
- Handoff: Start in indexer-service because it owns generic index-event consumption and OpenSearch writes.

### `lfx-v2-fga-sync`

- Path: `lfx-v2-fga-sync`
- GitHub: https://github.com/linuxfoundation/lfx-v2-fga-sync
- Owns: FGA event consumption, OpenFGA tuple writes/reads/checks, access-check NATS behavior, FGA cache behavior, and fga-sync chart templates/defaults.
- Local entrypoints: `CLAUDE.md`, service chart under `charts/lfx-v2-fga-sync/`, and local conventions under `.claude/skills/fga-sync-dev/`. FGA contract docs are listed in `contract-ownership.md`.
- Route when the task mentions: FGA, OpenFGA, authorization tuple, tuple, access data, access-check NATS, FGA cache.
- Default peers: `lfx-v2-access-check`, `lfx-v2-query-service`
- Handoff: Start in fga-sync because it owns generic tuple sync, checks, and cache behavior.

### `lfx-v2-access-check`

- Path: `lfx-v2-access-check`
- GitHub: https://github.com/linuxfoundation/lfx-v2-access-check
- Owns: HTTP Goa wrapper around NATS/OpenFGA access checks, access-check API contract, and access-check chart templates/defaults.
- Local entrypoints: `CLAUDE.md`, service chart under `charts/lfx-v2-access-check/`, and local conventions under `.claude/skills/access-check-dev/`. Access-check docs are listed in `contract-ownership.md`.
- Route when the task mentions: access check, permission check, authorization check, access-check API.
- Default peers: `lfx-v2-fga-sync`
- Handoff: Start in access-check because it owns the HTTP access-check API wrapper.

### `lfx-v2-helm`

- Path: `lfx-v2-helm`
- GitHub: https://github.com/linuxfoundation/lfx-v2-helm
- Owns: `charts/lfx-platform`, shared/local platform install behavior, platform dependency composition, umbrella subchart wiring, OpenFGA authorization model, Gateway/Traefik/Heimdall/NATS/OpenSearch/OpenFGA topology, External Secrets Operator as a platform dependency, and platform chart release mechanics.
- Local entrypoints: `CLAUDE.md` and platform chart under `charts/lfx-platform/`. Platform chart and OpenFGA docs are listed in `contract-ownership.md`.
- Route when the task mentions: Helm, local platform, LFX platform chart, `charts/lfx-platform`, OpenFGA model, Gateway, Traefik, Heimdall, NATS, OpenSearch, platform dependency, umbrella chart, platform chart.
- Default peers: `lfx-v2-argocd`
- Handoff: Start in Helm because it owns shared local platform composition and OpenFGA model topology.
- Notes: `lfx-v2-helm` does not own every service-local chart template. Route service chart templates and defaults to the owning service/app repo unless the task is about how the service chart is consumed as a dependency of `charts/lfx-platform`.

### `lfx-v2-argocd`

- Path: `lfx-v2-argocd`
- GitHub: https://github.com/linuxfoundation/lfx-v2-argocd
- Owns: `apps/<env>/` Applications/ApplicationSets, deployed app membership, namespaces, chart source type, source revisions and chart pins, `values/global` plus environment overlays, image tags, deployed custom resources, ExternalSecret/SecretStore manifests, preview deployment wiring, and promotion mechanics.
- Local entrypoints: `CLAUDE.md`, `apps/<env>/`, `values/`, and `custom-resources/`. Deployment handoff docs are listed in `contract-ownership.md`.
- Route when the task mentions: ArgoCD, GitOps, app membership, namespace, environment values, image tag, chart pin, targetRevision, ApplicationSet, preview deployment, promotion, custom resources, ExternalSecrets, SecretStores, deployed secret references.
- Default peers: `lfx-v2-helm`
- Handoff: Start in ArgoCD because it owns deployed environment state and promotion mechanics.
- Notes: Dev often deploys from source repo `path: charts/...` with `targetRevision: HEAD`; staging/prod generally use GHCR OCI chart entries with pinned chart versions. Secrets may originate from the DevOps/CloudOps-managed secrets manager / `lfx-secrets-management` flow, but that is not a normal implementation route. Agents should not ask for or print secret values; treat source secret definitions, AWS Secrets Manager paths/tags, service tags, and values as a DevOps/CloudOps handoff unless the task is explicitly about ArgoCD references or ExternalSecrets manifests.

### `lfx-v2-mockdata`

- Path: `lfx-v2-mockdata`
- GitHub: https://github.com/linuxfoundation/lfx-v2-mockdata
- Owns: Local fixture loading/reset tooling through APIs, NATS requests, NATS KV writes, seed data, and local data reset behavior.
- Local entrypoints: `CLAUDE.md`, `.claude/skills/load-mock-data/SKILL.md`, `README.md`, `Makefile`, `playbooks/`, `scripts/setup-env.sh`, `scripts/reset-data.sh`, and `scripts/mock-heimdall-jwt.sh`.
- Route when the task mentions: mockdata, fixture, fixtures, reset data, seed data.
- Default peers: `lfx-v2-helm`
- Handoff: Start in mockdata because it owns local fixture load, reset, and seed behavior.

### `lfx-mcp`

- Path: `lfx-mcp`
- GitHub: https://github.com/linuxfoundation/lfx-mcp
- Owns: Hosted LFX MCP server, AI tool contract surfaces, semantic tool behavior, MCP package/runtime behavior, and hosted tool access.
- Route when the task mentions: MCP, semantic tool, hosted tool, semantic layer, AI tool contract.
- Default peers: `lfx-lens`
- Handoff: Start in `lfx-mcp` because it owns hosted MCP server and AI tool contract surfaces.

### `lfx-lens`

- Path: `lfx-lens`
- GitHub: https://github.com/linuxfoundation/lfx-lens
- Owns: Lens product/workflow runtime, semantic model sync, Lens KB/eval/session debugging, and Snowflake enforcement behavior.
- Route when the task mentions: Lens, semantic model, semantic sync, Lens workflow, Snowflake enforcement.
- Default peers: `lfx-mcp`
- Handoff: Start in `lfx-lens` because it owns Lens workflows, semantic models, and runtime behavior.

### `member-onboarding`

- Path: `member-onboarding`
- GitHub: https://github.com/linuxfoundation/member-onboarding
- Owns: LFX Member Onboarding AI automation, Agno/FastAPI backend, member-onboarding agents and prompts, onboarding rules/config snapshots, Snowflake membership queries, and the `demo-ui` Next.js frontend.
- Route when the task mentions: member onboarding, onboarding agent, onboarding rules, onboarding config snapshot, Slack onboarding, email onboarding, Discord onboarding, member-onboarding demo UI.
- Default peers: none.
- Handoff: Start in `member-onboarding` for member-onboarding agents, prompts, rules, data flow, and demo UI behavior.

### `lfx-ui`

- Path: `lfx-ui`
- GitHub: https://github.com/linuxfoundation/lfx-ui
- Owns: Shared UI core package, design tokens, vanilla web components, browser bundles, Storybook, package exports, and package release behavior.
- Route when the task mentions: UI core, design token, web component, Storybook, package release.
- Default peers: `lfx-self-serve`
- Handoff: Start in `lfx-ui` because it owns UI core tokens, web components, Storybook, and package release. Do not import Self Serve Angular app rules here.

### `lfx-changelog`

- Path: `lfx-changelog`
- GitHub: https://github.com/linuxfoundation/lfx-changelog
- Owns: Separate Angular/Express/Prisma/OpenSearch product, GitHub App webhooks, Slack OAuth, AI generation flows, and changelog MCP package behavior.
- Route when the task mentions: changelog, GitHub App webhook, Slack OAuth, Prisma, changelog MCP.
- Default peers: none.
- Handoff: Start in changelog because it is a separate product and owns its own app platform rules.

### `insights`

- Path: `insights`
- GitHub: https://github.com/linuxfoundation/insights
- Owns: LF Insights Nuxt/Vue app, Insights server APIs, PostgreSQL data access, Tinybird analytics integration, app-side Auth0 flow, Storybook/docs surfaces, and its app-side Intercom plugin.
- Route when the task mentions: Insights, LF Insights, insights frontend, Nuxt Insights, Tinybird analytics, Insights Auth0, Insights Intercom plugin.
- Default peers: `auth0-terraform`, `identity-cookie-helper`, `lfx-v2-argocd`
- Handoff: Start in `insights` for Insights app/runtime behavior. Use `/lfx-skills:lfx-intercom` for the central Intercom workflow, but keep actual plugin changes in this repo.

### `lfx-skills`

- Path: `lfx-skills`
- GitHub: https://github.com/linuxfoundation/lfx-skills
- Owns: Central Claude Code runtime skills, topology map, repo map, reviewer-agent prompt source files, and Claude plugin package.
- Route when the task mentions: central dev AI, platform map, repo map, central reviewer agent prompts, Claude plugin package.
- Default peers: none.
- Handoff: Start in `lfx-skills` for central runtime assets, routing, and reviewer-agent prompt files.
- Notes: Claude-only central plugin for now. The plugin manifest exposes the skills surface; `agents/` contains explicit reviewer-agent prompt files. Do not add agents.md, Codex, OpenCode, or extra install surfaces unless project scope changes.

### `crowd.dev`

- Path: `crowd.dev`
- GitHub: https://github.com/linuxfoundation/crowd.dev
- Owns: CDP Snowflake connector implementation code and templates, CDP frontend behavior, and its app-side Intercom integration. The connector scaffolding workflow remains the retained central `/lfx-skills:lfx-cdp-snowflake-connectors` skill.
- Route when the task mentions: CDP, Snowflake connector, CDP Snowflake connectors, crowd.dev frontend, CDP Intercom plugin.
- Default peers: `auth0-terraform`, `identity-cookie-helper`, `lfx-v2-argocd` for Intercom work; otherwise none.
- Handoff: For Snowflake connector scaffolding, invoke `/lfx-skills:lfx-cdp-snowflake-connectors`; it uses `crowd.dev` as the target implementation repo. For Intercom app work, use `/lfx-skills:lfx-intercom`, but keep actual plugin changes in this repo.

## Cross-Cutting Reference Repos

### `lfx-architecture`

- Path: `lfx-architecture`
- GitHub: https://github.com/linuxfoundation/lfx-architecture
- Owns: Published Architecture Team standards, recommendations, and cross-platform diagrams (LFX data flow, secrets workflows, repository layout best-practices, GTM restrictions, OSS transition checklist, private-key client auth, Postman setup). Read-only reference; no runtime code.
- Route when the task mentions: architecture standards, architecture review, architecture team, LFX best practices, architecture diagram, secrets workflow standard, repository setup standard, open source transition checklist.
- Default peers: none.
- Handoff: Read `lfx-architecture` references when a contributor needs the canonical LF best practice or platform diagram. Implementation work routes to the owning runtime repo, not here.
- Notes: For prototypes, historical migration guides, and scratch material, see the sibling `lfx-architecture-scratch` repo (out of scope for routing in normal sessions).

## V1 Bridge / Legacy Sync

### `lfx-v1-sync-helper`

- Path: `lfx-v1-sync-helper`
- GitHub: https://github.com/linuxfoundation/lfx-v1-sync-helper
- Owns: Real-time replication of v1 PostgreSQL WAL events and DynamoDB Streams into the `v1-objects` NATS KV bucket (consumed by V2 wrapper services for indexer/FGA pipelines), Meltano backfills, bidirectional sync for projects and committees between LFX v1 and LFX One, and the v1/v2 ID mapping service that answers the `lfx.lookup_v1_mapping` NATS request/reply contract used by every ITX wrapper.
- Local entrypoints: `AGENTS.md`, `README.md`, `cmd/lfx-v1-sync-helper/README.md`, and `research/`.
- Route when the task mentions: v1 sync, v1-sync-helper, v1-to-v2 replication, `v1-objects` bucket, WAL listener, Meltano, DynamoDB Streams, project v1/v2 sync, committee v1/v2 sync, `lfx.lookup_v1_mapping`, v1 SFID to v2 UUID mapping, v1/v2 ID mapper service.
- Default peers: `lfx-v2-meeting-service`, `lfx-v2-voting-service`, `lfx-v2-survey-service`, `lfx-v2-mailing-list-service` (consumer wrappers); `lfx-v2-project-service`, `lfx-v2-committee-service` (sync targets).
- Handoff: Start in `lfx-v1-sync-helper` for changes to the WAL listener, Meltano taps, replication pipeline, sync-helper service, or the `lfx.lookup_v1_mapping` server implementation. Wrapper-side consumption belongs to the consuming wrapper repo; ID-mapping client patterns belong to the `/lfx-skills:lfx-itx-integration` skill.

## Legacy Names

### `lfx-v2-ui`

- Canonical repo: `lfx-self-serve`
- Note: Legacy deployment and chart naming; route implementation knowledge to `lfx-self-serve`.

## Ambiguity Rules

- Prefer the repo where most edits should happen as the primary repo.
- Add peer repos only when their contracts, generated APIs, platform consumers, deployment values, or product behavior must be inspected or changed.
- If a task says "UI" but describes Self Serve/LFX One behavior, route to `lfx-self-serve`, not `lfx-ui`.
- If a task says "UI core", "design tokens", "web components", or Storybook package release, route to `lfx-ui`.
- If a task says `lfx-v2-ui`, normalize it to `lfx-self-serve` unless the work is explicitly about legacy chart or Argo names.
