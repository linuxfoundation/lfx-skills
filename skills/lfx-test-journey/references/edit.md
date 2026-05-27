<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Edit

Add or remove branches from an existing journey.

## Step 1: Load Manifest

Read `~/.lfx-journeys/<journey-name>/manifest.yaml`.

If the journey doesn't exist, list available journeys and ask which one.

## Step 2: Show Current State

Present the current journey branches as a numbered list:

```
Journey "committee-onboarding" currently includes:

lfx-self-serve:
  1. feat/committee-list (merged)
  2. feat/committee-detail (merged)
  3. feat/committee-invite-drawer (skipped)

lfx-v2-committee-service:
  4. feat/invite-endpoint (merged)
  5. feat/role-permissions (merged)
```

## Step 3: Ask What to Change

```
AskUserQuestion: "What would you like to do?
  1. Add branches
  2. Remove branches (type numbers, e.g. '3, 5')
  3. Reorder merge sequence
  4. Add a new repo
  5. Done, refresh with changes"
```

**If add branches (1):**
- Run the branch discovery flow ([`create.md`](create.md) Steps 2-3) for the relevant repo(s)
- Let the user pick from discovered branches
- Add them to the manifest

**If remove branches (2):**
- Parse the numbers
- Remove those branches from the manifest

**If reorder (3):**
- Show the current merge order as a numbered list per repo
- Ask the user to type the new order (e.g., "3, 1, 2" to move branch 3 first)
- Update the branch order in the manifest

**If add new repo (4):**
- Run the full repo + branch discovery flow ([`create.md`](create.md) Steps 1-3)
- Add the new repo and its branches to the manifest

**If done (5):**
- Proceed to Step 4

Allow the user to make multiple changes (loop back to Step 3) until they choose "Done".

## Step 4: Refresh

After edits are complete, trigger an automatic refresh ([`refresh.md`](refresh.md)) to rebuild the worktrees with the updated branch set.
