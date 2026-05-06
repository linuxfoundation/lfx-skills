<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Intent → CLI mapping

Reference for `/lfx-skills-helper`. Maps natural-language **management** intents to the corresponding `lfx-skills` CLI invocation.

This file is for agents.md skill *management*: install, uninstall, update, list, info, config, and legacy Claude symlink cleanup. It is not a recommendation engine. Routing questions ("which skill should I use for X?") belong to `/lfx`. Diagnostic questions belong to `/lfx-doctor`. Authoring belongs to `/lfx-new-skill`.

When the user's phrasing isn't an exact match, infer the closest intent and confirm the chosen command before running anything stateful.

## Listing

| User says                                       | Run                                                       | Notes                                                                       |
|-------------------------------------------------|-----------------------------------------------------------|-----------------------------------------------------------------------------|
| "What lfx skills do I have here?"               | `lfx-skills list --scope=repo --repo="$(pwd)"`            | Per-repo install only                                                       |
| "What lfx skills are installed globally?"       | `lfx-skills list --scope=global`                          | Across every recorded global config dir                                     |
| "What lfx skills do I have anywhere?"           | `lfx-skills list`                                         | Both scopes combined                                                        |
| "What lfx skills are available in the clone?"   | `lfx-skills list --available`                             | All installable skills, regardless of install state                         |

## Inspecting one skill

| User says                                       | Run                                                       | Notes                                                                       |
|-------------------------------------------------|-----------------------------------------------------------|-----------------------------------------------------------------------------|
| "What does /lfx-coordinator do?"                | `lfx-skills info lfx-coordinator`                         | Strip the leading slash; pass the bare name                                 |
| "Where is /lfx-coordinator installed?"          | `lfx-skills info lfx-coordinator`                         | The output includes install locations                                       |
| "Show me my full setup"                         | `lfx-skills config`                                       | Pretty-print the JSON for the user                                          |
| "Where is my LFX dev root?"                     | `lfx-skills config get lfx_dev_root`                      |                                                                             |
| "Which clone of lfx-skills am I using?"         | `lfx-skills config get canonical_clone`                   |                                                                             |
| "What repos are in my LFX dev root?"            | `lfx-skills repos`                                        |                                                                             |

## Installing / changing scope

Always confirm via `AskUserQuestion` before running. Show the exact command first.

| User says                                       | Run                                                                                  |
|-------------------------------------------------|--------------------------------------------------------------------------------------|
| "Add lfx skills to this repo"                   | Confirm, then `lfx-skills install --yes --scope=repo --repos="$(pwd)"`. Suggest `/lfx-doctor` after. |
| "Remove lfx skills from this repo"              | Confirm, then `lfx-skills uninstall --yes --scope=repo --repos="$(pwd)"`              |
| "Install lfx skills globally for Claude"        | Explain the Claude Code plugin path: `/plugin marketplace add linuxfoundation/lfx-plugins`, then `/plugin install lfx-skills@lfx` |
| "Add agents.md support"                         | Confirm, then `lfx-skills install --yes --scope=global`                              |
| "Install everything everywhere"                 | Confirm. Don't assume `--repos=`; ask the user which repos.                          |
| "Uninstall lfx skills"                          | Confirm, then `lfx-skills uninstall --yes --all`                                     |

## Maintenance

| User says                                       | Run                                                       | Notes                                                                       |
|-------------------------------------------------|-----------------------------------------------------------|-----------------------------------------------------------------------------|
| "Update lfx skills"                             | `lfx-skills update --pull`                                | Suggest `/lfx-doctor` after                                                 |
| "Re-apply my install"                           | `lfx-skills update`                                       | No `--pull`; just refresh symlinks against the manifest                     |
| "Remove old Claude symlinks"                    | Confirm, then `lfx-skills uninstall --yes --legacy-claude-only` | Removes only lfx-skills-owned legacy Claude symlinks                  |
| "Remove lfx-skills completely"                  | Confirm, then `lfx-skills uninstall --yes --all`          | Removes agents.md symlinks, legacy Claude symlinks, CLI symlink, config     |
| "Update my LFX dev root"                        | Confirm new path, `lfx-skills config set lfx_dev_root=NEW_PATH` | Rewrites `~/.lfx-skills/dev-root` automatically                       |
| "Switch my Claude config dir"                   | Explain that Claude Code plugin scope is managed by Claude Code settings, not this CLI. |

## Hand-offs (not your job)

| User says                                       | Hand off to                                                                          |
|-------------------------------------------------|--------------------------------------------------------------------------------------|
| "Which skill should I use for X?" / task descriptions | `/lfx`                                                                          |
| "Run a health check" / "is my install OK?"      | `/lfx-doctor`                                                                         |
| "Why isn't /lfx-foo working?"                   | `/lfx-doctor`                                                                         |
| "Fix my broken symlinks"                        | `/lfx-doctor`                                                                         |
| "How do I create a new lfx skill?"              | `/lfx-new-skill` (only inside the lfx-skills clone)                                   |
| "Scaffold a new skill called lfx-foo"           | `/lfx-new-skill`                                                                      |

## Disambiguation rules

- The leading slash in user phrasing (e.g., `/lfx-coordinator`) is conversational; strip it when passing to the CLI.
- If the user says "skill X" without specifying scope, assume per-repo when they're inside a repo, global otherwise. Confirm before acting.
- If the user gives a custom command-line flag combo you don't recognise, defer to the CLI: `lfx-skills help <subcommand>`.
- If the user describes a *task* rather than asking about install state, that's a routing question — hand off to `/lfx` even mid-conversation.
