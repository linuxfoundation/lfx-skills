<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# LFX Skills

Central Claude Code plugin for LFX development. Bundles the canonical LFX architecture knowledge, cross-repo workflow skills, and post-commit reviewer agents that every LFX contributor needs. Each LFX repo's local setup (`CLAUDE.md`, `.claude/rules/`, `.claude/skills/`, and repo-owned `docs/`) calls out to this plugin for cross-repo topology, platform conventions, and review automation.

## Install

In Claude Code:

```text
/plugin marketplace add linuxfoundation/lfx-skills
/plugin install lfx-skills@lfx-skills
```

Restart Claude Code, then open any LFX repo and invoke `/lfx-skills:lfx` (or `/lfx` if your environment has no naming collision). The router auto-detects your context and points you at the right skill, repo, or reference.

### Codex and other Agent Skills tools

LFX skills follow the open Agent Skills (`SKILL.md`) standard, so OpenAI Codex and
similar tools can use them too. Clone this repo and run `./install.sh` to symlink
the skills into your user-global Agent Skills directory (`~/.agents/skills/`);
`./update.sh` re-syncs after a `git pull`, and `./uninstall.sh` removes them. See
[docs/platform-install.md](docs/platform-install.md) for details.

## How It Works

Type `/lfx-skills:lfx` and describe what you want in plain language:

- **"Where does the meeting data flow live?"** — the router classifies the task and points at the owning repos plus the relevant central skill.
- **"I'm adding a new V2 resource service"** — routes you to `/lfx-skills:lfx-platform-architecture` for platform flow, service class, and cross-service handoff points; the owning repo's path-scoped guidance handles Go conventions.
- **"Does this API already exist?"** — `/lfx-skills:lfx` runs a read-only research pass to verify owning repos, contracts, examples, and blockers before implementation.
- **"Generate a new silver dbt model"** — routes to `/lfx-skills:lfx-data-engineer` for medallion-layer conventions, sqlfluff formatting, tests, and dbt validation guidance.
- **"Add or fix Intercom in this app"** — routes to `/lfx-skills:lfx-intercom`.
- **"Add a CDP Snowflake connector"** — routes to `/lfx-skills:lfx-cdp-snowflake-connectors`.
- **"Catch me up on my open PRs"** — routes to `/lfx-skills:lfx-pr-catchup`.

The plugin assumes you have a workspace with LFX repos checked out (typically `~/lfx/`, `~/lf/`, or similar). The `/lfx` router will ask once if it cannot find a workspace root. If a required repo is missing from that root, `/lfx` uses the GitHub URL in its repo map to clone it before reading repo-local setup.

## What's Inside

### Central architecture and integration skills (6)

Canonical LFX knowledge that lives in this plugin and is referenced by every LFX repo's local setup. These are *not* implementation recipes; they hand off to the owning repo for detail.

| Skill                                   | Purpose                                                                                                                                                                                        |
|-----------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `/lfx-skills:lfx`                       | Cross-repo topology and ownership router; entry point for any multi-repo task or "where does X live" question.                                                                                 |
| `/lfx-skills:lfx-platform-architecture` | V2 platform composition, service classes, and cross-repo flow: Self Serve, Goa services, NATS, KV, OpenFGA, indexer, query, Heimdall, Helm, ArgoCD.                                            |
| `/lfx-skills:lfx-itx-integration`       | ITX wrapper patterns: OAuth2 M2M tokens, v1 KV sync, NATS ID mapping via `lfx.lookup_v1_mapping`.                                                                                              |
| `/lfx-skills:lfx-intercom`              | Retained central Intercom workflow from `main`, plus Fin AI optimization: Fin Guidance, Help Center content quality, and resolution rate.                                                      |
| `/lfx-skills:lfx-object-store-design`   | Add object storage capability to a service: S3-compatible code patterns, upload/download API shapes, Helm credential modes, nats-s3 + nginx-s3-gateway local stack, `CDN_URL_PREFIX` contract. |
| `/lfx-skills:lfx-object-store-ops`      | Provision object storage backends (private S3 + CloudFront OAC + IRSA) in `lfx-v2-opentofu`. For linuxfoundation org members.                                                                  |

### Workflow skills (8)

Cross-repo developer workflows that apply across every LFX repo.

| Skill                                      | Purpose                                                                                                                                                                      |
|--------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `/lfx-skills:lfx-setup`                    | Environment setup for any LFX repo (Angular or Go). Prerequisites, clone, install, env vars, dev server.                                                                     |
| `/lfx-skills:lfx-git-setup`                | Interactive DCO sign-off plus GPG-signed commit setup. Required for all LFX repos.                                                                                           |
| `/lfx-skills:lfx-pr-catchup`               | Morning PR catch-up dashboard: unresolved comments, status changes, stale PRs, approved-but-not-merged across all your open PRs.                                             |
| `/lfx-skills:lfx-pr-resolve`               | Address PR review comments, post follow-up summary, dismiss stale "changes requested" reviews, re-request review.                                                            |
| `/lfx-skills:lfx-test-journey`             | Combine feature branches across repos into git worktrees for end-to-end journey testing.                                                                                     |
| `/lfx-skills:lfx-snowflake-access`         | Request Snowflake access or service accounts via the `lfx-snowflake-terraform` repo.                                                                                         |
| `/lfx-skills:lfx-cdp-snowflake-connectors` | Scaffold a CDP snowflake-connector data source in `crowd.dev`; retained centrally from `main`.                                                                               |
| `/lfx-skills:lfx-data-engineer`            | Generate PR-ready dbt models, SQL transformations, and tests for `lf-dbt`, including medallion architecture, sqlfluff conventions, macros, and validation workflow guidance. |

### Local review skills (2)

Author-side, pre-PR review that runs on your machine and stops at PR-open.
Reviewers may read GitHub and fetch, but never write GitHub state: no comment,
review, check, status, label or approval, and no gate or merge.

| Skill                               | Purpose                                                                                                                                                                                     |
|-------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `/lfx-skills:lfx-local-review`      | Run the review trio on the current repo — the general reviewer plus the repo's own code and learnings reviewers — on headless Pi when available, Claude subagents otherwise. Reviews the newest commit and runs in the background. |
| `lfx-general-code-review`           | The general review method itself: correctness, security, error handling, simplicity, naming, DRY, testing, performance, style. Loaded by the review trio in either harness. Not invoked by hand. |

Pi is what makes this **cross-model** — the same skills, judged by a different
model. Without it the trio still runs on Claude, and the host says plainly that
the result is same-model rather than cross-model evidence.

The repo under review owns its own two reviewer skills at
`.claude/skills/local-code-review/SKILL.md` and
`.claude/skills/local-learnings-review/SKILL.md`; a repo without them is not set
up for local review. See
[`skills/lfx-local-review/references/repo-brains.md`](skills/lfx-local-review/references/repo-brains.md)
to author them, and
[`references/pi-setup.md`](skills/lfx-local-review/references/pi-setup.md) to
install Pi.

### Platform skill (1)

| Skill                              | Purpose                                                                                                              |
|------------------------------------|----------------------------------------------------------------------------------------------------------------------|
| `/lfx-skills:lfx-v2-ticket-writer` | Create a single LFXV2 Jira ticket via guided prompts; requirement-focused descriptions, reproduction steps for bugs. |

### Reviewer agents (13)

Post-commit code reviewers that LFX repos invoke after every pre-PR commit. Launched in parallel as subagents via the `Agent` tool. The general reviewer is repo-agnostic; repo-specific reviewers are packaged centrally for runtime availability but read their owning repo's `CLAUDE.md`, local skills, docs, contracts, and code.

| Agent                                                  | Purpose                                                                                                                                                    |
|--------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `lfx-skills:lfx-general-code-reviewer`                 | Generic senior-reviewer pass: correctness, security, performance, maintainability, tests, code truthfulness. No repo-specific rulebook.                    |
| `lfx-skills:lfx-committee-service-code-reviewer`       | Committee Service convention and contract audit against repo-owned guidance, Goa/NATS/FGA/indexer contracts, chart wiring, and code layout.                |
| `lfx-skills:lfx-committee-service-learnings-reviewer`  | Empirical pattern matcher against `lfx-v2-committee-service/docs/reviews/knowledge-base/` (patterns sampled from past PR review comments).                 |
| `lfx-skills:lfx-email-service-code-reviewer`           | Email Service convention and contract audit against repo-owned guidance, public NATS payloads, SES/SQS/KV tracking, and chart wiring.                      |
| `lfx-skills:lfx-email-service-learnings-reviewer`      | Empirical pattern matcher against `lfx-v2-email-service/docs/reviews/knowledge-base/` (starter pattern set sampled from past PR review comments).          |
| `lfx-skills:lfx-member-service-code-reviewer`          | Member Service convention and contract audit against repo-owned guidance, Salesforce/cache docs, NATS integration, and chart wiring.                       |
| `lfx-skills:lfx-member-service-learnings-reviewer`     | Empirical pattern matcher against `lfx-v2-member-service/docs/reviews/knowledge-base/` (patterns sampled from past PR review comments).                    |
| `lfx-skills:lfx-newsletter-service-code-reviewer`      | Newsletter Service convention and contract audit against repo-owned guidance, recipient resolution, email-service handoff, API behavior, and chart wiring. |
| `lfx-skills:lfx-newsletter-service-learnings-reviewer` | Empirical pattern matcher against `lfx-v2-newsletter-service/docs/reviews/knowledge-base/` (starter pattern set sampled from past PR review comments).     |
| `lfx-skills:lfx-project-service-code-reviewer`         | Project Service convention and contract audit against repo-owned guidance, Goa/NATS/KV rules, FGA/indexer contracts, and chart wiring.                     |
| `lfx-skills:lfx-project-service-learnings-reviewer`    | Empirical pattern matcher against `lfx-v2-project-service/docs/reviews/knowledge-base/` (patterns sampled from past PR review comments).                   |
| `lfx-skills:lfx-self-serve-code-reviewer`              | Convention audit against `lfx-self-serve`'s `.claude/rules/`, `docs/reviews/` checklists, architecture docs, and upstream API contracts.                   |
| `lfx-skills:lfx-self-serve-learnings-reviewer`         | Empirical pattern matcher against `lfx-self-serve/docs/reviews/knowledge-base/` (patterns sampled from past PR review comments).                           |

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
│   ├── lfx-itx-integration/
│   ├── lfx-intercom/
│   ├── lfx-setup/
│   ├── lfx-git-setup/
│   ├── lfx-pr-catchup/
│   ├── lfx-pr-resolve/
│   ├── lfx-test-journey/
│   ├── lfx-snowflake-access/
│   ├── lfx-cdp-snowflake-connectors/
│   ├── lfx-data-engineer/       # dbt model + SQL transformation skill
│   │   └── references/          # dbt setup, style, macros, testing, debugging
│   ├── lfx-object-store-design/
│   ├── lfx-object-store-ops/
│   └── lfx-v2-ticket-writer/
├── agents/
│   ├── lfx-committee-service-code-reviewer.md
│   ├── lfx-committee-service-learnings-reviewer.md
│   ├── lfx-email-service-code-reviewer.md
│   ├── lfx-email-service-learnings-reviewer.md
│   ├── lfx-general-code-reviewer.md
│   ├── lfx-member-service-code-reviewer.md
│   ├── lfx-member-service-learnings-reviewer.md
│   ├── lfx-newsletter-service-code-reviewer.md
│   ├── lfx-newsletter-service-learnings-reviewer.md
│   ├── lfx-project-service-code-reviewer.md
│   ├── lfx-project-service-learnings-reviewer.md
│   ├── lfx-self-serve-code-reviewer.md
│   └── lfx-self-serve-learnings-reviewer.md
├── docs/                        # plugin docs (platform install, tool mapping)
├── install.sh                   # Agent Skills installer (Codex etc. → ~/.agents/skills)
├── update.sh                    # re-sync Agent Skills symlinks after a pull
├── uninstall.sh                 # remove LFX Agent Skills symlinks
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
