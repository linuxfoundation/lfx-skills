<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# New Skill Quick Reference

## Frontmatter

```yaml
---
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
name: lfx-<name>
description: >
  One paragraph with 3-5 trigger phrases users might say.
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion
---
```

- `---` must be line 1.
- License comments must be lines 2-3 inside frontmatter.
- `name:` must match the directory basename.
- `description:` should use `>`.

## Input Modes

- **Complete skill:** preserve the supplied body; normalize only frontmatter, license, path, and repo-specific placeholders.
- **Idea:** ask enough questions to draft concrete runtime instructions. Cover triggers, inputs, steps, allowed tools, output, and explicit non-goals.

## Tool Defaults

| Use case | Tools |
|---|---|
| Read-only research | `Bash, Read, Glob, Grep, AskUserQuestion` |
| Reads external URLs | `Bash, Read, Glob, Grep, AskUserQuestion, WebFetch` |
| Edits files | `Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion` |
| Delegates to skills | `Bash, Read, Glob, Grep, AskUserQuestion, Skill` |
| MCP-dependent | Add the specific `mcp__*` tools |

MCP-dependent skills should include `## Prerequisites`.

## Body Shape

Use this as the default body structure when drafting:

```markdown
# <Title>

<Who this helps and what it does.>

## Step 1: <Action>

<Concrete instructions. Ask for user input when needed.>

## Step 2: <Action>

<Concrete instructions.>

## What this skill does NOT do

- <Boundary>

## Reference files

- (none yet)
```

## References

Use `references/` for long tables, checklists, examples, JSON/YAML snippets, or content the model should load only when needed.

## Routing

User-facing skills should usually be mentioned in `skills/lfx/SKILL.md` so `/lfx` can route to them. Internal-only skills can stay unrouted.

## Validation

Run:

```bash
./cli/lfx-skills doctor --skill-formatting-only --skill=lfx-<name>
```

This checks only the new skill's frontmatter and license header.

## Claude Code Local Test

If the skill should ship in the Claude plugin, add its path to the `skills` allowlist in `.claude-plugin/plugin.json`. Creating `skills/lfx-<name>/SKILL.md` is not enough; Claude plugin users only get skills listed in that manifest.

Give the user:

```bash
cd "<absolute-path-to-lfx-skills>"
claude plugin validate .
```

Then ask which LFX repo they want to test in, resolve it under `~/.lfx-skills/dev-root` if they gave a repo name, and give:

```bash
LFX_SKILLS_CLONE="<absolute-path-to-lfx-skills>"
cd "<resolved-target-repo-path>"
claude --plugin-dir "$LFX_SKILLS_CLONE"
```

They should test:

```text
/lfx-skills:lfx-<name>
```

## agents.md Local Test

Run:

```bash
./cli/lfx-skills update
```

Then tell the user to restart their agents.md-compatible coding agent and run:

```text
/lfx-<name>
```

## Commit And Release

After validation, ask if the user wants help committing. If yes:

- Review `git diff` and `git status`.
- Commit only intended files.
- Use `git commit -s -S`.
- Do not add co-author trailers.
- Do not push unless explicitly asked.

For Claude Code plugin updates, bump the SemVer `version` in `.claude-plugin/plugin.json` with the skill changes. Claude Code will keep using the cached plugin if the version is unchanged. For new Claude-facing skills, commit both the `skills` allowlist entry and the version bump.
