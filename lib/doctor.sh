# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
#
# Diagnostic checks for bin/lfx-skills doctor. Sourced; do not execute directly.
#
# Architecture: records flow as text. Each check writes pipe-delimited records
# to stdout; aggregators concatenate; formatters consume stdin and render either
# a human report or a JSON array. No temp files.
#
# Record shape: SEVERITY|CHECK_ID|CATEGORY|TITLE|DETAIL|FIXABLE|PAYLOAD
#   SEVERITY: pass | warn | fail
#   FIXABLE:  yes | no
#   PAYLOAD:  optional structured datum the auto-fix can use directly
#             (e.g. the symlink path for symlink-missing). Empty when N/A.
# Pipe character is forbidden in DETAIL/PAYLOAD (none of our checks use it).

# _emit SEVERITY ID CATEGORY TITLE DETAIL FIXABLE [PAYLOAD]
_emit() {
  printf '%s|%s|%s|%s|%s|%s|%s\n' "$1" "$2" "$3" "$4" "$5" "$6" "${7:-}"
}

# ─── Category 1: Symlinks ────────────────────────────────────────────────
check_symlinks() {
  if ! config_exists; then
    _emit warn no-config symlinks "No config.json found" \
      "Run \`lfx-skills install\` first." no
    return
  fi
  local link source skill_md_target n=0
  while IFS= read -r link; do
    [ -z "$link" ] && continue
    n=$((n + 1))
    if [ ! -L "$link" ]; then
      _emit fail symlink-missing symlinks \
        "Symlink missing: $(basename "$link")" \
        "Expected at $link" yes "$link"
      continue
    fi
    source="$(readlink "$link" || true)"
    if [ -z "$source" ] || [ ! -d "$source" ]; then
      _emit fail symlink-broken symlinks \
        "Broken symlink: $(basename "$link")" \
        "$link → $source (target not a directory)" yes "$link"
      continue
    fi
    skill_md_target="$source/SKILL.md"
    if [ ! -f "$skill_md_target" ]; then
      # Not fixable by the CLI: the symlink itself is correct; the source skill
      # has no SKILL.md, which is a content gap, not an install issue. The Phase
      # 4 /lfx-doctor skill can still act on this (e.g. offer to scaffold one).
      _emit warn symlink-no-skillmd symlinks \
        "Symlink target missing SKILL.md: $(basename "$link")" \
        "$skill_md_target does not exist" no
      continue
    fi
    _emit pass symlink-ok symlinks \
      "Symlink OK: $(basename "$link")" \
      "$link → $source" no
  done < <(config_list_symlinks)
  if [ "$n" -eq 0 ]; then
    _emit warn no-symlinks symlinks "No symlinks recorded in config" \
      "Run \`lfx-skills install\` to install skills." no
  fi
}

# ─── Category 2: Source clone ────────────────────────────────────────────
check_source_clone() {
  local recorded current
  recorded="$(config_get canonical_clone)"
  current="${CLONE_ROOT:-$(probe_canonical_clone "${BASH_SOURCE[0]:-$0}")}"
  if [ -z "$recorded" ]; then
    _emit warn clone-not-recorded source_clone \
      "Canonical clone not recorded" \
      "config.json has no canonical_clone." no
  elif [ "$recorded" != "$current" ]; then
    _emit warn clone-mismatch source_clone \
      "Source clone path drifted" \
      "Recorded: $recorded; running from: $current" no
  else
    _emit pass clone-match source_clone \
      "Source clone matches config" "$current" no
  fi
  if [ -d "$current/.git" ]; then
    if (cd "$current" && [ -z "$(git status --porcelain 2>/dev/null)" ]); then
      _emit pass clone-clean source_clone "Clone working tree clean" "$current" no
    else
      _emit warn clone-dirty source_clone \
        "Clone working tree has uncommitted changes" \
        "Run \`git status\` in $current" no
    fi
  fi
}

# ─── Category 3: LFX dev root ────────────────────────────────────────────
check_lfx_dev_root() {
  local recorded dev_root_file
  recorded="$(config_get lfx_dev_root)"
  dev_root_file="$(dev_root_path)"

  # The recorded path itself
  if [ -z "$recorded" ]; then
    _emit warn dev-root-not-recorded lfx_dev_root \
      "lfx_dev_root not recorded in config" \
      "Re-run \`lfx-skills install\` to capture it." no
  elif [ ! -d "$recorded" ]; then
    _emit fail dev-root-missing lfx_dev_root \
      "Recorded LFX dev root path does not exist" \
      "Recorded: $recorded" no
  else
    local repo_count
    repo_count="$(probe_count_repos_in "$recorded")"
    if [ "$repo_count" -eq 0 ]; then
      _emit warn dev-root-empty lfx_dev_root \
        "LFX dev root contains no lf* git repos" \
        "$recorded — clone some LFX repos here." no
    else
      _emit pass dev-root-ok lfx_dev_root \
        "LFX dev root has $repo_count lf* repo(s)" "$recorded" no
    fi
  fi

  # The dev-root cache file that skills `cat` to resolve LFX_DEV_ROOT
  if [ ! -f "$dev_root_file" ]; then
    _emit fail dev-root-file-missing lfx_dev_root \
      "Skills' dev-root cache file is missing" \
      "Expected at $dev_root_file. Run \`lfx-skills config set lfx_dev_root=...\` to regenerate." yes "$dev_root_file"
  else
    local file_value
    file_value="$(cat "$dev_root_file" 2>/dev/null)"
    if [ "$file_value" != "$recorded" ]; then
      _emit warn dev-root-file-mismatch lfx_dev_root \
        "dev-root file out of sync with config.json" \
        "File: $file_value; config: $recorded" yes "$dev_root_file"
    else
      _emit pass dev-root-file-ok lfx_dev_root \
        "dev-root cache file in sync with config" "$dev_root_file" no
    fi
  fi
}

# ─── Category 4: Platforms ───────────────────────────────────────────────
check_platforms() {
  local platforms_json
  platforms_json="$(config_get_json platforms)"
  if [ -z "$platforms_json" ] || [ "$platforms_json" = "null" ] || [ "$platforms_json" = "{}" ]; then
    _emit warn platforms-none platforms "No platforms recorded" \
      "config.json has no platforms entry." no
    return
  fi

  local claude_dirs
  claude_dirs="$(echo "$platforms_json" | jq -r '.claude.config_dirs[]?' 2>/dev/null)"
  if [ -n "$claude_dirs" ]; then
    if command -v claude >/dev/null 2>&1; then
      _emit pass cli-on-path platforms "claude CLI on PATH" "$(command -v claude)" no
    else
      _emit warn cli-not-on-path platforms "claude CLI not on PATH" \
        "Install Claude Code or check your PATH." no
    fi
    local d
    while IFS= read -r d; do
      [ -z "$d" ] && continue
      if [ -d "$d" ]; then
        _emit pass platform-dir-ok platforms "Claude config dir exists" "$d" no
      else
        _emit fail platform-dir-missing platforms \
          "Claude config dir missing" "$d" no
      fi
    done <<EOF
$claude_dirs
EOF
  fi

  local agents_dirs
  agents_dirs="$(echo "$platforms_json" | jq -r '.agents.config_dirs[]?' 2>/dev/null)"
  if [ -n "$agents_dirs" ]; then
    local d
    while IFS= read -r d; do
      [ -z "$d" ] && continue
      if [ -d "$d" ]; then
        _emit pass platform-dir-ok platforms "Agents config dir exists" "$d" no
      else
        _emit fail platform-dir-missing platforms \
          "Agents config dir missing" "$d" no
      fi
    done <<EOF
$agents_dirs
EOF
  fi
}

# ─── Category 5: Frontmatter ─────────────────────────────────────────────
check_frontmatter() {
  local clone
  clone="${CLONE_ROOT:-$(probe_canonical_clone "${BASH_SOURCE[0]:-$0}")}"
  local skill_md skill_name name_in_md desc_in_md
  for skill_md in "$clone"/lfx*/SKILL.md; do
    [ -f "$skill_md" ] || continue
    skill_name="$(basename "$(dirname "$skill_md")")"
    if [ "$(head -1 "$skill_md")" != "---" ]; then
      _emit fail frontmatter-missing frontmatter \
        "$skill_name: SKILL.md missing frontmatter" \
        "$skill_md does not start with ---" no
      continue
    fi
    local fm
    fm="$(awk 'NR==1 && /^---$/ {start=1; next} start && /^---$/ {exit} start {print}' "$skill_md")"
    name_in_md="$(printf '%s\n' "$fm" | awk -F': *' '/^name: */ {print $2; exit}')"
    desc_in_md="$(printf '%s\n' "$fm" | awk -F': *' '/^description: */ {print $2; exit}')"

    if [ -z "$name_in_md" ]; then
      _emit fail frontmatter-no-name frontmatter \
        "$skill_name: missing required \`name\` field" "$skill_md" no
    elif [ "$name_in_md" != "$skill_name" ]; then
      _emit fail frontmatter-name-mismatch frontmatter \
        "$skill_name: name field is \`$name_in_md\`, expected \`$skill_name\`" \
        "$skill_md" no
    fi
    if [ -z "$desc_in_md" ]; then
      if ! printf '%s\n' "$fm" | awk '/^description:/{f=1; next} f && /^[a-z_-]+:/{exit} f && /^ +./{print; exit}' | grep -q '.'; then
        _emit warn frontmatter-no-description frontmatter \
          "$skill_name: missing or empty \`description\` field" "$skill_md" no
      fi
    fi
  done
}

# ─── Category 6: Routing ─────────────────────────────────────────────────
check_routing() {
  local clone lfx_md
  clone="${CLONE_ROOT:-$(probe_canonical_clone "${BASH_SOURCE[0]:-$0}")}"
  lfx_md="$clone/lfx/SKILL.md"
  if [ ! -f "$lfx_md" ]; then
    _emit warn routing-no-lfx routing "/lfx skill not found" \
      "$lfx_md missing — routing check skipped." no
    return
  fi
  # Match /lfx-xxx only when the leading slash is at start-of-line or after a
  # non-word, non-slash char. Excludes path references like apps/lfx-one/foo.
  local routed s
  routed="$(grep -oE '(^|[^a-zA-Z0-9_/])/lfx-[a-z0-9-]+' "$lfx_md" | sed 's|^[^/]*||' | sort -u)"
  while IFS= read -r s; do
    [ -z "$s" ] && continue
    local skill_name="${s#/}"
    if [ ! -d "$clone/$skill_name" ]; then
      _emit warn routing-dangling routing \
        "/lfx mentions $s but skill directory missing" \
        "Expected $clone/$skill_name" no
    fi
  done <<EOF
$routed
EOF
  # Inverse: every USER-FACING skill mentioned in /lfx?
  # Skip /lfx itself and skills that intentionally don't belong in the user-task
  # router: internal builders only invoked by /lfx-coordinator, and management
  # surfaces (doctor / skills-helper) which the user reaches by name, not via
  # plain-language routing.
  local routing_exempt="lfx lfx-backend-builder lfx-ui-builder lfx-doctor lfx-skills-helper"
  local skill skipped
  while IFS= read -r skill; do
    [ -z "$skill" ] && continue
    skipped=0
    for ex in $routing_exempt; do
      if [ "$skill" = "$ex" ]; then skipped=1; break; fi
    done
    [ "$skipped" -eq 1 ] && continue
    if ! grep -qE "/${skill}([^a-z0-9-]|\$)" "$lfx_md" 2>/dev/null; then
      _emit warn routing-uncovered routing \
        "/lfx routing table does not mention /$skill" \
        "Add an entry for /$skill in $lfx_md" no
    fi
  done < <(symlinks_eligible_skills "$clone")
}

# ─── Category 7: License headers ─────────────────────────────────────────
check_license_headers() {
  local clone
  clone="${CLONE_ROOT:-$(probe_canonical_clone "${BASH_SOURCE[0]:-$0}")}"
  local skill_md skill_name
  for skill_md in "$clone"/lfx*/SKILL.md; do
    [ -f "$skill_md" ] || continue
    skill_name="$(basename "$(dirname "$skill_md")")"
    if head -4 "$skill_md" | grep -qF "Copyright The Linux Foundation"; then
      _emit pass license-ok license_headers "$skill_name has license header" "$skill_md" no
    else
      _emit fail license-missing license_headers \
        "$skill_name missing license header in first 4 lines" "$skill_md" no
    fi
  done
}

# ─── Aggregator ──────────────────────────────────────────────────────────
# doctor_run_all → emit every check's records to stdout, in category order.
doctor_run_all() {
  check_symlinks
  check_source_clone
  check_lfx_dev_root
  check_platforms
  check_frontmatter
  check_routing
  check_license_headers
}

# doctor_format_human → render results read from stdin as a colourised report.
# Single pass, buffering errors and warnings into shell variables before printing.
# Returns 0 if no failures, 1 otherwise.
doctor_format_human() {
  local pass=0 warn=0 fail=0
  local errors_buf="" warnings_buf=""
  local sev id cat title detail fixable payload line
  while IFS='|' read -r sev id cat title detail fixable payload; do
    case "$sev" in
      pass) pass=$((pass + 1)) ;;
      fail)
        fail=$((fail + 1))
        line="$(printf '  %s✗%s [%s] %s' "$_UI_RED" "$_UI_RESET" "$id" "$title")"
        errors_buf="${errors_buf}${line}"$'\n'
        if [ -n "$detail" ]; then
          errors_buf="${errors_buf}$(printf '      %s%s%s' "$_UI_DIM" "$detail" "$_UI_RESET")"$'\n'
        fi
        if [ "$fixable" = "yes" ]; then
          errors_buf="${errors_buf}$(printf '      %s(fixable: lfx-skills doctor --fix)%s' "$_UI_DIM" "$_UI_RESET")"$'\n'
        fi
        ;;
      warn)
        warn=$((warn + 1))
        line="$(printf '  %s⚠%s [%s] %s' "$_UI_YELLOW" "$_UI_RESET" "$id" "$title")"
        warnings_buf="${warnings_buf}${line}"$'\n'
        if [ -n "$detail" ]; then
          warnings_buf="${warnings_buf}$(printf '      %s%s%s' "$_UI_DIM" "$detail" "$_UI_RESET")"$'\n'
        fi
        if [ "$fixable" = "yes" ]; then
          warnings_buf="${warnings_buf}$(printf '      %s(fixable: lfx-skills doctor --fix)%s' "$_UI_DIM" "$_UI_RESET")"$'\n'
        fi
        ;;
    esac
  done

  ui_section "LFX Skills Health Check"
  printf '%s%d%s passed, %s%d%s warnings, %s%d%s errors\n\n' \
    "$_UI_GREEN" "$pass" "$_UI_RESET" \
    "$_UI_YELLOW" "$warn" "$_UI_RESET" \
    "$_UI_RED" "$fail" "$_UI_RESET"

  if [ "$fail" -gt 0 ]; then
    ui_bold "Errors:"
    printf '%s\n' "$errors_buf"
  fi
  if [ "$warn" -gt 0 ]; then
    ui_bold "Warnings:"
    printf '%s\n' "$warnings_buf"
  fi
  if [ "$fail" -eq 0 ] && [ "$warn" -eq 0 ]; then
    ui_success "All checks passed."
  fi

  [ "$fail" -eq 0 ]
}

# doctor_format_json → render results read from stdin as a JSON array on stdout.
doctor_format_json() {
  jq -Rsn '
    [inputs | split("\n")[] | select(length > 0) | split("|") |
     {severity: .[0], id: .[1], category: .[2], title: .[3], detail: .[4],
      fixable: (.[5] == "yes"), payload: (.[6] // "")}]
  '
}

# doctor_fix_one ID PAYLOAD → apply the auto-fix for the given check.
# Returns 0 on success, 1 on failure or unknown ID. PAYLOAD comes straight from
# the structured 7th column of the result record — no string parsing required.
doctor_fix_one() {
  local id="$1" payload="${2:-}"
  case "$id" in
    symlink-missing|symlink-broken)
      local link="$payload" source
      if [ -z "$link" ]; then
        ui_error "Internal: $id record has no payload."
        return 1
      fi
      source="$(config_read | jq -r --arg l "$link" '(.symlinks // [])[] | select(.link == $l) | .source' | head -1)"
      if [ -z "$source" ] || [ "$source" = "null" ]; then
        ui_error "No manifest entry for $link — re-run \`lfx-skills install\` to recreate."
        return 1
      fi
      if [ ! -d "$source" ]; then
        ui_error "Source skill missing on disk: $source"
        return 1
      fi
      [ -L "$link" ] && rm -f "$link"
      mkdir -p "$(dirname "$link")"
      ln -s "$source" "$link"
      ui_success "Recreated symlink: $link → $source"
      ;;
    dev-root-file-missing|dev-root-file-mismatch)
      write_dev_root_file
      ui_success "Wrote $(dev_root_path)"
      ;;
    *)
      ui_warn "No auto-fix available for: $id"
      return 1
      ;;
  esac
}
