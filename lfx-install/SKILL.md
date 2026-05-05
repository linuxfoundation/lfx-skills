---
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
name: lfx-install
description: >
  Install or set up LFX Skills. Walks the user through every choice in plain
  language: which AI tools they use (Claude Code, agents.md tools, both),
  where their LFX repos live, scope (global / per-repo / both), then runs the
  installer and verifies. Use whenever the user says "I just cloned this — what
  now?", "set up lfx skills", "install lfx skills", "I'm new to lfx-skills",
  "first-time setup", or runs into the repo with no install manifest yet. Only
  available inside the lfx-skills clone.
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion
---

<!-- Tool names in this file use Claude Code vocabulary. See docs/tool-mapping.md for other platforms. -->

# LFX Skills Install

You guide the user through their first-time install. The bash CLI (`bin/lfx-skills install`) can do this non-interactively if every flag is supplied; this skill is the conversational layer that figures out what those flags should be by asking the user, in plain language, one question at a time.

## Step 1: Verify you're in the clone

This skill only works inside the `lfx-skills` clone (it's the only place where it's auto-discovered, via committed symlinks under `.claude/skills/`). Verify:

```bash
[ -x ./bin/lfx-skills ] && echo OK || echo NOT_IN_CLONE
```

If `NOT_IN_CLONE`, tell the user:

> "I only run inside the lfx-skills clone. `cd` to your clone of `linuxfoundation/lfx-skills` and ask again."

Stop.

## Step 2: Probe the system

Run `./bin/lfx-skills` indirectly via its install command's PROBE step — but for the conversation, you also want the data yourself so you can ask informed questions. Do these one-shot probes:

```bash
# CLIs available
for cli in claude codex gemini opencode; do
  command -v "$cli" >/dev/null 2>&1 && echo "$cli"
done

# Claude config dirs
ls -d "$HOME"/.claude* 2>/dev/null

# Agents config dirs
ls -d "$HOME"/.agents* 2>/dev/null

# Dev root candidates
for d in "$HOME/lf" "$HOME/lfx" "$HOME/code/lfx" "$HOME/work/lfx"; do
  [ -d "$d" ] && echo "$d"
done
```

## Step 3: Q1 — Platform

Use `AskUserQuestion`:

> "Which AI coding tools do you use? (1) Claude Code, (2) an agents.md-compatible tool (Codex, Gemini CLI, OpenCode), (3) both."

If you detected only one CLI installed, default to it but still confirm.

## Step 4: Q2 — Scope

> "Install scope? (1) **Global** — available in every session of your AI tool. (2) **Per-repo** — only in specific repos (their `.claude/skills/` or `.agents/skills/`). (3) **Both** — global plus pin into specific repos."

This question goes second so subsequent questions can adapt. (Per-repo only? Skip the global config picker. Global only? Skip the repo picker.)

## Step 5: Q3 — LFX dev root

Show the candidates you probed with their repo counts:

```
Where do you keep your LFX repo clones?
  1. ~/lf (12 lf* repos)
  2. ~/code/lfx (3 lf* repos)
  3. Custom path…
```

Use `AskUserQuestion`. If the user already has `LFX_DEV_ROOT` set in the shell, mention it and ask whether to keep it.

If the chosen path doesn't exist, ask whether to create it (`mkdir -p`). If it has zero `lf*` git repos, warn but proceed: the install will still work; the dev-root-empty doctor warning will trigger until they clone some.

## Step 6: Q4 — Config dirs (only if scope includes Global)

If you saw multiple Claude config dirs (e.g., `~/.claude`, `~/.claude-work`, `~/.claude-personal`), ask which to install into:

> "I see these Claude config dirs: …. Install into all of them, or just one? (defaults to `~/.claude`)"

Same for `~/.agents*` if applicable. (Most users have one each; this only matters for power users with multiple profiles.)

If scope is Per-repo only, skip this step entirely.

## Step 7: Q5 — Repos (only if scope includes Per-repo)

List `lf*` git repos under the chosen dev root:

> "Which repos? Pick numbers (e.g., `1, 3, 5`), `all`, or `none`."

If scope is Global only, skip this step entirely.

## Step 8: Show the plan

Before running anything, summarise:

```
Plan:
  Platform:       claude + agents
  Scope:          global + per-repo
  LFX_DEV_ROOT:   ~/lf
  Claude dirs:    ~/.claude, ~/.claude-work
  Agents dir:     ~/.agents
  Repos (4):      lfx-v2-ui, lfx-v2-meeting-service, lfx-v2-committee-service, lfx-v2-query-service
  Skills:         15 user-facing + lfx-doctor + lfx-skills-helper

Will create approximately N symlinks. Proceed?
```

`AskUserQuestion`. If no, stop.

## Step 9: Run the installer

Compose the non-interactive flags from the user's answers:

```bash
./bin/lfx-skills install --yes \
  --platform=<platform> \
  --scope=<scope> \
  --lfx-dev-root=<path> \
  --claude-config=<dir1,dir2,...> \
  --agents-config=<dir> \
  --repos=<repo1,repo2,...>
```

Stream the output to the user.

## Step 10: Verify

Run a quick verification:

```bash
./bin/lfx-skills doctor
```

If errors, walk the user through the auto-fix:

> "One or more checks failed. Want me to run `/lfx-doctor` to investigate?"

## Step 11: Confirm the CLI is on PATH

The installer creates a symlink at a writable PATH dir (`~/.local/bin/lfx-skills`, `~/bin/lfx-skills`, or `/usr/local/bin/lfx-skills`) so the user can type `lfx-skills` from anywhere — no shell rc edit. Read the install output to see which path was used and tell the user:

> "`lfx-skills` is now at `<reported path>` and ready to use from any terminal."

If the installer reported it couldn't find a writable PATH dir, share the alias snippet it printed:

> "I couldn't find a writable PATH dir to drop the CLI into. Add this alias to your shell rc to use `lfx-skills` from anywhere:
> ```bash
> alias lfx-skills='<clone>/bin/lfx-skills'
> ```
> Or extend PATH to include `~/.local/bin`, `~/bin`, or `/usr/local/bin`."

## Step 12: Suggest next steps

> "All set. Next:
>
> 1. Restart your AI coding assistant (or open a new session).
> 2. `cd` to any LFX repo and type `/lfx` — that's your plain-language entry point.
> 3. Run `/lfx-doctor` anytime to recheck the install.
> 4. Run `/lfx-skills-helper` to manage what's installed where."

## What this skill does NOT do

- **Edit your shell rc** — never. Always print the snippet for the user to paste.
- **Install only some skills** — v1 always installs everything (the full set per chosen target). Filtering is a v2 idea.
- **Run outside the clone** — bail in Step 1.
- **Re-run silently** — confirm at the plan step before doing anything stateful.
