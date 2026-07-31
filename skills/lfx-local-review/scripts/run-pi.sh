#!/usr/bin/env bash
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
#
# Run the three local reviewers as headless Pi processes and print their
# ordinary Markdown reports.
#
#   run-pi.sh --repo <path> [--mode post-commit|branch] [--extra <text>]
#   run-pi.sh --readiness [--repo <path>]      # print the harness decision only
#
# This script does two jobs and nothing else: decide whether Pi can serve this
# run, and launch three Pi children against three physical skills. It holds no
# state, writes nothing durable, and never interprets a review.
#
# Everything it deliberately does NOT do: no run ids, no worktrees or
# snapshots, no cleanup or cancellation commands, no liveness records, no
# result schema, no aggregation, no verdict. A review is whatever the reviewer
# wrote.

set -uo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERAL_SKILL="$(cd "$SKILL_DIR/../lfx-general-code-review" && pwd)/SKILL.md"
PROVIDER="${LFX_LOCAL_REVIEW_PROVIDER:-github-copilot}"
MODEL_ID="${LFX_LOCAL_REVIEW_MODEL:-gpt-5.6-sol}"
ROLES="general repo_code repo_learnings"

# Repo-owned reviewer skills. Overridable so a repo that keeps them elsewhere
# can point at them without central knowing its layout.
CODE_SKILL_REL="${LFX_LOCAL_REVIEW_CODE_SKILL:-.claude/skills/local-code-review/SKILL.md}"
LEARNINGS_SKILL_REL="${LFX_LOCAL_REVIEW_LEARNINGS_SKILL:-.claude/skills/local-learnings-review/SKILL.md}"

ONBOARDING="Pi is not available, so all three reviewers will run on Claude
instead. That makes this a same-model review, not the cross-model one. To get
the cross-model review, install Pi (https://aweb.ai/docs/pi/) and authenticate
it with your Copilot seat, then run this again."

# Host-detected failure. Never phrased as a reviewer's INCOMPLETE — only a
# reviewer that produced usable output may say that about its own review.
host_fail() {
  printf 'LOCAL REVIEW FAILED — %s\n' "$1" >&2
  exit 1
}

log() { printf '%s\n' "$1" >&2; }

# --------------------------------------------------------------------------
# Arguments
# --------------------------------------------------------------------------
REPO=""
MODE="post-commit"
EXTRA=""
READINESS_ONLY=""

# An option that takes a value must actually have one. Without this check a
# trailing `--repo` leaves $# at 1, `shift 2` fails without consuming anything,
# and the loop spins on the same argument forever at full CPU.
need_value() {
  [ "$2" -ge 2 ] || host_fail "$1 requires a value"
}

while [ $# -gt 0 ]; do
  case "$1" in
  --repo)
    need_value --repo $#
    REPO="$2"
    shift 2
    ;;
  --mode)
    need_value --mode $#
    MODE="$2"
    shift 2
    ;;
  --extra)
    need_value --extra $#
    EXTRA="$2"
    shift 2
    ;;
  --readiness)
    READINESS_ONLY="yes"
    shift
    ;;
  -h | --help)
    sed -n '5,20p' "${BASH_SOURCE[0]}"
    exit 0
    ;;
  *) host_fail "unknown option: $1" ;;
  esac
done

case "$MODE" in
post-commit | branch) ;;
*) host_fail "--mode must be post-commit or branch, got: $MODE" ;;
esac

# --------------------------------------------------------------------------
# Repo resolution — a path contract, deliberately boring.
#
# Either the caller hands us a path, or we take the repo we are standing in.
# There is no search by name and no walking of sibling directories: guessing
# which repo the developer meant is how a review silently audits the wrong one.
# A workspace-root caller resolves the path itself and passes --repo.
# --------------------------------------------------------------------------
if [ -n "$REPO" ]; then
  [ -d "$REPO" ] || host_fail "--repo is not a directory: $REPO"
  REPO="$(cd "$REPO" && git rev-parse --show-toplevel 2>/dev/null)" ||
    host_fail "--repo is not inside a git repository: $REPO"
else
  REPO="$(git rev-parse --show-toplevel 2>/dev/null)" ||
    host_fail "not inside a git repository, and no --repo <path> was given"
fi

# --------------------------------------------------------------------------
# Pin the revisions ONCE, before any child starts.
#
# Three children reading a moving HEAD is a race: the developer commits again
# mid-review and the reviewers disagree about what they reviewed. Pinning costs
# one git call and removes the whole class of problem — without a snapshot, a
# worktree or a patch file.
# --------------------------------------------------------------------------
# Fetch first, then pin — in that order. Exactly one fetch, here, before any
# child and before any revision is pinned. The children never fetch for the
# base: three concurrent fetches would contend on the same remote-tracking ref
# lock, and a fetch landing mid-run could move the base out from under reviewers
# who had already started. Pinning strictly afterwards means every pinned value
# describes the post-fetch state, and a later fetch by anyone cannot change what
# this run is reviewing.
#
# Note this makes branch mode require network. That is deliberate — a branch
# sweep measured against a stale base is a wrong answer that looks like a right
# one — but it does mean branch mode cannot run offline. Post-commit mode needs
# no fetch and still works.
if [ "$MODE" = "branch" ]; then
  log "lfx-local-review: fetching origin once to establish the branch base."
  git -C "$REPO" fetch origin --quiet ||
    host_fail "could not fetch origin in $REPO, so the branch base cannot be established"
fi

TARGET_SHA="$(git -C "$REPO" rev-parse --verify --quiet 'HEAD^{commit}')" ||
  host_fail "no commit to review in $REPO"

BASE_SHA=""
ORIGIN_MAIN_SHA=""
if [ "$MODE" = "branch" ]; then
  ORIGIN_MAIN_SHA="$(git -C "$REPO" rev-parse --verify --quiet 'origin/main^{commit}')" ||
    host_fail "local origin/main is unavailable in $REPO even after fetching"
  # The base is the MERGE-BASE, not the origin/main tip. When origin/main has
  # advanced on a divergent line the tip is not the pre-change state, and the
  # false-positive floor must be read from the state the patch started from.
  BASE_SHA="$(git -C "$REPO" merge-base "$ORIGIN_MAIN_SHA" "$TARGET_SHA")" ||
    host_fail "no merge-base between origin/main and $TARGET_SHA in $REPO"
else
  # Post-commit: the base is the first parent. A root commit has none, which is
  # legitimate and means an empty pre-change floor — not an error.
  BASE_SHA="$(git -C "$REPO" rev-parse --verify --quiet "$TARGET_SHA^" 2>/dev/null)" || true
fi

# --------------------------------------------------------------------------
# Skill resolution
# --------------------------------------------------------------------------
skill_for_role() {
  case "$1" in
  general) printf '%s\n' "$GENERAL_SKILL" ;;
  repo_code) printf '%s\n' "$REPO/$CODE_SKILL_REL" ;;
  repo_learnings) printf '%s\n' "$REPO/$LEARNINGS_SKILL_REL" ;;
  esac
}

for role in $ROLES; do
  skill="$(skill_for_role "$role")"
  [ -f "$skill" ] ||
    host_fail "no $role reviewer skill at $skill — this repo does not own local review brains"
done

# --------------------------------------------------------------------------
# Harness readiness.
#
# Best-effort and checked once, before any child. A successful model listing
# proves the model is discoverable right now — not that authentication will
# still hold in ten minutes. If it lapses mid-run the Pi run fails plainly; we
# never switch harness half way, because a trio split across two models is not
# a cross-model review of anything.
# --------------------------------------------------------------------------
pi_ready() {
  command -v pi >/dev/null 2>&1 || {
    printf 'PI_NOT_INSTALLED\n'
    return 1
  }
  local listing
  listing="$(pi --no-approve --no-extensions --list-models "$PROVIDER" 2>/dev/null)" || {
    printf 'PI_UNAUTHENTICATED\n'
    return 1
  }
  printf '%s' "$listing" |
    awk -v p="$PROVIDER" -v m="$MODEL_ID" '$1==p && $2==m {f=1} END{exit f?0:1}' || {
    printf 'PI_MODEL_UNAVAILABLE\n'
    return 1
  }
  printf 'PI_READY\n'
  return 0
}

READINESS="$(pi_ready)" || true

# The pinned values, printed with every decision. This run has already fetched
# (branch mode) and pinned; whoever acts on the decision must use THESE values.
print_pins() {
  printf 'repo=%s\nmode=%s\ntarget_sha=%s\nbase_sha=%s\norigin_main_sha=%s\n' \
    "$REPO" "$MODE" "$TARGET_SHA" "${BASE_SHA:-}" "${ORIGIN_MAIN_SHA:-}"
}

if [ -n "$READINESS_ONLY" ]; then
  printf '%s\n' "$READINESS"
  print_pins
  [ "$READINESS" = "PI_READY" ] || printf '\n%s\n' "$ONBOARDING"
  exit 0
fi

if [ "$READINESS" != "PI_READY" ]; then
  # Not a failure — it is the decision to run the other harness. The host reads
  # this and launches three Claude subagents instead.
  #
  # The pinned values go out WITH the decision, deliberately. If the host had to
  # ask again to get them, branch mode would fetch and pin a second time, and
  # the Claude trio could end up reviewing a different target or base than the
  # one this decision was made about. One decision, one fetch, one set of pins.
  printf '%s\n' "$READINESS"
  print_pins
  printf '\n%s\n' "$ONBOARDING"
  exit 0
fi

# --------------------------------------------------------------------------
# Launch
# --------------------------------------------------------------------------
role_prompt() {
  local role="$1" skill="$2"
  printf 'target repo: %s\n' "$REPO"
  printf 'mode: %s\n' "$MODE"
  printf 'target_sha: %s\n' "$TARGET_SHA"
  if [ -n "$BASE_SHA" ]; then
    printf 'base_sha: %s\n' "$BASE_SHA"
  else
    printf 'base_sha: none (root commit — the pre-change false-positive floor is empty)\n'
  fi
  [ -n "$ORIGIN_MAIN_SHA" ] &&
    printf 'origin_main_sha: %s (fetched once by the host, then pinned, immediately before this run)\n' "$ORIGIN_MAIN_SHA"
  printf 'role: %s\n' "$role"
  [ -n "$EXTRA" ] && printf 'extra: %s\n' "$EXTRA"
  printf '\n'
  # Naming the skill in the prompt as well as passing --skill is deliberate
  # belt and braces: --skill loading alongside --no-skills works but is not
  # documented to, so the prompt does not depend on it.
  printf 'Read %s in full and follow it exactly. It is your entire rulebook.\n' "$skill"
  printf 'Review the pinned revisions above — not a moving HEAD.\n'
  printf 'Return an ordinary Markdown review.\n'
}

TMPDIR_RUN="$(mktemp -d "${TMPDIR:-/tmp}/lfx-local-review.XXXXXX")" ||
  host_fail "could not create a temporary directory for reviewer output"
# Ephemeral by construction: the captures exist only to keep three concurrent
# children from interleaving, and they go away with the process.
trap 'rm -rf "$TMPDIR_RUN"' EXIT

pids=""
for role in $ROLES; do
  skill="$(skill_for_role "$role")"
  (
    cd "$REPO" || exit 97
    exec pi -p --mode text --model "$PROVIDER/$MODEL_ID" --no-session --no-approve \
      --no-skills --no-context-files --no-prompt-templates --no-extensions \
      --tools read,bash,grep,find,ls \
      --skill "$skill" \
      "$(role_prompt "$role" "$skill")"
  ) >"$TMPDIR_RUN/$role.out" 2>"$TMPDIR_RUN/$role.err" </dev/null &
  pids="$pids $role:$!"
done

# Wait on each child and record its outcome. `rc` is captured immediately:
# testing the exit status inside a negation would throw the number away, and
# the number is what tells a developer whether the reviewer crashed or was
# killed.
failed=""
for entry in $pids; do
  role="${entry%%:*}"
  pid="${entry##*:}"
  wait "$pid"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    failed="$failed $role:exit-$rc"
  elif [ ! -s "$TMPDIR_RUN/$role.out" ]; then
    # Exit 0 with nothing on stdout is its own failure: a reviewer that said
    # nothing has not reviewed anything, and rendering that as "no findings"
    # would turn a broken run into a clean bill of health.
    failed="$failed $role:empty"
  fi
done

role_label() { printf '%s' "$1" | tr '[:lower:]_' '[:upper:] '; }

# Why a role failed, or nonzero if it succeeded.
reason_for() {
  local wanted="$1" entry
  for entry in $failed; do
    if [ "${entry%%:*}" = "$wanted" ]; then
      printf '%s' "${entry##*:}"
      return 0
    fi
  done
  return 1
}

failure_line() {
  case "$2" in
  empty) printf '%s REVIEW FAILED — the reviewer exited 0 but produced no output.\n' "$(role_label "$1")" ;;
  exit-*) printf '%s REVIEW FAILED — process exited %s.\n' "$(role_label "$1")" "${2#exit-}" ;;
  esac
}

# Emit in a FIXED role order, so two runs of the same commit read the same way
# regardless of which child finished first.
#
# A failed role's stdout is DISCARDED, never printed under its heading. A
# crashed reviewer can leave perfectly plausible half-written Markdown behind,
# and a developer reading stdout — or piping it to a file — would have no way to
# tell it apart from a finished review. The failure is stated in the same stream
# so that stdout alone is never misleading.
for role in $ROLES; do
  printf '\n===== %s =====\n\n' "$role"
  if reason="$(reason_for "$role")"; then
    failure_line "$role" "$reason"
    printf 'No review was produced. Any partial output from the failed process\n'
    printf 'has been discarded: it is not a review and must not be read as one.\n'
  else
    cat "$TMPDIR_RUN/$role.out"
  fi
done

if [ -n "$failed" ]; then
  printf '\n'
  for entry in $failed; do
    role="${entry%%:*}"
    reason="${entry##*:}"
    failure_line "$role" "$reason" >&2
    if [ -s "$TMPDIR_RUN/$role.err" ]; then
      printf '  stderr: %s\n' "$(head -c 2000 "$TMPDIR_RUN/$role.err" | tr '\n' ' ')" >&2
    fi
  done
  printf '\nThis review cycle is incomplete. Rerun the whole trio on the same harness.\n' >&2
  exit 1
fi
