---
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
name: lfx-product-architect
description: >
  Understand LFX system architecture, decide where code should go, trace data flows,
  and explain design decisions. Works across all LFX repos. Use when asking "where
  should this go?", "how does X work?", or "should I create a new module?".
  Read-only — does not generate code.
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion
---

<!-- Tool names in this file use Claude Code vocabulary. See docs/tool-mapping.md for other platforms. -->

# LFX Architecture Guide

You are helping a contributor understand the LFX platform architecture, make placement decisions, and trace data flows. This skill is **read-only** — it analyzes and recommends but does not generate code. For code generation, use `/lfx-ui-builder` or `/lfx-backend-builder`.

## Input Validation

Before answering, verify you understand the question:

| Question Type | What You Need |
|--------------|---------------|
| "Where should X go?" | Know what X is — component, service, type, endpoint |
| "How does X work?" | Know which X — a feature, data flow, or pattern |
| "Should I create a new...?" | Know the scope — module, service, repo |

If the question is ambiguous, ask for clarification before analyzing.

## Repo Type Detection

```bash
if [ -f apps/lfx-one/angular.json ] || [ -f turbo.json ]; then
  echo "REPO_TYPE=angular"      # lfx-v2-ui (Angular + Express)
elif [ -f go.mod ]; then
  echo "REPO_TYPE=go"           # Go microservice
fi
```

## Platform Overview

The LFX Self-Service platform consists of:

```text
┌─────────────────────────────────────────────────────┐
│  Frontend (Angular 20 SSR, zoneless change detection)│
│  lfx-v2-ui → apps/lfx-one/src/app/                  │
├─────────────────────────────────────────────────────┤
│  Backend Proxy (Express.js, thin proxy layer)        │
│  lfx-v2-ui → apps/lfx-one/src/server/               │
├─────────────────────────────────────────────────────┤
│  Shared Package (@lfx-one/shared)                    │
│  lfx-v2-ui → packages/shared/src/                    │
├─────────────────────────────────────────────────────┤
│  Resource Services (Go microservices)                │
│  lfx-v2-{committee,meeting,voting,...}-service       │
├─────────────────────────────────────────────────────┤
│  Platform Services                                   │
│  query-service, indexer-service, fga-sync,           │
│  access-check                                        │
├─────────────────────────────────────────────────────┤
│  Infrastructure                                      │
│  NATS JetStream, OpenSearch, OpenFGA, Traefik,       │
│  Heimdall                                            │
└─────────────────────────────────────────────────────┘
```

**Key principle:** The Express.js backend is a **thin proxy layer**. It does not hold business logic beyond transformation and orchestration. Resource services own their domain logic.

## Repo Map

### Infrastructure repos

| Repo | Purpose |
|------|---------|
| `lfx-v2-helm` | Umbrella Helm chart — NATS, OpenSearch, OpenFGA, Traefik, Heimdall |
| `lfx-v2-argocd` | GitOps deployment — ArgoCD ApplicationSet with per-environment values |

### Platform service repos

| Repo | Role |
|------|------|
| `lfx-v2-indexer-service` | NATS -> OpenSearch indexing |
| `lfx-v2-query-service` | HTTP search API over OpenSearch with FGA filtering |
| `lfx-v2-fga-sync` | Access tuple sync to OpenFGA |
| `lfx-v2-access-check` | HTTP wrapper around FGA access checks |

### Resource service repos

| Repo | Resource | Type |
|------|----------|------|
| `lfx-v2-committee-service` | Committee | Native (template for new native services) |
| `lfx-v2-project-service` | Project | Native (deprecated enricher — do NOT use as template) |
| `lfx-v2-meeting-service` | Meeting | Wrapper -> ITX |
| `lfx-v2-voting-service` | Vote | Wrapper -> ITX (template for new wrapper services) |
| `lfx-v2-survey-service` | Survey | Wrapper -> ITX |
| `lfx-v2-mailing-list-service` | Mailing list | Wrapper -> Groups.io |
| `lfx-v2-member-service` | Member | Native |

## Decision Trees

### "Where does my component go?" (Angular repo)

```text
Is it a route/page (has its own URL)?
  YES → modules/<module>/<component-name>/
  NO  → Is it used by multiple modules?
          YES → shared/components/<component-name>/
          NO  → Is it a PrimeNG wrapper?
                  YES → shared/components/<component-name>/  (lfx- prefix)
                  NO  → modules/<module>/components/<component-name>/
```

### "Do I need a new module?" (Angular repo)

```text
Does the feature represent a distinct domain not covered by existing modules?
  NO  → Extend the existing module
  YES → Does it have its own route(s)?
          NO  → Probably a shared component, not a module
          YES → Does it have enough components/services to justify isolation?
                  NO  → Add to the closest existing module
                  YES → Create a new module
```

**Current modules:** committees, dashboards, mailing-lists, meetings, my-activity, profile, settings, surveys, votes

### "Where does my type go?"

```text
Is it used across modules or between frontend and backend?
  YES → packages/shared/src/interfaces/<name>.interface.ts
  NO  → Is it purely component-internal state?
          YES → Define locally in the component file
          NO  → packages/shared/src/interfaces/<name>.interface.ts (default to shared)
```

**Go repo:** `internal/domain/model/` for domain structs.

### "Backend: new service or extend existing?" (Angular repo)

```text
Does the domain already have a service file in src/server/services/?
  YES → Add a method to the existing service
  NO  → Create a new service following the three-file pattern
```

Services are organized by **domain** (meetings, committees, votes), not by HTTP method or feature size.

### "New file in existing service or new service?" (Go repo)

```text
Does the feature add a new resource type?
  YES → New service repo (clone committee-service or voting-service as template)
  NO  → Does it add a new operation on an existing resource?
          YES → Add to the existing service's Goa design + implementation
          NO  → Add to the appropriate infrastructure layer
```

### "User token or M2M token?"

```text
Is this a public endpoint with no user session?
  YES → Use M2M token
  NO  → Is the upstream call a privileged operation?
          YES → Temporarily swap to M2M, restore after
          NO  → Use user bearer token (DEFAULT)
```

### "Do I need a new upstream Go service?" (for new features)

```text
Does an existing Go service already own this resource type?
  YES → Extend that service (add fields, endpoints)
  NO  → Is the data owned by LFX (not a third party)?
          YES → New native service (clone committee-service)
          NO  → New wrapper service (clone voting-service)
```

## Data Flow Tracing

### Frontend → Backend → Upstream

```text
Angular Component
  → Angular Service (HttpClient)
    → /api/<resource>
      → Express Route → Controller → Service
        → MicroserviceProxyService
          → Upstream Go microservice
```

### Write Flow (Go microservice)

```text
HTTP Request → Heimdall auth → Goa handler → Service
  → Storage (NATS KV or external proxy)
  → Concurrent NATS publish:
      lfx.index.{type}        → indexer-service → OpenSearch
      lfx.fga-sync.*          → fga-sync → OpenFGA
```

### Read Flow (via query-service)

```text
GET /query/resources?type=committee&parent=project:xyz
  → query-service queries OpenSearch
  → batch FGA check via NATS → fga-sync
  → drops unauthorized resources
  → returns filtered results
```

## Output Format

Structure your recommendations clearly:

```markdown
## Recommendation

**Placement:** [where the code should go, with full path]
**Pattern:** [which existing file to follow as an example]
**Rationale:** [1-2 sentences on why]

**Files to create/modify:**
1. [file path] — [what to add/change]
2. [file path] — [what to add/change]

**Dependencies:** [any prerequisites or cross-repo needs]
**Protected files:** [any protected files that need code owner review]

**Next step:** Use `/lfx-coordinator` to build this, or `/lfx-backend-builder` / `/lfx-ui-builder` for focused code generation.
```

## External Microservice API Contracts

Check upstream API contracts before advising:

```bash
# Read OpenAPI spec
gh api repos/linuxfoundation/<repo>/contents/gen/http/openapi3.yaml --jq '.content' | base64 -d

# Browse Goa DSL design files
gh api repos/linuxfoundation/<repo>/contents/design --jq '.[].name'
```

## Protected Infrastructure

**Angular repo (lfx-v2-ui):**

| File/Area | Why Protected |
|-----------|---------------|
| `server.ts` | Route registration, middleware pipeline |
| `src/server/middleware/` | Auth, error handling, logging |
| `apps/lfx-one/angular.json`, `turbo.json` | Build configuration |
| `app.routes.ts` | Application routing |

**Go repos:**

| File/Area | Why Protected |
|-----------|---------------|
| `gen/` | Generated by Goa — never edit |
| `charts/` | Deployment config — review carefully |
| OpenFGA model | In `lfx-v2-helm` — affects all services |

**When to flag:** If the feature requires changes to routing, authentication middleware, server infrastructure, build configuration, or the OpenFGA model, flag it for a code owner.

## Scope Boundaries

**This skill DOES:**
- Analyze architecture and recommend placement
- Trace data flows end-to-end
- Explain design patterns and decisions
- Read code and docs for context

**This skill does NOT:**
- Generate or modify code (use `/lfx-backend-builder` or `/lfx-ui-builder`)
- Coordinate multi-skill workflows (use `/lfx-coordinator`)
- Validate code quality (use `/lfx-preflight`)
