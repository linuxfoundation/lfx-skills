---
name: lfx-pr-resolve
description: >
  Address PR review comments, fetches unresolved threads, general review bodies,
  and PR conversation comments, makes code changes,
  commits with a summary, responds to each comment, resolves threads, posts
  a follow-up summary, dismisses stale "changes requested" reviews, and
  re-requests review, and offers up to three opt-in monitoring rounds. Use
  whenever someone wants to address PR feedback, fix review comments, resolve
  PR threads, iterate on a pull request after review, or "monitor this PR for
  new comments." Works on one PR; monitoring follows its feedback-resolution
  pass. Do not use for a read-only dashboard across all open PRs; use
  lfx-pr-catchup instead. Route to the repo-owned lifecycle instead when
  the PR's repo carries a `## Review lifecycle configuration` section
  in its root CLAUDE.md, in which case `/lfx-skills:lfx-local-review` owns its
  PR iteration (and validates that section) instead, or a `PR driver:` value in
  its `## Pre-PR review` section, in which case that repo skill owns it; both
  headings together is a broken migration — stop.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion, Skill
---

<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->
<!-- Tool names in this file use Claude Code vocabulary. See docs/tool-mapping.md for other platforms. -->

# PR Review Comment Resolver

**Before working any thread, check whether the PR's repo owns its PR iteration
elsewhere.** Run this check **after Step 1 has identified the PR's repository**
— the PR may live in a different repo from the current checkout — and read only
that repository's root `CLAUDE.md`. If it carries **both** a
`## Review lifecycle configuration` section and a `## Pre-PR review` section,
two lifecycles are declared: say so and stop — a broken migration, routed to
neither owner. If it carries exactly one
`## Review lifecycle configuration` section and no `## Pre-PR review`
section, the repo has adopted
`/lfx-skills:lfx-local-review` as the sole owner of its review lifecycle: hand
the work to that skill and stop; that skill validates the declaration and fails
closed itself. It also verifies the checkout it runs in against its `origin`,
so if the current checkout is not that repository, do not hand off from here —
tell the user to open a checkout of the PR's repository and run it there. If
there is no such section, the repo is not an adopter and this skill is the
right one — unless its `## Pre-PR review` section carries a `PR driver:`
value: that repo skill owns its PR iteration, so hand the work to it and stop.
The driver is a repo-local skill, so the same checkout rule applies as above:
if the current checkout is not that repository, do not hand off from here —
tell the user to open a checkout of the PR's repository and run it there.
If there is more than one such section, say so and stop
— that is a broken adoption, not an absent one, and running this skill instead
would answer a configuration error with a different workflow.

You address PR review feedback end-to-end: read the comments, make the code changes, commit, respond to each reviewer, resolve the threads, and post a summary. The goal is to close the feedback loop completely, reviewers should see exactly what was done and why.

## Step 1: Identify the PR

Determine which PR to work on. The user may provide:

- A PR number (e.g., `#142`)
- A PR URL (e.g., `https://github.com/org/repo/pull/142`)
- Nothing, auto-detect from the current branch

### Verify GitHub CLI Authentication

Before making any `gh` calls, verify authentication:

```bash
gh auth status 2>&1
```

If auth fails, stop and tell the user to run `gh auth login`.

### Apply the adoption check to the identified repository

Once the PR's `org/repo` and base branch are known, run the adoption check
from the top of this skill against **that** repository's root `CLAUDE.md`. If
it is not the current checkout, read the file from the identified repository
at the PR's base branch, as raw text rather than the JSON envelope:

```bash
gh api "repos/<org>/<repo>/contents/CLAUDE.md?ref=<base-branch>" \
  -H "Accept: application/vnd.github.raw"
```

Do not read `CLAUDE.md` from wherever this session happens to be running.
### Auto-detection

```bash
# Get current branch
BRANCH=$(git branch --show-current)

# Find PR for this branch
gh pr list --head "$BRANCH" --state open --json number,url,title --jq '.[0]'
```

If no PR is found for the current branch, ask:

> "I don't see an open PR for this branch. Which PR would you like to address? (Give me a number or URL)"

## Step 2: Fetch PR Details and Review Threads

### Derive Repository Variables

Extract the owner, repo, and PR number from the identified PR. If the user provided a URL, parse it. If auto-detected, derive from the current repo:

```bash
# From the current repo's remote
OWNER=$(gh repo view --json owner -q '.owner.login')
REPO=$(gh repo view --json name -q '.name')
# NUMBER comes from Step 1 (user input or auto-detection)
```

### Fetch Review Threads

Fetch the PR metadata, all review-thread pages, and each thread's full conversation
using [`references/graphql-queries.md`](references/graphql-queries.md), "Fetch PR
review threads". Bind `$OWNER`, `$REPO`, and `$NUMBER`; follow its separate thread
and per-thread comment continuation queries until every `hasNextPage` is false.

Also fetch general review bodies and PR conversation comments using
[`references/graphql-queries.md`](references/graphql-queries.md), "Fetch general
PR feedback". Read these alongside unresolved threads; actionable feedback is
not limited to inline comments.

### Identify AI Bot Reviewers

Before processing threads, identify which reviewers are AI bots. Common bot indicators:

- Username ends with `[bot]` (e.g., `copilot[bot]`, `coderabbitai[bot]`, `github-actions[bot]`)
- Username matches known AI review bots: `copilot`, `coderabbitai`, `codeclimate`, `sonarcloud`, `deepsource`, `sourcery-ai`, `ellipsis-dev`, `korbit-ai`, `bito-ai`, `pr-agent`
- User type from the API is `Bot` rather than `User`

Maintain a list of bot reviewer logins for this PR. These reviewers must **never be `@mentioned`** in any content posted to GitHub (comments, commit messages, summary). Tagging bots causes them to re-trigger and attempt to act on already-resolved feedback.

**Bot comments are still actionable**, address their feedback like any other reviewer. The restriction is only on `@mentioning` them in GitHub-posted content.

### Filter to Actionable Threads

From the response, collect only **unresolved** threads (`isResolved == false`). Skip threads that are already resolved, someone else handled them or they were resolved in a previous iteration.

For each unresolved thread, extract:

| Field | Source |
|-------|--------|
| Thread ID | `id` (needed for resolving later) |
| File path | `path` |
| Line(s) | `line`, `startLine` |
| Reviewer | Author of the comment being assessed; retain the first comment's author as thread-opener context |
| Comment body | All comments in the thread (the conversation) |
| Outdated? | `isOutdated` (file has changed since the comment was made) |

### Track All Feedback from the Initial Pass

Initialize the assessed-feedback record in this step, before deciding whether
there is anything to address. For each review thread, retain its thread ID,
disposition, and response permalink; snapshot every comment's ID, author login,
bot classification, full body, available update timestamp, and disposition so
new replies and edits can be distinguished from unchanged open conversations.
For each general review body or PR conversation comment, retain its source type,
ID, author login, bot classification, full body, available update timestamp,
disposition, and the permalink of any response that addresses it. Classify each
author using the API type (`__typename` in GraphQL, `user.type` in REST) and the
bot indicators above; retain that classification for attribution and replies.
Use this same record during monitoring; merely fetching a source or snapshotting
a conversation does not mark its feedback handled.

Split multi-point feedback into one checkable item per distinct actionable claim,
requested change, or question. Match each item to a specific existing response;
do not treat a reply covering only some items as handling the whole source.

On a fresh invocation, inspect existing workflow replies and summaries for a
specific answer to the source's current actionable feedback. Count a source as
handled only when all its actionable items are addressed and any claimed fix is
confirmed published on the PR. A human reply, acknowledgment, or status message
alone is not evidence of handling. If the evidence is unclear, keep it unaddressed.
New or edited feedback needs assessment; compare the body as well as any available
timestamp. Record this workflow's own replies and summaries so they are not
mistaken for new reviewer feedback.

### Edge Cases

- **No unaddressed feedback**: If there are no unresolved threads or unaddressed general review/PR comments,
  tell the user there is nothing to address and go to Step 14. During an active monitoring loop, count this
  as a completed check and continue within its existing limit instead of prompting again.
- **Outdated threads**: Include them but flag them, the code may have shifted since the comment was made. Read the current file to determine if the feedback still applies.
- **General PR review comments** (not attached to a specific line): Collect review
  bodies separately and respond through Step 9's PR-level reply mechanics. Reference
  the source permalink, reviewer, and published fixing commit (if any). Mention human
  reviewers with `@`; use plain bot names to avoid re-triggering them.
- **PR conversation comments**: Assess feedback posted directly on the PR like
  general review comments and use the same Step 9 PR-level reply mechanics. These
  comments have no review thread to resolve. Skip acknowledgments, status messages,
  and this workflow's own replies and summaries.

## Step 3: Validate Each Comment Against Repo Patterns

Before categorizing or acting on any comment, validate whether the reviewer's feedback is actually correct. Reviewers can make mistakes; blindly implementing every comment can introduce regressions.

For each unresolved thread and unaddressed general review/PR comment, follow the four-step validation flow in [`references/validation-heuristics.md`](references/validation-heuristics.md):

Attribute each item to the author of the comment or general source being assessed,
not automatically to the thread opener. Use that author's bot classification
when drafting replies and summaries; a later bot reply must not be `@mentioned`.

1. Read the current code/docs at the referenced location with surrounding context.
   If no file/line is given, use step 1's no-location guidance in the reference:
   map concrete claims to current code/docs, or validate pure discussion against PR context.
2. For code/doc claims, check the repo's relevant existing patterns via `grep`.
3. Cross-reference with project conventions (CLAUDE.md, eslint, style guides).
4. Assign one of four assessments: **Valid**, **Likely false positive**, **Partially valid**, or **Outdated**, and act accordingly.

Lean toward implementing when in doubt, but always surface your assessment to the user.

## Step 4: Categorize Comments

After validation, categorize each feedback item from an unresolved thread,
general review body, or PR conversation comment. Keep a stable item number, source
type and ID, reviewer, source permalink, and optional code location. A general
source may contain several actionable items; track each separately without
duplicating findings already represented by a thread.

| Category | Description | Action |
|----------|-------------|--------|
| **Code change** | Reviewer requests a specific modification and the suggestion is valid | Make the change |
| **Question** | Reviewer asks "why did you...?" or "what about...?" | Respond with explanation |
| **Nitpick / style** | Minor formatting, naming suggestion, or preference | Make the change (quick wins build goodwill) |
| **Approval with comment** | "Looks good, but consider..." or "Nit: ..." with no blocking intent | Assess, fix if trivial, explain if not |
| **False positive** | Reviewer's suggestion conflicts with repo patterns or is based on a misread | Flag for user, recommend a polite response explaining why |
| **Discussion** | Architectural debate, trade-off, or open-ended feedback | Flag for user decision |

### Present the Plan

Before making any changes, present every categorized feedback item to the user,
including general sources without a file/line. Use the source permalink to identify
the conversation; include a code location only when one is available. Show the
validation assessment for each item so the user can make an informed decision:

```
═══════════════════════════════════════════
PR #[number], REVIEW COMMENTS TO ADDRESS
═══════════════════════════════════════════

[N] actionable feedback items from [reviewers]: [T] unresolved threads and
[G] general review/PR comment items

CODE CHANGES NEEDED
───────────────────
1. ✓ [reviewer] — [source permalink] ([optional file:line]), "[summary of what they want]"
     Validated: [brief reason, e.g., "matches pattern in other components"]
2. ✓ [reviewer] — [source permalink] ([optional file:line]), "[summary of what they want]"
     Validated: [brief reason]

QUESTIONS TO ANSWER
───────────────────
3. [reviewer] — [source permalink] ([optional file:line]), "[the question]"

LIKELY FALSE POSITIVES
──────────────────────
4. ⚠ [reviewer] — [source permalink] ([optional file:line]), "[what they suggested]"
     Assessment: [why this appears incorrect, e.g., "Reviewer suggests
     BehaviorSubject but this repo uses signals for component-local state.
     Found 12 components using signal() vs 3 legacy BehaviorSubjects."]
     Recommendation: Respond explaining the repo convention. No code change.

NEEDS YOUR INPUT
────────────────
5. [reviewer] — [source permalink] ([optional file:line]), "[the discussion point]"
   → What would you like me to do here?

═══════════════════════════════════════════
Shall I proceed with items 1-2? Items 4-5 need your direction.
═══════════════════════════════════════════
```

**Wait for user approval before making changes.** The user has final say on whether to implement, push back, or discuss further, especially for items flagged as potential false positives.

### Responding to False Positives

When the user confirms a comment is a false positive, draft a respectful response (acknowledge intent, explain the repo convention with evidence, offer to discuss). See [`references/validation-heuristics.md`](references/validation-heuristics.md), "Responding to a confirmed false positive" for the response template and tone.

## Step 5: Address Each Comment

Work through the approved comments systematically.

### For Code Changes and Nitpicks

1. **Read the current file** at the relevant location to understand the context
2. **Make the change** using Edit, keep changes minimal and focused on what the reviewer asked
3. **Verify the change**, re-read the modified area to confirm it addresses the feedback
4. **Track what was done**, keep a running log of changes for the commit message and responses

### For Questions

1. **Read the relevant code** to understand the context
2. **Draft a response** that explains the reasoning, be specific, reference the code
3. **Ask the user to review the draft response** if the question touches on architectural decisions or trade-offs the user should weigh in on

### For Discussion Items

Only address these after the user provides direction in Step 4.

### Delegation to Builder Skills

For complex changes that span multiple files or require repo-specific pattern
knowledge (e.g., "refactor this to use signals instead of BehaviorSubject"),
route to the owning repo's local workflow. Use `/lfx-skills:lfx` when the
owner is unclear, then use that repo's `CLAUDE.md` and local skills.

```
Skill(skill: "<repo-local-skill>", args: "FIX PR REVIEW: [description of the change needed]. File: [path]. Context: reviewer asked for [what they said]. Follow the existing pattern in [example file].")
```

```
Skill(skill: "<repo-local-skill>", args: "FIX PR REVIEW: [description of the change needed]. Repo: [path]. Context: reviewer asked for [what they said].")
```

For simple, targeted fixes (rename a variable, add a null check, fix an import), make the change directly, no need to delegate.

## Step 6: Validate Changes

If there are no approved code changes in this round, skip Steps 6–8 and continue
to Step 9 with the approved responses.

After all code changes are made, run validation. Delegate to preflight with `--skip-review` since this is an iteration, not a fresh PR:

```bash
# Quick validation, format, lint, build
yarn format && yarn lint && yarn build
# Or for Go repos:
go vet ./... && go build ./...
```

If validation fails, fix the issues before proceeding. Do not commit broken code.

## Step 7: Commit with Detailed Summary

If there are no approved code changes, skip Steps 7 and 8 and continue to Step 9
with the approved responses. Do not create an empty commit for a response-only
iteration. Otherwise, create one commit summarizing the approved changes.

### Commit Message Format

The commit message must clearly state what review feedback was addressed, so that both git history readers and PR reviewers can understand what happened. **Do NOT include real reviewer GitHub handles in the commit message body** — the LFX plugin-wide PII rule at `skills/lfx/SKILL.md` (hard rule 4 in `skills/lfx/references/data-privacy.md`) treats GitHub handles as linked pseudonyms and prohibits them in commit messages except in the DCO `Signed-off-by:` trailer and consenting `Co-authored-by:` trailers. A reviewer is neither the DCO signer nor a coauthor, so their handle does not qualify. Bot reviewer names (e.g. `copilot[bot]`, `coderabbitai[bot]`) are tool identifiers, not linked pseudonyms, and may appear in commit bodies. Human reviewer identity is captured by the linked PR — readers can consult the PR thread history for who requested what:

```
fix(review): address PR #[number] review feedback

Address review comments from the reviewers on PR #[number]:

- [file]: [what was changed and why]
- [file]: [what was changed and why] (per botname[bot])
- [file]: responded to question about [topic]

Resolves [N] review threads.
```

Note: The `--signoff` flag automatically appends the `Signed-off-by:` trailer, do not include it manually in the message body.

### Commit Rules

- **One commit per review iteration**, don't create separate commits per comment. Reviewers want to see a single cohesive response to their feedback.
- **Reference the PR number** in the commit subject.
- **Do not include real reviewer handles in commit messages.** Bot reviewer names (e.g. `copilot[bot]`) are tool identifiers and may appear — but never with an `@` prefix, since tagging bots causes them to re-trigger. Human reviewer identity belongs in the PR thread reply and the PR summary comment (Steps 9 and 11), which are not persistent commit-message content and are not in the scope of hard rule 4.
- **Include `--signoff` and `-S`**, `--signoff` is required for DCO compliance, `-S` for GPG-signed commits. Both are enforced on LFX repos.
- **List every change**, the commit body should be a complete record. Someone reading the commit message should know exactly what review feedback was addressed without needing to read the diff.

```bash
git add [specific files that were changed]
git commit -S --signoff -m "$(cat <<'EOF'
fix(review): address PR #[number] review feedback

Address review comments from the reviewers on PR #[number]:

- path/to/file.ts: renamed variable per reviewer suggestion
- path/to/component.html: added loading guard for stats display (per copilot[bot])
- path/to/service.ts: explained error handling approach (no code change)

Resolves 3 review threads.
EOF
)"
```

## Step 8: Push Changes

Skip this step for a response-only iteration. When code changes were made, publish
the fixing commit before posting fix replies, resolving those threads, or posting
the summary, so reviewers can inspect the changes being claimed.

```bash
git push
```

If the push fails due to remote changes, pull and rebase first:

```bash
git pull --rebase origin $(git branch --show-current)
# Re-run quick validation after rebase
yarn lint && yarn build
git push
```

## Step 9: Respond to Each Feedback Source

After any fixing commit is confirmed published, respond to each addressed thread
and general feedback source on GitHub. If no approved code change was made, proceed
directly with the approved responses without a commit or push. Reviewers need to
know what was answered and whether anything changed.

### Response Format by Category

For review threads, post each reply with the `addPullRequestReviewThreadReply`
mutation in [`references/graphql-queries.md`](references/graphql-queries.md),
"Reply to a review thread", bound to `$THREAD_ID` and `$RESPONSE_BODY`.

For general review bodies and PR conversation comments, use the PR-comment POST
command in the same reference, "Reply to general PR feedback". Include the source
permalink, the specific answer or change, and the published commit SHA when a fix
was made. Record the returned reply permalink in the Step 2 record; do not mark a
source handled until all its actionable items are addressed. These sources have
no thread ID, so Step 10's resolution mutation does not apply.

**For code changes made:**

Response body:

```
Done, [specific description of the change made].

See commit [short SHA]: [one-line summary of what changed in this file].
```

**For questions answered (no code change):**

```
[Clear, specific answer to the question with code references where helpful].

No code change needed, [brief explanation of why the current approach is correct].
```

**For nitpicks fixed:**

```
Fixed, [what was changed]. Good catch!
```

**For discussion items where user provided direction:**

```
[Explanation of the decision and reasoning].

[Description of what was changed, or why no change was made].
```

**For false positives (user confirmed no change needed):**

```
Thanks for flagging this, I can see why it looks [wrong/inconsistent/off].

[Explanation with evidence: "This repo uses [pattern X] for [reason]. You can see
the same approach in [file1], [file2], etc."]

[If applicable: "Happy to discuss further if you think we should reconsider."]
```

### Response Rules

- **Be specific**, don't say "Fixed." Say what was fixed and how.
- **Reference the published fixing commit when a fix was made**, including its
  short SHA. For response-only outcomes, explain the answer or decision without
  requiring a commit reference.
- **Keep it concise**, one or two sentences for simple fixes, a short paragraph for questions or discussions.
- **Be professional and appreciative**, reviewers spent time reading the code. Acknowledge good catches.
- **Never `@mention` bot reviewers**, when replying to a bot's thread, do not include `@botname` in the response body. Tagging bots causes them to re-trigger and attempt to re-review or act on already-resolved feedback.

## Step 10: Resolve Review Threads

After responding to each thread, resolve it with the `resolveReviewThread` mutation in [`references/graphql-queries.md`](references/graphql-queries.md) (section "Resolve a review thread"), bound to `$THREAD_ID`. Only resolve threads where the feedback has been fully addressed, if a thread required user input and the user chose not to address it, leave it unresolved.

### Do NOT Resolve If

- The comment was a discussion point and no conclusion was reached
- The user explicitly said to skip or defer a comment
- The change couldn't be made due to a technical constraint (explain why in the response, leave unresolved)
- You're unsure whether your change fully addresses the feedback, leave unresolved and let the reviewer confirm

## Step 11: Post Summary Comment

After responding to the addressed feedback items and resolving eligible threads,
post a single summary comment on the PR. Include thread findings, general
review-body findings, and PR conversation comments, even when they have no code
location, so reviewers can see everything addressed in this iteration:

Response-only iterations still post the applicable summary. Omit the commit field
and empty changes section when no code change was made; report the answers,
explanations, resolutions, and anything left open instead.

```bash
gh pr comment $NUMBER --repo $OWNER/$REPO --body "$(cat <<'EOF'
## Review Feedback Addressed

[If this iteration published a fixing commit:]
Commit: [full SHA]

[If code changes were made:]
### Changes Made
- **[file]**: [what changed] ([source permalink]; per @[human-reviewer])
- **[file]**: [what changed] ([source permalink]; per botname[bot])

### Questions Answered
- **[source permalink]** ([optional file:line]): [brief answer] (asked by @[human-reviewer])

[If any comments were identified as false positives:]
### No Change Needed
- **[source permalink]** ([optional file:line]): [brief explanation of why the current code is correct and what repo pattern it follows] (flagged by botname[bot])

### Feedback Items Addressed
[N] of [M] actionable feedback items addressed in this iteration, including
[G] general review/PR comment items. Count items separately from thread resolutions.

### Threads Resolved
[T] of [U] initially unresolved threads resolved in this iteration. General review
bodies and PR conversation comments have no thread to resolve.

[If any feedback items were left unaddressed or threads remain open:]
### Still Open
- **[source permalink]** ([optional file:line]): [why it was left open, e.g., "deferred to follow-up PR", "awaiting reviewer confirmation"]
EOF
)"
```

### Summary Rules

- **List every feedback item** that was addressed, not just code changes or threads;
  identify its source permalink and include the code location only when available
- **Group by action type**, changes made, questions answered, deferred
- **Include the commit SHA when a fixing commit exists** so reviewers can inspect
  the diff; omit this field for response-only iterations
- **Call out anything left open**, don't hide unresolved items
- **Credit human reviewers** by `@mentioning` them next to their feedback (e.g., write `(per @alice)` or `(asked by @bob)`)
- **Never `@mention` bot reviewers** in the summary, use their plain name without the `@` prefix (e.g., write `(per copilot[bot])` not `(per @copilot[bot])`). Tagging bots in the summary causes them to re-trigger and attempt to act on already-resolved feedback.

## Step 12: Dismiss Stale Reviews and Re-request

If changes were pushed in Step 8, dismiss any `CHANGES_REQUESTED` reviews from reviewers whose feedback was fully addressed in this iteration, then re-request their review so they receive a notification. If no code changes were made (e.g., only questions answered), skip this step.

See [`references/dismiss-rerequest.md`](references/dismiss-rerequest.md) for the full flow (identify reviews, dismiss, re-request, edge cases).

## Step 13: Report to User

Outside monitoring, present the final status using the template below. During a
monitoring round, the loop's round report replaces this template; do not include
the "Optionally monitor" bullet or offer another monitoring cycle.
For a response-only iteration, omit the commit and pushed-branch fields; report
the approved replies and applicable resolutions without implying publication.

```
═══════════════════════════════════════════
PR #[number], REVIEW FEEDBACK ADDRESSED
═══════════════════════════════════════════

[If this iteration published a fixing commit:]
Commit: [SHA], [commit subject]
Pushed to: [branch]

Feedback items addressed: [N] of [M]
  ✓ [N] code-change items addressed
  ✓ [N] questions answered
  ✓ [N] general review/PR comment items addressed (included above)
Threads resolved on GitHub: [T] of [U] initially unresolved threads
  [- [N] feedback items left unaddressed; [N] threads still open]
Sources: [item numbers and source permalinks, with code locations when available]

[If reviews were dismissed:]
Reviews refreshed:
  ✓ Dismissed "changes requested" from @[reviewer1], @[reviewer2]
  ✓ Re-requested review from @[reviewer1], @[reviewer2]

Summary comment posted: [PR URL]

What's next:
  [- Reviewers have been re-requested and will be notified (only if refreshed)]
  - Optionally monitor this PR for feedback in up to 3 follow-up rounds
  [- [N] feedback items still need discussion, follow up at their source permalinks]
═══════════════════════════════════════════
```

## Step 14: Offer Bounded PR Monitoring

After the final report (or Step 2 finds nothing to address), use
`AskUserQuestion` to ask:

> "Would you like me to monitor this PR for new comments and remaining
> unresolved feedback, validate what needs fixing, and run this same resolution
> workflow for up to 3 follow-up rounds? I'll wait 60 seconds before each check
> and still ask for approval before making changes."

Offer **Monitor (up to 3 rounds)** and **Finish now**. Do not start monitoring
without an explicit opt-in. If the user declines, finish without further checks.

### Monitoring Loop

The initial resolution pass does **not** count toward the limit. Maintain one
session-local counter for this PR, initially `0`, and reuse the assessed-feedback
record initialized in Step 2. Unassessed feedback remains eligible.

For each of **at most 3 follow-up rounds**:

1. **Wait and count.** Wait 60 seconds (`sleep 60`), then increment the counter
   before fetching. Every check consumes a round, even if no new or valid
   feedback appears. Honor a user's request to stop immediately.
2. **Re-fetch the same PR.** Check its state; stop if it is merged or closed.
   Repeat Step 2, including paginated review threads, their full conversations,
   general review bodies, and PR conversation comments. Do not reuse a stale
   snapshot. If a fetch fails, report the failure and stop rather than claiming
   the PR has no feedback.
3. **Identify eligible feedback.** Read new or edited comments and all remaining
   unresolved threads, including outdated ones against the current code. Skip
   resolved threads and unchanged feedback already answered, rejected with user
   approval, deferred, or awaiting user/reviewer input. A new reply or edited
   body reopens assessment; an unchanged open thread alone does not justify
   repeating a reply or asking the same question again.
4. **Validate and resolve.** For eligible feedback, follow Steps 3–13 again:
   validate against current code and repo patterns, present the categorized
   plan, obtain Step 4 approval, and make only approved fixes. Monitoring consent
   does not approve code changes or false-positive dismissals. Preserve the same
   validation, commit/push, per-comment response, resolution, summary, and
   re-request rules; do not create empty commits or post duplicate replies or
   summaries when no action is taken.
5. **Report the round.** Replace Step 13's terminal report with
   `Monitoring round [N]/3`, feedback assessed, actions taken, commit/publication
   state (if any), and anything still unresolved. Do not repeat the monitoring
   offer. If there is no eligible feedback, say so and continue to the next check
   within the limit.

When Step 13 completes inside this loop, return to the next numbered round,
**not** to a fresh Step 14 prompt. Never recursively invoke this skill, reset
the counter after a push, or automatically extend/restart monitoring. After
round 3, stop and report any remaining unresolved feedback and that the
monitoring limit was reached; do not claim that future comments are covered.

## Idempotency, Safe to Re-run

If the user runs this skill again on the same PR:

1. **Re-fetch all feedback**, including every thread conversation, general review
   body, and PR conversation comment. Skip already-resolved threads.
2. **Reconstruct the Step 2 record** from specific existing replies and summaries.
   Match source IDs, full bodies, and available update timestamps; do not repeat
   answers to unchanged, addressed feedback. Keep deferred or uncertain sources
   unaddressed, and require publication evidence for claimed fixes.
3. **Assess new or edited feedback** even when its source ID was seen before.
4. **Keep monitoring state invocation-local.** Consent and the round counter belong
   to the active invocation only. A fresh invocation requires a new Step 14 opt-in
   and starts its follow-up counter at `0`; it does not silently inherit consent.
   Within an active loop, retain the existing counter and consent after a push.
5. Tell the user: "Found [N] new/remaining unresolved threads and [M] unaddressed
   general feedback sources since the last iteration."

## Scope Boundaries

**This skill DOES:**
- Fetch and analyze PR review threads, general review bodies, and PR conversation comments
- Categorize comments by type (code change, question, discussion)
- Make targeted code changes to address review feedback
- Commit with a detailed summary of what was addressed
- Respond to each feedback source through thread replies or PR-level comments for
  general review and PR conversation feedback
- Resolve addressed threads
- Post a summary comment on the PR
- Push changes to the remote branch
- Dismiss stale "changes requested" reviews after addressing feedback
- Re-request review from reviewers whose feedback was addressed
- Route complex changes to the owning repo's local skills and `CLAUDE.md`
- Offer opt-in monitoring for new comments and remaining unresolved feedback, capped at 3 follow-up rounds

**This skill does NOT:**
- Create new PRs (use the owning repo's local preflight/readiness flow first)
- Build new features from scratch (use the owning repo's local development skill)
- Review code (use the configured reviewer agents or repo-local review workflow)
- Merge PRs (the reviewer does that)
- Resolve threads where the feedback wasn't fully addressed
