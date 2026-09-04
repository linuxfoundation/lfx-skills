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
- **Distribution**: the README's *Project Structure* section.

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

The recommended workflow is Anthropic's `skill-creator` plugin (`/skill-creator:skill-creator`, from the
official marketplace): it walks the draft → test-prompt → evaluate → iterate loop and can optimize the
description for triggering accuracy. What follows is the craft it teaches plus this repo's own rules.

### Anatomy

```text
skills/<name>/
├── SKILL.md          # required; frontmatter (name, description) + markdown instructions
└── bundled resources # optional
    ├── scripts/      # executable code for deterministic or repetitive steps
    ├── references/   # docs loaded into context only when needed
    └── assets/       # files used in output (templates, icons)
```

Frontmatter `name:` must match the directory name — skill resolution breaks otherwise. The two MIT
license comment lines (as at the top of this file) sit directly below the frontmatter, never inside it;
CI enforces headers on every PR.

### Progressive disclosure

A skill loads in three levels, and each level has a budget:

1. **Metadata** (`name` + `description`) — always in context, for every skill, on every prompt.
2. **SKILL.md body** — loads in full whenever the skill triggers; keep it under ~500 lines.
3. **Bundled resources** — loaded (or executed) only as needed; effectively unlimited.

So push depth downward: a body approaching the limit moves detail into `references/<topic>.md` files,
each linked from the body with explicit guidance on when to read it (give reference files over ~300 lines
a table of contents). When a skill spans variants (frameworks, clouds, repos), give each variant its own
reference file so the agent reads only the relevant one. Ship deterministic repeated procedures as
bundled scripts, not prose the agent re-derives every run.

### The description is the triggering mechanism

The `description:` is the only surface an agent sees when deciding whether to load the skill, and agents
undertrigger by default — so make it a little pushy: state what the skill does plus concrete positive
triggers ("Use when the user mentions X, Y, or asks any variation of Z, even without naming the skill"),
and negative triggers when a nearby skill could fire on the same prompt. All when-to-use information goes
in the description; buried in the body it cannot influence triggering.

### Writing style

- **Imperative form, explained.** Prefer direct instructions, but state the why behind each rule in lieu
  of heavy-handed MUSTs — an agent that knows the reason can generalize to cases you did not foresee.
- **General, not overfitted.** The skill fires across many repos and prompts, not just the incident you
  wrote it from. Draft, then re-read with fresh eyes.
- **Show output formats and examples** as explicit templates and input → output pairs rather than
  describing them in prose.
- **Internal consistency is the highest-signal review finding here**: a value or rule stated in one
  section and contradicted in another leaves the consuming agent unable to resolve them. Re-read the
  whole file after editing part of it, and check that every cross-reference (files, skills, commands,
  external facts) actually resolves.

### Repo-specific rules

- **Use Claude Code tool names** in the body, and carry the tool-vocabulary note pointing at
  [`docs/tool-mapping.md`](docs/tool-mapping.md) if the skill names tools.
- **Placeholder data only.** Examples use synthetic identities and credentials (`user@example.com`-style
  addresses, reserved IP ranges, fixed sample UUIDs) — never real emails, names, tokens, or keys. This
  repo is public; a real address in an example is a PII leak, not a style issue.
- **Register the skill on the human-facing surfaces** (discovery is automatic, listings are not): the
  skills table and project-structure tree in `README.md`, and — if the router should forward to it — the
  tables in [`skills/lfx/SKILL.md`](skills/lfx/SKILL.md), which also state skill counts in prose.

### Test before you PR

You can load your local checkout as the plugin without installing anything: from the repo root, run

```bash
claude --plugin-dir .
```

This loads the working tree — uncommitted edits included — as the `lfx-skills` plugin for that session
only, taking the place of any installed copy, so skills resolve under their real `/lfx-skills:<name>`
namespaces exactly as users will see them. For quick non-interactive checks, combine it with headless
mode:

```bash
claude --plugin-dir . -p "Is lfx-my-new-skill available? Give its namespaced name."
```

Then, even without the full skill-creator eval loop, run 2–3 realistic prompts — the kind a real user
would actually say — in such a session, and check the skill triggers and that following it produces the
expected result. Simple one-step prompts are poor tests: agents skip skills for tasks they can handle
directly, so test with the substantive multi-step requests the skill exists for.

## Local review

After every commit on the local branch, and before a pull request exists, run
`/lfx-skills:lfx-local-review` from this repo, with no argument. It reviews
the newest commit against its first parent. Run it from inside the checkout,
or pass a resolved `--repo <path>`. Never pass a bare repo name for the
launcher to look up.

This repo owns two of the three reviewer brains:

- `.claude/skills/local-code-review/SKILL.md` cites the written rule surface
  (`.github/skills/lfx-skills-code-review`, this file, `README.md`)
- `.claude/skills/local-learnings-review/SKILL.md` matches
  `docs/reviews/knowledge-base/`

The `general` brain stays central. Local review stops at PR-open. After the
trio comes back clean, or remaining findings are documented as trade-offs,
run the checks under Before you push.

## Before you push

- `claude plugin validate .` — must pass. Its missing-`version` warning is expected: this plugin
  deliberately doesn't use versioning (see the README's *Plugin versioning* section) — don't "fix" it.
- `npx markdownlint-cli2 "**/*.md" "#node_modules" "#local-agents"` — the baseline is not fully clean, so
  the bar is: introduce no *new* errors relative to `main`.
- License headers on new files (CI blocks the PR otherwise).
- Commits need DCO sign-off (`git commit -s`); GPG signing is the LFX convention — the
  `lfx-git-setup` skill walks through both.
