#!/usr/bin/env bash
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
#
# Checks the LFX license header on markdown files that carry YAML frontmatter.
#
# The shared lfx-public-workflows check greps the first four lines of a file.
# In a file with frontmatter, `---` has to be line 1 and the header sits below
# the closing `---`, so it lands outside that window no matter how short the
# frontmatter is. Those files are excluded from the shared job and checked
# here instead, against the convention that the header follows the closing
# `---`. Files without frontmatter belong to the shared job, not this one.

set -uo pipefail

COPYRIGHT="Copyright The Linux Foundation and each contributor to LFX."
SPDX="SPDX-License-Identifier: MIT"

status=0
checked=0

while IFS= read -r file; do
  [ "$(head -1 "$file")" = "---" ] || continue
  checked=$((checked + 1))

  close=$(awk 'NR>1 && /^---$/{print NR; exit}' "$file")
  if [ -z "$close" ]; then
    echo "$file has unterminated YAML frontmatter"
    status=1
    continue
  fi

  window=$(sed -n "$((close + 1)),$((close + 4))p" "$file")
  if ! grep -qF "$COPYRIGHT" <<<"$window"; then
    echo "$file is missing the license header below its frontmatter (expected within 4 lines of line $close)"
    status=1
  elif ! grep -qF "$SPDX" <<<"$window"; then
    echo "$file is missing '$SPDX' below its frontmatter"
    status=1
  fi
done < <(git ls-files '*.md')

echo "Checked $checked markdown files with frontmatter for the license header..."

if [ $status -eq 0 ]; then
  echo "License check passed."
else
  echo "One or more source files is missing the license header."
fi

exit $status
