<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Dismiss Stale Reviews and Re-request

After pushing changes and posting the summary, dismiss any "changes requested" reviews from reviewers whose feedback was addressed, then re-request their review so they're prompted to look at the updated code.

**Only do this if changes were pushed.** If no code changes were made (e.g., only questions were answered), skip the entire flow.

## Identify reviews to dismiss

Use the REST API to list pull request reviews and identify those where:
- `state` is `CHANGES_REQUESTED`
- The reviewer had unresolved threads that were addressed in this iteration

```bash
# Get the most recent CHANGES_REQUESTED review per reviewer
gh api repos/$OWNER/$REPO/pulls/$NUMBER/reviews --jq '[ map(select(.state == "CHANGES_REQUESTED")) | group_by(.user.login)[] | max_by(.submitted_at) | {id: .id, user: .user.login}]'
```

## Dismiss each stale review

For each reviewer whose "changes requested" review was addressed:

```bash
gh api repos/$OWNER/$REPO/pulls/$NUMBER/reviews/$REVIEW_ID/dismissals \
  -X PUT \
  -f message="Review feedback has been addressed in commit [short SHA]. Re-requesting your review."
```

## Re-request review

After dismissing, re-request a review from those same reviewers so they receive a notification:

```bash
gh pr edit $NUMBER --repo $OWNER/$REPO --add-reviewer "$REVIEWER_LOGIN"
```

If multiple reviewers had changes requested, add all of them:

```bash
# All reviewers whose changes_requested was dismissed (comma-separated)
gh pr edit $NUMBER --repo $OWNER/$REPO --add-reviewer "reviewer1,reviewer2"
```

## Edge cases

- **Reviewer is not a collaborator**: `--add-reviewer` may fail for external contributors. If it fails, note it in the report but don't block.
- **Multiple reviews from the same reviewer**: A reviewer may have submitted multiple reviews. Only dismiss the most recent `CHANGES_REQUESTED` review, GitHub uses the latest review state per reviewer.
- **Mixed reviewers**: Some reviewers may have had all their threads addressed while others still have open threads. Only dismiss and re-request for reviewers whose feedback was fully addressed.
- **No `CHANGES_REQUESTED` reviews**: Skip this step entirely, nothing to dismiss.
