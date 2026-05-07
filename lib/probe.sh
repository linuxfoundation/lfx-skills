# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
#
# System probes for cli/lfx-skills. Sourced; do not execute directly.
# All probe_* functions have no side effects — they only inspect the system.

# probe_clis → echo each detected agents.md-compatible CLI on its own line.
# Detects: codex, gemini, opencode.
probe_clis() {
  local cli
  for cli in codex gemini opencode; do
    if command -v "$cli" >/dev/null 2>&1; then
      printf '%s\n' "$cli"
    fi
  done
}

# probe_agents_config_dirs → echo each ~/.agents*/ directory that exists.
probe_agents_config_dirs() {
  local d
  for d in "$HOME"/.agents*; do
    [ -d "$d" ] || continue
    printf '%s\n' "$d"
  done
}

# probe_dev_root_candidates → echo each existing path among common LFX dev root locations.
# Order matters: first match wins as the suggested default.
probe_dev_root_candidates() {
  local d
  for d in "$HOME/lf" "$HOME/lfx" "$HOME/code/lfx" "$HOME/work/lfx" "$HOME/dev/lfx"; do
    [ -d "$d" ] || continue
    printf '%s\n' "$d"
  done
}

# probe_repos_in DIR → echo each path under DIR that:
#   - has a basename starting with "lf"
#   - contains a .git directory or file (worktrees use .git as a file)
probe_repos_in() {
  local dir="$1"
  [ -d "$dir" ] || return 0
  local entry
  for entry in "$dir"/lf*/; do
    [ -d "$entry" ] || continue
    if [ -e "${entry%/}/.git" ]; then
      # strip trailing slash for display
      printf '%s\n' "${entry%/}"
    fi
  done
}

# probe_count_repos_in DIR → echo number of lf* git repos under DIR.
probe_count_repos_in() {
  probe_repos_in "$1" | wc -l | tr -d ' '
}

# probe_shell_rcs → echo each shell rc file that exists.
# Kept for manifest context; install does not edit shell rc files.
probe_shell_rcs() {
  local rc
  for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile" "$HOME/.config/fish/config.fish"; do
    [ -f "$rc" ] && printf '%s\n' "$rc"
  done
}

# probe_have_jq → return 0 if jq is on PATH, 1 otherwise.
probe_have_jq() {
  command -v jq >/dev/null 2>&1
}

# probe_writable_path_dir → echo the best dir on the user's PATH where we can
# create a symlink to `lfx-skills` without sudo. Returns empty if none qualifies.
# Preference (user-owned first):
#   ~/.local/bin   pipx convention; many Linux distros add this to PATH
#   ~/bin          older convention; some users still use it
#   /opt/homebrew/bin   Apple Silicon Homebrew; user-writable since brew chowns it
#   /usr/local/bin Intel Macs and Linux; often root-owned, but writable for some setups
# A dir qualifies if it exists, is writable by the current user, and is on PATH.
probe_writable_path_dir() {
  local d
  for d in "$HOME/.local/bin" "$HOME/bin" "/opt/homebrew/bin" "/usr/local/bin"; do
    [ -d "$d" ] || continue
    [ -w "$d" ] || continue
    case ":$PATH:" in
      *":$d:"*) printf '%s\n' "$d"; return 0 ;;
    esac
  done
  return 1
}

# probe_canonical_clone → echo the absolute path of the lfx-skills clone this script lives in.
# Caller passes the script's $0 (or any path inside the clone).
# Walks up from cli/ or lib/ to the clone root.
probe_canonical_clone() {
  local script_path="$1"
  local script_dir
  script_dir="$(cd "$(dirname "$script_path")" && pwd)"
  case "$(basename "$script_dir")" in
    cli|lib) (cd "$script_dir/.." && pwd) ;;
    *) printf '%s\n' "$script_dir" ;;
  esac
}
