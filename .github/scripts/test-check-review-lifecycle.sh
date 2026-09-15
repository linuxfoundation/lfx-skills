#!/usr/bin/env bash
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
#
# Mutation tests for check-review-lifecycle.sh.
#
# The checker is a bundle of negative assertions over a fixed set of files, and
# a negative assertion whose guard has stopped firing is indistinguishable from
# one that passes. So each case copies the guarded surface into a throwaway
# tree, applies exactly one mutation, and asserts that the checker fails and
# names the mutation — not just that it exits non-zero. One unmutated case
# pins the baseline so a broken copy cannot make every mutation "pass".
#
# This is deliberately small: one case per guard family, not one per
# assertion. The checker's own `need`/`reject` lines are the exhaustive list.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHECKER=.github/scripts/check-review-lifecycle.sh

pass=0
fail=0

# fresh_tree: copy only what the checker reads, so each case is independent
fresh_tree() {
  local dir
  dir=$(mktemp -d)
  mkdir -p "$dir/.github/scripts" "$dir/.github/workflows" \
           "$dir/skills/lfx-local-review" "$dir/skills/lfx-general-code-review" \
           "$dir/skills/lfx" "$dir/skills/lfx-pr-resolve"
  cp "$ROOT/$CHECKER" "$dir/$CHECKER"
  cp "$ROOT/.github/workflows/review-lifecycle-check.yml" "$dir/.github/workflows/"
  cp -R "$ROOT/skills/lfx-local-review/." "$dir/skills/lfx-local-review/"
  cp -R "$ROOT/skills/lfx-general-code-review/." "$dir/skills/lfx-general-code-review/"
  cp "$ROOT/skills/lfx/SKILL.md" "$dir/skills/lfx/SKILL.md"
  cp "$ROOT/skills/lfx-pr-resolve/SKILL.md" "$dir/skills/lfx-pr-resolve/SKILL.md"
  cp "$ROOT/README.md" "$dir/README.md"
  printf '%s' "$dir"
}

# run_case <name> <expected: ok|bad> <expected message substring> <mutation command run inside the tree>
run_case() {
  local name="$1" expect="$2" want="$3" mutate="$4"
  local dir out rc got

  dir=$(fresh_tree)
  (cd "$dir" && eval "$mutate") >/dev/null 2>&1 || {
    echo "FAIL  $name — mutation did not apply"
    fail=$((fail + 1)); rm -rf "$dir"; return
  }

  if out=$(cd "$dir" && "./$CHECKER" 2>&1); then rc=0; else rc=$?; fi
  rm -rf "$dir"

  got="ok"; [ "$rc" -ne 0 ] && got="bad"
  if [ "$got" != "$expect" ]; then
    echo "FAIL  $name — expected $expect, got $got"
    echo "$out" | sed 's/^/        /'
    fail=$((fail + 1)); return
  fi
  if [ -n "$want" ] && ! grep -qF -- "$want" <<<"$out"; then
    echo "FAIL  $name — expected message containing: $want"
    echo "$out" | sed 's/^/        /'
    fail=$((fail + 1)); return
  fi
  echo "ok    $name"
  pass=$((pass + 1))
}

# --- baseline -------------------------------------------------------------
run_case "unmutated tree passes" ok "all groups passed" "true"

# --- frozen canonical lifecycle -------------------------------------------
# One byte inside the hashed sections must change the hash: THREE -> TWO in the
# batch rule. The message must name the hash, not just some phrase assertion.
run_case "canonical byte change is caught" bad "hash is" \
  "sed -i.bak 's/exactly THREE generic background subagents/exactly TWO generic background subagents/' skills/lfx-local-review/SKILL.md && rm -f skills/lfx-local-review/SKILL.md.bak"

# --- CI paths completeness ------------------------------------------------
run_case "workflow drops its own paths: entry" bad \
  "does not trigger on .github/workflows/review-lifecycle-check.yml" \
  "sed -i.bak \"/- '.github\/workflows\/review-lifecycle-check.yml'/d\" .github/workflows/review-lifecycle-check.yml"

run_case "workflow drops the router path" bad "does not trigger on skills/lfx/SKILL.md" \
  "sed -i.bak \"/- 'skills\/lfx\/SKILL.md'/d\" .github/workflows/review-lifecycle-check.yml"

run_case "workflow keeps paths: but loses the run step" bad "has no run step invoking this checker" \
  "sed -i.bak '/run: .\/.github\/scripts\/check-review-lifecycle.sh/d' .github/workflows/review-lifecycle-check.yml"

run_case "workflow keeps paths: but loses the harness step" bad "has no run step invoking the checker's mutation tests" \
  "sed -i.bak '/run: .\/.github\/scripts\/test-check-review-lifecycle.sh/d' .github/workflows/review-lifecycle-check.yml"

# --- PR-iteration routing surfaces ----------------------------------------
run_case "pr-resolve loses its adoption gate" bad \
  "skills/lfx-pr-resolve/SKILL.md: missing" \
  "sed -i.bak 's/\*\*Before working any thread, check whether the PR.s repo owns its PR iteration/Before working any thread, check whether the repo owns its PR iteration/' skills/lfx-pr-resolve/SKILL.md"

run_case "router loses its two-routes rule" bad \
  "skills/lfx/SKILL.md: missing" \
  "sed -i.bak 's/\*\*PR review threads have two routes, decided by the repo, not by this table\.\*\*/PR review threads./' skills/lfx/SKILL.md"

# --- retired Pi harness must stay gone -------------------------------------
run_case "a retired launcher file reappears" bad "must be deleted" \
  "mkdir -p skills/lfx-local-review/scripts && : > skills/lfx-local-review/scripts/run-pi.sh"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
