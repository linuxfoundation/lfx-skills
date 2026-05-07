<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# LFX Skills Distribution

LFX Skills has two supported installation paths:

- **Claude Code:** use the Claude Code plugin.
- **agents.md-compatible tools:** use the LFX Skills clone plus the `lfx-skills` CLI installer and agent first usage.

Start with the `lfx` skill in either setup. It is the plain-language entry point and routes users to the right workflow.

## Claude Code Plugin

Claude Code users should install LFX Skills from the LFX plugin marketplace:

```text
/plugin marketplace add linuxfoundation/lfx-skills
/plugin install lfx-skills@lfx-skills
```

After installation, start with:

```text
/lfx-skills:lfx
```

The Claude Code plugin is only for Claude Code. It does not install the CLI and does not use the agents.md installer.

## LFX Plugin Marketplace

The marketplace lives in LFX Skills:

```text
linuxfoundation/lfx-skills
```

The marketplace publishes the `lfx-skills` Claude Code plugin. Its source is `"./"`, so the plugin is loaded from the LFX Skills repo root when the marketplace is cloned.

LFX Skills also owns the plugin manifest. The Claude plugin version is tracked in `.claude-plugin/plugin.json`.

The `skills` array in `.claude-plugin/plugin.json` is the Claude plugin allowlist. New user-facing skills are not available through the plugin just because they exist under `skills/`; they must be added to that allowlist and the plugin version must be bumped.

## Legacy Claude Symlink Cleanup

Before the plugin split, some local setups may have installed LFX Skills into Claude Code with symlinks. Those installs should be removed before using the plugin.

Recommended flow:

```bash
git clone https://github.com/linuxfoundation/lfx-skills.git
cd lfx-skills
```

Start your coding agent in the cloned LFX Skills directory and ask:

```text
Uninstall the legacy Claude setup for LFX Skills.
```

Manual fallback:

```bash
./cli/lfx-skills uninstall --legacy-claude-only
```

The cleanup only removes legacy Claude links owned by the local LFX Skills clone. It does not remove unrelated Claude skills or unrelated files.

## agents.md-Compatible Tools

Codex, Gemini CLI, OpenCode, and similar tools use the agents.md path.

Clone LFX Skills:

```bash
git clone https://github.com/linuxfoundation/lfx-skills.git
cd lfx-skills
```

Then start your coding agent in the cloned LFX Skills directory and ask it to set up LFX Skills.

LFX Skills includes four helper skills for this flow. They are available out of the box inside the cloned repo through committed `.agents/skills/` and `.claude/skills/` bootstrap wrappers, so a coding agent can use them before anything is installed:

- `lfx-install` — guided first-time setup
- `lfx-doctor` — install health checks and repair guidance
- `lfx-skills-helper` — list, update, uninstall, and inspect the setup
- `lfx-new-skill` — scaffold a new LFX skill

The canonical helper skill bodies live under `skills/`; the repo-local `.agents/skills/` and `.claude/skills/` files are lightweight wrappers for bootstrapping work in this repository.

Manual fallback:

```bash
./install.sh
```

After installation, restart your coding agent, open any LFX repo, and start with:

```text
/lfx
```

The CLI installer is only for agents.md-compatible tools. It installs the skills into agents.md skill locations, keeps track of what it owns, and avoids editing shell startup files.

## Updating

Claude Code users update from Claude:

```text
/plugin marketplace update lfx-skills
/plugin update lfx-skills@lfx-skills
```

Auto-updating can also be enabled in Claude Code.

agents.md-compatible users can ask their coding agent:

```text
Update LFX Skills and run the doctor.
```

Manual fallback:

```bash
lfx-skills update --pull
lfx-skills doctor
```

If `lfx-skills` is not on `PATH`, run it from the local LFX Skills clone:

```bash
/path/to/lfx-skills/cli/lfx-skills update --pull
/path/to/lfx-skills/cli/lfx-skills doctor
```

## Releases

Skill versions use SemVer in `.claude-plugin/plugin.json`.

Version bump guide:

| Change type                                                                                     | Version component |
| ----------------------------------------------------------------------------------------------- | ----------------- |
| Docs, prompt wording, installer fixes, small bug fixes                                          | **patch**         |
| New skills or substantial skill behavior updates                                                | **minor**         |
| Breaking command names, plugin name changes, removing or renaming skills, install layout breaks | **major**         |

For Claude Code users to receive plugin changes, update `.claude-plugin/plugin.json` before merging or pushing the change to `main`. Because the plugin manifest defines `version`, Claude Code uses that value for cache and update detection. If skill content changes but the plugin version stays the same, Claude Code will keep using the already cached plugin version.

For new Claude-facing skills, update both the `skills` allowlist and `version` in `.claude-plugin/plugin.json`.

This follows Anthropic's Claude Code marketplace guidance:

- [Create and distribute a plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces)
- [Plugins reference](https://code.claude.com/docs/en/plugins-reference)

Commit the version bump with the skill changes, using DCO and cryptographic signing:

```bash
git add .claude-plugin/plugin.json skills/<changed-skill>
git commit -s -S -m "feat: update lfx skills plugin"
```

After the change is on `main`, Claude Code users update the marketplace and plugin from Claude Code.

## Removing agents.md Installs

To remove the complete agents.md installation, CLI symlink, config, and any legacy Claude symlinks owned by the local LFX Skills clone:

```bash
lfx-skills uninstall --all
```

## Other Tools

For tools that do not support Claude plugins or agents.md skill directories directly:

1. Clone LFX Skills.
2. Point the tool at the `SKILL.md` files under `skills/`.
3. Use [tool-mapping.md](tool-mapping.md) to translate tool names to the closest available tools on that platform.
