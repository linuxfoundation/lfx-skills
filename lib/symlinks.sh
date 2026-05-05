# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
#
# Symlink create/remove logic for bin/lfx-skills. Sourced; do not execute directly.
# 3-way create logic lifted from install.sh and battle-tested.

# Skills that should NEVER be installed to user-level or per-repo targets.
# These are clone-only meta-skills: they live only inside the lfx-skills clone
# (auto-discovered via committed `.claude/skills/` and `.agents/skills/` symlinks).
SYMLINKS_CLONE_ONLY="lfx-install lfx-new-skill"

# symlinks_eligible_skills CLONE → echo each installable skill directory name (one per line).
# A skill is eligible if:
#   - basename matches lfx* (catches lfx + lfx-* variants)
#   - directory contains SKILL.md
#   - basename is NOT in SYMLINKS_CLONE_ONLY
symlinks_eligible_skills() {
  local clone="$1"
  local skill_path skill_name excluded
  for skill_path in "$clone"/lfx*/; do
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

# symlinks_create_one SOURCE TARGET → create or update one symlink.
# Echoes one of: installed | updated | skipped | failed
# Stderr gets a one-line human-readable note.
# This is the lifted 3-way logic from the original install.sh (lines 31-46).
symlinks_create_one() {
  local source="$1" target="$2"
  if [ -L "$target" ]; then
    rm "$target"
    if ln -s "$source" "$target"; then
      ui_dim "  updated  $(basename "$target")  →  $source" >&2
      printf 'updated\n'
    else
      ui_warn "  failed   $(basename "$target")"
      printf 'failed\n'
    fi
  elif [ -e "$target" ]; then
    ui_warn "  skipped  $(basename "$target")  (non-symlink already exists at $target)"
    printf 'skipped\n'
  else
    if ln -s "$source" "$target"; then
      ui_dim "  installed  $(basename "$target")  →  $source" >&2
      printf 'installed\n'
    else
      ui_warn "  failed   $(basename "$target")"
      printf 'failed\n'
    fi
  fi
}

# symlinks_install_all CLONE PLATFORM SCOPE BASE
#   CLONE:    absolute path to lfx-skills clone
#   PLATFORM: claude | agents
#   SCOPE:    global | repo
#   BASE:     for global → config dir; for repo → repo path
# Creates one symlink per eligible skill in CLONE into the platform target dir.
# Records each created symlink in config.json.
# Echoes a summary line: "<installed>/<updated>/<skipped>/<total>"
symlinks_install_all() {
  local clone="$1" platform="$2" scope="$3" base="$4"
  local target_dir
  target_dir="$(platform_target_dir "$platform" "$scope" "$base")" || {
    ui_error "Unknown platform/scope: $platform/$scope"
    return 1
  }
  mkdir -p "$target_dir"

  local n_installed=0 n_updated=0 n_skipped=0 n_total=0
  local skill source target outcome

  while IFS= read -r skill; do
    [ -z "$skill" ] && continue
    n_total=$((n_total + 1))
    source="$clone/$skill"
    target="$target_dir/$skill"
    outcome="$(symlinks_create_one "$source" "$target")"
    case "$outcome" in
      installed)
        n_installed=$((n_installed + 1))
        config_add_symlink "$platform" "$scope" "$target" "$source" "$base"
        ;;
      updated)
        n_updated=$((n_updated + 1))
        config_add_symlink "$platform" "$scope" "$target" "$source" "$base"
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
