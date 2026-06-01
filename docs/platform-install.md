<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Platform Installation Guide

LFX Skills ship as [Agent Skills](https://developers.openai.com/codex/skills) —
each skill is a `SKILL.md` folder following the open standard that Claude Code,
OpenAI Codex, and a growing set of tools understand. This guide covers
non-Claude assistants. **Claude Code users should install the plugin instead**
(see the [README](../README.md)).

## Claude Code

Claude Code is the reference implementation — install the marketplace plugin
(see the [README](../README.md)). The legacy `~/.claude/skills` symlink approach
is no longer needed.

**Migrating from the old installer?** Earlier versions of `install.sh` symlinked
skills into `~/.claude/skills/`, including some that have since been removed from
this plugin. Those links are no longer managed — clear the stale ones with:

```bash
rm -f ~/.claude/skills/lfx-*
```

## Codex and other Agent Skills–compatible tools

Codex discovers skills from your **user-global** Agent Skills directory,
`~/.agents/skills/` (alongside repo-level `.agents/skills/` and admin/system
locations). The bundled scripts symlink every LFX skill into that directory so
your agent picks them up — explicitly via `$<skill>` (e.g. `$lfx`) or implicitly
by matching each skill's `description`.

**Install:**

```bash
git clone https://github.com/linuxfoundation/lfx-skills.git
cd lfx-skills
./install.sh
```

Then restart your agent (e.g. Codex) and invoke `$lfx` to get started.

**Update** — after a `git pull` that adds or removes skills (skill *content*
updates need no script, since the symlinks track this checkout):

```bash
git pull
./update.sh
```

**Uninstall** — removes only the symlinks that point into this checkout; any
other skills you have installed are left intact:

```bash
./uninstall.sh
```

**Custom location:** all three scripts honor `AGENTS_SKILLS_DIR`. Point it at a
single repo to scope the skills to that project instead of installing globally:

```bash
AGENTS_SKILLS_DIR=/path/to/repo/.agents/skills ./install.sh
```

**Verify:** the destination should contain one symlink per skill, e.g.
`~/.agents/skills/lfx -> /path/to/lfx-skills/skills/lfx`.

## Gemini CLI

Reference the SKILL.md files in your project's `GEMINI.md` configuration. Consult
[Gemini CLI documentation](https://github.com/google-gemini/gemini-cli) for
details on loading external context files.

## Other Platforms

Most AI coding tools support loading context from Markdown files. To use LFX
Skills with your tool:

1. Clone this repository.
2. Point your tool at the `SKILL.md` files in each skill directory.
3. Consult [docs/tool-mapping.md](tool-mapping.md) to translate tool names used
   in SKILL.md files to your platform's equivalents.

## Contributing

To add installation instructions for a new platform, submit a PR updating this
file and the capability table in [docs/tool-mapping.md](tool-mapping.md).
