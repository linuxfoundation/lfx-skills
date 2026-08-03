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

set -uo pipefail

COPYRIGHT="Copyright The Linux Foundation and each contributor to LFX."
SPDX="SPDX-License-Identifier: MIT"

status=0
checked=0

while IFS= read -r file; do
  checked=$((checked + 1))

  if [ "$(head -1 "$file")" = "---" ]; then
    # Frontmatter: the header belongs below the closing delimiter.
    close=$(awk 'NR>1 && /^---$/{print NR; exit}' "$file")
    if [ -z "$close" ]; then
      echo "$file has unterminated YAML frontmatter"
      status=1
      continue
    fi
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
