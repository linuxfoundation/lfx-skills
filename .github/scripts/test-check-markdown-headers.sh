#!/usr/bin/env bash
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
#
# Fixture tests for check-markdown-headers.sh.
#
# The checker reads `git ls-files`, so each case is a throwaway git repo
# holding a single markdown file. That keeps the cases independent and lets
# them assert on the message, not just the exit code — a check that fails for
# the wrong reason is its own bug.

# The checker is expected to exit non-zero for most cases here, so its exit
# status is captured through `if` rather than `$?` — a bare `out=$(...)` would
# abort the run under -e on the first case that is supposed to fail.
set -euo pipefail

CHECKER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-markdown-headers.sh"
HEADER='<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->'

pass=0
fail=0

# run_case <name> <expected: ok|bad> <expected message substring> <file content>
run_case() {
  local name="$1" expect="$2" want="$3" content="$4"
  local dir out rc

  dir=$(mktemp -d)
  (
    cd "$dir"
    git init -q .
    printf '%s\n' "$content" > case.md
    git add case.md
  ) >/dev/null 2>&1

  if out=$(cd "$dir" && "$CHECKER" 2>&1); then rc=0; else rc=$?; fi
  rm -rf "$dir"

  local got="ok"
  [ "$rc" -ne 0 ] && got="bad"

  if [ "$got" != "$expect" ]; then
    echo "FAIL  $name — expected $expect, got $got"
    echo "$out" | sed 's/^/        /'
    fail=$((fail + 1))
    return
  fi

  if [ -n "$want" ] && ! grep -qF "$want" <<<"$out"; then
    echo "FAIL  $name — expected message containing: $want"
    echo "$out" | sed 's/^/        /'
    fail=$((fail + 1))
    return
  fi

  echo "ok    $name"
  pass=$((pass + 1))
}

# --- no frontmatter -------------------------------------------------------
run_case "plain file, header on top" ok "" \
"$HEADER

# Title"

run_case "plain file, no header" bad "within 4 lines of line 1" \
"# Title

Body."

run_case "plain file, copyright but no SPDX" bad "missing '<!-- SPDX-License-Identifier: MIT -->'" \
"<!-- Copyright The Linux Foundation and each contributor to LFX. -->

# Title"

# --- frontmatter ----------------------------------------------------------
run_case "frontmatter, header below close" ok "" \
"---
name: thing
description: a thing
---
$HEADER

# Title"

run_case "frontmatter, no header" bad "within 4 lines of line 5" \
"---
name: thing
description: a thing
---

# Title"

# Frontmatter opening with YAML comments still counts as frontmatter, so a
# header sitting inside it is rejected rather than accepted at the top.
run_case "frontmatter, header inside frontmatter is not accepted" bad "within 4 lines of line 6" \
"---
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
name: thing
---

# Title"

run_case "frontmatter, header pushed past the window" bad "within 4 lines of line 4" \
"---
name: thing
---

# Title

More body.

$HEADER"

run_case "unterminated frontmatter" bad "unterminated YAML frontmatter" \
"---
name: thing
description: never closed

# Title"

# The key sits below a YAML comment, so the classification cannot be decided
# on the line under the delimiter alone — otherwise this reads as a rule and
# the header inside the broken frontmatter satisfies the check.
run_case "unterminated frontmatter opening with YAML comments" bad "unterminated YAML frontmatter" \
"---
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
name: thing
description: never closed

# Title"

# --- the header has to be a comment, not prose ----------------------------
run_case "bare prose copyright is not a header" bad "within 4 lines of line 1" \
"Copyright The Linux Foundation and each contributor to LFX.
SPDX-License-Identifier: MIT

# Title"

# --- horizontal rule on line 1, not frontmatter ---------------------------
run_case "leading horizontal rule, header below it" ok "" \
"---
$HEADER

# Title"

run_case "leading horizontal rule with a later rule, header below it" ok "" \
"---
$HEADER

# Title

---

More body."

run_case "leading horizontal rule, no header" bad "within 4 lines of line 1" \
"---

# Title

---

Body."

# Colon-led prose below the first blank line is not a YAML key: without the
# blank-line bound this file read as unterminated frontmatter despite its
# valid header, because the 'Note:' line matched the key pattern.
run_case "leading rule, header, colon-led prose, no later rule" ok "" \
"---
$HEADER

# Heading

Note: this repo uses X."

# Same shape with a later rule: without the bound the block between the two
# rules read as frontmatter, moving the expected header position below the
# later rule and failing the correctly placed header.
run_case "leading rule, header, colon-led prose, later rule" ok "" \
"---
$HEADER

Handoff: the owning repo takes over here.

---

Body."

# --- report ---------------------------------------------------------------
echo
echo "$pass passed, $fail failed"
[ $fail -eq 0 ] || exit 1
