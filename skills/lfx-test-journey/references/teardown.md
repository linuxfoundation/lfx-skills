<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Teardown

Remove a journey's worktrees and manifest.

## Step 1: Identify Journey

If the user provided a journey name, use it. Otherwise, run [`list.md`](list.md) and ask which one.

## Step 2: Confirm

```
AskUserQuestion: "This will remove the journey 'committee-onboarding' and all its worktrees:
  ~/.lfx-journeys/committee-onboarding/lfx-self-serve/
  ~/.lfx-journeys/committee-onboarding/lfx-v2-committee-service/

Proceed? (yes/no)"
```

## Step 3: Remove Worktrees

For each repo in the manifest:

```bash
cd <repo-path>

# Remove the worktree
git worktree remove <worktree-path> --force

# Delete the journey branch
git branch -D journey/<journey-name>/<repo-name>
```

If a worktree doesn't exist (already manually deleted), skip it without error:

```bash
git worktree remove <worktree-path> --force 2>/dev/null || true
git branch -D journey/<journey-name>/<repo-name> 2>/dev/null || true
```

## Step 4: Clean Up Files

```bash
rm -rf ~/.lfx-journeys/<journey-name>
```

## Step 5: Confirm

```
Journey "committee-onboarding" cleaned up.
  - 2 worktrees removed
  - 2 journey branches deleted
  - Manifest deleted
```
