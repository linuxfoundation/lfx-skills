<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Tool Name Mapping

SKILL.md files in this repository use Claude Code tool names as the reference vocabulary. If you use a different AI coding assistant, this table maps each capability to the equivalent tool name on your platform.

## Capability Table

| Capability | Claude Code | Gemini CLI | Generic Fallback |
|---|---|---|---|
| Read a file | `Read` | `read_file` | `cat` / your tool's file reader |
| Write a file | `Write` | `write_file` | your tool's file writer |
| Edit a file | `Edit` | `edit_file` | your tool's file editor |
| Run a shell command | `Bash` | `shell` | terminal / shell |
| Find files by pattern | `Glob` | `glob` | `find` / `fd` |
| Search file contents | `Grep` | `grep` | `grep` / `rg` |
| Ask the user a question | `AskUserQuestion` | prompt the user | ask the user |
| Delegate to another skill | `Skill` | `activate_skill` | your tool's skill system |
| Fetch a URL | `WebFetch` | `web_fetch` | `curl` / your tool's fetcher |

## Adapting for Your Platform

If your AI coding tool is not listed above, map each capability to the equivalent in your environment. The tool names in SKILL.md files describe *what* to do, not *how* — your tool's equivalent will work the same way.

Contributions to expand this table are welcome. To add support for a new platform, submit a PR adding a column to the table above.
