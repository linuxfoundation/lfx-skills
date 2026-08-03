#!/usr/bin/env bash
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
#
# Checks the LFX license header on every tracked markdown file.
#
# Markdown is handled here rather than by the shared lfx-public-workflows
# check for two reasons. That check greps the first four lines of a file, and
# in a file with YAML frontmatter `---` has to be line 1 and the header sits
# below the closing `---`, so it lands outside the window no matter how short
# the frontmatter is. It also only greps the copyright line, never the SPDX
# line, so it cannot enforce the full two-line header this repo uses.
#
# Both shapes are checked the same way: find where the header is supposed to
# start, then require both lines within four lines of it. The shared job keeps
# every non-markdown file.
#
# Run .github/scripts/test-check-markdown-headers.sh to exercise the branches.

set -euo pipefail

COPYRIGHT="Copyright The Linux Foundation and each contributor to LFX."
SPDX="SPDX-License-Identifier: MIT"

YAML_KEY='^[A-Za-z_][A-Za-z0-9_.-]*:'

# A leading `---` is ambiguous: YAML frontmatter opens that way, but so does a
# markdown horizontal rule. What separates them is the block itself — real
# frontmatter carries at least one key somewhere inside it, a rule is followed
# by prose. Looking at the whole block rather than just the line below the
# delimiter matters, because frontmatter may legitimately open with YAML
# comments; judging on that one line would read such a file as a rule and then
# accept a header sitting inside the frontmatter, which 3dc97ca moved out.
#
# Deciding on content rather than on a line budget matters too: the deepest
# closing `---` in the repo today is already at line 20, so any fixed window
# would sit right on top of files that exist.
# Prints "fm <close-line>", "plain", or "unterminated".
classify() {
  local file="$1" close
  [ "$(head -1 "$file")" = "---" ] || { echo plain; return; }

  close=$(awk 'NR>1 && /^---$/{print NR; exit}' "$file")
  if [ -n "$close" ]; then
    if sed -n "2,$((close - 1))p" "$file" | grep -qE "$YAML_KEY"; then
      echo "fm $close"
    else
      # A rule, and the `---` found above is a later rule.
      echo plain
    fi
  elif sed -n '2p' "$file" | grep -qE "$YAML_KEY"; then
    # Opens like frontmatter but never closes.
    echo unterminated
  else
    echo plain
  fi
}

status=0
checked=0

while IFS= read -r file; do
  checked=$((checked + 1))

  read -r kind close <<<"$(classify "$file")"
  if [ "$kind" = "unterminated" ]; then
    echo "$file has unterminated YAML frontmatter"
    status=1
    continue
  elif [ "$kind" = "fm" ]; then
    # The header belongs below the closing delimiter.
    start=$((close + 1))
  else
    # No frontmatter: the header belongs at the top of the file.
    start=1
  fi

  window=$(sed -n "${start},$((start + 3))p" "$file")
  if ! grep -qF "$COPYRIGHT" <<<"$window"; then
    echo "$file is missing the license header (expected within 4 lines of line $start)"
    status=1
  elif ! grep -qF "$SPDX" <<<"$window"; then
    echo "$file is missing '$SPDX' (expected within 4 lines of line $start)"
    status=1
  fi
done < <(git ls-files '*.md')

echo "Checked $checked markdown files for the license header..."

if [ $status -eq 0 ]; then
  echo "License check passed."
else
  echo "One or more source files is missing the license header."
fi

exit $status
