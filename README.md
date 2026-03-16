# LFX Skills

A collection of specialized Claude Code skills that encode the full development workflow for the LFX Self-Service platform. These skills turn Claude into a context-aware development partner that understands LFX conventions, architecture, and code patterns — eliminating the need to repeatedly explain project structure, naming rules, or coding standards.

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated
- Access to LFX repositories (for the skills to operate on)

## Installation

### Step 1: Clone this repo

```bash
git clone https://github.com/linuxfoundation/skills.git
```

### Step 2: Install the skills

Claude Code auto-discovers skills from `~/.claude/skills/`. Symlink each skill into that directory:

```bash
# From the cloned repo directory
mkdir -p ~/.claude/skills
for skill in lfx-*/; do
  ln -sf "$(pwd)/$skill" ~/.claude/skills/"$(basename "$skill")"
done
```

This makes all seven `/lfx-*` skills available globally in every Claude Code session.

### Step 3: Verify

Restart Claude Code (or open a new session) in any LFX repo and type `/lfx-` — you should see all seven skills in the autocomplete list:

```
/lfx-coordinator
/lfx-research
/lfx-backend-builder
/lfx-ui-builder
/lfx-product-architect
/lfx-preflight
/lfx-setup
```

### Alternative: Per-repo installation

If you prefer skills scoped to a specific repo instead of global:

```bash
# From inside a target repo (e.g., lfx-v2-ui)
mkdir -p .claude/skills
for skill in /path/to/skills/lfx-*/; do
  ln -sf "$skill" .claude/skills/"$(basename "$skill")"
done

# Keep symlinks out of version control
echo '.claude/skills/' >> .gitignore
```

### Uninstall

```bash
rm -f ~/.claude/skills/lfx-*
```

## Architecture

The skills form a layered system where each skill has a clear responsibility and mode of operation:

```
┌─────────────────────────────────────────────────────────┐
│              /lfx-coordinator (orchestrator)             │
│       Researches, plans, delegates, validates            │
├──────────┬──────────┬───────────────┬───────────────────┤
│ /lfx-    │ /lfx-    │ /lfx-product- │ /lfx-research    │
│ backend- │ ui-      │ architect      │ (read-only       │
│ builder  │ builder  │ (read-only     │  exploration)    │
│ (codegen)│ (codegen)│  guidance)     │                  │
├──────────┴──────────┴───────────────┴───────────────────┤
│  /lfx-preflight (validation)  │  /lfx-setup (env)      │
└───────────────────────────────┴─────────────────────────┘
```

## Skill Overview

| Skill | Purpose | Mode | Tools |
|-------|---------|------|-------|
| `/lfx-coordinator` | Orchestrates full feature development — researches, plans, delegates to builders in parallel, validates | Read + delegate | Bash, Read, Glob, Grep, AskUserQuestion, **Skill** |
| `/lfx-research` | Explores upstream APIs, discovers code patterns, reads architecture docs, validates contracts via MCP | Read-only | Bash, Read, Glob, Grep, AskUserQuestion, **WebFetch** |
| `/lfx-backend-builder` | Generates Express.js proxy endpoints, Go microservice code, shared types. Encodes three-file pattern, logging, Goa DSL, NATS messaging | Code gen | Bash, Read, **Write, Edit**, Glob, Grep, AskUserQuestion |
| `/lfx-ui-builder` | Generates Angular 20 components, services, drawers, pagination UI, styling. Encodes signal patterns, PrimeNG wrappers | Code gen | Bash, Read, **Write, Edit**, Glob, Grep, AskUserQuestion |
| `/lfx-product-architect` | Answers "where should this go?", traces data flows, makes placement decisions, explains design patterns | Read-only | Bash, Read, Glob, Grep, AskUserQuestion |
| `/lfx-preflight` | Pre-PR validation — auto-fixes formatting & license headers, runs lint, build, checks protected files, offers PR creation | Validate + fix | Bash, Read, **Write, Edit**, Glob, Grep, AskUserQuestion |
| `/lfx-setup` | Environment setup — prerequisites, clone, install, env vars, dev server. Adapts to Angular or Go repos | Interactive guide | Bash, Read, Glob, Grep, AskUserQuestion |

---

## Skill Details

### `/lfx-coordinator`

The top-level orchestrator for any feature development. It **never writes code directly** — instead, it researches the codebase, builds a delegation plan, and invokes `/lfx-backend-builder` and `/lfx-ui-builder` in parallel.

**Workflow:**
1. **Setup** — detects repo type (Angular or Go), checks/creates feature branch
2. **Plan** — determines scope, build order (upstream Go → shared types → Express proxy → frontend)
3. **Research** — inline exploration (5–10 tool calls) to find existing patterns, upstream APIs, file paths
4. **Delegation Plan** — outputs a structured plan and **pauses for user approval**
5. **Build** — invokes builder skills **in parallel** via the Skill tool
6. **Validate** — runs format, lint, build across all modified repos
7. **Summary** — structured completion report with files changed, validation results, and next steps

**Key behaviors:**
- Identifies the upstream Go service by reading Express proxy code API paths (e.g., `/committees/...` → `lfx-v2-committee-service`)
- Includes upstream Go service changes when the data model needs modification
- Handles validation failures by re-invoking only the skill that owns the broken file
- Idempotent — safe to re-run after partial completion; detects and skips already-completed work

---

### `/lfx-research`

A **read-only** exploration agent that gathers all context needed before code generation. Returns structured, compact findings (under 30 lines) that the coordinator consumes.

**Research tasks:**
- **Upstream API validation** — reads OpenAPI specs via `gh api` or local files to check if endpoints/fields exist
- **Codebase exploration** — finds existing services, components, controllers, domain models
- **Architecture doc reading** — checks placement rules, protected files, dependencies
- **Example discovery** — finds the closest existing implementation to use as a pattern
- **MCP-assisted exploration** — uses LFX MCP tools to validate live data shapes, Atlassian MCP for JIRA context

**Upstream service mapping:**

| Domain | Repo |
|--------|------|
| Committees | `lfx-v2-committee-service` |
| Meetings | `lfx-v2-meeting-service` |
| Voting | `lfx-v2-voting-service` |
| Mailing Lists | `lfx-v2-mailing-list-service` |
| Members | `lfx-v2-member-service` |
| Projects | `lfx-v2-project-service` |
| Surveys | `lfx-v2-survey-service` |
| Queries | `lfx-v2-query-service` |

---

### `/lfx-backend-builder`

Generates **PR-ready backend code** for both the Express.js proxy layer (in `lfx-v2-ui`) and Go microservices (in `lfx-v2-*-service` repos). Always reads target files before generating code — never works from memory alone.

**Express.js proxy (Angular repo):**
- Follows the **three-file pattern**: service → controller → route
- Services use `MicroserviceProxyService` for all upstream calls (never raw `fetch`/`axios`)
- Controllers use `logger.startOperation()` / `logger.success()` / `logger.error()` lifecycle
- Routes are created but `server.ts` registration is flagged for code owner (protected file)
- Encodes logging conventions, error handling (`next(error)`, never `res.status(500)`), pagination (`page_size`), and auth defaults (user bearer token)

**Go microservices:**
- Goa v3 DSL for API design (`cmd/{service}/design/`) with `make apigen` for code generation
- Domain models in `internal/domain/model/` with `Tags()` method for OpenSearch indexing
- NATS messaging — publish index + access messages on every write operation
- OpenFGA access control via generic fga-sync handlers
- Helm chart updates for deployment, HTTPRoute, Heimdall authorization rules

**Reference docs included:**

| Reference | Content |
|-----------|---------|
| `getting-started.md` | Repo map, deployment overview, local dev setup |
| `goa-patterns.md` | Goa DSL conventions, `make apigen`, ETag/If-Match optimistic locking |
| `nats-messaging.md` | Subject naming, service-to-service communication, KV storage |
| `indexer-patterns.md` | IndexerMessageEnvelope, IndexingConfig, OpenSearch document structure |
| `fga-patterns.md` | OpenFGA tuples, permission inheritance, debugging access |
| `service-types.md` | Native vs wrapper services, which template to follow |
| `query-service.md` | Query service API, OpenSearch queries, FGA-based filtering |
| `helm-chart.md` | Deployment, HTTPRoute, Heimdall rules, KV buckets, secrets |
| `new-service.md` | End-to-end checklist for building a new resource service |
| `backend-endpoint.md` | Three-file pattern, authentication, pagination, error handling |

---

### `/lfx-ui-builder`

Generates **PR-ready Angular 20 frontend code** — components, services, drawers, pagination, and styling. Only activates in Angular repos.

**Components:**
- Standalone with direct imports (no barrel exports)
- Strict 11-section class structure: injections → inputs → forms → model signals → writable signals → computed/toSignal → constructor → public methods → protected methods → private init functions → private helpers
- Signal-based reactivity: `signal()`, `input()`, `output()`, `computed()`, `model()`, `toSignal()`
- Templates use `@if`/`@for` (never `*ngIf`/`*ngFor`), `flex + gap-*` layout (never `space-y-*`), `data-testid` attributes
- PrimeNG components wrapped with `lfx-` prefix and `descendants: false` on `@ContentChild`

**Services:**
- `@Injectable({ providedIn: 'root' })` with `inject(HttpClient)`
- GET requests: `catchError(() => of(default))` for graceful degradation
- POST/PUT/DELETE: `take(1)`, let errors propagate
- Interfaces from `@lfx-one/shared/interfaces`, relative API paths (`/api/...`)

**Drawers:**
- `model<boolean>(false)` for visibility
- Lazy data loading via `toObservable(visible).pipe(skip(1), switchMap(...))`
- `forkJoin` for parallel API calls, responsive width classes

**Pagination:**
- Infinite scroll with `page_token`, `scan()` accumulator, separate first-page and next-page streams

**Reference docs included:**

| Reference | Content |
|-----------|---------|
| `frontend-component.md` | Component placement, class structure, signal types, template rules, drawer conventions |
| `frontend-service.md` | Service patterns, state management, signals vs RxJS guidance |

---

### `/lfx-product-architect`

A **read-only** advisory skill that answers architectural questions without generating code. Provides decision trees, data flow traces, and placement recommendations.

**Decision trees:**
- "Where does my component go?" — route vs module-specific vs shared vs PrimeNG wrapper
- "Do I need a new module?" — distinct domain + own routes + enough isolation
- "Where does my type go?" — shared package vs local definition
- "Backend: new service or extend existing?" — organized by domain, not by HTTP method
- "New Go service or extend existing?" — based on resource type ownership
- "User token or M2M token?" — default to user bearer, M2M only for public/privileged calls

**Data flow tracing:**
- Frontend → Backend → Upstream: Angular component → HttpClient → Express proxy → MicroserviceProxyService → Go microservice
- Write flow: HTTP → Heimdall auth → Goa handler → Storage → concurrent NATS publish (index + FGA)
- Read flow: query-service → OpenSearch → batch FGA check → filtered results

**Platform overview:** Maps the full system from Angular frontend through Express proxy, shared package, resource services, platform services (query, indexer, fga-sync, access-check), down to infrastructure (NATS JetStream, OpenSearch, OpenFGA, Traefik, Heimdall).

---

### `/lfx-preflight`

Runs a comprehensive **pre-PR validation** with auto-fix capabilities. Adapts all checks to the repo type.

**Checks (in order):**
1. **Working tree status** — uncommitted changes, commits ahead of main, JIRA references, `--signoff`
2. **License headers** — verifies and auto-fixes missing headers on `.ts`, `.html`, `.scss`, `.go` files
3. **Formatting** — `yarn format` (Angular) or `gofmt -w .` (Go), reports which files changed
4. **Linting** — `yarn lint` (Angular) or `go vet ./...` (Go), auto-fixes import order/unused imports
5. **Build verification** — `yarn build` (Angular) or `go build ./...` (Go), fixes simple issues
6. **Tests** — runs if test files exist for modified code (doesn't block on failures)
7. **Protected files check** — flags changes to infrastructure files (`server.ts`, middleware, `angular.json`, `gen/`, `charts/`, etc.)
8. **Commit verification** — conventions, signoff, JIRA ticket
9. **Change summary** — categorized list of all new and modified files

**Modes:** Auto-fix (default) or report-only ("dry run"). Offers to commit auto-fixes and create PR when all checks pass.

---

### `/lfx-setup`

An **interactive setup guide** that walks through environment configuration step by step, verifying each step before proceeding.

**Angular repo setup (lfx-v2-ui):**
1. Prerequisites: Node.js v22+, Yarn v4.9.2+, Git
2. Clone the repository
3. Environment variables from `.env.example` + 1Password credentials
4. `yarn install` with troubleshooting for common failures
5. `yarn start` → `http://localhost:4200`
6. Verification with HTTP status check

**Go microservice setup:**
1. Prerequisites: Go 1.22+, Git, Make (optional: Helm, Docker)
2. Clone the repository
3. Environment variables for local or shared dev stack
4. `go mod download && go build ./...`
5. `make apigen` for Goa API code generation
6. `go run cmd/*-api/main.go` → verify `/livez` endpoint
7. Optional: full local platform stack via Helm

**Includes troubleshooting** for common issues: corepack permissions, EACCES errors, port conflicts, auth loops, NATS connection failures, Goa installation.

---

## Typical Workflows

### Build a new feature end-to-end
```
/lfx-coordinator → researches → plans → delegates to /lfx-backend-builder + /lfx-ui-builder → validates → /lfx-preflight → PR
```

### Understand the architecture before coding
```
/lfx-product-architect → "where should this component go?" / "how does the data flow?"
```

### Explore what exists before planning
```
/lfx-research → upstream API contract + codebase patterns + example files
```

### Quick backend-only or frontend-only change
```
/lfx-backend-builder → generates Express proxy + shared types
/lfx-ui-builder → generates Angular component + service
```

### Validate before submitting a PR
```
/lfx-preflight → license headers → format → lint → build → protected files → PR
```

### Set up a new developer environment
```
/lfx-setup → prerequisites → clone → env vars → install → dev server
```

## Project Structure

```
├── lfx-coordinator/
│   ├── SKILL.md                    # Orchestrator — plans, delegates, validates
│   └── references/
│       └── shared-types.md         # Shared package conventions
├── lfx-research/
│   └── SKILL.md                    # Read-only exploration and API validation
├── lfx-backend-builder/
│   ├── SKILL.md                    # Express.js proxy + Go microservice codegen
│   └── references/
│       ├── backend-endpoint.md     # Three-file pattern for Express endpoints
│       ├── fga-patterns.md         # OpenFGA access control patterns
│       ├── getting-started.md      # Repo map and deployment overview
│       ├── goa-patterns.md         # Goa v3 DSL conventions
│       ├── helm-chart.md           # Service Helm chart structure
│       ├── indexer-patterns.md     # OpenSearch indexing patterns
│       ├── nats-messaging.md       # NATS subject naming and messaging
│       ├── new-service.md          # New resource service checklist
│       ├── query-service.md        # Query service API reference
│       └── service-types.md        # Native vs wrapper service types
├── lfx-ui-builder/
│   ├── SKILL.md                    # Angular 20 frontend codegen
│   └── references/
│       ├── frontend-component.md   # Component patterns and conventions
│       └── frontend-service.md     # Service patterns and state management
├── lfx-product-architect/
│   └── SKILL.md                    # Architecture guidance and decision trees
├── lfx-preflight/
│   └── SKILL.md                    # Pre-PR validation and auto-fix
└── lfx-setup/
    └── SKILL.md                    # Environment setup guide
```

## License

This project is licensed under the [MIT License](LICENSE).
