#!/usr/bin/env bash
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
#
# Watch a local review while it runs.
#
#   watch.sh <run-dir> [role]     follow one role, or all three interleaved
#   watch.sh --tmux <run-dir>     one pane per role, then attach
#
# The run directory is printed by run-pi.sh when it starts. Transcripts live
# only for the length of the run: when the review ends they are deleted, so
# this is a window onto work in progress, never an archive.
#
# What you are reading is the reviewer's own transcript -- what it read, which
# commands it ran, what it concluded. It is NOT the review. The review is the
# Markdown run-pi.sh prints when it finishes, and only that is worth citing.
set -uo pipefail

ROLES="general repo_code repo_learnings"

die() { printf 'watch: %s\n' "$1" >&2; exit 1; }

TMUX_MODE=""
[ "${1:-}" = "--tmux" ] && { TMUX_MODE=yes; shift; }

DIR="${1:-}"
[ -n "$DIR" ] || die "usage: watch.sh [--tmux] <run-dir> [role]"
[ -d "$DIR" ] || die "no such run directory: $DIR
The run may already have finished -- transcripts are deleted when it ends."
ROLE="${2:-}"

# Render a transcript readably. Falls back to the raw JSONL when jq is absent,
# which is ugly but still shows progress rather than failing.
render() {
  local file="$1" label="$2"
  if command -v jq >/dev/null 2>&1; then
    tail -F -n +1 "$file" 2>/dev/null | jq -r --unbuffered --arg L "$label" '
      select(.type=="message")
      | .message.role as $r
      | (.message.content // [])[]
      | if   .type=="text"     then "\($L)[\($r)] \(.text)"
        elif .type=="thinking" then "\($L)[thinking] \(((.thinking // .text) // "")[0:100])"
        elif .type=="toolCall" then "\($L)  > \(.name) \((.arguments|tostring)[0:100])"
        else empty end'
  else
    tail -F -n +1 "$file" 2>/dev/null
  fi
}

if [ -n "$TMUX_MODE" ]; then
  command -v tmux >/dev/null 2>&1 || die "tmux is not installed. Run without --tmux to follow in this terminal."
  self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
  session="lfx-review-$(basename "$DIR")"
  if tmux has-session -t "$session" 2>/dev/null; then
    exec tmux attach -t "$session"
  fi
  # shellcheck disable=SC2086  # deliberate word split of the role list
  set -- $ROLES
  tmux new-session -d -s "$session" -n review "$self" "$DIR" "$1" || die "could not start tmux session"
  shift
  for r in "$@"; do tmux split-window -t "$session:review" "$self" "$DIR" "$r"; done
  tmux select-layout -t "$session:review" even-vertical >/dev/null
  exec tmux attach -t "$session"
fi

if [ -n "$ROLE" ]; then
  case " $ROLES " in *" $ROLE "*) ;; *) die "unknown role: $ROLE (expected one of: $ROLES)" ;; esac
  render "$DIR/sessions/$ROLE.jsonl" ""
else
  # All three at once. Each line is prefixed so interleaved output stays
  # attributable -- and interleaved order is NOT the report's fixed order.
  pids=""
  for r in $ROLES; do
    render "$DIR/sessions/$r.jsonl" "$(printf '%-15s| ' "$r")" &
    pids="$pids $!"
  done
  # shellcheck disable=SC2064
  trap "kill $pids 2>/dev/null" INT TERM EXIT
  wait
fi
