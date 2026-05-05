# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
#
# Config + env.sh I/O for bin/lfx-skills. Sourced; do not execute directly.
# Requires: jq (caller validates with probe_have_jq).

# Config dir lives at $HOME/.lfx-skills (sibling of $HOME/.claude, $HOME/.codex,
# etc. — the convention the user-facing AI tools follow). Each config artefact
# is a sibling file inside that dir:
#   config.json   manifest of every symlink the CLI installed (incl. cli_symlink)
#   dev-root      single-line text file containing the resolved LFX_DEV_ROOT.
#                 Skills `cat` this to get the dev root without depending on
#                 env vars or shell rc edits.
# Nothing in $HOME/.lfx-skills/ is sourced by the user's shell. The CLI is made
# available system-wide via a symlink installed into a writable PATH dir
# (~/.local/bin, ~/bin, or /usr/local/bin) — see install_cli_symlink.
CONFIG_DIR_DEFAULT="$HOME/.lfx-skills"
CONFIG_JSON_DEFAULT="$CONFIG_DIR_DEFAULT/config.json"
DEV_ROOT_FILE_DEFAULT="$CONFIG_DIR_DEFAULT/dev-root"

# Allow overrides via env (used by tests).
config_dir()       { printf '%s\n' "${LFX_SKILLS_CONFIG_DIR:-$CONFIG_DIR_DEFAULT}"; }
config_json_path() { printf '%s\n' "${LFX_SKILLS_CONFIG_JSON:-$(config_dir)/config.json}"; }
dev_root_path()    { printf '%s\n' "${LFX_SKILLS_DEV_ROOT_FILE:-$(config_dir)/dev-root}"; }

# config_exists → return 0 if config.json exists, 1 otherwise.
config_exists() { [ -f "$(config_json_path)" ]; }

# config_init [canonical_clone] [lfx_dev_root]
# Ensure config dir + config.json exist with schema_version=1 baseline.
# Idempotent: leaves existing config alone, only fills missing top-level keys.
config_init() {
  local clone="${1:-}" devroot="${2:-}"
  mkdir -p "$(config_dir)"
  local cfg
  cfg="$(config_json_path)"
  if [ ! -f "$cfg" ]; then
    local now
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    jq -n \
      --arg clone "$clone" \
      --arg devroot "$devroot" \
      --arg now "$now" \
      '{
         schema_version: "1",
         lfx_dev_root: $devroot,
         canonical_clone: $clone,
         shell_rc_detected: [],
         installed_at: $now,
         last_updated_at: $now,
         platforms: {},
         symlinks: []
       }' > "$cfg"
  fi
}

# config_read → cat config.json to stdout (or an empty default if missing).
config_read() {
  if config_exists; then
    cat "$(config_json_path)"
  else
    echo '{}'
  fi
}

# config_get KEY → echo the JSON value (raw) at .KEY. Empty if missing.
# KEY may be a dotted path: e.g., "platforms.claude.config_dirs"
config_get() {
  local key="$1"
  config_read | jq -r --arg k "$key" '
    def get(p): reduce (p / ".")[] as $part (.; if . == null then null else .[$part] end);
    get($k) // empty
  '
}

# config_get_json KEY → echo the JSON value (preserving structure) at .KEY.
config_get_json() {
  local key="$1"
  config_read | jq --arg k "$key" '
    def get(p): reduce (p / ".")[] as $part (.; if . == null then null else .[$part] end);
    get($k)
  '
}

# config_set KEY VALUE → set .KEY to a STRING value (top-level or dotted path).
# Updates last_updated_at automatically.
config_set() {
  local key="$1" value="$2"
  local cfg now tmp
  cfg="$(config_json_path)"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  tmp="$cfg.tmp.$$"
  jq --arg k "$key" --arg v "$value" --arg now "$now" '
    def setpath_dotted(p; v):
      (p / ".") as $parts | setpath($parts; v);
    setpath_dotted($k; $v) | .last_updated_at = $now
  ' < "$cfg" > "$tmp" && mv "$tmp" "$cfg"
}

# config_set_json KEY JSON_VALUE → set .KEY to a JSON value (object/array/etc.)
config_set_json() {
  local key="$1" value="$2"
  local cfg now tmp
  cfg="$(config_json_path)"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  tmp="$cfg.tmp.$$"
  jq --arg k "$key" --argjson v "$value" --arg now "$now" '
    def setpath_dotted(p; v):
      (p / ".") as $parts | setpath($parts; v);
    setpath_dotted($k; $v) | .last_updated_at = $now
  ' < "$cfg" > "$tmp" && mv "$tmp" "$cfg"
}

# config_add_symlink PLATFORM SCOPE LINK SOURCE [BASE]
# Append a symlink record to the symlinks array.
#   PLATFORM: claude | agents
#   SCOPE:    global | repo
#   LINK:     absolute path of the symlink we created
#   SOURCE:   absolute path of the skill directory the symlink points at
#   BASE:     for global → the config_dir; for repo → the repo path
# Skill name is inferred from basename(LINK).
config_add_symlink() {
  local platform="$1" scope="$2" link="$3" source="$4" base="${5:-}"
  local skill cfg now tmp
  skill="$(basename "$link")"
  cfg="$(config_json_path)"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  tmp="$cfg.tmp.$$"
  local entry
  if [ "$scope" = "global" ]; then
    entry="$(jq -n \
      --arg platform "$platform" \
      --arg scope "$scope" \
      --arg config_dir "$base" \
      --arg skill "$skill" \
      --arg link "$link" \
      --arg source "$source" \
      '{platform:$platform, scope:$scope, config_dir:$config_dir, skill:$skill, link:$link, source:$source}')"
  else
    entry="$(jq -n \
      --arg platform "$platform" \
      --arg scope "$scope" \
      --arg repo "$base" \
      --arg skill "$skill" \
      --arg link "$link" \
      --arg source "$source" \
      '{platform:$platform, scope:$scope, repo:$repo, skill:$skill, link:$link, source:$source}')"
  fi
  jq --argjson entry "$entry" --arg now "$now" '
    .symlinks = ((.symlinks // []) | map(select(.link != $entry.link)) + [$entry])
    | .last_updated_at = $now
  ' < "$cfg" > "$tmp" && mv "$tmp" "$cfg"
}

# config_remove_symlink LINK → drop the entry whose .link matches.
config_remove_symlink() {
  local link="$1"
  local cfg now tmp
  cfg="$(config_json_path)"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  tmp="$cfg.tmp.$$"
  jq --arg link "$link" --arg now "$now" '
    .symlinks = ((.symlinks // []) | map(select(.link != $link)))
    | .last_updated_at = $now
  ' < "$cfg" > "$tmp" && mv "$tmp" "$cfg"
}

# config_list_symlinks [SCOPE] [TARGET]
# Echo absolute symlink paths, one per line.
#   SCOPE empty → all symlinks
#   SCOPE=global → only global
#   SCOPE=repo, TARGET=PATH → only symlinks whose .repo matches PATH
config_list_symlinks() {
  local scope="${1:-}" target="${2:-}"
  if [ -z "$scope" ]; then
    config_read | jq -r '(.symlinks // [])[] | .link'
  elif [ "$scope" = "global" ]; then
    config_read | jq -r '(.symlinks // [])[] | select(.scope == "global") | .link'
  elif [ "$scope" = "repo" ] && [ -n "$target" ]; then
    config_read | jq -r --arg t "$target" '(.symlinks // [])[] | select(.scope == "repo" and .repo == $t) | .link'
  elif [ "$scope" = "repo" ]; then
    config_read | jq -r '(.symlinks // [])[] | select(.scope == "repo") | .link'
  fi
}

# config_list_symlink_records [JQ_FILTER] → echo full records as compact JSON, one per line.
# If JQ_FILTER is provided, use it as a select expression.
config_list_symlink_records() {
  local filter="${1:-true}"
  config_read | jq -c --argjson _ 0 "(.symlinks // [])[] | select($filter)"
}

# config_set_platform_claude DIR... → record the list of claude config dirs.
config_set_platform_claude() {
  local dirs_json
  dirs_json="$(printf '%s\n' "$@" | jq -R . | jq -sc .)"
  config_set_json "platforms.claude" "{\"config_dirs\": $dirs_json}"
}

# config_set_platform_agents DIR... → record the list of agents config dirs.
# Mirror of config_set_platform_claude — both use a `config_dirs` array so the
# manifest shape is symmetric across platforms.
config_set_platform_agents() {
  local dirs_json
  dirs_json="$(printf '%s\n' "$@" | jq -R . | jq -sc .)"
  config_set_json "platforms.agents" "{\"config_dirs\": $dirs_json}"
}

# config_set_shell_rcs RC... → record the list of detected shell rcs.
config_set_shell_rcs() {
  local rcs_json
  rcs_json="$(printf '%s\n' "$@" | jq -R . | jq -sc .)"
  config_set_json "shell_rc_detected" "$rcs_json"
}

# config_clear → delete config.json and dev-root.
config_clear() {
  rm -f "$(config_json_path)" "$(dev_root_path)"
  rmdir "$(config_dir)" 2>/dev/null || true
}

# write_dev_root_file → write the resolved LFX_DEV_ROOT path to
# $HOME/.lfx-skills/dev-root as a single line. Skills read this with `cat` so
# they don't have to source env.sh, parse JSON, or depend on env vars.
write_dev_root_file() {
  local devroot path
  devroot="$(config_get lfx_dev_root)"
  path="$(dev_root_path)"
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$devroot" > "$path"
}

# config_set_cli_symlink PATH → record the lfx-skills CLI symlink path.
config_set_cli_symlink() {
  config_set cli_symlink "$1"
}
