<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Refresh

Re-merge all branches with their current HEADs.

## Contents

- Step 1: Load Manifest
- Step 2: Check for Uncommitted Changes
- Step 3: Fetch Latest Refs
- Step 4: Reset and Re-Merge
- Step 5: Update Manifest
- Step 6: Report

Cross-link: merge conflicts during Step 4 go to [`conflict-resolution.md`](conflict-resolution.md).

## Step 1: Load Manifest

Read `~/.lfx-journeys/<journey-name>/manifest.yaml`.

If the journey doesn't exist, list available journeys and ask which one.

## Step 2: Check for Uncommitted Changes

For each repo worktree:

```bash
cd <worktree-path>
git status --porcelain
```

If any worktree has uncommitted changes:

```
AskUserQuestion: "Worktree for <repo-name> has uncommitted changes that will be lost on refresh:
  M src/app/modules/committees/list.component.ts
  M src/app/modules/committees/list.component.html

What would you like to do?
  1. Continue, discard changes and refresh
  2. Stash, save changes before refreshing (git stash)
  3. Abort, cancel refresh"
```

**If stash:** `git stash push -m "lfx-journey pre-refresh stash"`
**If abort:** Stop here.

## Step 3: Fetch Latest Refs

For each repo:

```bash
cd <repo-path>
git fetch --all --prune
```

## Step 4: Reset and Re-Merge

For each repo worktree, first check if the worktree directory exists:

```bash
ls -d <worktree-path> 2>/dev/null
```

**If the worktree is missing** (manually deleted), recreate it:

```bash
cd <repo-path>
BASE_SHA=$(git rev-parse origin/main)
git worktree add <worktree-path> -b journey/<journey-name>/<repo-name> $BASE_SHA
```

If the branch already exists (from a previous creation), force-reset it:

```bash
cd <repo-path>
git worktree remove <worktree-path> --force 2>/dev/null || true
git branch -D journey/<journey-name>/<repo-name> 2>/dev/null || true
BASE_SHA=$(git rev-parse origin/main)
git worktree add <worktree-path> -b journey/<journey-name>/<repo-name> $BASE_SHA
```

**If the worktree exists**, reset it:

```bash
cd <worktree-path>

# Reset to current base
git reset --hard origin/main
```

Then merge all branches (except `skipped`) in order, same as Create → Step 6 (see [`create.md`](create.md)).

**Handle conflicts the same way as [`conflict-resolution.md`](conflict-resolution.md).**

## Step 5: Update Manifest

Update the manifest with new SHAs and `last_refreshed` timestamp.

```bash
# Get new base SHA
cd <repo-path>
git rev-parse origin/main
```

Update each branch SHA and the base_sha in the manifest. Write using the `Write` tool with the **full absolute path** (not `~`).

## Step 6: Report

```
Journey "<journey-name>" refreshed!

<repo-1>: N branches merged
<repo-2>: N branches merged (S skipped)

Last refreshed: just now
```
