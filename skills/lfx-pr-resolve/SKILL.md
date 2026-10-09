---
name: lfx-pr-resolve
description: >
  Address PR review comments, fetches unresolved threads, makes code changes,
  commits with a summary, responds to each comment, resolves threads, posts
  a follow-up summary, dismisses stale "changes requested" reviews, and
  re-requests review, and offers up to three opt-in monitoring rounds. Use
  whenever someone wants to address PR feedback, fix
  review comments, resolve PR threads, or iterate on a pull request after review
  — unless the PR's repo carries a `## Review lifecycle configuration` section
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

Fetch PR metadata and the first review-thread page with the query in
[`references/graphql-queries.md`](references/graphql-queries.md), "Fetch PR
review threads". Bind `$OWNER`, `$REPO`, and `$NUMBER`, then follow its executable
cursor queries to drain all thread pages and every thread's comment pages before
filtering feedback. Keep comment IDs, bodies, and `updatedAt` for detecting edits,
and each comment's `url` for inline links in approval plans and replies.

Also fetch general review bodies and PR conversation comments using
[`references/graphql-queries.md`](references/graphql-queries.md), "Fetch general
PR feedback". Read these alongside unresolved threads; actionable feedback is
not limited to inline comments.
Keep each non-thread item's source (general review or PR conversation comment),
ID, author, body, link, and available update timestamp for approval and replies.

### Identify AI Bot Reviewers

Before processing threads, identify which reviewers are AI bots. Common bot indicators:

- Username ends with `[bot]` (e.g., `copilot[bot]`, `coderabbitai[bot]`, `github-actions[bot]`)
- Username matches known AI review bots: `copilot`, `coderabbitai`, `codeclimate`, `sonarcloud`, `deepsource`, `sourcery-ai`, `ellipsis-dev`, `korbit-ai`, `bito-ai`, `pr-agent`
- User type from the API is `Bot` rather than `User`

Maintain a list of bot reviewer logins for this PR. These reviewers must **never be `@mentioned`** in any content posted to GitHub (comments, commit messages, summary). Tagging bots causes them to re-trigger and attempt to act on already-resolved feedback.

**Bot comments are still actionable**, address their feedback like any other reviewer. The restriction is only on `@mentioning` them in GitHub-posted content.

### Filter to Actionable Threads

On the initial pass, collect **unresolved** threads (`isResolved == false`).
Keep a baseline snapshot of resolved conversations, but do not re-address their
existing comments or mark them assessed. During monitoring, also collect resolved
threads containing new or edited reviewer comments since the previous snapshot;
resolution status does not suppress fresh feedback. Ignore this workflow's own
replies and skip unchanged handled feedback as described in Step 14.

For each eligible thread, extract:

| Field | Source |
|-------|--------|
| Thread ID | `id` (needed for resolving later) |
| File path | `path` |
| Line(s) | `line`, `startLine` |
| Reviewer | First comment's `author.login` |
| Comment body | All comments in the thread (the conversation) |
| Comment identity/version | Each comment's `id`, `body`, and `updatedAt` |
| Outdated? | `isOutdated` (file has changed since the comment was made) |

### Edge Cases

- **No unaddressed feedback**: If there are no eligible threads or unaddressed
  general review/PR comments, tell the user there is nothing to address and go to
  Step 14. During active monitoring, count this as a completed check and continue
  within its existing limit instead of prompting again.
- **Outdated threads**: Include them but flag them, the code may have shifted since the comment was made. Read the current file to determine if the feedback still applies.
- **General PR review comments** (not attached to a specific line): These appear as reviews with a `body` but no associated thread path. Collect these separately, they need responses but may not require code changes. You will respond to each of these later via a PR-level comment that references the reviewer and the commit that addresses their feedback (if any). When referencing reviewers, `@mention` human reviewers but use plain names (no `@` prefix) for bot reviewers to avoid re-triggering them.
- **PR conversation comments**: Assess feedback posted directly on the PR like general review comments.
  Reply at PR level; these comments have no review thread to resolve. Skip acknowledgments, status messages,
  and this workflow's own replies and summaries.

## Step 3: Validate Each Comment Against Repo Patterns

Before categorizing or acting on any comment, validate whether the reviewer's feedback is actually correct. Reviewers can make mistakes; blindly implementing every comment can introduce regressions.

For each eligible thread and unaddressed general review/PR comment, follow the
four-step validation flow in
[`references/validation-heuristics.md`](references/validation-heuristics.md):

1. Read the actual code at the referenced location (with 20-30 lines of surrounding context).
2. Check the repo's existing patterns via `grep`.
3. Cross-reference with project conventions (CLAUDE.md, eslint, style guides).
4. Assign one of four assessments: **Valid**, **Likely false positive**, **Partially valid**, or **Outdated**, and act accordingly.

Lean toward implementing when in doubt, but always surface your assessment to the user.

## Step 4: Categorize Comments

After validation, categorize every eligible feedback item: review threads,
general review bodies, and PR conversation comments.

| Category | Description | Action |
|----------|-------------|--------|
| **Code change** | Reviewer requests a specific modification and the suggestion is valid | Make the change |
| **Question** | Reviewer asks "why did you...?" or "what about...?" | Respond with explanation |
| **Nitpick / style** | Minor formatting, naming suggestion, or preference | Make the change (quick wins build goodwill) |
| **Approval with comment** | "Looks good, but consider..." or "Nit: ..." with no blocking intent | Assess, fix if trivial, explain if not |
| **False positive** | Reviewer's suggestion conflicts with repo patterns or is based on a misread | Flag for user, recommend a polite response explaining why |
| **Discussion** | Architectural debate, trade-off, or open-ended feedback | Flag for user decision |

### Present the Plan

Before making changes or posting responses, present every eligible feedback
item with its assessment and proposed action. Identify inline feedback by
file/line and thread link; identify non-thread feedback by source, author, and
ID/link. Count feedback items separately from review threads. Use the approval
plan in [`references/feedback-templates.md`](references/feedback-templates.md),
"Approval plan", omitting empty categories.

**Wait for user approval before making changes or posting responses.** The user
decides whether to implement, push back, or discuss further, especially for
potential false positives. Monitoring consent does not supply this approval.

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

### Choose the change or response-only path

After Step 5, if no repository files changed, skip Steps 6–8 and proceed directly
to Step 9 with the approved responses. Do not create an empty commit or push an
unrelated existing commit. Omit commit/SHA and push fields from replies, the
Step 11 summary, and the Step 13 report; state "No code changes" instead. Skip
Step 12 because no changes were pushed. If files changed, complete Steps 6–8 and
push before posting responses, resolving threads, or posting the summary.

## Step 6: Validate Changes

After all code changes are made, run validation. Delegate to preflight with `--skip-review` since this is an iteration, not a fresh PR:

```bash
# Quick validation, format, lint, build
yarn format && yarn lint && yarn build
# Or for Go repos:
go vet ./... && go build ./...
```

If validation fails, fix the issues before proceeding. Do not commit broken code.

## Step 7: Commit with Detailed Summary

Create a single commit that summarizes all changes made to address the review feedback.

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

Push the commit to the remote branch **before** posting any comments, resolving threads, or posting summaries. This ensures that when bots and reviewers are notified of your responses, the code changes are already available for them to validate.

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

## Step 9: Respond to Each Comment Thread

After pushing changes, or selecting the response-only path in Step 5, respond to
each eligible conversation on GitHub. Reviewers need to know what was addressed.

### Choose the response route

- **Review threads:** Use `addPullRequestReviewThreadReply` in
  [`references/graphql-queries.md`](references/graphql-queries.md), "Reply to a
  review thread", bound to `$THREAD_ID` and `$RESPONSE_BODY`.
- **General review bodies and PR conversation comments:** Use the executable
  PR-level command in that reference, "Reply to non-thread feedback". Identify
  the source and ID/link, credit the reviewer, and reference the fix commit when
  files changed. These sources have no thread ID or resolution mutation.

Draft the category-specific response using
[`references/feedback-templates.md`](references/feedback-templates.md), "Response
bodies". Respond to independent non-thread feedback; when a review overview
only repeats inline findings, cover it in the iteration summary without a
duplicate per-finding response.

### Response Rules

- **Be specific**, don't say "Fixed." Say what was fixed and how.
- **Reference the commit when files changed**, include its short SHA. For a
  response-only iteration, omit commit references; no new commit exists.
- **Keep it concise**, one or two sentences for simple fixes, a short paragraph for questions or discussions.
- **Be professional and appreciative**, reviewers spent time reading the code. Acknowledge good catches.
- **Never `@mention` bot reviewers**, when replying to a bot's thread, do not include `@botname` in the response body. Tagging bots causes them to re-trigger and attempt to re-review or act on already-resolved feedback.

## Step 10: Resolve Review Threads

After responding, resolve each fully addressed **unresolved** thread with the
`resolveReviewThread` mutation in
[`references/graphql-queries.md`](references/graphql-queries.md), "Resolve a
review thread", bound to `$THREAD_ID`. A resolved thread with fresh feedback
still receives a reply, but needs no resolution mutation. Leave feedback open
when it is deferred, undecided, or not fully addressed.

### Do NOT Resolve If

- The comment was a discussion point and no conclusion was reached
- The user explicitly said to skip or defer a comment
- The change couldn't be made due to a technical constraint (explain why in the response, leave unresolved)
- You're unsure whether your change fully addresses the feedback, leave unresolved and let the reviewer confirm

## Step 11: Post Summary Comment

After posting the approved responses and resolving fully addressed threads,
post one iteration summary using
[`references/feedback-templates.md`](references/feedback-templates.md), "Summary
comment". Include non-thread feedback as well as review threads.

### Summary Rules

- **List every feedback item** addressed, not just code changes or review threads;
  identify non-thread items by source and ID/link, and count them separately.
- **Group by action type**, changes made, questions answered, deferred
- **Include the commit SHA only when files changed** so reviewers can see the
  diff; otherwise omit it and state "No code changes".
- **Call out anything left open**, don't hide unresolved items
- **Credit human reviewers** by `@mentioning` them next to their feedback (e.g., write `(per @alice)` or `(asked by @bob)`)
- **Never `@mention` bot reviewers** in the summary, use their plain name without the `@` prefix (e.g., write `(per copilot[bot])` not `(per @copilot[bot])`). Tagging bots in the summary causes them to re-trigger and attempt to act on already-resolved feedback.

## Step 12: Dismiss Stale Reviews and Re-request

If changes were pushed in Step 8, dismiss any `CHANGES_REQUESTED` reviews from reviewers whose feedback was fully addressed in this iteration, then re-request their review so they receive a notification. If no code changes were made (e.g., only questions answered), skip this step.

See [`references/dismiss-rerequest.md`](references/dismiss-rerequest.md) for the full flow (identify reviews, dismiss, re-request, edge cases).

## Step 13: Report to User

Present the final status using
[`references/feedback-templates.md`](references/feedback-templates.md), "User
report". Include every feedback source, verification, and anything left open.

## Step 14: Offer Bounded PR Monitoring

After the final report (or Step 2 finds nothing to address), use
`AskUserQuestion` to ask:

> "Would you like me to monitor this PR for new comments and remaining
> unresolved feedback, validate what needs fixing, and run this same resolution
> workflow for up to 3 follow-up rounds? I'll wait 60 seconds before each check
> and still ask for approval before making changes."

Offer **Monitor (up to 3 rounds)** and **Finish now**. Do not start monitoring
without an explicit opt-in. If the user declines, finish without further checks.

After explicit opt-in, read and follow
[`references/monitoring.md`](references/monitoring.md) for the session-local
records, all-source eligibility checks, and bounded loop. Within an active loop,
return to its next numbered round instead of offering monitoring again.

## Idempotency, Safe to Re-run

A fresh invocation has no prior session-local handling record:

1. **Re-fetch complete conversations.** Collect unresolved threads and substantive
   general review/PR comments; baseline resolved threads without re-addressing
   old inline comments. Read visible replies/summaries to avoid duplicate answers.
2. **Do not assume prior dispositions.** Reassess unresolved feedback whose prior
   deferred or awaiting-input state cannot be established from the conversation.
3. **Within the same monitoring session only**, skip unchanged handled feedback;
   new or edited feedback from any source is eligible, including resolved threads.
4. Tell the user: "Found [N] remaining eligible feedback items, including [T]
   review threads." Do not claim to detect changes since a lost snapshot.

## Scope Boundaries

**This skill DOES:**
- Fetch and analyze PR review threads
- Categorize comments by type (code change, question, discussion)
- Make targeted code changes to address review feedback
- Commit with a detailed summary of what was addressed
- Respond to each review thread on GitHub
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
