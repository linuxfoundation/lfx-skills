---
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
name: lfx-doctor
description: >
  Diagnose problems with the LFX Skills installation: broken symlinks, missing
  dev root, frontmatter errors, routing gaps, MCP setup. Use whenever a skill
  isn't loading, when /lfx commands aren't appearing in autocomplete, when
  newly installed skills don't show up, or when the user asks "what's wrong
  with my install", "is my setup OK", or "check my lfx skills". Wraps
  `lfx-skills doctor --json` with a conversational fix flow.
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion
---

<!-- Tool names in this file use Claude Code vocabulary. See docs/tool-mapping.md for other platforms. -->

# LFX Skills Doctor

You diagnose problems with a user's LFX Skills install and walk them through fixing the ones that need a human-in-the-loop. The bash CLI handles mechanical repairs; you handle everything that needs judgment (content gaps, scaffolding, file edits).

## Step 1: Locate the CLI

The `lfx-skills` CLI lives in the user's lfx-skills clone at `cli/lfx-skills`. Try, in order:

1. **On PATH:** `command -v lfx-skills` — if found, use it directly.
2. **From the manifest:** `jq -r .canonical_clone ~/.lfx-skills/config.json 2>/dev/null` — if the file exists, append `/cli/lfx-skills`.
3. **Current dir:** if the user is inside the lfx-skills clone (a `cli/lfx-skills` exists relative to `pwd`), use `./cli/lfx-skills`.
4. **Last resort:** ask the user: "Where is your lfx-skills clone? (e.g., `~/lf/lfx-skills`)".

If none of the above works, the install was never run: tell the user to clone the repo and run `./install.sh` (or use `/lfx-install` if they're inside the clone). Stop here.

## Step 2: Run diagnostics

```bash
"$LFX_SKILLS_CLI" doctor --json
```

This emits a JSON array of records. Parse it. Each record has:
`{severity, id, category, title, detail, fixable, payload}`.

Group by severity (`pass` / `warn` / `fail`).

## Step 3: Render the report

Use this layout. Keep it scannable.

```
LFX Skills Health Check
═══════════════════════════════════════════

✓ <N> checks passed.

✗ <K> errors:

  1. <title>
     Why this matters: <plain-language consequence>
     Fix: <action>
     [auto-fixable] or [needs you to: <action>]

⚠ <M> warnings:

  1. <title>
     Why: <consequence>
     Fix: <action>
```

Don't dump every passing check. Summarise (`✓ 36 checks passed`) and let the user ask for the full list if they want it.

For each error and warning, give plain-language context: not just the title from the JSON, but *why it matters* and *what to do about it*. Use `references/fix-recipes.md` (in this skill directory) to look up the per-issue narrative when the JSON record alone isn't enough.

## Step 4: Offer fixes

If there are fixable errors or warnings, ask:

> "I can auto-fix N issue(s). Want me to walk through them?"

Use `AskUserQuestion`. Wait for the answer.

If yes:

For each `fixable: true` record, ask per-issue (`AskUserQuestion`): "Fix `<id>`? — `<title>`". On yes, invoke:

```bash
echo y | "$LFX_SKILLS_CLI" doctor --fix
```

(Or, more granularly, mark which issues to fix and answer the CLI's prompts. The CLI's `--fix` flow walks every fixable issue and asks per-issue too — you can let it drive, or you can pre-filter to the issues the user picked.)

## Step 5: Handle the not-fixable cases

For records with `fixable: false` that the user wants addressed, apply judgment. Common cases:

| Issue ID                     | What you can offer                                                              |
|------------------------------|---------------------------------------------------------------------------------|
| `frontmatter-no-name` / `frontmatter-name-mismatch` | Read the SKILL.md, identify the line, offer to fix it via Edit. |
| `frontmatter-no-description` | Read the SKILL.md body, draft a one-paragraph description from it, offer to insert. |
| `license-missing`            | Insert the YAML license-header lines (see `references/fix-recipes.md` template). |
| `routing-uncovered`          | Read `lfx/SKILL.md`, find the routing table, offer to add an entry for the missing skill. |
| `routing-dangling`           | Either remove the dangling entry from `lfx/SKILL.md` or hand off to `/lfx-new-skill` to scaffold the missing skill. Ask the user. |
| `symlink-no-skillmd`         | Hand off to `/lfx-new-skill` to scaffold the missing SKILL.md. |
| `clone-dirty`                | Informational only. Mention that the user has uncommitted changes; don't act. |

Always ask before editing files. Never edit `lfx/SKILL.md` (or anything else) silently.

## Step 6: Re-verify

After applying fixes, re-run:

```bash
"$LFX_SKILLS_CLI" doctor --json
```

Show the new counts. Celebrate if everything's green; otherwise, note what's still outstanding and why.

## Step 7: Close

End with:

> "Run `/lfx-doctor` anytime to recheck. For installation changes, `/lfx-install` or `/lfx-skills-helper` is the right entry point."

## What this skill does NOT do

- Install new skills or change install scope: that's `/lfx-install`.
- List, manage, or scaffold skills: `/lfx-skills-helper` and `/lfx-new-skill`.
- Modify `lfx/SKILL.md`'s routing table without asking the user first.
- Run destructive operations (force-removing real files, etc.) — only mechanical repairs the CLI considers safe.

## Reference files

- [`references/fix-recipes.md`](references/fix-recipes.md) — per-issue narrative, fix templates, and copy-pasteable snippets.
