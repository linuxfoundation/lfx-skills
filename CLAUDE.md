<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# LFX Skills repo

You are inside the LFX Skills source repository. Claude Code users install the runtime skills through the `.claude-plugin/plugin.json` plugin manifest; agents.md-compatible tools use the `cli/lfx-skills` CLI. Claude Code does not use the CLI installer. The four helper skills live under `skills/` for clone/agent workflows and are intentionally not in the Claude plugin.

- **`/lfx-install`** — guides users through agents.md setup after clone. Walks them through scope, config dirs, repos, and dev root, then runs the CLI installer.
- **`/lfx-doctor`** — diagnoses problems with an existing install. Use when the user reports skills not loading, missing autocomplete entries, or unexpected behavior.
- **`/lfx-skills-helper`** — manages the install: lists what's installed, installs/uninstalls in this repo, updates from upstream, shows config. Skill management only — *not* a router.
- **`/lfx-new-skill`** — scaffolds a new skill in this repo. Use when the contributor wants to add a new lfx skill or asks "how do I create a new skill".

The CLI itself is at `cli/lfx-skills`. Run `cli/lfx-skills help` for the full command reference.

## Claude vs agents.md

- Claude Code install/update happens through the in-repo plugin marketplace: `/plugin marketplace add linuxfoundation/lfx-skills`, then `/plugin install lfx-skills@lfx-skills`.
- agents.md install/update happens through `cli/lfx-skills`.
- The CLI has no platform picker anymore. It installs agents.md symlinks only.
- To remove old Claude symlink installs from before the plugin pivot, run `cli/lfx-skills uninstall --legacy-claude-only`.
- To remove the complete local agents.md install, CLI symlink, config, and legacy Claude symlinks owned by this clone, run `cli/lfx-skills uninstall --all`.

## When to use which

- "How do I install this?" / "I just cloned, what now?" → `/lfx-install`
- "Skills aren't loading" / "is my setup OK?" → `/lfx-doctor`
- "What's installed?" / "add to this repo" / "what does X do?" → `/lfx-skills-helper`
- "Create a new skill called …" → `/lfx-new-skill`
- Anything else (modifying an existing skill, writing docs, reviewing changes): proceed normally — use the existing user-facing skills (`/lfx`, `/lfx-coordinator`, `/lfx-preflight`, etc.) as you would in any LFX repo.

## Repo layout

- `cli/lfx-skills` — multi-subcommand bash CLI.
- `lib/*.sh` — sourced by the CLI (probe, config, symlinks, doctor, ui, targets).
- `skills/lfx*/` — each directory is one skill, with `SKILL.md` and optional `references/`.
- `.claude-plugin/plugin.json` — Claude Code plugin manifest. It explicitly lists Claude-facing runtime skills and intentionally excludes `lfx-install`, `lfx-doctor`, `lfx-skills-helper`, and `lfx-new-skill`.
- `.claude-plugin/marketplace.json` — Claude Code marketplace manifest. It lists the `lfx-skills` plugin, points its source at the released `linuxfoundation/lfx-skills` tag, and carries the published plugin version.
- `install.sh` — thin shim that execs `cli/lfx-skills install "$@"`.
- `~/.lfx-skills/config.json` — agents.md install manifest written by the CLI (not in this repo). New installs do not record a platform.
- `~/.lfx-skills/dev-root` — single-line text file the 3 dev-root-aware skills `cat` to resolve `LFX_DEV_ROOT` without depending on shell env.
- `~/.local/bin/lfx-skills` (or `~/bin/...`, or `/usr/local/bin/...`) — symlink the installer creates so `lfx-skills` is on PATH everywhere. No shell rc edit needed.

## Conventions

- Every `SKILL.md` starts with `---` on line 1, with `# Copyright …` and `# SPDX-License-Identifier:` as YAML comments on lines 2–3.
- The `name:` frontmatter field equals the directory basename.
- DCO-signed and cryptographically signed manual commits are required (`git commit -s -S`).

## Releases

- Releases use GitHub Releases with `vMAJOR.MINOR.PATCH`, like `lfx-mcp`.
- One skill change or a batch of skill changes can ship in the same release.
- Create releases through GitHub Releases or `gh release create`; GitHub creates the tag.
- Before release, update `.claude-plugin/marketplace.json` so `plugins[].source.ref` equals the release tag and `plugins[].version` equals the release without the leading `v`.
- `.claude-plugin/plugin.json` must not contain `version`; Anthropic resolves `plugin.json` version before marketplace version, so keep the explicit version in the marketplace only.

Version bump guidelines:

| Change type | Version component |
|---|---|
| Typo fixes, prompt wording tweaks, docs, installer fixes, CI fixes | **patch** |
| New skills, substantial skill behavior updates, new supported platform behavior | **minor** |
| Breaking command names, plugin name changes, removing or renaming skills, install layout breaks | **major** (only when explicitly instructed) |

Release command shape:

```bash
LATEST=$(git tag --sort=-v:refname | head -1)
echo "Latest tag: $LATEST"
NEXT=v0.1.0

gh release create "$NEXT" \
  --generate-notes \
  --latest
```

Before creating the GitHub Release, update and commit the plugin version plus marketplace tag reference:

```bash
# Edit .claude-plugin/marketplace.json:
# - plugins[].source.ref = "$NEXT"
# - plugins[].version = "${NEXT#v}"
git add .claude-plugin/marketplace.json
git commit -s -S -m "chore: release lfx-skills plugin $NEXT"
```

After the release, Claude users update with `/plugin marketplace update lfx-skills` and `/plugin update lfx-skills@lfx-skills`. agents.md users update with `lfx-skills update --pull` and `lfx-skills doctor`.
