<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# LFX Skills repo

You are inside the LFX Skills source repository. Four meta-skills are auto-discovered here (via committed `.agents/skills/` symlinks) so you can help users without anything else being installed first:

- **`/lfx-install`** — guides users through installing the skills (one-time setup after clone). Walks them through platform / config dirs / scope / repos in plain language, then runs the installer.
- **`/lfx-doctor`** — diagnoses problems with an existing install. Use when the user reports skills not loading, missing autocomplete entries, or unexpected behavior.
- **`/lfx-skills-helper`** — manages the install: lists what's installed, installs/uninstalls in this repo, updates from upstream, shows config. Skill management only — *not* a router.
- **`/lfx-new-skill`** — scaffolds a new skill in this repo. Use when the contributor wants to add a new lfx skill or asks "how do I create a new skill".

The CLI itself is at `bin/lfx-skills`. Run `bin/lfx-skills help` for the full command reference.

## When to use which

- "How do I install this?" / "I just cloned, what now?" → `/lfx-install`
- "Skills aren't loading" / "is my setup OK?" → `/lfx-doctor`
- "What's installed?" / "add to this repo" / "what does X do?" → `/lfx-skills-helper`
- "Create a new skill called …" → `/lfx-new-skill`
- Anything else (modifying an existing skill, writing docs, reviewing changes): proceed normally — use the existing user-facing skills (`/lfx`, `/lfx-coordinator`, `/lfx-preflight`, etc.) as you would in any LFX repo.

## Repo layout

- `bin/lfx-skills` — multi-subcommand bash CLI.
- `lib/*.sh` — sourced by the CLI (probe, config, symlinks, doctor, ui, platforms).
- `lfx*/` — each directory is one skill, with `SKILL.md` and optional `references/`.
- `.claude/skills/` and `.agents/skills/` — committed relative symlinks to the four meta-skills above (this is what makes them auto-discoverable when someone clones).
- `install.sh` — thin shim that execs `bin/lfx-skills install "$@"`.
- `~/.config/lfx-skills/config.json` — user-level manifest written by the CLI (not in this repo).

## Tool-name compatibility

The skill bodies in this repo use Claude Code's tool vocabulary by default (Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion, Skill, WebFetch). When running under Codex, Gemini CLI, or OpenCode, treat them as the closest equivalent on your platform. See `docs/tool-mapping.md` if present.

## Conventions

- Every `SKILL.md` starts with `---` on line 1, with `# Copyright …` and `# SPDX-License-Identifier:` as YAML comments on lines 2–3.
- The `name:` frontmatter field equals the directory basename.
- DCO-signed commits required (`git commit -s`); GPG signing strongly preferred (`-S`).
