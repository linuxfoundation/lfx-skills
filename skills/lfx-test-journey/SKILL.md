---
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
name: lfx-test-journey
description: >
  Combine multiple feature branches across repos into worktrees for
  end-to-end journey testing. Create, refresh, and teardown integration
  environments that merge branches from multiple repos.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

<!-- Tool names in this file use Claude Code vocabulary. See docs/tool-mapping.md for other platforms. -->

# Journey Testing: Multi-Branch Integration Worktrees

You help the user combine feature branches from one or more repos into isolated git worktrees for end-to-end journey testing. You never modify the user's actual branches, you create temporary worktrees that merge everything together.

**Journeys are stored at `~/.lfx-journeys/`.**

## CRITICAL: Interactive Gates

**This skill is interactive. You MUST stop and wait for user input at each selection step. NEVER skip ahead.**

The create flow has THREE mandatory user gates:
1. **Repo selection**, present repos, STOP, wait for user to pick
2. **Branch selection**, present branches per repo, STOP, wait for user to pick (per repo)
3. **Journey naming**, STOP, wait for user to name the journey

**Do NOT proceed past any gate without the user's explicit response.** Do NOT auto-select branches, auto-name journeys, or skip selection steps. The whole point of this skill is that the USER chooses what to combine.

## Subcommand Router

Parse the user's input to determine which subcommand to run. If no subcommand is clear, default to `create`.

| If the user says... | Run... | Reference |
|----------------------|--------|-----------|
| "create", or invokes the skill with no args | Create Journey | [`references/create.md`](references/create.md) |
| "status" or "check" | Status | [`references/status.md`](references/status.md) |
| "refresh" followed by a journey name | Refresh | [`references/refresh.md`](references/refresh.md) |
| "edit" followed by a journey name | Edit | [`references/edit.md`](references/edit.md) |
| "teardown", "remove", "delete" followed by a journey name | Teardown | [`references/teardown.md`](references/teardown.md) |
| "list" | List | [`references/list.md`](references/list.md) |

If a subcommand requires a journey name and the user didn't provide one, run [`references/list.md`](references/list.md) first to show available journeys, then ask which one.

Merge conflicts during create or refresh follow [`references/conflict-resolution.md`](references/conflict-resolution.md).

## Scope Boundaries

**This skill DOES:**
- Discover unmerged branches authored by the user
- Create git worktrees that merge multiple branches together
- Track journey state via manifest files
- Detect staleness and refresh worktrees
- Clean up worktrees and manifests

**This skill does NOT:**
- Run the application, it sets up worktrees, the user runs the app as usual
- Manage PRs or merge to main, purely local testing
- Persist across machines, worktrees and manifests are local
- Replay previous conflict resolutions, each refresh is a clean re-merge

## Workspace root

Repo discovery uses `$LFX_DEV_ROOT/` as the workspace root. If `$LFX_DEV_ROOT` is not set, ask the user where their LFX repos live and offer to run `/lfx-skills:lfx-setup` to persist it.
