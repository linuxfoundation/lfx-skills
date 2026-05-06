<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Skill conventions — quick reference

Cheat sheet for `/lfx-new-skill`. The full version is `docs/skill-authoring.md` (when present). When in doubt, copy a sibling skill that does something close to what you want.

## Required frontmatter

```yaml
---
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
name: lfx-<your-skill>
description: >
  One paragraph. Include 3–5 trigger phrases users might say.
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion
---
```

- The `---` MUST be line 1. No blank lines or comments above it. Skill loaders refuse anything else.
- The two `#` lines on lines 2–3 are valid YAML comments and satisfy the CI license-header check.
- `name:` MUST equal the directory basename.
- `description:` is YAML folded scalar (`>`), so newlines in source become spaces at parse time.

## Allowed tools — common shapes

| Use case                                  | Tools                                                                 |
|-------------------------------------------|-----------------------------------------------------------------------|
| Read-only research/exploration             | `Bash, Read, Glob, Grep, AskUserQuestion`                             |
| Read + URLs                                | `Bash, Read, Glob, Grep, AskUserQuestion, WebFetch`                   |
| Code generation / file edits               | `Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion`                |
| Orchestrator that delegates to other skills | `Bash, Read, Glob, Grep, AskUserQuestion, Skill`                     |
| MCP-dependent (e.g. Snowflake, Atlassian)  | Above + the specific `mcp__*` tool names                              |

If you list any `mcp__*` tools, add a `## Prerequisites` section to the body so users without that MCP server configured know what to set up. Otherwise they'll hit cryptic errors when the skill tries to invoke a tool that doesn't exist.

## Body structure (suggested)

```markdown
# <Title-cased name>

<One paragraph: who this helps, what it does.>

## Step 1: <verb-noun>

<Concrete instructions. Use `AskUserQuestion` for any user input.>

## Step 2: <verb-noun>

...

## What this skill does NOT do

- <bound 1>
- <bound 2>

## Reference files

- (linked references/*.md)
```

## Naming the directory

- All skill directories start with `lfx-`. The exception is `lfx/` itself (the plain-language router).
- The directory name becomes the slash command (`/lfx-foo`). Pick something the user will type.

## When to use `references/`

Use `references/` for content that's:

- Too long to inline (tables, JSON config, checklists, recipe libraries).
- Read selectively by the LLM at runtime (rather than always-loaded with the skill).

Reference files don't need frontmatter. Just markdown (or JSON / YAML / etc.). Add the LFX HTML license header at the top of markdown reference files for CI.

## Routing

`lfx/SKILL.md` is the plain-language router. If your new skill is **user-facing** (someone might describe a problem and want it routed), add a row to the routing table in `lfx/SKILL.md`. Internal skills (only invoked by another skill, like `/lfx-backend-builder` invoked by `/lfx-coordinator`) can stay out — `lfx-skills doctor`'s `routing-uncovered` warning for them is acceptable.

## Validation

After creating, run:

```bash
./cli/lfx-skills update      # install the new skill at every configured target
./cli/lfx-skills doctor      # validate frontmatter, license header, routing
```

Fix anything the doctor flags before opening a PR.
