---
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
name: lfx-new-skill
description: >
  Scaffold a new skill in the lfx-skills repo. Walks the contributor through
  picking a name, description, and tool list; generates the SKILL.md with the
  correct frontmatter shape per docs/skill-authoring.md conventions; sets up
  references/ if needed; chains into `lfx-skills update` to install the new
  skill locally and `lfx-skills doctor` to verify so it can be tried
  immediately. Use whenever someone wants to add a new lfx skill, scaffold a
  new SKILL.md, or asks "how do I create a new skill". Only available inside
  the lfx-skills clone.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

<!-- Tool names in this file use Claude Code vocabulary. See docs/tool-mapping.md for other platforms. -->

# LFX New Skill — Scaffolder

You help a contributor scaffold a new skill in the `lfx-skills` repo. Your job ends when there's a well-formed `lfx-<name>/SKILL.md` on disk, the new skill is installed locally, and `lfx-skills doctor` verifies it loads. You do not handle the rest of the contribution flow (DCO, PR, review) — for that, point at `CONTRIBUTING.md`.

## Step 1: Verify you're in the clone

This skill only works inside the `lfx-skills` clone. Verify:

```bash
[ -x ./bin/lfx-skills ] && [ -d ./lfx ] && echo OK || echo NOT_IN_CLONE
```

If `NOT_IN_CLONE`:

> "I only run inside the `lfx-skills` clone. `cd` to your clone and ask again."

Stop.

## Step 2: Q1 — Skill name

Use `AskUserQuestion`:

> "What's the skill name? It must:
>  - start with `lfx-`
>  - be lowercase with hyphens (kebab-case)
>  - be a noun-phrase or verb-phrase short enough to type as `/lfx-<name>`
>
> Examples: `lfx-release-notes`, `lfx-onboarding-checklist`, `lfx-search-jira`."

Validate the answer:
- Must match `^lfx-[a-z0-9-]+$`
- Must NOT collide with an existing directory: check `[ -d "lfx-<name>" ]` — if exists, ask for another.
- Must NOT collide with `lfx` itself or any reserved prefix.

Re-ask until you get a valid name.

## Step 3: Q2 — Description

> "Describe the skill in one paragraph. The description is what your AI tool reads to decide *when* to invoke this skill — so include 3–5 trigger phrases users might say (e.g., 'Use for "release notes for X", "what changed in Y", "draft an announcement"').
>
> Aim for 2–4 sentences."

Don't auto-generate this. The contributor knows their intent better than you do. Wait for their answer.

## Step 4: Q3 — Allowed tools

> "Which tools should the skill have access to?
>
> The typical default is: `Bash, Read, Glob, Grep, AskUserQuestion`.
>
> Add `Write, Edit` if the skill will modify files.
> Add `Skill` if the skill will delegate to other lfx skills.
> Add `WebFetch` if the skill reads external URLs.
> Add specific MCP tool names (e.g., `mcp__atlassian__getJiraIssue`) if the skill depends on MCP servers.
>
> Type the comma-separated list, or just press Enter for the default."

Validate: tools should be a comma-separated list of identifiers. If the user includes MCP tools, remind them they'll need a Prerequisites section in the body (see Step 7).

## Step 5: Q4 — references/ directory?

> "Will this skill have reference docs alongside `SKILL.md`? (e.g., a long table, a JSON config, a checklist that's too big to inline.) — yes / no."

If yes: create `lfx-<name>/references/` with a `.gitkeep` so the directory is tracked even when empty.

## Step 6: Generate SKILL.md

Use the `Write` tool with the absolute path `<clone>/lfx-<name>/SKILL.md`. Template:

```markdown
---
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
name: <skill-name>
description: >
  <user's description, joined into a YAML folded scalar>
allowed-tools: <comma-separated list>
---

<!-- Tool names in this file use Claude Code vocabulary. See docs/tool-mapping.md for other platforms. -->

# <Title-cased name>

<One-paragraph intro: who this skill helps and what it does. Pull from the description but expand.>

## Step 1: <verb-noun>

<Concrete instructions for the LLM running the skill. Use code fences for shell snippets and tool invocations. Be specific.>

## Step 2: <verb-noun>

<...>

## What this skill does NOT do

- <bound 1>
- <bound 2>

## Reference files

- (none yet — add as needed)
```

**Critical formatting rules** (mirror the rest of the lfx-skills repo):

- Frontmatter MUST start at line 1 with `---`. No blank lines, no comments above.
- The license header is two YAML comment lines (`# Copyright…`, `# SPDX-License-Identifier:`) **inside** the frontmatter, lines 2–3. Plain `#` comments are valid YAML — they pass `head -4 | grep` for the CI license check without breaking frontmatter parsing.
- `name:` value must equal the directory basename (the `lfx-<name>` you picked in Step 2).
- `description:` uses YAML folded scalar (`>`) so it can wrap nicely in source while staying a single string at parse time.

## Step 7: Prerequisites section (if MCP tools)

If the user listed any `mcp__*` tools in Step 4, add a `## Prerequisites` section to the body listing them, with a one-line note about how to set up the MCP server (or a link to the right docs). The doctor's `mcp-undocumented` check looks for this — without it, the doctor will warn.

## Step 8: Install locally + verify

Chain into the CLI to make the new skill available immediately:

```bash
./bin/lfx-skills update
```

This re-applies the manifest and detects the new `lfx-<name>/` directory. The CLI will list it as a new skill not in the manifest and prompt to install it everywhere already configured.

Then verify:

```bash
./bin/lfx-skills doctor
```

If the doctor flags `frontmatter-no-name`, `frontmatter-name-mismatch`, `license-missing`, `routing-uncovered`, or any other content issue with your new skill, fix it (use Edit) and re-run `doctor` until clean.

The `routing-uncovered` warning is a reminder to add an entry to `lfx/SKILL.md` (the plain-language router) so `/lfx` knows when to route to your new skill. Decide whether your skill is user-facing (add to routing) or internal-only-invoked-by-another-skill (skip routing — the warning is acceptable). Ask the user if you're unsure.

## Step 9: Tell the user how to try it

> "All set. To try `/lfx-<name>`:
>
> 1. Restart your AI tool (or open a new session).
> 2. Type `/lfx-<name>` — it should show in autocomplete and load with the description you wrote.
>
> Iterate on the body as you go: every time you save the SKILL.md, your tool picks it up on the next invocation."

## Step 10: Hand off to CONTRIBUTING

> "When you're ready to ship this skill upstream:
>
> - Read `CONTRIBUTING.md` for the DCO, sign-off, and review flow.
> - Run `/lfx-preflight` to validate your changes.
> - Open a PR against `main`.
>
> Welcome to lfx-skills."

## What this skill does NOT do

- **Install or set up the lfx-skills install** — that's `/lfx-install`.
- **Diagnose existing install problems** — that's `/lfx-doctor`.
- **Manage the install (list, uninstall, update)** — that's `/lfx-skills-helper`.
- **Open PRs or push to a remote** — point at `CONTRIBUTING.md` and stop.
- **Author the body of the skill for the contributor** — you scaffold the structure, they write the substance. Don't fabricate steps that match a guess at intent; ask if you don't know.
