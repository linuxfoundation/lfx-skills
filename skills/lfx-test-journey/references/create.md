<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Create Journey

## Contents

- Step 1: Discover Repos
- Step 2: Fetch Latest Refs
- Step 3: Discover Branches
- Step 4: Ask for Journey Name
- Step 5: Create Worktrees
- Step 6: Merge Branches
- Step 7: Write Manifest
- Step 8: Print Summary

Cross-link: merge conflicts during Step 6 go to [`conflict-resolution.md`](conflict-resolution.md).

## Step 1: Discover Repos

Scan `$LFX_DEV_ROOT/` for git repositories:

```bash
: "${LFX_DEV_ROOT:?set LFX_DEV_ROOT to your workspace root}"
for dir in "$LFX_DEV_ROOT"/*/; do
  if [ -d "$dir/.git" ]; then
    echo "$dir"
  fi
done
```

Present as a numbered list and **STOP, use `AskUserQuestion` and wait for the user to respond before continuing**:

```
Scanning $LFX_DEV_ROOT/ for git repos...

Which repos are part of this journey? (type numbers, e.g. "1, 3")
  1. $LFX_DEV_ROOT/lfx-self-serve
  2. $LFX_DEV_ROOT/lfx-v2-committee-service
  3. $LFX_DEV_ROOT/lfx-v2-meeting-service
```

**⛔ GATE: You MUST call `AskUserQuestion` here and wait for the user's response. Do NOT continue to Step 2 until the user has selected repos.** Parse their response (comma-separated numbers or repo names).

## Step 2: Fetch Latest Refs

For each selected repo, fetch to ensure refs are current:

```bash
cd <repo-path>
git fetch --all --prune
```

Report progress: "Fetching latest refs for <repo-name>..."

## Step 3: Discover Branches

For each selected repo, find the user's unmerged branches:

```bash
cd <repo-path>
# Get the git user name for filtering
GIT_USER=$(git config user.name)

# Use temp files to avoid clobbering across parallel runs
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Find branches with recent work by this user, not yet merged to main
git log --author="$GIT_USER" --all --since='30 days ago' --format='%D' \
  | tr ',' '\n' \
  | sed 's/^ *//' \
  | grep -E '^origin/' \
  | sed 's|^origin/||' \
  | grep -v '^main$' \
  | grep -v '^HEAD$' \
  | sort -u > "$TMPDIR/author_branches.txt"

# Cross-reference with unmerged branches
git branch -r --no-merged origin/main \
  | sed 's|^ *origin/||' \
  | sort -u > "$TMPDIR/unmerged_branches.txt"

# Intersection: branches by user AND not merged
comm -12 "$TMPDIR/author_branches.txt" "$TMPDIR/unmerged_branches.txt"
```

For each branch found, get the last commit date for sorting:

```bash
git log -1 --format='%ci' origin/<branch-name>
```

Present as a numbered list sorted by most recent first, and **STOP, use `AskUserQuestion` and wait for the user to pick branches**:

```
Your unmerged branches in lfx-self-serve (type numbers to include):
  1. feat/committee-invite-drawer (today)
  2. feat/committee-detail (1 day ago)
  3. feat/committee-list (3 days ago)
  4. feat/meeting-calendar (5 days ago)
```

**⛔ GATE: You MUST call `AskUserQuestion` for EACH repo separately and wait for the user's response. Do NOT continue to the next repo or to Step 4 until the user has selected branches for the current repo.** Parse comma-separated numbers.

**If no branches found for a repo:** Report it and skip: "No unmerged branches found for <repo>. Skipping."

## Step 4: Ask for Journey Name

**⛔ GATE: You MUST call `AskUserQuestion` here and wait for the user to name the journey. Do NOT auto-generate a name.**

```
AskUserQuestion: "Journey name?"
```

Validate: alphanumeric and hyphens only. **Reject** names containing `/`, `..`, spaces, or other special characters, the name is used in filesystem paths and git branch names. Suggest a name based on common branch prefixes if possible, but always wait for the user's response.

## Step 5: Create Worktrees

For each repo, create a worktree on a new branch:

```bash
cd <repo-path>

# Ensure journeys directory exists
mkdir -p ~/.lfx-journeys/<journey-name>

# Create worktree with a dedicated branch
# Use the full SHA of the base to avoid conflicts with checked-out branches
BASE_SHA=$(git rev-parse origin/main)
git worktree add ~/.lfx-journeys/<journey-name>/<repo-name> -b journey/<journey-name>/<repo-name> $BASE_SHA
```

**Important:** Use `$BASE_SHA` (not the branch name `main`) to avoid "already checked out" errors.

Record `BASE_SHA` for the manifest.

## Step 6: Merge Branches

In each worktree, merge the selected branches in order:

```bash
cd ~/.lfx-journeys/<journey-name>/<repo-name>

git merge origin/<branch-1> --no-edit
# Check exit code, if non-zero, go to Conflict Resolution
```

For each successful merge, record the branch SHA:

```bash
git rev-parse origin/<branch-name>
```

Report progress: "Merged <branch-name> into <repo-name> worktree."

**If a merge conflict occurs, see [`conflict-resolution.md`](conflict-resolution.md).**

## Step 7: Write Manifest

After all merges complete, write the manifest.

**IMPORTANT: The `Write` tool requires an absolute path, `~` will NOT work.** First resolve the home directory:

```bash
echo $HOME
```

Then use the `Write` tool with the **full absolute path**, e.g. `$HOME/.lfx-journeys/<journey-name>/manifest.yaml` (NOT `~/.lfx-journeys/...`).

All paths inside the manifest must also be absolute.

```yaml
name: <journey-name>
description: <journey-name> integration journey
created: <ISO 8601 timestamp>
last_refreshed: <ISO 8601 timestamp>

repos:
  - path: <absolute-repo-path>
    base: main
    base_sha: <sha>
    worktree: <absolute-worktree-path>
    branches:
      - name: <branch-name>
        sha: <sha>
        status: merged
      - name: <branch-name>
        sha: <sha>
        status: skipped
```

## Step 8: Print Summary

Print a clear, actionable summary. The most important thing is telling the user exactly what to do next, the `cd` command they need to run.

```
═══════════════════════════════════════════════════════
JOURNEY READY: <journey-name>
═══════════════════════════════════════════════════════

Branches merged: N/M (S skipped)

To start testing, run:

  cd ~/.lfx-journeys/<journey-name>/<repo-1>/
  <the normal dev server command for this repo, e.g. "yarn start" for Angular>

  cd ~/.lfx-journeys/<journey-name>/<repo-2>/
  <the normal dev server command for this repo>

─── What's next ──────────────────────────────────────

  /lfx-skills:lfx-test-journey status                     Check for upstream changes
  /lfx-skills:lfx-test-journey refresh <journey-name>     Re-merge with latest branch HEADs
  /lfx-skills:lfx-test-journey edit <journey-name>        Add/remove branches
  /lfx-skills:lfx-test-journey teardown <journey-name>    Clean up when done

═══════════════════════════════════════════════════════
```

**Important:** Include the full `cd` path for each worktree, do not make the user guess. If the repo is an Angular repo (has `angular.json`), suggest `yarn start`. If it's a Go repo (has `go.mod`), suggest `go run cmd/*/main.go` or the appropriate command.
