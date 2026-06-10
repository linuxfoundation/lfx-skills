<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Conflict Resolution

When `git merge` exits with a non-zero code during create or refresh.

## Step 1: Report the Conflict

```bash
# Show which files have conflicts
git diff --name-only --diff-filter=U

# Show the conflict markers
git diff
```

Present to the user:

```
Merge conflict while merging <branch-name> into <repo-name>:

Conflicting files:
  1. src/app/modules/committees/committee-list.component.ts
  2. src/app/modules/committees/committee.service.ts

[Show the conflicting sections from git diff]
```

## Step 2: Ask the User What to Do

```
AskUserQuestion: "How would you like to handle this?
  1. I'll resolve it, show me the files (skill assists with resolution)
  2. Skip this branch, exclude it from the journey
  3. Abort, cancel the entire journey creation"
```

## Step 3: Handle the Response

**If "resolve" (1):**
- Use `Read` to show the conflicting files
- Let the user guide resolution (they may ask you to pick one side, or edit manually)
- After resolution, run:
  ```bash
  git add <resolved-files>
  git merge --continue
  ```
- Continue with the next branch

**If "skip" (2):**
- Abort the current merge:
  ```bash
  git merge --abort
  ```
- Record the branch as `status: skipped` in the manifest
- Continue with the next branch

**If "abort" (3):**
- Abort the merge:
  ```bash
  git merge --abort
  ```
- Clean up all worktrees created so far:
  ```bash
  cd <repo-path>
  git worktree remove ~/.lfx-journeys/<journey-name>/<repo-name> --force
  git branch -D journey/<journey-name>/<repo-name>
  ```
- Remove the journey directory:
  ```bash
  rm -rf ~/.lfx-journeys/<journey-name>
  ```
- Report: "Journey creation aborted. Everything cleaned up."
- **Stop here.**
