<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Dismiss Stale Reviews and Re-request

After pushing changes and posting the summary, dismiss stale request-changes
reviews only when the reviewer still needs a fresh look at newly published
code.

**Only do this if changes were pushed.** If the round was response-only (for
example, questions answered without code changes), skip this entire flow.

## Identify eligible reviewers

> Determine each reviewer's effective submitted decision before considering dismissal.

Fetch every review page and collapse each reviewer to their latest
decision-bearing review (`APPROVED`, `CHANGES_REQUESTED`, or `DISMISSED`).
Ignore `PENDING` drafts and `COMMENTED` reviews: a comment-only review does not
supersede an earlier approval or change request. Only reviewers whose effective
decision is `CHANGES_REQUESTED` are candidates for dismissal and re-request.

A candidate reviewer is eligible only when all of that reviewer's actionable
feedback addressed in this iteration is fully handled, including inline thread
feedback, general review-body findings, and actionable PR conversation
comments. Unanswered, deferred, or still-open feedback blocks eligibility, even
if some threads were resolved.

```bash
# Fetch every page, ignore drafts and comment-only reviews, determine each
# reviewer's latest decision, then keep only effective CHANGES_REQUESTED reviews.
gh api "repos/$OWNER/$REPO/pulls/$NUMBER/reviews" --paginate --slurp |
  jq '[add | map(select(.state == "APPROVED" or .state == "CHANGES_REQUESTED"
      or .state == "DISMISSED")) | group_by(.user.login)[]
    | max_by([.submitted_at, .id]) | select(.state == "CHANGES_REQUESTED")
    | {id: .id, user: .user.login}]'
```

## Dismiss each stale review

> Dismiss only when the effective decision is still `CHANGES_REQUESTED` and
this iteration published the fixes being claimed.

For each eligible reviewer, dismiss that effective `CHANGES_REQUESTED` review:

```bash
gh api repos/$OWNER/$REPO/pulls/$NUMBER/reviews/$REVIEW_ID/dismissals \
  -X PUT \
  -f message="Review feedback has been addressed in commit [short SHA]. Re-requesting your review."
```

## Re-request review

> Re-request review only from the reviewers whose current stale
request-changes reviews you just dismissed.

After dismissing, re-request review from those same reviewers so they receive a
notification:

```bash
gh pr edit $NUMBER --repo $OWNER/$REPO --add-reviewer "$REVIEWER_LOGIN"
```

If several reviewers are eligible, add them together.

```bash
# All reviewers whose current CHANGES_REQUESTED review was dismissed
gh pr edit $NUMBER --repo $OWNER/$REPO --add-reviewer "reviewer1,reviewer2"
```

## Edge cases

> Later approvals or dismissals supersede older change requests; comment-only reviews do not.

- **Reviewer is not a collaborator**: `--add-reviewer` may fail for external
  contributors. Note it in the report, but do not block the rest of the flow.
- **Multiple reviews from the same reviewer**: Use the latest decision-bearing
  review across all pages, ignoring `PENDING` and `COMMENTED`. A later approval
  or dismissal excludes the reviewer; a later comment alone does not.
- **Mixed feedback status**: Some reviewers may have all actionable feedback
  handled while others still have open findings. Only dismiss and re-request for
  reviewers whose feedback is fully handled in this iteration.
- **No current `CHANGES_REQUESTED` reviews**: Skip this step; no reviewer is
  eligible.
