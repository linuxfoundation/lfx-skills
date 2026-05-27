---
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
name: lfx
description: >
  LFX cross-repo topology and ownership router. Use when the task spans more
  than one LFX repo, asks "which repo owns X", "where does Y live", "what
  repos does this touch", "what consumes Z", or needs a peer-repo file path
  from inside a single repo. Loads per-repo configs when invoked from the
  LFX workspace root with a full task prompt; gives targeted cross-repo
  guidance when invoked from inside a single repo. Also answers LFX glossary
  and topology questions. Do not fire for single-repo implementation tasks
  where the active repo's own CLAUDE.md already governs (those belong to
  the repo's local skills). Do not fire for V2 platform composition (use
  `/lfx-platform-architecture`), V2 Go conventions
  (`/lfx-service-conventions`), ITX wrapper plumbing
  (`/lfx-itx-integration`), or app-side Intercom integration
  (`/intercom-app-integration`).
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion
---

# LFX

Find which LFX repos are needed for a task, load their configs, give
cross-repo guidance, or answer LFX questions.

Three scenarios:

1. **Load configs** for multi-repo work (workspace-root invocation with a
   full task prompt or JIRA ticket).
2. **Give guidance** when an agent inside a single repo needs cross-repo
   knowledge.
3. **Answer questions** about LFX when no edits are coming.

## Finding the LFX workspace root

The workspace root (parent directory containing all LFX repo checkouts)
varies per user (`~/lfx/`, `~/lf/`, etc.). Find it before referencing
peer-repo paths. Ask the user if unsure (and offer `/lfx-setup` to persist).
Use `$LFX_DEV_ROOT` throughout this skill's paths.

## How LFX fits together (high-level)

LFX is the Linux Foundation's project-management platform. Three main layers:

- **Self Serve / LFX One** (`lfx-self-serve`): user-facing product (Angular 20
  SSR + Express BFF + `@lfx-one/shared`). Consumes V2 APIs.
- **V2 platform** (~14 Go services): resource services own domain (project,
  committee, meeting, vote, survey, mailing-list, member); platform services
  compose (fga-sync, indexer, query, access-check, auth). Built on Goa + NATS
  + KV + OpenFGA. Writes publish contracts to fga-sync (access tuples) and
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

Then, depending on context:

### Workspace-root invocation (full task prompt, JIRA ticket, etc.)

The primary mode for multi-repo work. Load configs for the primary repo and
each peer:

- Read `$LFX_DEV_ROOT/<repo>/CLAUDE.md` (or `AGENTS.md` if that's the real file)
- Browse `$LFX_DEV_ROOT/<repo>/.claude/rules/` for path-scoped conventions
- Browse `$LFX_DEV_ROOT/<repo>/.claude/skills/` for available workflows
- Browse `$LFX_DEV_ROOT/<repo>/docs/agent-guidance/` (or `docs/architecture/`
  for Self Serve)

Work continues in the same session with the loaded context.

### Single-repo invocation (cross-repo knowledge request)

Give targeted guidance: name the specific peer-repo files the asking agent
should read (at `$LFX_DEV_ROOT/<peer-repo>/<path>`) and any constraints to
apply. Skip the full config load; the asking agent's session is what matters
and may not need everything. If the work is genuinely multi-repo, recommend
relaunching from `$LFX_DEV_ROOT`.

### Pure question (no edits coming)

Use references plus forward to sibling skills for depth. Skip the full
config load.

## How to use the references

- **`references/glossary.md`**: read FIRST if an LFX term is unclear (Goa,
  Heimdall, FGA, OpenFGA, OpenSearch, etc.). Skip for routing decisions.
- **`references/repo-map.md`**: the primary tool for identifying primary
  and peer repos. Match task nouns to "route when the task mentions" phrases.
- **`references/routing-playbook.md`**: read only when `repo-map.md` doesn't
  give a clear answer or when the task spans multiple repos. Contains
  concrete primary/peer examples.
- **`references/deployment-routing.md`**: read INSTEAD of `repo-map.md` for
  deployment-related tasks (charts, ApplicationSets, image tags, environment
  values). It's the deployment-specific decision tree.
- **`references/topology.md`** and **`references/service-types.md`**: thin
  routing stubs. For platform-shape or service-classification depth, forward
  to `/lfx-platform-architecture` instead of expanding these.

Never load all references by default. Start with the smallest one.

## Sibling central skills

Each auto-fires on its own triggers; can also be invoked explicitly. These
ship in this same `lfx-skills` plugin.

| Topic | Skill |
|---|---|
| Platform shape, service taxonomy, NATS naming, Heimdall coordination | `/lfx-platform-architecture` |
| V2 Go service code conventions (logger, pagination, errors, context) | `/lfx-service-conventions` |
| ITX wrapper patterns (OAuth2 M2M, ID mapping, v1 KV sync) | `/lfx-itx-integration` |
| Intercom widget in consumer apps (Vue/Nuxt, Vue/Vite, Angular) | `/intercom-app-integration` |

## Workflow skills (this plugin)

Six workflow skills ship alongside the architecture skills in this same
`lfx-skills` plugin. Forward to them by name when relevant.

| Topic | Skill |
|---|---|
| Onboarding and first-time setup | `/lfx-setup` |
| DCO and GPG signing | `/lfx-git-setup` |
| Cross-repo personal PR dashboard | `/lfx-pr-catchup` |
| GitHub PR review threads | `/lfx-pr-resolve` |
| Local multi-branch journey worktrees | `/lfx-test-journey` |
| Snowflake access requests | `/lfx-snowflake-access` |

## Cross-repo path convention

Agent-guidance docs across LFX repos use **repo-qualified paths**, not
relative filesystem paths:

```
lfx-v2-indexer-service/docs/agent-guidance/indexer-patterns.md
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
