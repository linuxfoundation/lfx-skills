# LFX Skills

Central Claude Code plugin for LFX development. Bundles the canonical LFX architecture knowledge, cross-repo workflow skills, and post-commit reviewer agents that every LFX contributor needs. Each LFX repo's local setup (`CLAUDE.md`, `.claude/rules/`, `.claude/skills/`, `docs/agent-guidance/`) calls out to this plugin for cross-repo topology, platform conventions, and review automation.

## Install

In Claude Code:

```text
/plugin marketplace add linuxfoundation/lfx-skills
/plugin install lfx-skills@lfx-skills
```

Restart Claude Code, then open any LFX repo and invoke `/lfx-skills:lfx` (or `/lfx` if your environment has no naming collision). The router auto-detects your context and points you at the right skill, repo, or reference.

For other AI coding assistants that support skills, see [docs/platform-install.md](docs/platform-install.md).

## How It Works

Type `/lfx-skills:lfx` and describe what you want in plain language:

- **"Where does the meeting data flow live?"** — the router classifies the task and points at the owning repos plus the relevant central skill.
- **"I'm adding a new V2 resource service"** — routes you to `/lfx-skills:lfx-platform-architecture` for the platform shape and `/lfx-skills:lfx-service-conventions` for Go code conventions.
- **"Add or fix Intercom in this app"** — routes to `/lfx-skills:intercom-app-integration`.
- **"Catch me up on my open PRs"** — routes to `/lfx-skills:lfx-pr-catchup`.

The plugin assumes you have a workspace with LFX repos checked out (typically `~/lfx/`, `~/lf/`, or similar). The `/lfx` router will ask once if it cannot find a workspace root.

## What's Inside

### Central architecture skills (5)

Canonical LFX knowledge that lives in this plugin and is referenced by every LFX repo's local setup. These are *not* implementation recipes; they hand off to the owning repo for detail.

| Skill | Purpose |
|---|---|
| `/lfx` | Cross-repo topology and ownership router; entry point for any multi-repo task or "where does X live" question. |
| `/lfx-platform-architecture` | V2 platform shape (Goa, NATS, KV, OpenFGA, indexer, query, Heimdall) and service taxonomy (native vs wrapper vs proxy). |
| `/lfx-service-conventions` | V2 Go service code conventions: structured logging with slog, pagination contract, domain `ErrorType` enum, request-context propagation, test patterns. |
| `/lfx-itx-integration` | ITX wrapper patterns: OAuth2 M2M tokens, v1 KV sync, NATS ID mapping via `lfx.lookup_v1_mapping`. |
| `/intercom-app-integration` | Two paths: (1) Intercom widget integration for consumer apps (Vue/Nuxt, Vue/Vite, Angular); (2) Fin AI optimization (Fin Guidance, Help Center content quality, resolution rate). |

### Workflow skills (6)

Cross-repo developer workflows that apply across every LFX repo.

| Skill | Purpose |
|---|---|
| `/lfx-setup` | Environment setup for any LFX repo (Angular or Go). Prerequisites, clone, install, env vars, dev server. |
| `/lfx-git-setup` | Interactive DCO sign-off plus GPG-signed commit setup. Required for all LFX repos. |
| `/lfx-pr-catchup` | Morning PR catch-up dashboard: unresolved comments, status changes, stale PRs, approved-but-not-merged across all your open PRs. |
| `/lfx-pr-resolve` | Address PR review comments, post follow-up summary, dismiss stale "changes requested" reviews, re-request review. |
| `/lfx-test-journey` | Combine feature branches across repos into git worktrees for end-to-end journey testing. |
| `/lfx-snowflake-access` | Request Snowflake access or service accounts via the `lfx-snowflake-terraform` repo. |

### Platform skill (1)

| Skill | Purpose |
|---|---|
| `/lfx-v2-ticket-writer` | Create a single LFXV2 Jira ticket via guided prompts; requirement-focused descriptions, reproduction steps for bugs. |

### Reviewer agents (3)

Post-commit code reviewers that LFX repos invoke after every pre-PR commit. Launched in parallel as subagents via the `Agent` tool. `lfx-self-serve` is the primary consumer today; the general reviewer is repo-agnostic.

| Agent | Purpose |
|---|---|
| `lfx-skills:lfx-general-code-reviewer` | Generic senior-reviewer pass: correctness, security, performance, maintainability, tests, code truthfulness. No repo-specific rulebook. |
| `lfx-skills:lfx-self-serve-code-reviewer` | Convention audit against `lfx-self-serve`'s `.claude/rules/`, `docs/reviews/` checklists, architecture docs, and upstream API contracts. |
| `lfx-skills:lfx-self-serve-learnings-reviewer` | Empirical pattern matcher against `lfx-self-serve/docs/reviews/knowledge-base/` (patterns sampled from past PR review comments). |

Each agent locates its owning repo at runtime and uses repo-qualified paths for multi-repo sessions. See each agent's prompt under `agents/` for the exact invocation contract.

## Project Structure

```text
.
├── .claude-plugin/
│   ├── plugin.json              # Claude plugin manifest (name: lfx-skills)
│   └── marketplace.json         # Marketplace manifest (name: lfx-skills)
├── skills/
│   ├── lfx/                     # central topology router
│   ├── lfx-platform-architecture/
│   ├── lfx-service-conventions/
│   ├── lfx-itx-integration/
│   ├── intercom-app-integration/
│   ├── lfx-setup/
│   ├── lfx-git-setup/
│   ├── lfx-pr-catchup/
│   ├── lfx-pr-resolve/
│   ├── lfx-test-journey/
│   ├── lfx-snowflake-access/
│   └── lfx-v2-ticket-writer/
├── agents/
│   ├── lfx-general-code-reviewer.md
│   ├── lfx-self-serve-code-reviewer.md
│   └── lfx-self-serve-learnings-reviewer.md
├── docs/                        # plugin docs (platform install, tool mapping)
├── install.sh                   # CLI installer for non-Claude-Code platforms
├── LICENSE
├── LICENSE-docs
├── README.md
└── SECURITY.md
```

Skill bodies live under `skills/<name>/SKILL.md`; supporting files live under `skills/<name>/references/` and are loaded on demand.

## Prerequisites

- Claude Code (`claude.ai/code`) is the primary supported environment for this plugin.
- A workspace root with your LFX repos checked out. The `/lfx` router will ask once if it cannot find one.
- Access to the LFX repositories you intend to work on.

For non-Claude-Code AI assistants that support skills, see [docs/platform-install.md](docs/platform-install.md).

## License

MIT. See [LICENSE](LICENSE).
