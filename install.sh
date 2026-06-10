#!/usr/bin/env bash
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT

# LFX Skills — Agent Skills installer
#
# Symlinks every LFX skill into your user-global Agent Skills directory
# (~/.agents/skills by default) so AGENTS.md / Agent Skills–compatible agents
# such as OpenAI Codex discover them automatically — explicitly via $<skill>
# or implicitly by matching each skill's description.
#
# Claude Code users should install the plugin instead (see README.md); this
# script is for Codex and other tools that read the Agent Skills standard.
#
# Override the destination with AGENTS_SKILLS_DIR, e.g. to scope to one repo:
#   AGENTS_SKILLS_DIR=./.agents/skills ./install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$SCRIPT_DIR/skills"
TARGET_DIR="${AGENTS_SKILLS_DIR:-$HOME/.agents/skills}"

echo "Installing LFX skills into $TARGET_DIR ..."
echo ""

mkdir -p "$TARGET_DIR"

installed=0
updated=0
skipped=0

for skill_path in "$SKILLS_SRC"/*/; do
  skill_path="${skill_path%/}"
  [ -d "$skill_path" ] || continue
  [ -f "$skill_path/SKILL.md" ] || continue # only directories that are real skills

  skill_name="$(basename "$skill_path")"
  target="$TARGET_DIR/$skill_name"

  if [ -L "$target" ]; then
    # Existing symlink — re-point it at the current source.
    rm "$target"
    ln -s "$skill_path" "$target"
    echo "  refreshed  $skill_name"
    updated=$((updated + 1))
  elif [ -e "$target" ]; then
    # A real file/dir already lives here — never clobber it.
    echo "  skipped    $skill_name (non-symlink already exists at $target)"
    skipped=$((skipped + 1))
  else
    ln -s "$skill_path" "$target"
    echo "  installed  $skill_name"
    installed=$((installed + 1))
  fi
done

echo ""
echo "Done: $((installed + updated)) skill(s) linked ($installed new, $updated refreshed)."
if [ "$skipped" -gt 0 ]; then
  echo "$skipped skill(s) skipped — a non-symlink already exists at the path (see above)."
fi

echo ""
echo "Next steps:"
echo "  1. Restart your agent (e.g. Codex) so it picks up the new skills."
echo "  2. Invoke one explicitly with \$lfx, or let the agent auto-select by task."
echo ""
echo "The links track this checkout, so 'git pull' here updates skill content in place."
echo "After a pull that adds or removes skills, run ./update.sh. To remove everything, run ./uninstall.sh."
