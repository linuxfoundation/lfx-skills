# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
#
# UI helpers for bin/lfx-skills. Sourced; do not execute directly.
# Targets bash 3.2+ (stock macOS).

# Color codes — only emitted when stdout is a TTY and NO_COLOR is unset.
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  _UI_RED=$'\033[31m'
  _UI_GREEN=$'\033[32m'
  _UI_YELLOW=$'\033[33m'
  _UI_BLUE=$'\033[34m'
  _UI_BOLD=$'\033[1m'
  _UI_DIM=$'\033[2m'
  _UI_RESET=$'\033[0m'
else
  _UI_RED=
  _UI_GREEN=
  _UI_YELLOW=
  _UI_BLUE=
  _UI_BOLD=
  _UI_DIM=
  _UI_RESET=
fi

ui_info()    { printf '%s\n' "$*"; }
ui_step()    { printf '%s==>%s %s\n' "$_UI_BLUE" "$_UI_RESET" "$*"; }
ui_success() { printf '%s✓%s %s\n'   "$_UI_GREEN" "$_UI_RESET" "$*"; }
ui_warn()    { printf '%s⚠%s %s\n'   "$_UI_YELLOW" "$_UI_RESET" "$*" >&2; }
ui_error()   { printf '%s✗%s %s\n'   "$_UI_RED" "$_UI_RESET" "$*" >&2; }
ui_dim()     { printf '%s%s%s\n'     "$_UI_DIM" "$*" "$_UI_RESET"; }
ui_bold()    { printf '%s%s%s\n'     "$_UI_BOLD" "$*" "$_UI_RESET"; }
ui_blank()   { printf '\n'; }

# ui_die MSG → print error and exit 1.
ui_die() { ui_error "$*"; exit 1; }

# ui_confirm "Question?" [default=N] → returns 0 if yes, 1 if no.
# Auto-answers Y when LFX_SKILLS_YES=1 (set by --yes flag).
# default arg: "Y" or "N" (case-insensitive).
ui_confirm() {
  local prompt="$1"
  local default="${2:-N}"
  local hint reply
  case "$default" in
    [Yy]*) hint="[Y/n]" ;;
    *)     hint="[y/N]" ;;
  esac
  if [ "${LFX_SKILLS_YES:-0}" = "1" ]; then
    printf '%s %s (auto-yes)\n' "$prompt" "$hint"
    return 0
  fi
  printf '%s %s ' "$prompt" "$hint" >&2
  read -r reply || reply=""
  reply="${reply:-$default}"
  case "$reply" in
    [Yy]|[Yy][Ee][Ss]) return 0 ;;
    *) return 1 ;;
  esac
}

# ui_input "Question?" [default] → echo user input to stdout (default if empty).
# Auto-uses default when LFX_SKILLS_YES=1.
ui_input() {
  local prompt="$1"
  local default="${2:-}"
  local reply
  if [ "${LFX_SKILLS_YES:-0}" = "1" ]; then
    printf '%s\n' "$default"
    return 0
  fi
  if [ -n "$default" ]; then
    printf '%s [%s]: ' "$prompt" "$default" >&2
  else
    printf '%s: ' "$prompt" >&2
  fi
  read -r reply || reply=""
  printf '%s\n' "${reply:-$default}"
}

# ui_select "Question?" OPT1 OPT2 ... → echo chosen option to stdout.
# Auto-picks first option when LFX_SKILLS_YES=1.
ui_select() {
  local prompt="$1"; shift
  local n=$#
  if [ "$n" -eq 0 ]; then
    ui_die "ui_select: no options provided"
  fi
  if [ "${LFX_SKILLS_YES:-0}" = "1" ]; then
    printf '%s\n' "$1"
    return 0
  fi
  printf '%s\n' "$prompt" >&2
  local i=1
  for opt in "$@"; do
    printf '  %d) %s\n' "$i" "$opt" >&2
    i=$((i + 1))
  done
  local reply
  while true; do
    printf 'Choose 1-%d: ' "$n" >&2
    read -r reply || reply=""
    case "$reply" in
      ''|*[!0-9]*) ui_warn "Enter a number 1-$n." ;;
      *)
        if [ "$reply" -ge 1 ] && [ "$reply" -le "$n" ]; then
          # shift is 1-indexed, so use eval to grab nth arg
          eval "printf '%s\n' \"\${$reply}\""
          return 0
        else
          ui_warn "Out of range. Pick 1-$n."
        fi
        ;;
    esac
  done
}

# ui_multiselect "Question?" "default-spec" OPT1 OPT2 ...
# default-spec: comma-separated 1-indexed positions selected by default
#               (e.g., "1,3" or "" for none, "all" for everything).
# Echoes one selected option per line.
# Auto-picks defaults when LFX_SKILLS_YES=1.
ui_multiselect() {
  local prompt="$1"; shift
  local default_spec="$1"; shift
  local n=$#
  if [ "$n" -eq 0 ]; then
    return 0
  fi
  local -a opts
  local i=1
  for opt in "$@"; do
    opts[i]="$opt"
    i=$((i + 1))
  done

  _expand_default_spec() {
    case "$1" in
      all) seq 1 "$n" | tr '\n' ',' | sed 's/,$//' ;;
      none|"") echo "" ;;
      *) echo "$1" ;;
    esac
  }

  if [ "${LFX_SKILLS_YES:-0}" = "1" ]; then
    local resolved
    resolved="$(_expand_default_spec "$default_spec")"
    if [ -z "$resolved" ]; then
      return 0
    fi
    local IFS=','
    for idx in $resolved; do
      printf '%s\n' "${opts[$idx]}"
    done
    return 0
  fi

  printf '%s\n' "$prompt" >&2
  i=1
  for opt in "$@"; do
    printf '  %d) %s\n' "$i" "$opt" >&2
    i=$((i + 1))
  done

  local hint default_resolved
  default_resolved="$(_expand_default_spec "$default_spec")"
  if [ -n "$default_resolved" ]; then
    hint="comma-separated, e.g. \"1,3\"; \"all\"; \"none\"; or Enter for default [$default_resolved]"
  else
    hint="comma-separated, e.g. \"1,3\"; \"all\"; \"none\"; or Enter for none"
  fi

  local reply
  while true; do
    printf '%s: ' "$hint" >&2
    read -r reply || reply=""
    if [ -z "$reply" ]; then
      reply="$default_resolved"
    fi
    case "$reply" in
      all) reply="$(seq 1 "$n" | tr '\n' ',' | sed 's/,$//')" ;;
      none) return 0 ;;
    esac
    if [ -z "$reply" ]; then
      return 0
    fi
    # Validate each token is a number in range
    local valid=1 token
    local IFS=','
    for token in $reply; do
      token="${token# }"; token="${token% }"
      case "$token" in
        ''|*[!0-9]*) valid=0; break ;;
        *)
          if [ "$token" -lt 1 ] || [ "$token" -gt "$n" ]; then
            valid=0; break
          fi
          ;;
      esac
    done
    if [ "$valid" -eq 1 ]; then
      for token in $reply; do
        token="${token# }"; token="${token% }"
        printf '%s\n' "${opts[$token]}"
      done
      return 0
    fi
    ui_warn "Invalid selection. Use comma-separated numbers in 1-$n, \"all\", or \"none\"."
  done
}

# ui_checkbox_select PROMPT DEFAULT_SPEC MIN_REQUIRED OPT1 OPT2 ...
#   PROMPT       text shown above the menu
#   DEFAULT_SPEC same shape as ui_multiselect: "1,2", "all", "none"/""
#   MIN_REQUIRED minimum number of items that must be selected before Enter
#                is accepted (use 1 for "select one or both")
#   OPT*         option strings (also the values emitted to stdout on confirm)
#
# Renders an interactive checkbox menu on stderr; emits each selected option
# (one per line) on stdout. Navigation:
#   ↑ / ↓ or k / j   move the cursor (wraps top/bottom)
#   space            toggle the current item
#   enter            confirm (refused if fewer than MIN_REQUIRED selected)
#   q or Esc         cancel (returns 1, no output)
#
# When LFX_SKILLS_YES=1, emits the resolved defaults without rendering.
# When stdin or stderr is not a TTY, falls back to the number-prompt
# implementation in ui_multiselect (so CI / piped input keeps working).
ui_checkbox_select() {
  local prompt="$1" default_spec="$2" min_required="$3"
  shift 3
  local n=$#
  [ "$n" -eq 0 ] && return 0

  local i opt
  local -a opts=()
  for opt in "$@"; do opts[${#opts[@]}]="$opt"; done

  # Compute initial selection state from the default spec.
  local -a selected=()
  for ((i=0; i<n; i++)); do selected[i]=0; done
  case "$default_spec" in
    all) for ((i=0; i<n; i++)); do selected[i]=1; done ;;
    none|"") ;;
    *)
      local _idx
      for _idx in $(printf '%s' "$default_spec" | tr ',' ' '); do
        case "$_idx" in
          ''|*[!0-9]*) continue ;;
          *)
            if [ "$_idx" -ge 1 ] && [ "$_idx" -le "$n" ]; then
              selected[_idx-1]=1
            fi
            ;;
        esac
      done
      ;;
  esac

  # Auto-pick path: respect LFX_SKILLS_YES.
  if [ "${LFX_SKILLS_YES:-0}" = "1" ]; then
    for ((i=0; i<n; i++)); do
      [ "${selected[i]}" = "1" ] && printf '%s\n' "${opts[i]}"
    done
    return 0
  fi

  # Non-TTY fallback: use the existing numbered ui_multiselect.
  if ! [ -t 0 ] || ! [ -t 2 ]; then
    ui_multiselect "$prompt" "$default_spec" "${opts[@]}"
    return $?
  fi

  # Save terminal state and ensure restore on any exit.
  local _stty_saved
  _stty_saved="$(stty -g 2>/dev/null || true)"
  trap 'stty '"'$_stty_saved'"' 2>/dev/null; printf "\033[?25h" >&2' EXIT INT TERM
  stty -icanon -echo 2>/dev/null
  printf '\033[?25l' >&2  # hide cursor

  # Header (printed once).
  printf '%s\n' "$prompt" >&2
  printf '  %s↑/↓ move • space toggle • enter confirm • q cancel%s\n' \
    "$_UI_DIM" "$_UI_RESET" >&2

  # Render the option block (callable repeatedly).
  _ui_cb_render() {
    local _i marker arrow
    for ((_i=0; _i<n; _i++)); do
      marker=' '
      arrow=' '
      [ "${selected[_i]}" = "1" ] && marker='x'
      if [ "$_i" -eq "$cursor" ]; then
        arrow='›'
        printf '\033[K  %s%s%s [%s] %s\n' "$_UI_BOLD" "$arrow" "$_UI_RESET" "$marker" "${opts[_i]}" >&2
      else
        printf '\033[K  %s [%s] %s\n' "$arrow" "$marker" "${opts[_i]}" >&2
      fi
    done
  }

  local cursor=0
  _ui_cb_render

  # Event loop.
  local key rest cancelled=0 count
  while true; do
    IFS= read -rsn1 key || break
    case "$key" in
      $'\e')
        # Could be a 3-byte arrow-key escape (ESC '[' 'A'/'B'/'C'/'D')
        # or a bare Esc (timeout fires, $rest stays empty).
        IFS= read -rsn2 -t 0.05 rest || rest=""
        case "$rest" in
          '[A')  cursor=$(( (cursor - 1 + n) % n )) ;;  # Up
          '[B')  cursor=$(( (cursor + 1) % n )) ;;       # Down
          '')    cancelled=1; break ;;                    # bare Esc
          *)     ;;                                       # ignore other seqs
        esac
        ;;
      'k') cursor=$(( (cursor - 1 + n) % n )) ;;          # vim up
      'j') cursor=$(( (cursor + 1) % n )) ;;              # vim down
      ' ')                                                 # toggle
        if [ "${selected[cursor]}" = "1" ]; then
          selected[cursor]=0
        else
          selected[cursor]=1
        fi
        ;;
      '')                                                  # Enter
        count=0
        for ((i=0; i<n; i++)); do
          [ "${selected[i]}" = "1" ] && count=$((count + 1))
        done
        if [ "$count" -ge "$min_required" ]; then
          break
        fi
        # Below threshold: flash a warning and keep waiting.
        printf '\033[K  %s(select at least %d before pressing enter)%s\r' \
          "$_UI_YELLOW" "$min_required" "$_UI_RESET" >&2
        # The next render below will overwrite this line via the up-N-lines move.
        ;;
      q|Q) cancelled=1; break ;;
      *) ;;
    esac
    # Move cursor up to start of options block, then redraw.
    printf '\033[%dA' "$n" >&2
    _ui_cb_render
  done

  # Restore terminal state.
  stty "$_stty_saved" 2>/dev/null
  printf '\033[?25h' >&2
  trap - EXIT INT TERM

  if [ "$cancelled" -eq 1 ]; then
    printf '\n' >&2
    return 1
  fi

  # Emit selected options on stdout.
  for ((i=0; i<n; i++)); do
    [ "${selected[i]}" = "1" ] && printf '%s\n' "${opts[i]}"
  done
  return 0
}

# ui_section "Title" → bold heading + underline.
ui_section() {
  local title="$1"
  local len=${#title}
  printf '\n%s%s%s\n' "$_UI_BOLD" "$title" "$_UI_RESET"
  printf '%s\n' "$(printf '%*s' "$len" '' | tr ' ' '─')"
}
