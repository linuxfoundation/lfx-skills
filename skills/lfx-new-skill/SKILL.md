---
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
name: lfx-new-skill
description: >
  Scaffold a new skill in the lfx-skills repo under skills/. Use when someone
  wants to add a new lfx skill, provides a complete SKILL.md to import, has an
  idea for a skill and wants help drafting it, or asks how to create a skill.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

<!-- Tool names in this file use Claude Code vocabulary. See docs/tool-mapping.md for other platforms. -->

# LFX New Skill — Scaffolder

You help contributors add a skill under `skills/lfx-<name>/`. Read [`references/conventions-quickref.md`](references/conventions-quickref.md) before writing files.

Use two modes:

- **Complete skill provided:** if the user pastes or points to a complete `SKILL.md`, use it as the source of truth. Preserve the body. Only normalize frontmatter, license header, directory name, and repo-specific placeholders when needed.
- **Draft from idea:** if the user only has an idea, help write the body. Ask targeted questions about trigger phrases, inputs, steps, tools, outputs, and boundaries. Draft concrete step-by-step instructions from the answers.

## Step 1: Verify Location

Run:

```bash
[ -x ./cli/lfx-skills ] && [ -d ./skills/lfx ] && echo OK || echo NOT_IN_CLONE
```

If `NOT_IN_CLONE`, tell the user to `cd` to the `lfx-skills` clone and stop.

## Step 2: Gather Inputs

Ask whether the user has a complete `SKILL.md` or wants help drafting one.

For a complete skill:

- Read the supplied file/content.
- Extract `name`, `description`, and `allowed-tools` when present.
- Ask only for missing required fields.

For a draft:

- Ask for the skill name. It must match `^lfx-[a-z0-9-]+$` and not already exist under `skills/`.
- Ask for a frontmatter description with 3-5 trigger phrases.
- Ask which tools it needs. Default: `Bash, Read, Glob, Grep, AskUserQuestion`.
- Ask what the skill should do, what inputs it needs, what it may inspect or modify, what output it should produce, and what it must not do.

Ask whether it needs `references/`.

## Step 3: Write Files

Create:

```text
skills/lfx-<name>/SKILL.md
```

If requested, also create:

```text
skills/lfx-<name>/references/.gitkeep
```

Ensure:

- frontmatter starts on line 1
- license comments are lines 2-3 inside the frontmatter
- `name:` equals the directory basename
- `description:` uses a YAML folded scalar
- `allowed-tools:` is present
- MCP-dependent skills include a `## Prerequisites` section

If the skill is user-facing, ask whether to add routing guidance to `skills/lfx/SKILL.md`. Internal-only skills can remain unrouted.

## Step 4: Validate

Run only the new skill formatting check:

```bash
./cli/lfx-skills doctor --skill-formatting-only --skill=lfx-<name>
```

Fix `frontmatter-*` and `license-missing` issues, then rerun until clean. Do not run the full doctor for this scaffolding check; full doctor includes agents.md install/setup checks.

## Step 5: Explain Local Testing

Ask which runtime they want to test: Claude Code plugin, agents.md, or both.

For Claude Code plugin testing:

- If the skill should ship in the Claude plugin, add its path to the `skills` allowlist in `.claude-plugin/plugin.json`. Creating `skills/lfx-<name>/SKILL.md` is not enough; Claude plugin users only get skills listed in that manifest.
- If the new skill is user-facing and should be available to Claude plugin users, treat the plugin allowlist entry as required, not optional.
- Give the user this validation command to run from their normal terminal:

  ```bash
  cd "<absolute-path-to-lfx-skills>"
  claude plugin validate .
  ```

- Ask which target LFX repo they want to test in. Resolve a repo name under `~/.lfx-skills/dev-root` or use the absolute path they provide.
- Give the user a ready-to-run command:

  ```bash
  LFX_SKILLS_CLONE="<absolute-path-to-lfx-skills>"
  cd "<resolved-target-repo-path>"
  claude --plugin-dir "$LFX_SKILLS_CLONE"
  ```

- Tell them to run `/lfx-skills:lfx-<name>` in that Claude Code session.

For agents.md testing:

- Run `./cli/lfx-skills update`.
- Tell the user to restart their agents.md-compatible coding agent and run `/lfx-<name>`.
- If LFX Skills is not installed for agents.md, point them to `/lfx-install` or `./install.sh`.

Keep the two paths separate: the CLI is for agents.md installs; Claude Code uses the plugin path.

## Step 6: Offer Commit And Release Help

After validation, ask whether the user wants help committing the scaffolded skill.

If they say yes:

- Review `git diff` and `git status`.
- Commit only the intended files.
- Use `git commit -s -S`.
- Do not add co-author trailers.
- Do not push unless explicitly asked.

For plugin versioning, explain that Claude Code picks up plugin changes when `.claude-plugin/plugin.json` gets a new SemVer `version` and the change reaches `main`. Offer to help choose the next patch/minor/major version and include the plugin version bump in the signed commit. If the skill is Claude-facing, include both the `skills` allowlist entry and the version bump in the commit.

## Boundaries

- Do not install or repair the user's LFX Skills setup; route that to `/lfx-install` or `/lfx-doctor`.
- Do not use the CLI to install Claude Code skills.
- Do not run Claude Code plugin commands for agents.md testing.
- Do not invent unclear behavior. Ask when scope, inputs, outputs, or safety boundaries are unclear.
