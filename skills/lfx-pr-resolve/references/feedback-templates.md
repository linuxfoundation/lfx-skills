<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Feedback Plans, Responses, and Reports

Read the relevant section when presenting the Step 4 approval plan, drafting
Step 9 replies, posting the Step 11 summary, or reporting Step 13 results.

## Approval plan (Step 4)

List every eligible feedback item, not only review threads. Identify inline
feedback by file/line and thread or comment link; identify general review bodies
and PR conversation comments by source, author, and ID/link. Use plain bot names
and `@mention` only human reviewers. Count feedback items separately from threads.

```text
PR #[number] — REVIEW FEEDBACK TO ADDRESS

[N] eligible feedback items from [reviewers]:
[T] review threads, [G] general review bodies, [C] PR conversation comments

CODE CHANGES NEEDED
1. [reviewer] — [file:line and thread link], "[requested change]"
   Validated: [assessment and evidence]
2. [reviewer] — PR conversation comment [ID/link], "[requested change]"
   Validated: [assessment and evidence]

QUESTIONS TO ANSWER
3. [reviewer] — general review [ID/link], "[question]"
   Assessment: [evidence and proposed answer]

LIKELY FALSE POSITIVES
4. [reviewer] — [source and ID/link], "[suggestion]"
   Assessment: [repo-pattern evidence]
   Recommendation: [response explaining why no change is needed]

NEEDS YOUR INPUT
5. [reviewer] — [source and ID/link], "[discussion point]"
   What would you like me to do here?

Shall I proceed with items 1–3? Items 4–5 need your direction.
```

Omit empty categories and adjust numbering to the actual items. Wait for approval
before implementing or posting responses; monitoring consent is not that approval.

## Response bodies (Step 9)

Use the appropriate source-specific posting command from
[`graphql-queries.md`](graphql-queries.md). For a non-thread response, start with
its source and ID/link, credit the human reviewer or plain bot name, then answer
the specific feedback. Never invent a thread ID for a general review or PR comment.

### Code change

```text
Done, [specific change made].

See commit [short SHA]: [one-line summary of this feedback's fix].
```

### Question (no code change)

```text
[Specific answer, with code references where helpful].

No code change needed, [why the current approach is correct].
```

### Nitpick

```text
Fixed, [what changed]. Good catch! See commit [short SHA].
```

### Discussion with an approved decision

```text
[Decision and reasoning].

[What changed, with its commit SHA, or why no change was needed].
```

### Confirmed false positive

```text
Thanks for flagging this; I can see why it looks [wrong/inconsistent/off].

[Repo convention and evidence from specific files].

[If applicable: Happy to discuss further if we should reconsider.]
```

For response-only iterations, omit commit references: no new commit exists.

## Summary comment (Step 11)

Post one iteration summary with this command, replacing placeholders and omitting
empty categories. List every addressed item, including non-thread feedback by
source and ID/link; only review threads can be resolved. Credit human reviewers
with `@mentions`, but use plain bot names without `@`.

```bash
gh pr comment "$NUMBER" --repo "$OWNER/$REPO" --body "$SUMMARY_BODY"
```

Build `SUMMARY_BODY` using this template:

```text
## Review Feedback Addressed

[If files changed: Commit: full SHA]
[Otherwise: No code changes.]

### Changes Made
- **[file]**: [change] — [feedback source and ID/link] (per [reviewer])

### Questions Answered
- **[source and ID/link]**: [answer] (asked by [reviewer])

### No Change Needed
- **[source and ID/link]**: [evidence-based explanation] (flagged by [reviewer])

### Feedback Addressed
[N] of [M] eligible feedback items addressed, including [G] general review bodies
and [C] PR conversation comments; [R] unresolved review threads resolved.

### Still Open
- **[source and ID/link]**: [why deferred, undecided, or awaiting confirmation]
```

## User report (Step 13)

```text
PR #[number] — REVIEW FEEDBACK ADDRESSED

[If files changed:]
Commit: [SHA], [commit subject]
Pushed to: [branch]
[Otherwise: No code changes; no commit or push.]

Feedback addressed: [N] of [M] eligible items
  [T] review threads, [G] general review bodies, [C] PR conversation comments
  [N] changes made
  [N] questions answered
  [R] review threads resolved on GitHub
  [N] items left open (reason for each)

[If reviews were dismissed:]
Reviews refreshed:
  Dismissed "changes requested" from [reviewers]
  Re-requested review from [reviewers]

Summary comment posted: [comment URL]

What's next:
  [If re-requested: Reviewers will be notified.]
  Optionally monitor this PR in up to 3 follow-up rounds.
  [Any feedback still needing discussion.]
```

During monitoring, include the round number and return to the existing loop,
not a new opt-in prompt. Do not claim reviewers were re-requested when they were not.
