# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
#
# agents.md target path construction. Sourced; do not execute directly.

# target_dir_for_scope SCOPE BASE
#   SCOPE:    global | repo
#   BASE:     for global → the agents config dir (e.g., $HOME/.agents)
#             for repo   → the repo path  (e.g., $HOME/lf/lfx-v2-ui)
# Echoes the absolute target directory where skills should be symlinked.
target_dir_for_scope() {
  local scope="$1" base="$2"
  case "$scope" in
    global) printf '%s/skills\n' "$base" ;;
    repo)   printf '%s/.agents/skills\n' "$base" ;;
    *) return 1 ;;
  esac
}

# default_agents_config_dir → echo the conventional global agents config dir.
default_agents_config_dir() { printf '%s/.agents\n' "$HOME"; }
