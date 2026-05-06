---
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
name: lfx-skills-helper
description: >
  Manage the agents.md LFX Skills installation via the lfx-skills CLI: list
  what's installed, install or uninstall in this repo or globally, update from
  upstream, view or change config, look up what a specific skill does, and
  remove legacy Claude symlink installs. Use for "add lfx skills to this repo",
  "what's installed", "update lfx skills", "show my lfx setup", "uninstall",
  "remove old Claude symlinks", "what does /lfx-foo do". For Claude plugin
  installs, explain the plugin marketplace path. For "which skill should I use
  for X" or other plain-language routing questions, hand off to /lfx. For health
  checks or repair, hand off to /lfx-doctor.
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion
---

<!-- Tool names in this file use Claude Code vocabulary. See docs/tool-mapping.md for other platforms. -->

# LFX Skills Helper

You are the conversational front-end for the agents.md-only `lfx-skills` CLI: install, uninstall, update, list, info, config, and legacy Claude symlink cleanup. You are NOT a router. If the user asks "which skill should I use for X" or describes a task ("I need to add a feature", "review my PR"), hand off to `/lfx` — that's the plain-language router. Your job is skill *management*, not skill *discovery*.

Claude Code is separate: it installs LFX Skills as a plugin with `/plugin marketplace add linuxfoundation/lfx-plugins` and `/plugin install lfx-skills@lfx`. Do not use the CLI to install Claude Code skills. The CLI can only remove old Claude symlink installs via `lfx-skills uninstall --legacy-claude-only` or as part of `lfx-skills uninstall --all`.

## Step 1: Locate the CLI

Same as `/lfx-doctor`. Try in order:

1. `command -v lfx-skills` (on PATH).
2. `jq -r .canonical_clone ~/.lfx-skills/config.json 2>/dev/null` then append `/cli/lfx-skills`.
3. `./cli/lfx-skills` if you're inside the lfx-skills clone.
4. Ask the user.

If none works: the install was never run. Tell the user to clone `linuxfoundation/lfx-skills` and run `./install.sh` (or invoke `/lfx-install` if they're already in the clone). Stop.

## Step 2: Classify the request

Decide which surface the request belongs to:

| User asks about…                           | Surface          | Action                                    |
|--------------------------------------------|------------------|-------------------------------------------|
| Installing, updating, removing, config     | This skill       | Map to a CLI subcommand (Step 3)          |
| What's installed / available / where       | This skill       | Map to a CLI subcommand (Step 3)          |
| What a specific skill does                 | This skill       | `lfx-skills info <name>`                  |
| **Which skill** to use for a task          | Hand off to `/lfx` | Stop here; let the router pick.          |
| **Diagnose** a problem / "why isn't X working" | Hand off to `/lfx-doctor` | Stop here.                  |
| **Scaffold a new skill**                   | Hand off to `/lfx-new-skill` | Stop here (clone-only).         |

Read `references/intents.md` once for the management-intent → CLI mapping. If the user's phrasing isn't in the table and doesn't fit your job either, say so and suggest the right entry point.

## Step 3: Run the CLI

Execute the chosen subcommand. Capture stdout. Use `--json` flags where available (currently `doctor --json`) when you need structured data.

For commands that change state (`install`, `uninstall`, `update`, `config set`), **always confirm with the user first** via `AskUserQuestion`, showing exactly what you're about to run. The CLI's `--yes` flag is appropriate only after the user has confirmed in chat.

## Step 4: Format the output

The CLI output is structured but utilitarian. Reformat it for conversation:

- **`lfx-skills list`** outputs `scope<TAB>skill<TAB>link`. Render as a friendly grouped list:

  ```
  Globally installed (agents.md):
    /lfx
    /lfx-coordinator
    ...

  Per-repo (lfx-v2-meeting-service):
    /lfx-coordinator
    /lfx-pr-resolve
    ...
  ```

- **`lfx-skills info <skill>`** outputs frontmatter + install locations. Render the description in prose, list trigger phrases, summarise where it's installed.

- **`lfx-skills config`** outputs raw JSON. Pretty-print it as a small table: dev root, canonical clone, total symlinks, and CLI symlink.

- **`lfx-skills repos`** outputs one path per line. Group as a numbered list with sizes/last-modified if helpful.

## Step 5: Hand-off rules

If during the conversation the request shifts to something off your turf, hand off cleanly:

- **Diagnostic questions** ("is my install OK?", "why isn't /lfx-foo working?", "fix my broken symlinks"): hand off to `/lfx-doctor`.
- **Routing / discovery** ("which skill should I use for backend work?", "I want to add a feature, where do I start?"): hand off to `/lfx`.
- **Creating a new skill**: hand off to `/lfx-new-skill` (only available inside the lfx-skills clone).

## What this skill does NOT do

- **Pick which skill the user should use**: that's `/lfx`'s job. This skill manages the install; it doesn't recommend skills.
- **Diagnose problems**: hand off to `/lfx-doctor`.
- **Scaffold new skills**: hand off to `/lfx-new-skill`.
- **Install/uninstall without confirmation**: always show the user the exact command first.
- **Invent categorisations**: skills aren't tagged backend/frontend/etc. anywhere in their metadata; don't pretend they are.

## Reference files

- [`references/intents.md`](references/intents.md) — management-intent → CLI command mapping.
