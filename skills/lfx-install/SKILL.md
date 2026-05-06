---
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
name: lfx-install
description: >
  Install or set up LFX Skills for agents.md-compatible tools via the
  lfx-skills CLI, and point Claude Code-only users to the Claude plugin path.
  Walks through the choices in plain language: where their LFX repos live,
  scope, agents config dirs, then runs the installer and verifies. Use
  whenever the user says "I just cloned this — what now?", "set up lfx skills",
  "install lfx skills", "I'm new to lfx-skills", or "first-time setup".
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion
---

<!-- Tool names in this file use Claude Code vocabulary. See docs/tool-mapping.md for other platforms. -->

# LFX Skills Install

You guide the user through their first-time install. The bash CLI (`cli/lfx-skills install`) can do this non-interactively if every flag is supplied; this skill is the conversational layer that figures out what those flags should be by asking the user, in plain language, one question at a time.

## Step 1: Verify you're in the clone

This skill only works inside the `lfx-skills` clone. Verify:

```bash
[ -x ./cli/lfx-skills ] && echo OK || echo NOT_IN_CLONE
```

If `NOT_IN_CLONE`, tell the user:

> "I only run inside the lfx-skills clone. `cd` to your clone of `linuxfoundation/lfx-skills` and ask again."

Stop.

## Step 2: Probe the system

Run `./cli/lfx-skills` indirectly via its install command's PROBE step — but for the conversation, you also want the data yourself so you can ask informed questions. Do these one-shot probes:

```bash
# agents.md-compatible CLIs available
for cli in codex gemini opencode; do
  command -v "$cli" >/dev/null 2>&1 && echo "$cli"
done

# Agents config dirs
ls -d "$HOME"/.agents* 2>/dev/null

# Dev root candidates
for d in "$HOME/lf" "$HOME/lfx" "$HOME/code/lfx" "$HOME/work/lfx"; do
  [ -d "$d" ] && echo "$d"
done
```

## Step 3: Q1 — Install route

Use `AskUserQuestion`:

> "Which setup do you need? (1) agents.md-compatible tool (Codex, Gemini CLI, OpenCode), (2) Claude Code only, (3) both."

If you detected only one CLI installed, default to it but still confirm.

If the user picks Claude Code only, explain that Claude installs this repo as a plugin and does not use the CLI symlink installer:

```text
/plugin marketplace add linuxfoundation/lfx-plugins
/plugin install lfx-skills@lfx
```

If they are testing from a local checkout, tell them to run Claude Code with the local plugin directory or add the local marketplace per the Claude Code plugin docs. Stop after explaining the plugin path; do not run `./cli/lfx-skills install` for Claude-only installs.

If the user picks both, use the plugin path for Claude Code and continue with the CLI flow below for agents.md-compatible tools. The CLI itself remains agents.md-only.

## Step 4: Q2 — Scope

> "Install scope? (1) **Global** — available in every session of your agents.md-compatible tool. (2) **Per-repo** — only in specific repos (their `.agents/skills/`). (3) **Both** — global plus pin into specific repos."

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

## Step 6: Q4 — Agents config dirs (only if scope includes Global)

If you saw multiple `~/.agents*` config dirs, ask which to install into:

> "I see these agents config dirs: …. Install into all of them, or just one? (defaults to `~/.agents`)"

Most users have one; this only matters for power users with multiple profiles.

If scope is Per-repo only, skip this step entirely.

## Step 7: Q5 — Repos (only if scope includes Per-repo)

List `lf*` git repos under the chosen dev root:

> "Which repos? Pick numbers (e.g., `1, 3, 5`), `all`, or `none`."

If scope is Global only, skip this step entirely.

## Step 8: Show the plan

Before running anything, summarise:

```
Plan:
  Scope:          global + per-repo
  LFX_DEV_ROOT:   ~/lf
  Agents dir:     ~/.agents
  Repos (4):      lfx-v2-ui, lfx-v2-meeting-service, lfx-v2-committee-service, lfx-v2-query-service
  Skills:         15 user-facing + lfx-doctor + lfx-skills-helper

Will create approximately N symlinks. Proceed?
```

`AskUserQuestion`. If no, stop.

## Step 9: Run the installer

Compose the non-interactive flags from the user's answers:

```bash
./cli/lfx-skills install --yes \
  --scope=<scope> \
  --lfx-dev-root=<path> \
  --agents-config=<dir> \
  --repos=<repo1,repo2,...>
```

Stream the output to the user.

## Step 10: Verify

Run a quick verification:

```bash
./cli/lfx-skills doctor
```

If errors, walk the user through the auto-fix:

> "One or more checks failed. Want me to run `/lfx-doctor` to investigate?"

## Step 11: Confirm the CLI is on PATH

The installer creates a symlink at a writable PATH dir (`~/.local/bin/lfx-skills`, `~/bin/lfx-skills`, or `/usr/local/bin/lfx-skills`) so the user can type `lfx-skills` from anywhere — no shell rc edit. Read the install output to see which path was used and tell the user:

> "`lfx-skills` is now at `<reported path>` and ready to use from any terminal."

If the installer reported it couldn't find a writable PATH dir, share the alias snippet it printed:

> "I couldn't find a writable PATH dir to drop the CLI into. Add this alias to your shell rc to use `lfx-skills` from anywhere:
> ```bash
> alias lfx-skills='<clone>/cli/lfx-skills'
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
