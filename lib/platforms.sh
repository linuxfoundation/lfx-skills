# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
#
# Per-platform target path construction. Sourced; do not execute directly.

# platform_target_dir PLATFORM SCOPE BASE
#   PLATFORM: claude | agents
#   SCOPE:    global | repo
#   BASE:     for global → the config dir (e.g., $HOME/.claude)
#             for repo   → the repo path  (e.g., $HOME/lf/lfx-v2-ui)
# Echoes the absolute target directory where skills should be symlinked.
platform_target_dir() {
  local platform="$1" scope="$2" base="$3"
  case "$platform:$scope" in
    claude:global) printf '%s/skills\n' "$base" ;;
    claude:repo)   printf '%s/.claude/skills\n' "$base" ;;
    agents:global) printf '%s/skills\n' "$base" ;;
    agents:repo)   printf '%s/.agents/skills\n' "$base" ;;
    *) return 1 ;;
  esac
}

# platform_default_global_dir PLATFORM → echo the conventional global config dir.
#   claude → $HOME/.claude
#   agents → $HOME/.agents
platform_default_global_dir() {
  case "$1" in
    claude) printf '%s/.claude\n' "$HOME" ;;
    agents) printf '%s/.agents\n' "$HOME" ;;
    *) return 1 ;;
  esac
}

# platform_supported PLATFORM → return 0 if PLATFORM is known.
platform_supported() {
  case "$1" in
    claude|agents) return 0 ;;
    *) return 1 ;;
  esac
}

# platform_all → echo every supported platform on its own line.
platform_all() {
  printf 'claude\nagents\n'
}
