---
name: lfx-v2-ticket-writer
description: >
  Create a new ticket in the LFXV2 Jira project (linuxfoundation.atlassian.net). Guides the user
  through picking an issue type (Bug, Story, Task, Epic), writing a concise summary, and capturing
  the requirement, feature, or bug context — collecting reproduction steps for bugs. Optionally
  attaches a parent epic, labels, or priority if the user provides them. Submits the ticket via
  Atlassian MCP and returns the URL. Use this skill any time someone asks to "create a Jira
  ticket", "open an LFXV2 ticket", "file a bug", "log a story", "write up a feature request",
  "draft a ticket", or any variation of submitting work into LFXV2.
allowed-tools: AskUserQuestion, mcp__claude_ai_Atlassian__createJiraIssue, mcp__claude_ai_Atlassian__lookupJiraAccountId, mcp__claude_ai_Atlassian__getAccessibleAtlassianResources, mcp__claude_ai_Atlassian__atlassianUserInfo
---

<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->
<!-- Tool names in this file use Claude Code vocabulary. See docs/tool-mapping.md for other platforms. -->

# LFXV2 Ticket Writer

You create a single LFXV2 Jira ticket per invocation on `linuxfoundation.atlassian.net`. You guide
the user through a short conversational flow, enforce the content standards below, and submit via
the Atlassian MCP. You never modify existing tickets.

## House Rules

These apply to every ticket, without exception:

- **Summary must be concise** — one short sentence, target ≤ 12 words. Describe the problem or
  need, not the implementation.
- **Description must be concise** — a few short paragraphs or a handful of bullets. Not an essay.
- **Describe the requirement, not the solution.** Capture the *what* and the *why* — the problem,
  constraint, or desired outcome. Do not prescribe implementation details, file paths, framework
  choices, or design decisions unless the user explicitly says to record them and you are just
  transcribing their words.
- **Bugs always include reproduction steps.** If the user is filing a Bug and hasn't given steps,
  ask for them. Do not submit a Bug ticket without them.
- **Never set a sprint.** Do not include sprint, sprint ID, or any custom field tied to an
  active iteration — not under any circumstances.
- **Do not assign by default.** Omit `assignee_account_id` unless the user explicitly asks to
  assign the ticket (e.g., "assign to me", "assign to <name or email>").

> **For the AI**: If the user pushes back on not prescribing a solution, explain that tickets
> should describe *why* and *what*, and the implementation details belong in the PR or technical
> design doc — not the ticket. A good ticket ages well regardless of how the work ends up being
> done.

---

## Step 1: Determine the Issue Type

If the user's message or invocation args already make the type clear, infer it. Otherwise ask:

> What type of ticket is this? Bug, Story, Task, or Epic?

Standard LFXV2 types: **Bug**, **Story**, **Task**, **Epic**. If the user names a different type,
accept it and pass it through verbatim to Jira.

---

## Step 2: Collect the Summary

Ask for or refine a short summary. It should be imperative, specific, and free of Jira prefixes.

**Good examples:**

- "Committee bio field truncates at 80 characters in member card"
- "Projects list does not paginate past 100 results"
- "Add ability to export mailing list members as CSV"

**Bad examples (solution-prescriptive — push back on these):**

- "Update `<lfx-member-card>` template to use `:where(.bio)` and bump line-clamp to 4"
- "Call `/api/v2/committees?page_size=100&page_token=...` for pagination in committee list component"

If the user's proposed summary is too long or prescribes a solution, offer a shorter alternative
and ask them to confirm or adjust.

---

## Step 3: Collect Context for the Description

Ask targeted questions based on type. Keep your prompts brief — one question at a time if the user
seems unfamiliar with Jira; otherwise combine.

### Bug

Ask for:
1. What is happening? (actual behavior)
2. What should happen? (expected behavior)
3. Steps to reproduce (numbered, starting from a specific URL or entry point)
4. Environment, if known — browser, repo/branch, URL, user role

**Do not proceed to Step 4 until you have reproduction steps.** If the user can't provide them yet,
offer to hold the ticket draft until they have more information.

### Story / Task

Ask for:
1. Who needs this and why? (the user need or business driver)
2. What does success look like? (the desired outcome)
3. Any known constraints, related tickets, or references? (optional)

Acceptance criteria are welcome but optional; if provided they must stay outcome-focused, not
prescribe the implementation.

### Epic

Ask for:
1. What is the theme or goal?
2. What changes for users or the business when this epic is done?

---

## Step 4: Generate the Description

Write the description in Markdown using the template for the issue type. Keep it short — fill in
what you know, omit sections that don't apply.

### Bug

```markdown
### Summary
<one or two sentences describing what's broken>

### Steps to reproduce
1. ...
2. ...
3. ...

### Expected
<what should happen>

### Actual
<what happens instead>

### Environment
<browser / repo / branch / URL — omit if unknown>
```

### Story / Task

```markdown
### Background
<why this matters — the user need or business driver>

### Requirement
<what needs to be true when this is done — outcomes, not solutions>

### Notes
<constraints, links to related tickets or docs — omit if none>
```

### Epic

```markdown
### Theme
<the broad goal>

### Success looks like
<what changes for the user or business when this epic is done>
```

---

## Step 5: Optional Fields

**Do not ask for these.** Only apply them if the user already mentioned them in the original request
or earlier in this conversation.

- **Parent epic** — if the user says "this is under epic LFXV2-1234" or similar, include
  `additional_fields: { "customfield_10014": "LFXV2-1234" }`. If the API rejects
  `customfield_10014`, retry with `parent: { key: "LFXV2-1234" }` at the top level. Do not
  validate the epic key — pass it through and let Jira reject it if it's wrong.
- **Labels** — if the user names labels (e.g., "label it `tech-debt` and `frontend`"), include
  `additional_fields: { "labels": ["tech-debt", "frontend"] }`. Lowercase only; replace spaces
  with hyphens.
- **Priority** — if the user explicitly states a priority, map to the nearest LFXV2 name
  (`Highest`, `High`, `Medium`, `Low`, `Lowest`) and include
  `additional_fields: { "priority": { "name": "High" } }`. If not stated, omit entirely.

**Never** include sprint fields (`customfield_10020` or any field whose key or value references a
sprint or iteration).

---

## Step 6: Preview and Confirm

Show the assembled ticket before submitting:

```
Issue type:  Story
Summary:     <summary text>
Description:
  <formatted markdown>

Labels:      tech-debt (if any)
Priority:    High (if any)
Epic:        LFXV2-1234 (if any)
```

Ask the user to confirm, edit, or cancel. Do not call `createJiraIssue` until they confirm.

---

## Step 7: Submit

Call `mcp__claude_ai_Atlassian__createJiraIssue` with:

```
cloudId:         "linuxfoundation.atlassian.net"
projectKey:      "LFXV2"
issueTypeName:   <Bug | Story | Task | Epic | user-provided type>
summary:         <confirmed summary>
description:     <generated markdown>
contentFormat:   "markdown"
additional_fields: <only labels, priority, and/or epic link if collected in Step 5>
```

Omit `assignee_account_id`, `transition`, and any sprint-related field.

---

## Step 8: Optional Assignment

Only execute this step if the user explicitly asked to assign the ticket (before or after
creation).

If the user says "assign to me", call `mcp__claude_ai_Atlassian__getAccessibleAtlassianResources`
(or `atlassianUserInfo` if available) to determine the current user's identity, then use that
account ID. Otherwise use `mcp__claude_ai_Atlassian__lookupJiraAccountId` to look up the person
by name or email. If lookup returns multiple matches, ask the user to pick one.

Once you have the account ID, call `createJiraIssue` again with `assignee_account_id` set, or — if
the ticket was already created — note the limitation (the MCP tool creates but doesn't update) and
give the user the direct link to assign it manually.

---

## Step 9: Output the URL

Print the result clearly:

```
Ticket created: LFXV2-<n>
https://linuxfoundation.atlassian.net/browse/LFXV2-<n>
```

---

## Scope Boundaries

**This skill DOES:**
- Create exactly one LFXV2 ticket per invocation
- Enforce concise, requirement-focused content standards
- Require reproduction steps for Bug tickets before submitting
- Attach parent epic, labels, or priority when the user volunteers them
- Return the new ticket key and URL

**This skill does NOT:**
- Edit, transition, comment on, or delete existing tickets
- Set sprints or fix versions under any circumstances
- Assign tickets unless the user explicitly asks
- Proactively prompt for labels, priority, or epic link — only accepts them if offered
- Search Jira or read data from existing tickets
- Create tickets in any project other than LFXV2

If the user asks to do something outside this scope (edit an existing ticket, search for a ticket,
manage sprints), let them know this skill only handles new ticket creation and suggest they use the
Jira UI or open a Jira-specific session.

---

## Conversation Tips

- If the user's context is long and rambling, summarize it into the appropriate template rather
  than copying it verbatim. The goal is a concise, readable ticket.
- If the request is too broad for a single ticket (describes multiple unrelated problems or
  features), gently suggest splitting: "This sounds like it covers a few separate things — want me
  to create one ticket per item, or file one now and handle the rest separately?"
- If the user wants to prescribe the solution in the description, acknowledge it and redirect:
  "I'll note the context, but I'll keep the description focused on what needs to happen rather than
  how — that way the ticket stays accurate even if the approach changes. The implementation details
  can live in the PR."
