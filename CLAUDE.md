<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Contributing to lfx-skills

This file guides agents and contributors changing **this repo** — adding or editing skills, reviewer
agents, and the plugin's distribution machinery. For what the plugin does and how to install it, see
[README.md](README.md).

Two sources of truth sit behind this file; this file summarizes them and they win on detail:

- **The review bar**: [`.github/skills/lfx-skills-code-review/SKILL.md`](.github/skills/lfx-skills-code-review/SKILL.md)
  is the exact lens every PR here is reviewed against — what makes a skill sound, and which side of the
  central-vs-repo boundary content belongs on. Read it *before* authoring, not after the review comes back.
- **Distribution and versioning**: the README's *Project Structure* and *Plugin versioning* sections.

## What this repo is

The central LFX AI plugin, distributed two ways: as a Claude Code plugin (the `.claude-plugin/`
manifest declares `"skills": "./skills/"`) and as plain Agent Skills symlinked by `./install.sh` for
Codex and similar tools (see [docs/platform-install.md](docs/platform-install.md)). Both paths
auto-discover any `skills/<name>/SKILL.md` — a new
skill needs no manifest registration, and a skill at a non-standard path is invisible to both. Reviewer
agents under `agents/` ship only via the Claude Code plugin path. Files under `.github/` are not shipped.

## Does your content belong here?

The core principle of the fanout architecture: **central finds the right owners and explains the shared
platform; each repo explains itself.** Before adding or expanding content, ask: does this help agents
across multiple repos, or does it serve a single repo? Content spanning repos belongs here; implementation
truth one repo owns belongs in that repo, with central pointing to it. The ownership index is
[`skills/lfx/references/repo-map.md`](skills/lfx/references/repo-map.md) — when it shows a single repo
owning the surface your change teaches, the fix is a pointer to that repo, not a central write-up.

One deliberate exception: repo-specific **reviewer agents** live centrally under `agents/` because they
are named workers repos launch explicitly — but they must direct the agent to read the owning repo's own
docs at runtime, never inline a copy of a repo's rulebook. Inlined copies drift; drift here misleads every
consumer of the plugin.

## Authoring a skill

Create `skills/<name>/SKILL.md`. The rules that catch most contributors:

- **Frontmatter `name:` matches the directory name** — skill resolution breaks otherwise.
- **The `description:` carries the entire when-to-use story.** It is the only surface an agent sees when
  deciding whether to load the skill, and agents undertrigger by default: state what the skill does plus
  concrete positive triggers, and negative triggers when a nearby skill could fire on the same prompt.
  When-to-use information buried in the body cannot influence triggering.
- **License header** — the two MIT comment lines (as at the top of this file) sit directly below the
  frontmatter, never inside it. CI enforces headers on every PR.
- **Explain, don't command.** State the why behind each rule so an agent can generalize to cases you did
  not foresee; the skill fires across many repos and prompts, not just the case you wrote it from.
- **Keep the body lean; push depth into `references/`.** The body loads in full on every trigger. A body
  approaching several hundred lines should move detail into `references/<topic>.md` files, each linked
  with explicit guidance on when to read it. Ship deterministic repeated procedures as bundled scripts,
  not prose the agent re-derives every run.
- **Use Claude Code tool names** in the body, and carry the tool-vocabulary note pointing at
  [`docs/tool-mapping.md`](docs/tool-mapping.md) if the skill names tools.
- **Placeholder data only.** Examples use synthetic identities and credentials (`user@example.com`-style
  addresses, reserved IP ranges, fixed sample UUIDs) — never real emails, names, tokens, or keys. This
  repo is public; a real address in an example is a PII leak, not a style issue.
- **Internal consistency is the highest-signal review finding here**: a value or rule stated in one
  section and contradicted in another leaves the consuming agent unable to resolve them. Re-read the
  whole file after editing part of it, and check that every cross-reference (files, skills, commands,
  external facts) actually resolves.

Then register the skill on the human-facing surfaces (discovery is automatic, listings are not): the
skills table and project-structure tree in `README.md`, and — if the router should forward to it — the
tables in [`skills/lfx/SKILL.md`](skills/lfx/SKILL.md), which also state skill counts in prose.

## Authoring a reviewer agent

Reviewer agents are single markdown files under `agents/<name>.md` with `name`, `description`, and
optionally `model`/`color` frontmatter, followed by the same license header. The `description:` obeys the
same triggering rules as skills. Repo-specific reviewers must read the owning repo's docs, rules, and
knowledge base at runtime as the source of truth (see the boundary section above). Findings vocabulary and
review contracts are shared assets — keep them consistent with the general reviewer and the
`lfx-local-review` skill rather than inventing per-agent variants.

## Plugin versioning — do not add a `version` field

`.claude-plugin/plugin.json` deliberately declares **no `version`**, so installs resolve to the git commit
SHA and every merge to `main` reaches users automatically. Adding a version back pins the plugin: users
stop receiving updates until someone remembers to bump the string. `claude plugin validate .` warns about
the missing version — that warning is expected; do not "fix" it. Full rationale in the README's *Plugin
versioning* section.

## Before you push

- `claude plugin validate .` — must pass (the no-version warning is the only expected output).
- `npx markdownlint-cli2 "**/*.md" "#node_modules" "#local-agents"` — the baseline is not fully clean, so
  the bar is: introduce no *new* errors relative to `main`.
- License headers on new files (CI blocks the PR otherwise).
- Commits need DCO sign-off (`git commit -s`); GPG signing is the LFX convention — the
  `lfx-git-setup` skill walks through both.
