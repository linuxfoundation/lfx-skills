<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Distribution

Empirical patterns where the two install paths, or the docs that describe
them, drifted. A skill that is invisible on one path, or a doc that tells
the user to invoke the wrong command after install, misdirects every
consumer of that path.

**Read when:** `.claude-plugin/**`, `install.sh`, `update.sh`,
`uninstall.sh`, or `docs/platform-install.md` changed.

---

## `distribution/installer-docs-must-match-install-path` — Important

**Pattern:** `install.sh`, `update.sh`, `uninstall.sh`, or
`docs/platform-install.md` names an install directory or an invoke command
that does not match what the installer actually does.

**Detect:** read `install.sh` for `TARGET_DIR` (today
`${AGENTS_SKILLS_DIR:-$HOME/.agents/skills}`) and the next-steps command it
prints. Confirm `docs/platform-install.md` and the README Codex section
name that same directory and the same invoke form (`$lfx`, not
`/lfx-skills:lfx`, for the Agent Skills path). Flag a doc that still says
`~/.claude/skills` or tells a Codex user to run the plugin-qualified
command.

**Empirical citation:** PR #59 `install.sh` — Copilot — "This script
symlinks skills into `~/.claude/skills` … Telling users to invoke the
plugin-qualified `/lfx-skills:lfx` command after using the legacy installer
will fail or confuse users who installed via this script." Also PR #59
`docs/platform-install.md` — Copilot — "This section documents the legacy
symlink installer, which installs skills into `~/.claude/skills` and exposes
`/lfx`, not the plugin-qualified `/lfx-skills:lfx`." Resolved in `eec3fac`.

**Failure message:** installer docs name a directory or invoke command the
installer does not produce.

**Fix:** make the doc and the script agree on one directory and one invoke
form. Claude Code users get the marketplace plugin; Codex users get
`~/.agents/skills` and `$lfx`.
