<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Dismiss Stale Reviews and Re-request

After pushing changes and posting the summary, dismiss any "changes requested" reviews from reviewers whose feedback was addressed, then re-request their review so they're prompted to look at the updated code.

**Only do this if changes were pushed.** If no code changes were made (e.g., only questions were answered), skip the entire flow.

## Identify reviews to dismiss

Fetch every REST review page and ignore pending drafts. Select each reviewer's
latest submitted review across all states, then identify candidates where:

- The latest review's `state` is `CHANGES_REQUESTED`
- The reviewer had actionable thread comments, general review-body feedback, or PR
  conversation comments addressed in this iteration, with any fixing commit
  confirmed published
- All of that reviewer's feedback is addressed; an unanswered or deferred general
  review-body finding or actionable PR conversation comment blocks eligibility
  just as an open thread does

```bash
# Fetch every page, select each reviewer's latest submitted state, then filter
gh api "repos/$OWNER/$REPO/pulls/$NUMBER/reviews" --paginate --slurp |
  jq '[add | map(select(.state != "PENDING")) | group_by(.user.login)[]
    | max_by([.submitted_at, .id]) | select(.state == "CHANGES_REQUESTED")
    | {id: .id, user: .user.login}]'
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
- **Multiple reviews from the same reviewer**: Use the latest submitted review
  across all pages and states, ignoring pending drafts. Dismiss only if that latest
  review is `CHANGES_REQUESTED`; a newer review in another state blocks dismissal.
- **Mixed reviewers**: Some reviewers may have had all their thread comments,
  general review-body feedback, and actionable PR conversation comments addressed
  while others still have open findings. Only dismiss and re-request for reviewers
  whose feedback was fully addressed.
- **No latest `CHANGES_REQUESTED` reviews**: Skip this step; no reviewer is eligible.
