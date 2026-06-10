<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Status

Show staleness information for all journeys (or a specific one if named).

## Step 1: Find Journeys

```bash
find ~/.lfx-journeys -maxdepth 2 -name manifest.yaml 2>/dev/null
```

If no journeys found: "No active journeys. Use `/lfx-skills:lfx-test-journey create` to start one."

If a specific journey was named, filter to just that one.

## Step 2: Fetch Latest Refs

For each repo referenced in the manifest(s):

```bash
cd <repo-path>
git fetch --all --prune
```

## Step 3: Compare SHAs

For each journey, read the manifest and compare:

**Branch staleness:**
```bash
cd <repo-path>
# Current SHA of the branch
CURRENT_SHA=$(git rev-parse origin/<branch-name> 2>/dev/null)
# Compare with stored SHA from manifest
```

- If branch no longer exists: report as "⚠ branch deleted upstream"
- If SHA matches: "✓ up to date"
- If SHA differs, count new commits:
  ```bash
  git rev-list <stored-sha>..<current-sha> --count
  ```
  Report as "⚠ N new commits"

**Base staleness:**
```bash
CURRENT_BASE=$(git rev-parse origin/main)
# Compare with stored base_sha
```

**Worktree health:**
```bash
# Check if worktree directory exists
ls -d <worktree-path> 2>/dev/null

# Check for uncommitted changes in worktree
cd <worktree-path>
git status --porcelain
```

## Step 4: Render Status

```
<journey-name> (created <relative-time>, refreshed <relative-time>)
  <repo-name>:
    <branch-1>        ✓ up to date
    <branch-2>        ⚠ 2 new commits
    <branch-3>        ✗ skipped
  <repo-name>:
    <branch-4>        ✓ up to date
  Base (main):        ⚠ 5 new commits
  Worktree:           ✓ exists [⚠ has uncommitted changes]

  → Refresh recommended
```

If everything is up to date: "→ All up to date, no refresh needed."
