# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
#
# Symlink create/remove logic for cli/lfx-skills. Sourced; do not execute directly.
# 3-way create logic lifted from install.sh and battle-tested.

# Skills that should NEVER be installed to user-level or per-repo targets by
# the CLI. These are authoring/install helpers for this clone, not runtime LFX
# workflow skills.
SYMLINKS_CLONE_ONLY="lfx-install lfx-new-skill"

# symlinks_eligible_skills CLONE → echo each installable skill directory name (one per line).
# A skill is eligible if:
#   - basename matches lfx* (catches lfx + lfx-* variants)
#   - directory contains SKILL.md
#   - basename is NOT in SYMLINKS_CLONE_ONLY
symlinks_eligible_skills() {
  local clone="$1"
  local skills_dir="$clone/skills"
  local skill_path skill_name excluded
  for skill_path in "$skills_dir"/lfx*/; do
    [ -d "$skill_path" ] || continue
    [ -f "${skill_path}SKILL.md" ] || continue
    skill_name="$(basename "${skill_path%/}")"
    excluded=0
    for ex in $SYMLINKS_CLONE_ONLY; do
      if [ "$skill_name" = "$ex" ]; then excluded=1; break; fi
    done
    [ "$excluded" -eq 1 ] && continue
    printf '%s\n' "$skill_name"
  done
}

# symlinks_create_one SOURCE TARGET [PREVIOUS_SOURCE] → create or update one symlink.
# Echoes one of: installed | updated | skipped | failed
# Stderr gets a one-line human-readable note.
# Existing symlinks are updated only when they already point to SOURCE, or when
# config.json records the existing source as one this CLI previously installed.
symlinks_create_one() {
  local source="$1" target="$2" previous="${3:-}"
  local name; name="$(basename "$target")"
  if [ -L "$target" ]; then
    local actual
    actual="$(readlink "$target" 2>/dev/null || true)"
    if [ "$actual" != "$source" ] && { [ -z "$previous" ] || [ "$actual" != "$previous" ]; }; then
      ui_warn "  skipped    $name  (symlink points to $actual, not this lfx-skills install)"
      printf 'skipped\n'
      return 0
    fi
    rm "$target"
    if ln -s "$source" "$target"; then
      ui_dim "  updated    $name" >&2
      printf 'updated\n'
    else
      ui_warn "  failed     $name"
      printf 'failed\n'
    fi
  elif [ -e "$target" ]; then
    ui_warn "  skipped    $name  (non-symlink already exists at $target)"
    printf 'skipped\n'
  else
    if ln -s "$source" "$target"; then
      ui_dim "  installed  $name" >&2
      printf 'installed\n'
    else
      ui_warn "  failed     $name"
      printf 'failed\n'
    fi
  fi
}

# symlinks_install_all CLONE SCOPE BASE
#   CLONE:    absolute path to lfx-skills clone
#   SCOPE:    global | repo
#   BASE:     for global → config dir; for repo → repo path
# Creates one symlink per eligible skill in CLONE into the agents.md target dir.
# Records each created symlink in config.json.
# Echoes a summary line: "<installed>/<updated>/<skipped>/<total>"
symlinks_install_all() {
  local clone="$1" scope="$2" base="$3"
  local target_dir
  target_dir="$(target_dir_for_scope "$scope" "$base")" || {
    ui_error "Unknown scope: $scope"
    return 1
  }
  mkdir -p "$target_dir"

  local n_installed=0 n_updated=0 n_skipped=0 n_total=0
  local skill source target outcome

  while IFS= read -r skill; do
    [ -z "$skill" ] && continue
    n_total=$((n_total + 1))
    source="$clone/skills/$skill"
    target="$target_dir/$skill"
    local previous_source=""
    if config_exists; then
      previous_source="$(config_read | jq -r --arg l "$target" '(.symlinks // [])[] | select(.link == $l) | .source' | head -1)"
      [ "$previous_source" = "null" ] && previous_source=""
    fi
    outcome="$(symlinks_create_one "$source" "$target" "$previous_source")"
    case "$outcome" in
      installed)
        n_installed=$((n_installed + 1))
        config_add_symlink "$scope" "$target" "$source" "$base"
        ;;
      updated)
        n_updated=$((n_updated + 1))
        config_add_symlink "$scope" "$target" "$source" "$base"
        ;;
      skipped)
        n_skipped=$((n_skipped + 1))
        ;;
    esac
  done < <(symlinks_eligible_skills "$clone")

  printf '%d/%d/%d/%d\n' "$n_installed" "$n_updated" "$n_skipped" "$n_total"
}

# symlinks_remove_one TARGET [EXPECTED_SOURCE]
# Safely remove one symlink. If EXPECTED_SOURCE is given, only remove if it matches.
# Echoes: removed | not-a-symlink | wrong-source | missing
symlinks_remove_one() {
  local target="$1" expected="${2:-}"
  if [ ! -e "$target" ] && [ ! -L "$target" ]; then
    printf 'missing\n'
    return 0
  fi
  if [ ! -L "$target" ]; then
    ui_warn "  refused  $target  (not a symlink — skipping for safety)"
    printf 'not-a-symlink\n'
    return 0
  fi
  if [ -n "$expected" ]; then
    local actual
    actual="$(readlink "$target" || true)"
    if [ "$actual" != "$expected" ]; then
      ui_warn "  refused  $target  (points to $actual, not expected $expected)"
      printf 'wrong-source\n'
      return 0
    fi
  fi
  rm "$target"
  ui_dim "  removed  $target" >&2
  printf 'removed\n'
}

# symlinks_uninstall_all [SCOPE_FILTER] [TARGET_FILTER]
# Walk config.json's symlinks array and remove each.
# Filters mirror config_list_symlinks: empty=all, global, repo+target.
# Updates config.json to drop removed entries.
# Echoes summary: "<removed>/<refused>/<missing>/<total>"
symlinks_uninstall_all() {
  local scope_filter="${1:-}" target_filter="${2:-}"
  local n_removed=0 n_refused=0 n_missing=0 n_total=0
  local link source outcome

  # Snapshot the list (config will mutate as we remove)
  local snapshot
  snapshot="$(config_list_symlinks "$scope_filter" "$target_filter")"

  while IFS= read -r link; do
    [ -z "$link" ] && continue
    n_total=$((n_total + 1))
    # Look up expected source from config (defensive)
    source="$(config_read | jq -r --arg l "$link" '(.symlinks // [])[] | select(.link == $l) | .source' | head -1)"
    outcome="$(symlinks_remove_one "$link" "$source")"
    case "$outcome" in
      removed)
        n_removed=$((n_removed + 1))
        config_remove_symlink "$link"
        ;;
      missing)
        n_missing=$((n_missing + 1))
        # Drop from config too — it's stale.
        config_remove_symlink "$link"
        ;;
      *)
        n_refused=$((n_refused + 1))
        ;;
    esac
  done <<EOF
$snapshot
EOF

  printf '%d/%d/%d/%d\n' "$n_removed" "$n_refused" "$n_missing" "$n_total"
}

# symlinks_uninstall_legacy_claude_recorded
# Remove legacy config-recorded Claude symlinks, and drop stale records for
# missing links. Refuses links that no longer point to the recorded source.
symlinks_uninstall_legacy_claude_recorded() {
  config_exists || { printf '0/0/0/0\n'; return 0; }
  local n_removed=0 n_refused=0 n_missing=0 n_total=0
  local snapshot link source outcome
  snapshot="$(config_read | jq -r '(.symlinks // [])[] | select(.platform == "claude") | .link')"

  while IFS= read -r link; do
    [ -z "$link" ] && continue
    n_total=$((n_total + 1))
    source="$(config_read | jq -r --arg l "$link" '(.symlinks // [])[] | select(.link == $l) | .source' | head -1)"
    outcome="$(symlinks_remove_one "$link" "$source")"
    case "$outcome" in
      removed)
        n_removed=$((n_removed + 1))
        config_remove_symlink "$link"
        ;;
      missing)
        n_missing=$((n_missing + 1))
        config_remove_symlink "$link"
        ;;
      *)
        n_refused=$((n_refused + 1))
        ;;
    esac
  done <<EOF
$snapshot
EOF

  printf '%d/%d/%d/%d\n' "$n_removed" "$n_refused" "$n_missing" "$n_total"
}

# symlinks_uninstall_legacy_claude_root CLONE
# Remove old root ~/.claude/skills links only when they are LFX skill links and
# their target points into this lfx-skills clone. This intentionally does not
# touch arbitrary Claude skills or non-symlink files.
symlinks_uninstall_legacy_claude_root() {
  local clone="$1"
  local target_dir="$HOME/.claude/skills"
  local n_removed=0 n_refused=0 n_missing=0 n_total=0
  [ -d "$target_dir" ] || { printf '0/0/0/0\n'; return 0; }

  local link name actual resolved dir base
  for link in "$target_dir"/lfx "$target_dir"/lfx-*; do
    [ -e "$link" ] || [ -L "$link" ] || continue
    n_total=$((n_total + 1))
    name="$(basename "$link")"
    case "$name" in
      lfx|lfx-*) ;;
      *) n_refused=$((n_refused + 1)); continue ;;
    esac
    if [ ! -L "$link" ]; then
      ui_warn "  refused  $link  (not a symlink — skipping for safety)"
      n_refused=$((n_refused + 1))
      continue
    fi
    actual="$(readlink "$link" || true)"
    case "$actual" in
      /*) resolved="$actual" ;;
      *)
        dir="$(dirname "$link")/$(dirname "$actual")"
        base="$(basename "$actual")"
        if [ -d "$dir" ]; then
          resolved="$(cd "$dir" && pwd -P)/$base"
        else
          resolved="$actual"
        fi
        ;;
    esac
    case "$resolved" in
      "$clone"/*)
        rm "$link"
        ui_dim "  removed  $link" >&2
        n_removed=$((n_removed + 1))
        ;;
      *)
        ui_warn "  refused  $link  (points to $actual, not this lfx-skills install)"
        n_refused=$((n_refused + 1))
        ;;
    esac
  done

  printf '%d/%d/%d/%d\n' "$n_removed" "$n_refused" "$n_missing" "$n_total"
}

# install_cli_symlink CLONE [TARGET_DIR]
# Symlink <CLONE>/cli/lfx-skills into a writable PATH dir so the user can type
# `lfx-skills` from anywhere — no shell rc edit required. If TARGET_DIR is not
# given, picks the best candidate via probe_writable_path_dir.
# Echoes the symlink path on success (e.g. "/Users/x/.local/bin/lfx-skills").
# Returns 1 if no writable PATH dir is available, OR if the target is occupied
# by anything other than the exact symlink this clone owns. Never edits PATH,
# and never silently clobbers a user's own script or a foreign symlink. The
# caller should print fallback instructions.
install_cli_symlink() {
  local clone="$1" target_dir="${2:-}"
  local source target
  source="$clone/cli/lfx-skills"
  [ -x "$source" ] || return 1
  if [ -z "$target_dir" ]; then
    target_dir="$(probe_writable_path_dir)" || return 1
  fi
  [ -d "$target_dir" ] || return 1
  [ -w "$target_dir" ] || return 1
  target="$target_dir/lfx-skills"
  if [ -L "$target" ]; then
    # An existing symlink at the target is only safe to replace when it already
    # points exactly where this install wants it to point. Anything else may be
    # user-managed, from another checkout, or from another tool.
    local actual; actual="$(readlink "$target" 2>/dev/null || true)"
    if [ "$actual" = "$source" ]; then
      :  # already correct — fall through to ln (will recreate identically)
      rm "$target"
    else
      ui_warn "Refused to overwrite existing symlink at $target → $actual"
      return 1
    fi
  elif [ -e "$target" ]; then
    ui_warn "Refused to overwrite existing non-symlink at $target"
    return 1
  fi
  if ln -s "$source" "$target"; then
    printf '%s\n' "$target"
    return 0
  fi
  return 1
}

# remove_cli_symlink TARGET CLONE → remove TARGET only if it's a symlink that
# points into the canonical clone we passed in. Safe-by-default: refuses to
# delete anything that doesn't look like our install. Refuses on empty CLONE.
remove_cli_symlink() {
  local target="$1" clone="${2:-}"
  [ -L "$target" ] || return 0
  if [ -z "$clone" ]; then
    ui_warn "Refused to remove $target (no canonical_clone in config — can't verify ownership)"
    return 1
  fi
  local actual; actual="$(readlink "$target" 2>/dev/null || true)"
  if [ "${actual#"$clone/"}" = "$actual" ]; then
    ui_warn "Refused to remove $target (points to $actual, outside $clone)"
    return 1
  fi
  rm -f "$target"
}
