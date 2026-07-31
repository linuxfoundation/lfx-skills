#!/usr/bin/env bash
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
#
# Run the three local reviewers as headless Pi processes and print their
# ordinary Markdown reports.
#
#   run-pi.sh [--repo <path>] [--commit <sha>] [--base <sha>] [--extra <text>]
#   run-pi.sh --readiness [--repo <path>]      # print the harness decision only
#
# Reviews one commit: the diff its parent introduced. `--base` overrides the
# parent when a caller wants a wider range; it is a parameter, not a mode, and
# the host never derives it. Nothing here fetches or consults a remote.
#
# This script does two jobs and nothing else: decide whether Pi can serve this
# run, and launch three Pi children against three physical skills. It keeps no
# durable review result or state, and never interprets a review.
#
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
# Reviewing is the kind of work that rewards deliberation, so the default is
# high rather than Pi's own. Pi 0.83 accepts off, minimal, low, medium, high,
# xhigh and max; an unknown value is rejected here rather than by three
# children at once, where it would read as three unrelated failures.
THINKING="${LFX_LOCAL_REVIEW_THINKING:-high}"
ROLES="general repo_code repo_learnings"

# Repo-owned reviewer skills. Overridable so a repo that keeps them elsewhere
# can point at them without central knowing its layout.
CODE_SKILL_REL="${LFX_LOCAL_REVIEW_CODE_SKILL:-.claude/skills/local-code-review/SKILL.md}"
LEARNINGS_SKILL_REL="${LFX_LOCAL_REVIEW_LEARNINGS_SKILL:-.claude/skills/local-learnings-review/SKILL.md}"

# A homepage link is not a path to a working reviewer. Give the three commands,
# name the provider to pick, and say what to do next -- the developer is in the
# middle of something else and this is an interruption, not a tutorial.
ONBOARDING="Pi is not available, so all three reviewers will run as Claude Opus
subagents instead. That is not the cross-model review: Pi with GitHub Copilot
GPT-5.6 Sol at thinking high is the intended cross-model check.

Install Pi:
  npm install -g @earendil-works/pi-coding-agent

Authenticate:
  pi
  /login

In Pi's login/provider picker, choose GitHub Copilot and complete login with the
Copilot-enabled GitHub account/seat. Then rerun local review.

Detail: references/pi-setup.md beside this skill, or
https://github.com/earendil-works/pi

Continuing now with the Claude Opus fallback."

# Host-detected failure. Never phrased as a reviewer's INCOMPLETE — only a
# reviewer that produced usable output may say that about its own review.
host_fail() {
  printf 'LOCAL REVIEW FAILED — %s\n' "$1" >&2
  exit 1
}

log() { printf '%s\n' "$1" >&2; }

# Validated here rather than at assignment: host_fail is defined just above, and
# calling it earlier would print "command not found" instead of a typed failure.
case "$THINKING" in
off | minimal | low | medium | high | xhigh | max) ;;
*) host_fail "LFX_LOCAL_REVIEW_THINKING must be one of off, minimal, low, medium, high, xhigh, max — got: $THINKING" ;;
esac

# --------------------------------------------------------------------------
# Arguments
# --------------------------------------------------------------------------
REPO=""
COMMIT=""
BASE_ARG=""
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
  --commit)
    need_value --commit $#
    COMMIT="$2"
    shift 2
    ;;
  --base)
    need_value --base $#
    BASE_ARG="$2"
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
    # Print the header block by shape, not by line number: a hardcoded range
    # silently truncates the moment the header grows, which is exactly what
    # happened when this comment block gained four lines.
    awk 'NR >= 5 && /^#/ { print; next } NR >= 5 { exit }' "${BASH_SOURCE[0]}"
    exit 0
    ;;
  *) host_fail "unknown option: $1" ;;
  esac
done

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
# Three children resolving HEAD for themselves is a race: the developer commits
# again mid-review and the reviewers disagree about what they reviewed. Pinning
# costs one git call and removes the whole class of problem — without a
# snapshot, a worktree or a patch file.
# --------------------------------------------------------------------------
TARGET_SHA="$(git -C "$REPO" rev-parse --verify --quiet 'HEAD^{commit}')" ||
  host_fail "no commit to review in $REPO"

# An explicitly named commit is accepted only if it IS the current HEAD. The
# point is to let a caller state what it believes it is reviewing and be told
# when that belief is stale -- not to review arbitrary history.
if [ -n "$COMMIT" ]; then
  want="$(git -C "$REPO" rev-parse --verify --quiet "$COMMIT^{commit}")" ||
    host_fail "--commit does not resolve to a commit in $REPO: $COMMIT"
  [ "$want" = "$TARGET_SHA" ] ||
    host_fail "--commit $COMMIT resolves to $want but HEAD is $TARGET_SHA — the working branch has moved"
fi

# The base defaults to the commit's first parent, which makes the reviewed range
# exactly what this commit introduced. A caller may name a different base to
# widen the range; the host neither derives nor second-guesses it, and never
# consults a remote to do so. A root commit has no parent, which is legitimate
# and means the range is the tree the root introduced.
if [ -n "$BASE_ARG" ]; then
  BASE_SHA="$(git -C "$REPO" rev-parse --verify --quiet "$BASE_ARG^{commit}")" ||
    host_fail "--base does not resolve to a commit in $REPO: $BASE_ARG"
else
  BASE_SHA="$(git -C "$REPO" rev-parse --verify --quiet "$TARGET_SHA^" 2>/dev/null)" || true
fi

# --------------------------------------------------------------------------
# Skill resolution
# --------------------------------------------------------------------------
# A skill is announced to the harness under the `name:` in its own frontmatter,
# which is NOT its directory name. A repo reaches its brain through a stable
# alias -- `.claude/skills/local-code-review` is a symlink to, say,
# `newsletter-service-code-reviewer` -- so naming the directory would tell the
# child to load a skill that does not exist under that name. Read the declared
# name, and read it only from the frontmatter block at the top of the file.
skill_name_of() {
  awk '
    NR == 1 && $0 != "---" { exit }         # no frontmatter at all
    NR > 1 && $0 == "---"  { exit }         # end of the block: stop looking
    NR > 1 && /^name:[[:space:]]*/ {
      sub(/^name:[[:space:]]*/, ""); sub(/[[:space:]]+$/, "")
      print; exit
    }
  ' "$1"
}

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
  # Unreadable or empty is as bad as absent. The child is told to load this
  # skill and follow it; if there is nothing to load it reviews with no rules
  # and still returns confident Markdown. Fail here, where it is visible.
  [ -r "$skill" ] ||
    host_fail "cannot read the $role reviewer skill at $skill"
  [ -s "$skill" ] ||
    host_fail "the $role reviewer skill at $skill is empty — it carries no rules to follow"
  # The child is told to load a skill BY NAME, so a skill that declares no name
  # cannot be asked for. Fail rather than fall back to the directory name: that
  # is how the child ends up told to load something that does not exist.
  [ -n "$(skill_name_of "$skill")" ] ||
    host_fail "the $role reviewer skill at $skill declares no 'name:' in its frontmatter — nothing to load it by"
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

# The pinned values, printed with every decision. Whoever acts on the decision
# must use THESE values.
#
# `none` is an explicit sentinel, not an empty field. A root commit genuinely
# has no parent — but an empty value after `=` is ambiguous between "no such
# thing" and "something went wrong and nobody noticed". The Claude fallback must
# not have to infer which it is, and the word it reads here is the same word the
# Pi children get in their prompts.
# Pins, plus what the review will actually be run by. The harness line is here
# so a developer confirming a manual test can see which model and thinking level
# produced a report without reading this script.
print_pins() {
  printf 'repo=%s\ntarget_sha=%s\nbase_sha=%s\n' \
    "$REPO" "$TARGET_SHA" "${BASE_SHA:-none}"
  printf 'provider=%s\nmodel=%s\nthinking=%s\n' \
    "$PROVIDER" "$MODEL_ID" "$THINKING"
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
  # ask again to get them, HEAD could have moved in between and the Claude trio
  # would review something other than what this decision was made about.
  # One decision, one set of pins.
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
  printf 'target_sha: %s\n' "$TARGET_SHA"
  if [ -n "$BASE_SHA" ]; then
    printf 'base_sha: %s\n' "$BASE_SHA"
    printf 'review exactly: git diff %s %s\n' "$BASE_SHA" "$TARGET_SHA"
  else
    printf 'base_sha: none (root commit)\n'
    printf 'review exactly: the tree introduced by root commit %s\n' "$TARGET_SHA"
  fi
  printf 'role: %s\n' "$role"
  [ -n "$EXTRA" ] && printf 'extra: %s\n' "$EXTRA"
  printf '\n'
  # `--skill` is the loading mechanism; the prompt does not restate the rules
  # and does not tell the child to go read a path. Measured against Pi 0.83.0:
  # the skill is announced, and the child loads it itself — in a canary run
  # given no reading instruction at all, it loaded the skill unprompted and
  # answered from it. So the prompt asks for the skill BY NAME and leaves the
  # loading to the harness — it never hands over a path to read, and never
  # restates the rules it would then have to keep in sync.
  printf 'Load the %s skill and follow it exactly. It is your entire rulebook.\n' \
    "$(skill_name_of "$skill")"
  # shellcheck disable=SC2016  # literal backticks for the reviewer, not expansion
  printf 'Review only the diff named above. Confirm `git rev-parse HEAD` equals\n'
  printf '%s before you rely on the working tree for anything.\n' "$TARGET_SHA"
  printf 'Return an ordinary Markdown review.\n'
}

# One temporary capture directory per run. `mktemp -d` creates it, so there is
# nothing left to make afterwards.
TMPDIR_RUN="$(mktemp -d "${TMPDIR:-/tmp}/lfx-local-review.XXXXXX")"
[ -n "$TMPDIR_RUN" ] ||
  host_fail "could not create a temporary capture directory for reviewer output"
# Ephemeral by construction: the captures exist only for the length of the run,
# and they go away with the process.
trap 'rm -rf "$TMPDIR_RUN"' EXIT

pids=""
for role in $ROLES; do
  skill="$(skill_for_role "$role")"
  (
    cd "$REPO" || exit 97
    exec pi -p --mode text --model "$PROVIDER/$MODEL_ID" --no-approve \
      --no-skills --no-context-files --no-prompt-templates --no-extensions \
      --tools read,bash,grep,find,ls \
      --thinking "$THINKING" --no-session \
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
