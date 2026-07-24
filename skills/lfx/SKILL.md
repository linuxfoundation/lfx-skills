---
name: lfx
description: >
  LFX cross-repo topology and ownership router. Use when the task spans more
  than one LFX repo, asks "which repo owns X", "where does Y live", "what
  repos does this touch", "what consumes Z", or needs a peer-repo file path
  from inside a single repo. Loads per-repo configs when invoked from the
  LFX workspace root with a full task prompt; gives targeted cross-repo
  guidance when invoked from inside a single repo. Also answers LFX glossary
  and topology questions, and performs read-only discovery when the user asks
  whether a contract, API, event, field, workflow, or repo capability exists.
  Do not fire for single-repo implementation tasks
  where the active repo's own CLAUDE.md already governs (those belong to
  the repo's local skills). Do not fire for V2 platform composition, service
  classes, or cross-service handoffs (use
  `/lfx-skills:lfx-platform-architecture`), ITX wrapper plumbing
  (`/lfx-skills:lfx-itx-integration`), or Intercom app/Fin workflows
  (`/lfx-skills:lfx-intercom`).
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion
---

<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# LFX

Find which LFX repos are needed for a task, load their configs, give
cross-repo guidance, or answer LFX questions.

Four scenarios:

1. **Load configs** for multi-repo work (workspace-root invocation with a
   full task prompt or JIRA ticket).
2. **Give guidance** when an agent inside a single repo needs cross-repo
   knowledge.
3. **Answer questions** about LFX when no edits are coming.
4. **Research before implementation** when the user asks what exists, what a
   task would touch, or whether an upstream contract supports a change.

## Finding the LFX workspace root

The workspace root (parent directory containing all LFX repo checkouts)
varies per user (`~/lfx/`, `~/lf/`, etc.). Find it before referencing
peer-repo paths. Ask the user if unsure (and offer `/lfx-skills:lfx-setup` to persist).
Use `$LFX_DEV_ROOT` throughout this skill's paths.

If a required repo is not present at `$LFX_DEV_ROOT/<repo>`, read its
`GitHub:` URL from `references/repo-map.md` and clone it into the workspace
root:

```bash
git clone <github-url> "$LFX_DEV_ROOT/<repo>"
```

If the clone fails because of auth, network, or missing access, report that
repo as blocked. Do not replace the missing repo with central implementation
guesses.

## How LFX fits together (high-level)

LFX is the Linux Foundation's project-management platform. Three main layers:

- **Self Serve / LFX One** (`lfx-self-serve`): user-facing product (Angular 20
  SSR + Express BFF + `@lfx-one/shared`). Consumes V2 APIs.
- **V2 platform** (~14 Go services): resource services own domain (project,
  committee, meeting, vote, survey, mailing-list, member); platform services
  compose (fga-sync, indexer, query, access-check, auth). Built on Goa + NATS
  - KV + OpenFGA. Writes publish contracts to fga-sync (access tuples) and
    indexer (search documents).
- **Deployment**: GitOps via ArgoCD. Service-local Helm charts per repo;
  umbrella chart + OpenFGA model in `lfx-v2-helm`; values, image tags, and
  ApplicationSets in `lfx-v2-argocd`. Auth0 emits JWTs, Heimdall enforces
  ruleset checks per route, fga-sync answers access decisions.

Depth lives in the sibling skills below.

## Workflow

Three steps apply to every scenario:

1. **Classify** the task or question. Read `references/glossary.md` if any
   LFX term is unclear.
2. **Identify the primary repo** via `references/repo-map.md`. The primary
   is where most edits happen and whose local instructions govern.
3. **Identify peer repos** (if any) via `repo-map.md` plus (when ambiguous)
   `routing-playbook.md`. Add peers only for contracts, generated APIs,
   FGA/indexer data, deployment values, or product consumption that matter.
4. **Resolve missing checkouts** by cloning the `GitHub:` URL listed in
   `repo-map.md` when a primary or required peer repo is absent locally.
5. **Read owned truth from the owner repo**. Use `CLAUDE.md` for local work
   mode and the top-level `docs/` files it names for contracts and other
   repo-owned truth that other agents may consume.

Then, depending on context:

### Workspace-root invocation (full task prompt, JIRA ticket, etc.)

The primary mode for multi-repo work. Load configs for the primary repo and
each peer.

For each repo:

- If `$LFX_DEV_ROOT/<repo>` is missing, clone the repo from the `GitHub:` URL
  in `references/repo-map.md`, then continue with local reads.
- Load `$LFX_DEV_ROOT/<repo>/CLAUDE.md`
- Load `$LFX_DEV_ROOT/<repo>/.claude/rules/` for path-scoped conventions
- Load `$LFX_DEV_ROOT/<repo>/.claude/skills/` for available workflows
- Read the top-level `docs/` contract files named by that repo's `CLAUDE.md`
  when cross-repo contracts, payloads, subjects, chart handoffs,
  integrations, or deployment surfaces matter.
- Browse `$LFX_DEV_ROOT/<repo>/docs/agent-guidance/` only when
  `references/repo-map.md` explicitly lists that path as a transitional owner
  location for the repo. For Self Serve, use `docs/architecture/` when
  `CLAUDE.md` or local skills point there.

Work continues in the same session with the loaded context.

### Single-repo invocation (cross-repo knowledge request)

Give targeted guidance: name the specific peer-repo files the asking agent
should read (at `$LFX_DEV_ROOT/<peer-repo>/<path>`) and any constraints to
apply. Skip the full config load; the asking agent's session is what matters
and may not need everything. If the work is genuinely multi-repo, recommend
relaunching from `$LFX_DEV_ROOT`.

### Cross-repo contract lookup

Use this protocol when an agent in one repo needs a contract, payload, subject,
chart surface, deployment handoff, or integration detail owned by another repo.
Do not infer cross-repo contracts from local examples.

1. Resolve the owner repo using `references/repo-map.md`.
2. If `$LFX_DEV_ROOT/<owner-repo>` is missing, clone the `GitHub:` URL from
   `repo-map.md` into the workspace root.
3. Read `references/contract-ownership.md` for the exact owner files for the
   contract, payload, subject, chart surface, deployment handoff, or integration
   detail being checked.
4. Read `$LFX_DEV_ROOT/<owner-repo>/CLAUDE.md` or `AGENTS.md` for that repo's
   local context order.
5. Read the top-level `docs/` files named by that repo's `CLAUDE.md` for the
   relevant owned contract.
6. Prefer stable top-level contract docs such as `docs/fga-contract.md`,
   `docs/indexer-contract.md`, `docs/fga-sync-contract.md`,
   `docs/query-service-contract.md`, or `docs/service-chart-patterns.md`
   when present.
7. Report the exact owner file read. If the path is absent, report a
   repo-readiness gap instead of substituting central guidance.

### Pure question (no edits coming)

Use references plus forward to sibling skills for depth. Skip the full
config load.

### Research before implementation

Use this mode for read-only discovery before an implementation starts. It
preserves the useful research workflow without adding another central skill.

1. Route the task to the primary repo and required peers using the repo map.
2. Ensure the required repos are available locally; clone missing repos from
   their `GitHub:` URLs if needed.
3. Read the owning repo's local truth: `CLAUDE.md` or `AGENTS.md`, relevant
   top-level `docs/` contract files, `.claude/skills/`, `.claude/rules/`,
   `docs/architecture/`, generated contracts, chart templates, or event docs.
   Use `docs/agent-guidance/` only where `repo-map.md` explicitly lists it as a
   transitional owner location.
4. Validate whether the needed API, event, field, relation, index document,
   query shape, chart value, or deployment reference exists.
5. Find the closest existing example in the owning repo first. Use peer repos
   only when the owner points to them as canonical examples.
6. Return concise findings:

```markdown
## Research Findings

**Primary repo:** <repo> - <why it owns the work>
**Peers:** <repo list or none> - <why each matters>
**Contract status:** <exists / partial / missing>. <path, method, subject, field, relation, value>
**Local truth read:** <CLAUDE/rules/skills/docs paths>
**Closest example:** <path> - <why it matches>
**Likely files:** <paths or "implementation belongs in repo-local workflow">
**Blockers:** <none or concrete missing contract/access/repo issue>
**Next step:** <repo-local skill or central skill to use next>
```

## How to use the references

- **`references/glossary.md`**: read FIRST if an LFX term is unclear (Goa,
  Heimdall, FGA, OpenFGA, OpenSearch, etc.). Skip for routing decisions.
- **`references/repo-map.md`**: the primary tool for identifying primary
  and peer repos. Match task nouns to "route when the task mentions" phrases.
- **`references/contract-ownership.md`**: read after `repo-map.md` when an
  agent needs the exact owner and file path for a cross-repo contract,
  payload, subject, chart surface, deployment handoff, integration detail, or
  other repo-owned truth.
- **`references/routing-playbook.md`**: read only when `repo-map.md` doesn't
  give a clear answer or when the task spans multiple repos. Contains
  concrete primary/peer examples.
- **`references/deployment-routing.md`**: read INSTEAD of `repo-map.md` for
  deployment-related tasks (charts, ApplicationSets, image tags, environment
  values). It's the deployment-specific decision tree.
- **`references/topology.md`**: thin routing stub. For platform-shape depth,
  forward to `/lfx-skills:lfx-platform-architecture` instead of expanding it.
- **`references/service-types.md`**: thin routing stub. For native, wrapper,
  proxy, or V2 Go service-class depth, forward to
  `/lfx-skills:lfx-platform-architecture`.

Never load all references by default. Start with the smallest one.

## Sibling central skills

Each auto-fires on its own triggers; can also be invoked explicitly. These
ship in this same `lfx-skills` plugin.

| Topic                                                                                      | Skill                                                 |
|--------------------------------------------------------------------------------------------|-------------------------------------------------------|
| Platform composition, V2 service classes, write/read/access-check flows, cross-repo owners | `/lfx-skills:lfx-platform-architecture`               |
| Go coding conventions after routing to a service repo                                      | That repo's path-scoped `<short-repo-name>-dev` skill |
| ITX wrapper plumbing (OAuth2 M2M, ID mapping, v1 KV sync)                                  | `/lfx-skills:lfx-itx-integration`                     |
| Intercom app workflow and Fin AI optimization                                              | `/lfx-skills:lfx-intercom`                            |
| Object storage capability in a service (uploads, S3, CDN, local dev)                       | `/lfx-skills:lfx-object-store-design`                 |
| Object storage backend provisioning (buckets, CloudFront, IRSA)                            | `/lfx-skills:lfx-object-store-ops`                    |

### `-ops` skill convention

Skills whose names end in `-ops` are for **members of the linuxfoundation
GitHub org** (Ops/infrastructure audience). Before loading an `-ops` skill,
validate that the current GitHub user is an org member (for example,
`gh api orgs/linuxfoundation/members/$(gh api user -q .login)` — a `204`
means member). If membership cannot be confirmed, do not load the `-ops`
skill; use the corresponding design skill instead.

## Workflow skills (this plugin)

Seven workflow skills ship alongside the architecture skills in this same
`lfx-skills` plugin. Forward to them by name when relevant.

| Topic                                | Skill                                      |
|--------------------------------------|--------------------------------------------|
| Onboarding and first-time setup      | `/lfx-skills:lfx-setup`                    |
| DCO and GPG signing                  | `/lfx-skills:lfx-git-setup`                |
| Cross-repo personal PR dashboard     | `/lfx-skills:lfx-pr-catchup`               |
| GitHub PR review threads             | `/lfx-skills:lfx-pr-resolve`               |
| Local multi-branch journey worktrees | `/lfx-skills:lfx-test-journey`             |
| Snowflake access requests            | `/lfx-skills:lfx-snowflake-access`         |
| CDP Snowflake connector scaffolding  | `/lfx-skills:lfx-cdp-snowflake-connectors` |

## Cross-repo path convention

Cross-repo references use **repo-qualified paths**, not relative filesystem
paths:

```
lfx-v2-indexer-service/docs/indexer-contract.md
```

That's the file inside `lfx-v2-indexer-service`, regardless of disk layout.
Resolve by reading at `$LFX_DEV_ROOT/<repo>/<path>` or `Glob`/`find` if
unsure. Never assume `../../<repo>/`.

## Hard rules

- Don't teach implementation recipes (Angular, Goa, Helm, ArgoCD,
  query-service, FGA, etc.) using this skill. Point to the owning repo or
  a sibling skill instead.
- Don't provide repo-specific setup, preflight, test, build, or deploy
  commands without reading that repo's current instructions this turn.
- Don't assert live deployment state, service health, or production behavior
  from this skill alone.
- `lfx-self-serve` is the canonical Self Serve repo; legacy deployment
  artifacts may say `lfx-v2-ui`, which is deployment naming only.
