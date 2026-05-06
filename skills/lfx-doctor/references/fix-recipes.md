<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Fix Recipes

Per-issue narrative for `/lfx-doctor`. The CLI's `--fix` flag handles the mechanical cases; this file covers everything else, plus extra context the JSON output doesn't include.

Each entry follows the same shape:

- **What:** plain-language description of what's wrong
- **Why it matters:** consequence for the user
- **Fix this session:** quick one-shot
- **Fix permanently:** lasting change
- **Auto-fixable?** yes (CLI), yes (skill), or no

---

## issue-id: no-config

**What:** No `~/.lfx-skills/config.json`.
**Why it matters:** the CLI doesn't know what's installed where. Doctor can only check things relative to the manifest, so most other checks will be skipped.
**Fix:** run `lfx-skills install`. Or, inside the lfx-skills clone, run `/lfx-install` for a guided walkthrough.
**Auto-fixable?** no (requires user choices about scope / dev root).

---

## issue-id: no-symlinks

**What:** Manifest exists but is empty (no symlinks recorded).
**Why it matters:** no LFX skills are actually installed.
**Fix:** run `lfx-skills install` to add them.
**Auto-fixable?** no.

---

## issue-id: symlink-missing

**What:** A symlink the manifest expects is gone from disk.
**Why it matters:** the corresponding `/lfx-...` command won't be available in your AI tool.
**Fix this session:** `lfx-skills doctor --fix` (CLI recreates from the manifest).
**Auto-fixable?** yes (CLI).

---

## issue-id: symlink-broken

**What:** A symlink exists but points to a path that's no longer a directory.
**Why it matters:** same as above — the skill won't load.
**Common cause:** the lfx-skills clone moved or was deleted.
**Fix this session:** `lfx-skills doctor --fix`.
**Fix permanently:** if you moved the clone, run `lfx-skills install` again from the new location to re-record `canonical_clone`.
**Auto-fixable?** yes (CLI).

---

## issue-id: symlink-no-skillmd

**What:** A symlink target exists, but the directory has no `SKILL.md`.
**Why it matters:** the skill won't load (the loader requires `SKILL.md`). Usually means someone created an empty `lfx-foo/` directory by accident, or pulled an in-progress branch.
**Fix:** either delete the empty directory, or scaffold a real skill via `/lfx-new-skill`.
**Auto-fixable?** no by CLI; the `/lfx-doctor` skill can hand off to `/lfx-new-skill`.

---

## issue-id: clone-not-recorded / clone-mismatch

**What:** The CLI doesn't know which clone is canonical, or the recorded path doesn't match where the script ran from.
**Why it matters:** `lfx-skills update` and other commands rely on `canonical_clone`. Symlinks may also be pointing to a different clone than the one you think you're working in.
**Fix:** re-run `lfx-skills install` from the clone you want to be canonical.
**Auto-fixable?** no.

---

## issue-id: clone-dirty

**What:** Your `lfx-skills` clone has uncommitted changes.
**Why it matters:** purely informational. If you ran `lfx-skills update --pull`, that would fail with this state. Otherwise no impact.
**Fix:** commit, stash, or discard, depending on intent.
**Auto-fixable?** no.

---

## issue-id: dev-root-not-recorded

**What:** No `lfx_dev_root` in the manifest.
**Why it matters:** skills like `/lfx-test-journey` and `/lfx-coordinator` can't auto-discover your local LFX repos.
**Fix:** `lfx-skills config set lfx_dev_root=/path/to/your/lfx-clones`. Or re-run `lfx-skills install`.
**Auto-fixable?** no (requires user input).

---

## issue-id: dev-root-missing

**What:** The recorded `lfx_dev_root` path doesn't exist on disk.
**Common cause:** moved your clones to a new location.
**Fix:** `lfx-skills config set lfx_dev_root=/new/path`. The CLI will rewrite `~/.lfx-skills/dev-root` automatically.
**Auto-fixable?** no.

---

## issue-id: dev-root-empty

**What:** `LFX_DEV_ROOT` exists but contains no `lf*` git repos.
**Why it matters:** the skills will run, but they won't find any local repos to work on (they'll fall back to GitHub API calls when possible).
**Fix:** clone the LFX repos you work on into that directory. Examples:

```bash
cd "$LFX_DEV_ROOT"
git clone https://github.com/linuxfoundation/lfx-v2-ui.git
git clone https://github.com/linuxfoundation/lfx-v2-meeting-service.git
```

**Auto-fixable?** no.

---

## issue-id: dev-root-file-missing

**What:** `~/.lfx-skills/dev-root` is gone.
**Why it matters:** the 3 skills that need a local LFX path (`/lfx-coordinator`, `/lfx-research`, `/lfx-test-journey`) read this file via `cat` to resolve the dev root without depending on env vars. Without it, they fall back to `~/lf`, which may not match your setup.
**Fix:** `lfx-skills doctor --fix` regenerates it from the manifest. Or `lfx-skills config set lfx_dev_root=/your/path` if you also need to change the path.
**Auto-fixable?** yes (CLI).

---

## issue-id: dev-root-file-mismatch

**What:** The contents of `~/.lfx-skills/dev-root` differ from `lfx_dev_root` in `config.json`.
**Common cause:** the file was hand-edited, or an old `lfx-skills` version wrote one source but not the other.
**Fix:** `lfx-skills doctor --fix` rewrites the file from `config.json` (the source of truth).
**Auto-fixable?** yes (CLI).

---

## issue-id: frontmatter-missing

**What:** A `SKILL.md` doesn't start with `---` on line 1.
**Why it matters:** the skill loader will refuse to load it. The loader requires frontmatter as the very first thing in the file (no blank lines, no comments above).
**Fix:** insert a frontmatter block at the top with the skill `name`, `description`, and `allowed-tools`. Use `/lfx-new-skill` as a template, or copy the shape from a sibling skill.
**Auto-fixable?** no by CLI; the `/lfx-doctor` skill can guide the rewrite.

---

## issue-id: frontmatter-no-name

**What:** Frontmatter present but the `name:` field is missing or empty.
**Fix:** add `name: <skill-directory-basename>` to the frontmatter. Loader will fail without it.
**Auto-fixable?** no by CLI; the `/lfx-doctor` skill can patch it via Edit.

---

## issue-id: frontmatter-name-mismatch

**What:** `name:` in the SKILL.md doesn't match the directory basename.
**Why it matters:** loaders use the directory name to register the slash command, but read the frontmatter for description and tools. A mismatch is confusing and may cause routing issues.
**Fix:** make `name:` equal `basename "$skill_dir"`.
**Auto-fixable?** no by CLI; the `/lfx-doctor` skill can patch via Edit.

---

## issue-id: frontmatter-no-description

**What:** No `description:` field, or it's empty.
**Why it matters:** the loader uses `description` to decide when to surface the skill. Missing description means the model has no context for *when* to invoke it.
**Fix:** write a one-paragraph description that includes 3–5 trigger phrases users might say.
**Auto-fixable?** no by CLI; the `/lfx-doctor` skill can draft one from the SKILL.md body.

---

## issue-id: license-missing

**What:** A `SKILL.md` doesn't have the LFX copyright header in its first 4 lines.
**Why it matters:** CI's `license-header-check` job will fail.
**Fix:** add these lines as lines 2–3, immediately after the opening `---`:

```yaml
---
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
name: ...
```

(The `#` comments are valid YAML comments. They satisfy the license check without breaking frontmatter parsing.)
**Auto-fixable?** no by CLI; the `/lfx-doctor` skill can patch via Edit.

---

## issue-id: routing-dangling

**What:** `lfx/SKILL.md` mentions `/lfx-foo` but no `lfx-foo/` directory exists.
**Why it matters:** the user asks `/lfx` to route to `/lfx-foo` and gets a confused error.
**Fix:** either remove the dangling reference from `lfx/SKILL.md`, or create the missing skill via `/lfx-new-skill`.
**Auto-fixable?** no — needs your call on which.

---

## issue-id: routing-uncovered

**What:** A skill exists in the clone but `lfx/SKILL.md` doesn't route to it.
**Why it matters:** users typing `/lfx` won't find the skill via the plain-language router. They can still invoke it directly with `/lfx-foo`.
**Fix:** add an entry to `lfx/SKILL.md`'s routing table for the skill, including 1–2 example trigger phrases.
**Caveat:** internal-only skills (like `lfx-backend-builder` and `lfx-ui-builder`, which are only invoked by `/lfx-coordinator`) can legitimately stay out of the routing table. Use judgment.
**Auto-fixable?** no by CLI; the `/lfx-doctor` skill can patch via Edit.
