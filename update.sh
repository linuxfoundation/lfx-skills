#!/usr/bin/env bash
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT

# LFX Skills — Agent Skills updater
#
# Re-syncs the LFX skill symlinks in your Agent Skills directory
# (~/.agents/skills by default): re-points existing links, adds skills that
# were introduced since you installed, and prunes links for skills that were
# removed from this checkout. Run it after a 'git pull' that adds or removes
# skills. (Skill *content* updates need no script — the links track this repo.)
#
# Override the destination with AGENTS_SKILLS_DIR (match what you used to install).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$SCRIPT_DIR/skills"
TARGET_DIR="${AGENTS_SKILLS_DIR:-$HOME/.agents/skills}"

if [ ! -d "$TARGET_DIR" ]; then
  echo "$TARGET_DIR does not exist yet — run ./install.sh first."
  exit 0
fi

echo "Updating LFX skills in $TARGET_DIR ..."
echo ""

linked=0
skipped=0
pruned=0

# 1. Link or refresh every skill currently in this checkout.
for skill_path in "$SKILLS_SRC"/*/; do
  skill_path="${skill_path%/}"
  [ -d "$skill_path" ] || continue
  [ -f "$skill_path/SKILL.md" ] || continue

  skill_name="$(basename "$skill_path")"
  target="$TARGET_DIR/$skill_name"

  if [ -L "$target" ] || [ ! -e "$target" ]; then
    ln -sfn "$skill_path" "$target"
    echo "  linked     $skill_name"
    linked=$((linked + 1))
  else
    echo "  skipped    $skill_name (non-symlink already exists at $target)"
    skipped=$((skipped + 1))
  fi
done

# 2. Prune symlinks that point into this repo's skills/ but no longer resolve
#    (the skill was renamed or removed upstream). Only our own links are touched.
for target in "$TARGET_DIR"/*; do
  [ -L "$target" ] || continue
  dest="$(readlink "$target")"
  case "$dest" in
    "$SKILLS_SRC"/*)
      if [ ! -e "$dest" ]; then
        rm "$target"
        echo "  pruned     $(basename "$target")"
        pruned=$((pruned + 1))
      fi
      ;;
  esac
done

echo ""
echo "Done: $linked linked/refreshed, $pruned pruned."
if [ "$skipped" -gt 0 ]; then
  echo "$skipped skill(s) skipped — a non-symlink already exists at the path (see above)."
fi
echo "Restart your agent (e.g. Codex) to pick up the changes."
