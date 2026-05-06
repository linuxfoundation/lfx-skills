<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Platform Installation Guide

LFX Skills work with any AI coding assistant that can load context from Markdown files. This guide covers installation for specific platforms.

## Claude Code

Claude Code uses the plugin system. The plugin manifest lives at `.claude-plugin/plugin.json`, and the Claude-facing skills live under `skills/`.

**Install from the LF marketplace:**

```text
/plugin marketplace add linuxfoundation/lfx-plugins
/plugin install lfx-skills@lfx
```

**Test this checkout locally:**

```bash
git clone https://github.com/linuxfoundation/lfx-skills.git
cd lfx-skills
claude --plugin-dir .
```

Plugin skills are namespaced by the plugin name, for example `/lfx-skills:lfx`.

The plugin manifest explicitly lists Claude-facing runtime skills and excludes the four helper skills: `lfx-install`, `lfx-doctor`, `lfx-skills-helper`, and `lfx-new-skill`.

The plugin is skills-only: it exposes the runtime skills listed in `.claude-plugin/plugin.json` and does not install or expose the CLI. The agents.md/manual installer owns the user-level CLI setup.

**Verify:** Restart Claude Code (or open a new session) and type `/lfx-skills:lfx`.

## agents.md-Compatible Tools

Codex, Gemini CLI, OpenCode, and similar tools use an agent-first setup flow.

```bash
git clone https://github.com/linuxfoundation/lfx-skills.git
cd lfx-skills
```

Start your coding agent in the cloned repo and ask it to set up LFX Skills. The repo includes four helper skills under `skills/`:

- `lfx-install` — guided first-time setup
- `lfx-doctor` — install health checks and repair guidance
- `lfx-skills-helper` — list, update, uninstall, and inspect the setup
- `lfx-new-skill` — scaffold a new skill in this repo

Manual fallback:

```bash
./install.sh
```

The installer can target global agents.md skill directories, selected repos, or both. It records the manifest in `~/.lfx-skills/config.json` and the chosen LFX repo root in `~/.lfx-skills/dev-root`.

The CLI is agents.md-only. Claude Code uses the plugin path above. To remove old Claude symlink installs from before the plugin pivot, run:

```bash
lfx-skills uninstall --legacy-claude-only
```

To remove the complete agents.md install, CLI symlink, config, and any legacy Claude symlinks owned by this clone:

```bash
lfx-skills uninstall --all
```
agents.md installs include the 15 runtime skills plus `lfx-doctor` and `lfx-skills-helper`. `lfx-install` and `lfx-new-skill` stay clone-only.

The CLI does not edit your shell rc or rewrite `PATH`. It only creates an `lfx-skills` symlink in an existing writable directory already on `PATH`, and it refuses to overwrite files or foreign symlinks.

## Gemini CLI

Use the agents.md-compatible install path above, or reference the SKILL.md files in your project's `GEMINI.md` configuration. Consult [Gemini CLI documentation](https://github.com/google-gemini/gemini-cli) for details on loading external context files.

## Other Platforms

Most AI coding tools support loading context from Markdown files. To use LFX Skills with your tool:

1. Clone this repository
2. Point your tool at the SKILL.md files in each directory under `skills/`
3. Consult [docs/tool-mapping.md](tool-mapping.md) to translate tool names used in SKILL.md files to your platform's equivalents

## Contributing

To add installation instructions for a new platform, submit a PR updating this file and the capability table in [docs/tool-mapping.md](tool-mapping.md).

## Claude Plugin Releases

Claude plugin releases follow the same GitHub Release pattern as `lfx-mcp`:

```bash
LATEST=$(git tag --sort=-v:refname | head -1)
echo "Latest tag: $LATEST"
NEXT=v0.1.0

gh release create "$NEXT" \
  --generate-notes \
  --latest
```

Use `vMAJOR.MINOR.PATCH` release names. GitHub creates the tag, and the tag is the canonical release version. After the `lfx-skills` release, manually update the sibling `lfx-plugins` marketplace repo so the marketplace entry points at that tag:

```json
{
  "source": {
    "source": "github",
    "repo": "linuxfoundation/lfx-skills",
    "ref": "v0.1.0"
  },
  "version": "0.1.0"
}
```

Commit that marketplace change with `git commit -s -S`.

Do not put `version` in `.claude-plugin/plugin.json`; the `lfx-plugins` marketplace entry owns the published version.
