<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Bounded PR Feedback Monitoring

Read and follow this procedure only after the user explicitly chooses monitoring
in Step 14. The initial resolution pass does **not** count toward the limit.
Monitoring consent does not approve changes, responses, or false-positive dismissals.

## Session-local records

Maintain one counter for this PR, initially `0`, and a handling record of feedback
already assessed or answered: source, comment/review ID, author, body, available update
timestamp, and disposition (answered, rejected with approval, deferred, or awaiting
input). Separately retain the last fetched versions and authors for every thread
comment, general review body, and PR conversation comment, including initially
resolved threads. Use the complete Step 2 fetch as the first baseline.

A fetched baseline is not a handling record: unresolved or non-thread feedback
that has not been assessed remains eligible even when its version is unchanged.
The exception is old comments in initially resolved threads: baseline them without
re-addressing them; later new or edited reviewer comments become eligible.
Record the IDs of replies and summaries this workflow posts so they never become
new work. Preserve both records and the counter across pushes within this session.

These records do not survive a fresh skill invocation. Do not infer a prior
deferred or awaiting-input disposition when there is no visible conversation
evidence; a fresh invocation follows the main skill's initial-pass rules.

## At most three follow-up rounds

1. **Wait and count.** Wait 60 seconds (`sleep 60`), then increment the counter
   before fetching. Every check consumes a round, even if no new or valid
   feedback appears. Honor a user's request to stop immediately.
2. **Re-fetch the same PR.** Check its state using
   [`graphql-queries.md`](graphql-queries.md), "Fetch general PR feedback"; stop
   if it is merged or closed. Repeat Step 2, draining all pages of review threads,
   every thread's full conversation, REST reviews, and PR conversation comments.
   Do not reuse a stale snapshot. If any fetch fails, report the failure and stop
   rather than claiming the PR has no feedback.
3. **Identify eligible feedback across all sources.** Compare each source's
   records with the previous fetched snapshot and the handling record:

   | Source | Identity/version | Eligible feedback |
   | --- | --- | --- |
   | Review threads | Thread ID and each comment's ID, body, `updatedAt` | Remaining unassessed unresolved threads; new or edited reviewer comments even in resolved threads |
   | General review bodies (REST) | Review ID and body; update timestamp when available | New non-empty reviewer bodies, edited bodies, and unchanged bodies not yet assessed |
   | PR conversation comments (REST) | Comment ID, body, `updated_at` | New or edited reviewer comments and unchanged comments not yet assessed |

   Apply Step 2's substantive-feedback filter: skip acknowledgments, status
   messages, and this workflow's own replies/summaries. Assess general review
   bodies only from authoritative REST records, not the GraphQL review summary.
   Read complete conversations for context; overviews repeating inline findings need no duplicate
   response beyond the iteration summary covering those findings. Include outdated
   eligible threads and validate against current code.
   Attribute each eligible item to its own comment or review author, including
   new or edited replies by someone other than a thread's original commenter.
   Carry that attribution into the plan, response, summary, bot-mention rules,
   and reviewer-refresh eligibility; do not inherit it from the thread opener.

   New IDs, changed bodies, or changed available update timestamps reopen
   assessment regardless of resolution or prior disposition. Skip unchanged
   feedback already answered, rejected with user approval, deferred, or awaiting
   input. An unchanged open thread alone does not justify another reply or the
   same approval question. Update the fetched snapshot after identifying changes
   without marking unassessed feedback handled.
4. **Validate and resolve.** For every eligible feedback item, follow Steps 3–13:
   validate against current code and repo patterns, include all sources in the
   categorized plan, obtain Step 4 approval, and make only approved fixes. Use
   Step 9's thread or PR-level response route according to the source. Preserve
   the same resolution, summary, and re-request rules; non-thread feedback has
   no resolution mutation. Record each item's approved disposition afterward.
   Use Step 5's response-only path when no files change: skip Steps 6–8 and 12,
   and omit commit/push fields. Do not post replies or summaries when no action
   is taken.
5. **Report the round.** Show `Monitoring round [N]/3`, feedback assessed,
   actions taken, and anything still unresolved. If there is no eligible
   feedback, say so and continue to the next check within the limit.

When Step 13 completes inside this loop, return to the next numbered round,
**not** a fresh Step 14 prompt. Never recursively invoke the skill, reset the
counter after a push, or automatically extend/restart monitoring. After round 3,
stop and report any remaining unresolved feedback and that the limit was reached;
do not claim future comments are covered.
