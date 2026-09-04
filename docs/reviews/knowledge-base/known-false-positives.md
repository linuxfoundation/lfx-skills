<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Known false positives — applied LAST in every learnings pass

Findings that match any pattern below MUST be dropped. This list is the floor.
Even a quotable KB pattern does not survive if it matches a known false
positive.

**Who applies this file:** the repo-owned `local-learnings-review` brain, as
its Step 4 floor, and nothing else. The `local-code-review` brain does not
load it.

---

## Already covered by tooling

### License-header complaints on a file that already has one, or that CI will catch

**Pattern matched:** finding states a Markdown, skill, or agent file is missing
the two-line MIT license header.

**Why false:** `.github/workflows/license-header-check.yml` and
`.github/scripts/check-markdown-headers.sh` gate every PR. `CLAUDE.md` lists
the same check under Before you push. Surfacing it in a learnings review is
duplicate signal.

**Source:** `CLAUDE.md` (Before you push); `.github/workflows/license-header-check.yml`.

### markdownlint / heading-style / line-length nits

**Pattern matched:** formatting, heading style, emphasis style, indentation,
or line-length findings on `.md` files.

**Why false:** `.markdownlint.json` owns those, and `CLAUDE.md` tells authors
to run `npx markdownlint-cli2` before push. Copilot's own reviewer skill
says leave style to the linter.

**Source:** `.github/skills/copilot-code-reviewer/SKILL.md` — "Leave style to
the linter."

---

## Deliberate repo policy

### Plugin missing-`version` warning

**Pattern matched:** finding that `.claude-plugin/plugin.json` should declare
a `version` field, or that `claude plugin validate` failed on a missing
version.

**Why false:** the plugin deliberately omits `version` so installs resolve by
commit SHA. `CLAUDE.md` and the README *Plugin versioning* section both say
not to add it.

**Source:** `README.md` (Plugin versioning); `CLAUDE.md` (Before you push).

### Reviewer agents omitted from `.claude-plugin/plugin.json`

**Pattern matched:** finding that a new file under `agents/` must be listed in
the plugin manifest's `agents` key.

**Why false:** Claude Code auto-discovers agents from the default top-level
`agents/` directory. The manifest only needs an explicit path when overriding
that location. Maintainer declined this on PR #59.

**Source:** PR #59 `.claude-plugin/plugin.json` — josep-reyero — "Claude Code
plugins auto-discover agents from the default top-level `agents/` directory;
the manifest only needs an explicit path key when overriding a non-default
location."

---

## How to add a new entry

When you find a bot or KB finding the team has explicitly decided is not
relevant for this repo:

1. Add an entry here with **Pattern matched**, **Why false**, and **Source**.
2. If the pattern was previously in a category file, remove it there.
3. Keep this list small. If it grows past ~25 entries, re-audit.
