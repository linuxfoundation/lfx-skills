<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Platform Installation Guide

LFX Skills work with any AI coding assistant that can load context from Markdown files. This guide covers installation for specific platforms.

## Claude Code

Claude Code is the reference implementation. Skills are auto-discovered from `~/.claude/skills/`.

**Automatic installation:**

```bash
git clone https://github.com/linuxfoundation/skills.git
cd skills
./install.sh
```

**Manual installation:**

```bash
mkdir -p ~/.claude/skills
for skill in lfx-*/ lfx/; do
  ln -sf "$(pwd)/$skill" ~/.claude/skills/"$(basename "$skill")"
done
```

**Verify:** Restart Claude Code (or open a new session) and type `/lfx`.

**Per-repo installation** (scoped to a single repo instead of global):

```bash
# From inside a target repo (e.g., lfx-v2-ui)
mkdir -p .claude/skills
for skill in /path/to/skills/lfx-*/ /path/to/skills/lfx/; do
  ln -sf "$skill" .claude/skills/"$(basename "$skill")"
done
echo '.claude/skills/' >> .gitignore
```

**Uninstall:**

```bash
rm -f ~/.claude/skills/lfx-*
rm -f ~/.claude/skills/lfx
```

## Gemini CLI

Reference the SKILL.md files in your project's `GEMINI.md` configuration. Consult [Gemini CLI documentation](https://github.com/google-gemini/gemini-cli) for details on loading external context files.

## Other Platforms

Most AI coding tools support loading context from Markdown files. To use LFX Skills with your tool:

1. Clone this repository
2. Point your tool at the SKILL.md files in each skill directory
3. Consult [docs/tool-mapping.md](tool-mapping.md) to translate tool names used in SKILL.md files to your platform's equivalents

## Contributing

To add installation instructions for a new platform, submit a PR updating this file and the capability table in [docs/tool-mapping.md](tool-mapping.md).
