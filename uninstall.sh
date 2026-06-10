#!/usr/bin/env bash
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT

# LFX Skills — Agent Skills uninstaller
#
# Removes the LFX skill symlinks from your Agent Skills directory
# (~/.agents/skills by default). Only symlinks that point into THIS repo's
# skills/ are removed — any other skills you have installed are left intact.
#
# Override the destination with AGENTS_SKILLS_DIR (match what you used to install).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$SCRIPT_DIR/skills"
TARGET_DIR="${AGENTS_SKILLS_DIR:-$HOME/.agents/skills}"

if [ ! -d "$TARGET_DIR" ]; then
  echo "Nothing to remove: $TARGET_DIR does not exist."
  exit 0
fi

echo "Removing LFX skills from $TARGET_DIR ..."
echo ""

removed=0
for target in "$TARGET_DIR"/*; do
  [ -L "$target" ] || continue
  dest="$(readlink "$target")"
  case "$dest" in
    "$SKILLS_SRC"/*)
      rm "$target"
      echo "  removed    $(basename "$target")"
      removed=$((removed + 1))
      ;;
  esac
done

echo ""
echo "Removed $removed LFX skill symlink(s) from $TARGET_DIR."
# Tidy the directory if our skills were the only thing in it.
if rmdir "$TARGET_DIR" 2>/dev/null; then
  echo "Removed now-empty $TARGET_DIR."
fi
echo "Restart your agent (e.g. Codex) to drop the skills from its context."
