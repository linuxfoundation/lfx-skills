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
/plugin marketplace add linuxfoundation/lfx-plugins
/plugin install lfx-skills@lfx
```

After installation, start with:

```text
/lfx-skills:lfx
```

The Claude Code plugin is only for Claude Code. It does not install the CLI and does not use the agents.md installer.

## LFX Plugin Marketplace

The marketplace lives separately from LFX Skills:

```text
linuxfoundation/lfx-plugins
```

That separate marketplace lets LFX publish multiple Claude Code plugins from one place. Today it publishes the `lfx-skills` plugin, and future LFX Claude Code plugins can be added there as separate plugin entries.

LFX Skills owns the skill source. The marketplace owns the published plugin listing, version, and release tag reference.

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

LFX Skills includes four helper skills for this flow:

- `lfx-install` — guided first-time setup
- `lfx-doctor` — install health checks and repair guidance
- `lfx-skills-helper` — list, update, uninstall, and inspect the setup
- `lfx-new-skill` — scaffold a new LFX skill

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
/plugin marketplace update lfx
/plugin update lfx-skills@lfx
```

Auto-updating can also be enabled in claude code.

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

Skill releases use GitHub Release tags in `linuxfoundation/lfx-skills`.

Use SemVer tags:

```text
vMAJOR.MINOR.PATCH
```

Version bump guide:

| Change type                                                                                     | Version component |
| ----------------------------------------------------------------------------------------------- | ----------------- |
| Docs, prompt wording, installer fixes, small bug fixes                                          | **patch**         |
| New skills or substantial skill behavior updates                                                | **minor**         |
| Breaking command names, plugin name changes, removing or renaming skills, install layout breaks | **major**         |

Create tag releases with the same `gh release create`:

```bash
LATEST=$(git tag --sort=-v:refname | head -1)
echo "Latest tag: $LATEST"
NEXT=v0.1.0

gh release create "$NEXT" \
  --generate-notes \
  --latest
```

The `gh release create` command creates the release tag. The tag is the canonical LFX Skills version.

Then update the `lfx-skills` entry in the LFX plugin marketplace so it points at the new release tag and version.

Commit the marketplace update with DCO and cryptographic signing:

```bash
git add .claude-plugin/marketplace.json
git commit -s -S -m "chore: publish lfx-skills plugin v0.1.0"
git push
```

Do not add a version to the LFX Skills Claude plugin manifest. The marketplace owns the published Claude plugin version.

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
