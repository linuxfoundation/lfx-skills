---
name: lfx-local-review
description: The canonical LFX review lifecycle and the single source of truth for it — Pre-PR local review on three background Claude Opus 5 reviewers in two modes (post-commit while work continues, then one full-branch review before the PR), and Post-PR iteration on the configured GitHub review bots. Load and follow this skill in an adopting LFX repo after every pre-PR commit, when preparing to open a PR, and when working PR review threads. Pre-PR local review produces local author-side evidence and writes no GitHub state; Post-PR follows the configured GitHub review/thread workflow; neither phase merges.
---
<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->
<!-- Tool names in this file use Claude Code vocabulary. See docs/tool-mapping.md for other platforms. -->

# LFX review lifecycle

This skill is the **single source of truth** for how an adopting LFX repo
reviews its own work, from the first pre-PR commit to the last PR review
thread. The two sections below are the whole lifecycle, and they are frozen:
they are reproduced byte for byte from the approved text, and changing them is
an architecture change that is human-gated.

No repo adopting this central lifecycle may hold a second lifecycle copy. An
adopting repo carries, in its `CLAUDE.md`, **one sentence that loads this skill
and five configuration values** — the identities of its own two reviewers, its
two checks, and its Post-PR extension or `none` — and nothing else about how
review works. Repositories that have not adopted this skill are outside that rule and
are not governed by it; adoption is what brings a repo under it.

The split is deliberate. **The repo owns the identities**, because they are
repo facts that change with the repo. **This skill owns every rule**, because a
rule copied into a repo is a rule that drifts. Adoption therefore changes only
the adopting repo: nothing needs adding here.

**Resolving the seven values.** The lifecycle below is written against seven repository-specific values —
`{{REPO}}`, `{{CODE_SKILL}}`, `{{LEARNINGS_SKILL}}`, `{{CODE_PATH}}`,
`{{LEARNINGS_PATH}}`, `{{READINESS}}` and `{{PREFLIGHT}}`. One comes from the
checkout's identity, four are declared, and two are derived. Resolve them in
that order, and only like this.

**Step 1 — identify the repo from its `origin` URLs.**

1. `git rev-parse --show-toplevel` — the checkout you were invoked in. If this
   fails, you are not in a git checkout: stop.
2. `git remote get-url --all origin` — **every** fetch URL configured for
   `origin`, not just the first. Plain `git remote get-url origin` returns only
   the default one, so a checkout with a second, contradicting URL would be
   read as unambiguous. If the command fails, or returns no URL at all, stop.
3. Take the **last path segment** of each returned URL and strip a trailing
   `.git`. This is the repository name, and it is the same for
   `https://host/<owner>/<repo>` and `git@host:<owner>/<repo>.git`. The owner
   may be anything — a fork is still that repository. When `origin` has more
   than one URL, every derived name must be identical; if any two differ, stop.

That name is `{{REPO}}`.

**Never identify the repo any other way.** Not from the checkout's directory
name — under a worktree or an agent workspace the repository root is routinely
a directory literally called `work`, so the basename says nothing about which
repository it holds. Not from a repository name asserted in a prompt without
evidence. Not from a close or fuzzy match against anything.

**Step 2 — read the repo's declaration.** In `<repo-root>/CLAUDE.md`, **from
that verified checkout**, find the single section whose heading is exactly
`## Review lifecycle configuration`. That block is the declaration. It is one
trigger sentence followed by five keys, each exactly once, each value in a code
span:

```markdown
## Review lifecycle configuration

Load and follow `/lfx-skills:lfx-local-review` as the sole owner of the review
lifecycle. The values below configure that skill and do not replace or override
its instructions.

- repo code reviewer: `/<repo-code-skill-name>`
- repo learnings reviewer: `/<repo-learnings-skill-name>`
- readiness action: `<exact skill invocation or non-fixing command>`
- preflight action: `<exact skill invocation or non-fixing command>`
- post-PR extension: `none` or `/<exact-skill-name>`
```

`{{CODE_SKILL}}` and `{{LEARNINGS_SKILL}}` are the two reviewer values.
`{{READINESS}}` and `{{PREFLIGHT}}` are the two action values.

**The first line is the bootstrap, not a sixth value.** A fresh session reading
that `CLAUDE.md` has to be *told* to load this skill; a passive
`lifecycle: /lfx-skills:lfx-local-review` key would validate and never launch
anything. `/lfx-skills:lfx-local-review` is a central constant, so it is not
configuration a repo supplies — it belongs in the imperative sentence that
invokes it, and nowhere else in the block.

**Resolve every value from inside that block, and only from there.** A
`CLAUDE.md` is a long document that may discuss review, name skills, or quote
this schema in passing; a key matched anywhere in the file could pick up a
sentence that was never meant as configuration. Read the block, then read the
keys within it. The block holds the trigger sentence and the five values and
nothing more — if it contains prose about how review works, that is a fork of
the lifecycle and the repo must remove it.

**The declaration comes from the checkout and nowhere else.** Not from a
prompt, which cannot supply or override it; not from another repo; not from a
central table — this skill deliberately holds no per-repo mapping, so that
adopting a repo never means editing this plugin.

**Validate before using it.** Reject, and stop, when:

- there is no `## Review lifecycle configuration` section, or more than one
- the block does not open with the exact trigger sentence, naming exactly
  `/lfx-skills:lfx-local-review` as the sole owner of the review lifecycle and
  stating that the values below configure it rather than override it. This
  skill is the sole owner; a block that points somewhere else, or that only
  lists values without invoking anything, is not an adoption of it
- any of the five keys is missing from that block, or appears more than once
- either reviewer value fails `^/[A-Za-z0-9][A-Za-z0-9._-]*$` — one leading
  slash, then letters, digits, dot, underscore or hyphen only. That excludes a
  second `/`, a `:` (which would be a plugin-namespaced skill, and the repo's
  own reviewers are repo skills), whitespace, and every shell or path
  metacharacter. It also makes a `..` path component unreachable: the value
  cannot contain `/`, and cannot begin with `.`, so no component of it can be
  `..`. This matters because these values are about to become a filesystem path
- the two reviewer values are identical, so one reviewer would run twice
- `post-PR extension` is neither exactly `none` nor a value passing that same
  syntax — it is loaded and it derives no path, but it is a skill name and gets
  the same scrutiny
- a non-`none` `post-PR extension` equals either reviewer value. A declaration
  naming its own local code reviewer as the Post-PR extension would run a local
  reviewer after the PR opens, breaking the no-local-review boundary before any
  prose constraint could catch it
- a readiness or preflight value is empty, spans more than one line, or is not
  a single terminated code span. These are commands: an unterminated span or a
  second value on the field makes what actually runs ambiguous

The two action values are not otherwise constrained here — there is no central
allowlist of commands, because the repo owns what its checks are. What the
adoption review must confirm is that each one is an **exact, documented,
non-fixing** action for that repo.

**Step 3 — derive the two fallback paths.** A reviewer loads its skill by name. `{{CODE_PATH}}` and `{{LEARNINGS_PATH}}`
are the one file each may read **instead**, and they are derived mechanically
from the declared names — never declared, never searched for:

```text
/foo  ->  .claude/skills/foo/SKILL.md
```

Strip the leading `/`, and that is the skill directory. **These two values are
repo-root-relative and carry no root of their own.** The frozen prompt below
hands the child `<repo-root>/{{CODE_PATH}}`, joining the root exactly once; a
value that already began with `<repo-root>/` would substitute into a doubled
path that no file answers to. The full path the child actually reads — root
joined to the derived value, once — is what its fallback attestation must name.

Nothing else is a permitted read: not an alias directory, a sibling or similarly
named skill, a cached or vendored copy, another checkout, or a legacy
`lfx-*-code-reviewer` / `lfx-*-learnings-reviewer` agent. If the derived file is
absent, that reviewer returns INCOMPLETE. The central general reviewer has no
file fallback at all.

**A fallback file must prove it is the declared skill.** Reaching the derived
path is not the same as reaching the declared reviewer: whatever occupies
`.claude/skills/foo/SKILL.md` could declare `name: bar`, and a child that
followed it would review under `bar`'s guidance while attesting `Skill: /foo`.
So before following the file, read its YAML frontmatter and require `name` to
equal the declared name with the leading `/` removed. Missing frontmatter,
frontmatter you cannot parse, or a `name` that differs by any character means
that reviewer returns INCOMPLETE — never look for the declared name elsewhere,
never accept a near match, and never substitute another file. This applies to
both repo reviewers; the central general reviewer has no file fallback to
validate.

**Fail closed.** Not a git checkout, no `origin`, no URL returned, a URL you cannot parse,
`origin` URLs whose derived names disagree, no `CLAUDE.md`, no declaration in
it, or a declaration failing any check above: stop, say exactly what was
missing, and review nothing. Running two reviewers out of three, promoting the
general reviewer into a repo reviewer's slot, or guessing a value produces a
weaker review that looks like a complete one.

**Ask every child for a verification envelope.** The frozen text has each
reviewer prepend two verification lines. In the prompt you construct, ask for
them as **raw text first**, ahead of any report heading or template the skill
it loads asks for. This is the preferred, stable shape:

```text
Reviewed range: <full base SHA>..<full target SHA>
Skill: /exact-skill-name
```

An incomplete child leads with `INCOMPLETE — <reason>` and then the same two
lines. A repo reviewer that used its allowed file fallback appends
`; read from: <exact derived path>` to its `Skill:` line. The central general
reviewer has no file fallback, so its `Skill:` line never carries that suffix.

**Accept on the evidence, not the formatting.** A child is not invalid for
adding a heading or preamble, putting the values in a list or table, or
wrapping them in backticks or bold. Reviewers load skills with report templates
of their own, and rejecting a review whose attestations are exact would cost a
whole trio for a cosmetic difference. Read the child's raw final text and
require:

1. At least one explicit **`Reviewed range` attestation** carrying the exact
   expected full 40-character base SHA, a literal `..`, and the exact expected
   full 40-character target SHA, in that order.
2. At least one explicit **`Skill` attestation** carrying the exact assigned
   `/skill-name`.
3. Repeating the **same** attestation is harmless. Any explicit **conflicting**
   range or skill attestation invalidates that child.
4. Decoration around the values is cosmetic and accepted, as is text or a
   heading before them — but decoration must not change the parsed values.
5. Validate the **raw child report**. Your own summary or rewrite of a child is
   never that child's evidence.
6. A failed or empty child, or one whose status is `INCOMPLETE — <reason>`,
   stays incomplete wherever the formatting puts it. Never normalize
   incompleteness into a completed review.
7. Fallback stays strict, and this is a claim about the **fallback**, not about
   paths in general: for a direct Skill-tool load the `Skill` attestation
   carries no `read from` suffix and the report makes no fallback-path claim,
   while ordinary source and evidence paths elsewhere in the review are
   unaffected. A repo reviewer that fell back must attest the one exact
   mechanically derived path, and any different or additional fallback path is
   invalid. The central general reviewer has no file fallback under any
   formatting.

A short SHA, a wrong or reversed endpoint, a wrong or missing skill, a missing
attestation, an unauthorized fallback path, or a value you could only infer
from prose is invalid — tolerance is about decoration, never about supplying,
guessing or repairing a value. Any invalid child invalidates the **entire
trio** under the all-or-none rule above; never accept or rerun one child alone.

Accepted, because the attestations are exact:

```text
## Review
Reviewed range: `<full base>..<full target>`
Skill: `/repo-skill`
```

Rejected: a missing, shortened, wrong-endpoint or conflicting range; a missing,
wrong or conflicting skill; a fallback path that is not the derived one, or any
fallback claim from the general reviewer; and a failed, empty or `INCOMPLETE`
child.

This shape is written down because coordinated smokes found children decorating
the values with backticks, repo skill templates emitting their own headings
first, and other children opening with a preamble. Every one of those carried
exact full attestations, so the evidence was there and only the rendering
varied.

**On entry to Post-PR review, load the declared extension.** Read the declaration's `post-PR extension` value:

- **A skill name** — load exactly that skill with the Skill tool, and use it
  only to refine and carry out canonical steps 1 through 6 for this repo's PR
  surface: which bots review there, how its threads, labels and gate behave.
  It never replaces or restates the lifecycle, never relaxes step 7, never runs
  a local reviewer, and never merges. Where it and this skill disagree, this
  skill wins.
- **`none`** — run steps 1 through 7 as written, and load nothing extra.
- **A named skill that will not load** — stop and tell the developer the
  extension is unavailable. Do not improvise a replacement, search for a
  similarly named skill, or silently continue without it.

**The wall around Pre-PR review.** Everything in **Pre-PR review** is author-side work on a local checkout, and
what it produces is local author-side evidence — a report to the developer, and
nothing else.

Its **code and change evidence is pinned**: the `git diff` range the parent
resolved, and the repository's own files read at those two revisions. A moving
working tree is not evidence about a commit. Reviewers may inspect GitHub
**read-only** where the skill they loaded calls for that context — a linked
issue, an upstream API, a referenced PR — and ordinary fetches are fine. What
Pre-PR review never does is **write** GitHub state: no comment, review, check,
status, label or approval, and no input to a gate, conductor or escalation.
Reviewers report; the parent session makes every edit and every commit.

**Post-PR review is different, and deliberately so**: it works the PR's review
threads, so it does post comments and resolve threads through the configured
GitHub workflow. That is the one phase permitted to write there, and it starts
only once the PR exists. The lifecycle moves to it and does not come back.

**Neither phase merges.** A merge happens only after a separate, explicit human
instruction.

**Which skill owns a repo's PR iteration.** `/lfx-skills:lfx-pr-resolve` is the
general-purpose PR-thread resolver, and it stays that for every repo that has
not adopted this lifecycle. The boundary is the declaration, and it is decided
per checkout, with no central list:

- **Exactly one valid declaration** — this skill is the sole owner of the
  lifecycle. PR iteration runs **Post-PR review** below, together with the
  declared extension if the repo names one, and not `lfx-pr-resolve`.
- **No `## Review lifecycle configuration` section at all** — the repo is not an
  adopter. Nothing here governs it, and `/lfx-skills:lfx-pr-resolve` is the
  right skill for its PR threads.
- **A declaration that is malformed, duplicated or otherwise ambiguous** — fail
  closed, as everywhere else. Say what was wrong and stop. A broken adoption is
  not an absent one, so it must never fall through to `lfx-pr-resolve`: that
  would answer a configuration error by silently running a different workflow.

**Neither phase merges** applies to both routes.

For the declaration schema in full, how a repo adopts this lifecycle, and how
the two repo-owned reviewer skills are written, see
[`references/ownership-and-adoption.md`](references/ownership-and-adoption.md).

<!-- The two sections below are reproduced byte for byte from the approved
     lifecycle text and must not be re-wrapped, so their long lines cannot be
     brought under the line-length limit. This directive sits above the frozen
     region and is not part of it. -->
<!-- markdownlint-disable MD013 -->

## Pre-PR review

Before a PR exists, local review uses the same three reviewers in two modes: **post-commit review** while development continues, and one **full-branch review** immediately before opening the PR.

Every review batch launches exactly THREE generic background subagents together, all with `subagent_type: general-purpose`, `model: opus` (Opus 5), and `run_in_background: true`. At most one batch may be active. The reviewers load exactly one skill each:

1. `/lfx-skills:lfx-general-code-review`
2. `{{CODE_SKILL}}`
3. `{{LEARNINGS_SKILL}}`

The reviewers only report findings. They never edit tracked files, stage, commit, push, or write GitHub state; the parent performs all changes.

### Shared reviewer prompt

Give each reviewer one complete prompt. Start with its loading policy, then append the common instructions.

- General: `Load /lfx-skills:lfx-general-code-review with the Skill tool. If that skill is unavailable, do not review unguided and do not read a replacement SKILL.md from any checkout or cache; return INCOMPLETE.`
- Repo code: `Load {{CODE_SKILL}} with the Skill tool. If and only if that skill is unavailable in this child's current session, locate the {{REPO}} repo root and read <repo-root>/{{CODE_PATH}}. Before following that file, read its YAML frontmatter and require its name field to equal {{CODE_SKILL}} with the leading / removed; if the frontmatter is missing, unparseable, or names anything else, return INCOMPLETE and do not follow it. Otherwise follow that file as the sole review guidance. Do not search another path or use another skill or agent. If the file is missing, return INCOMPLETE.`
- Repo learnings: `Load {{LEARNINGS_SKILL}} with the Skill tool. If and only if that skill is unavailable in this child's current session, locate the {{REPO}} repo root and read <repo-root>/{{LEARNINGS_PATH}}. Before following that file, read its YAML frontmatter and require its name field to equal {{LEARNINGS_SKILL}} with the leading / removed; if the frontmatter is missing, unparseable, or names anything else, return INCOMPLETE and do not follow it. Otherwise follow that file as the sole review guidance. Do not search another path or use another skill or agent. If the file is missing, return INCOMPLETE.`

```text
target repo: {{REPO}}
repo root: <absolute repo root>
target_sha: <full target SHA>
base_sha: <full base SHA>
review exactly: git diff <full base SHA> <full target SHA>
range label: <mode-specific range label>

The repo root and SHA range above are authoritative. Do not re-derive the range from HEAD or origin/main. If the assigned skill tells you to derive the review range or changed-file list from HEAD, git show, or origin/main, replace that instruction with the exact pinned git diff above. Read added or modified code from <target_sha>:<path>, deleted code from <base_sha>:<path>, and both revisions for a rename. Never use a moving working-tree copy as code evidence. Load current rule, contract, checklist, architecture, and knowledge-base policy as the assigned skill directs.

Report findings only. Follow the assigned skill's report conventions and return its complete findings. Prepend `Reviewed range: <full base SHA>..<full target SHA>`, then `Skill: /lfx-skills:lfx-general-code-review`, `Skill: {{CODE_SKILL}}`, or `Skill: {{LEARNINGS_SKILL}}`, matching that reviewer. If a repo reviewer used its allowed file fallback, append `; read from: <exact path>` to its Skill line. If incomplete, put `INCOMPLETE — <reason>` first, then the same two verification lines.
```

Accept a batch only when all three reviewers return non-empty, complete reports for the pinned full-SHA range, name their exact assigned `/...` skill, and report no unauthorized fallback path. If any reviewer fails these checks, reject the entire batch; never accept or rerun only one reviewer.

### Mode 1 — Post-commit review

Use this mode after normal development commits while work continues.

1. Commit with `git commit -s -S`.
2. Maintain `reviewed_through_sha`: the latest commit fully covered by an accepted post-commit batch. Before the first batch, initialize it to the parent of the first pending commit. Never advance it for a failed or incomplete batch.
3. When no batch is active, set `base_sha=$reviewed_through_sha` and `target_sha=$(git rev-parse HEAD)`. Label a one-commit range `the latest commit`; if commits accumulated, label it `the commits since the last review`.
4. Launch the three reviewers together with that exact range. If another batch is already active, let it finish; the next batch will cover everything from the unchanged `reviewed_through_sha` through the then-current `HEAD`.
5. While remaining in Mode 1, if the batch is invalid and `HEAD` is unchanged, rerun all three with the same pins. If `HEAD` changed, rerun all three over the coalesced range from the unchanged `reviewed_through_sha` through current `HEAD`. Once work moves to Mode 2, do not rerun an invalid post-commit batch; Mode 2's whole-branch review replaces its coverage.
6. After a valid batch, advance `reviewed_through_sha` to its `target_sha`. Verify its findings against current code and address every Critical and reasonable Important finding in a later commit; that commit is reviewed by the next post-commit batch.
7. The final planned commit skips post-commit review and moves directly to Mode 2. Leave `reviewed_through_sha` unchanged. If development resumes before Mode 2 starts, the next post-commit batch covers the entire pending range from that unchanged SHA.

### Mode 2 — Full-branch review before opening the PR

Entering this mode ends post-commit review for this PR attempt. Finish any active post-commit batch and retain every finding that Mode 1 requires the parent to address. Do not retry an invalid post-commit batch; the whole-branch review below replaces its coverage. Do not return to Mode 1.

1. Run `git fetch origin`, set `target_sha=$(git rev-parse HEAD)` and `base_sha=$(git merge-base origin/main HEAD)`, and launch the three reviewers together once against the whole branch range. Use the shared prompt with the range label `the branch's diff against origin/main` and review `git diff <full base SHA> <full target SHA>`. Never use `reviewed_through_sha` for this review.
2. If the batch is operationally incomplete, or invalid under the shared acceptance checks, it does not count as the review. Without editing files or creating commits, repeat step 1 so the unchanged branch is fetched, re-pinned, and reviewed again, until one valid and complete three-reviewer batch returns. Rerun the whole batch, never one reviewer alone, and never rerun a valid batch merely because it reported findings.
3. Fix the retained post-commit findings and the issues raised by the whole-branch review, then complete the repository's documentation-currency updates. Commit all resulting changes with `git commit -s -S`, then run `{{READINESS}}` and `{{PREFLIGHT}}` against the clean, committed `HEAD`. If either check requires fixes, apply the remedy appropriate to the finding—rewrite local commits for existing-history defects or create a new signed/DCO commit for file changes—then rerun the affected deterministic checks. Ensure every resulting commit is signed and carries DCO sign-off. Do not run the local reviewers again.
4. Push and open the PR. From that point onward, use Post-PR review only.

## Post-PR review

Once the PR exists, never run the local post-commit reviewers or another local full-branch review. PR iteration uses Copilot and every other configured GitHub code-review agent/bot.

1. After every push, wait for the configured GitHub reviewers to finish reviewing the current head, then enumerate every unresolved review thread. Collect compatible feedback into a batch rather than making one-comment-at-a-time commits.
2. Work in an isolated background task when safe so the developer can continue. Never allow two writers to edit the same worktree or race commits or pushes; otherwise handle the feedback synchronously.
3. Verify every finding against the current head, actual runtime/API contracts, repository guidance, and approved PR scope. Never assume a bot is correct and never silently ignore a finding.
4. For a genuine in-scope issue, make the smallest focused fix and validate it. Otherwise, tell the developer why and post an evidence-backed rebuttal. Escalate architecture, security, ownership, and excluded-surface questions instead of guessing.
5. Comment before resolving every thread. For a fix, cite the fix commit and validation evidence; for a rebuttal, give the reason and evidence. Every thread must end fixed-and-explained or rebutted-and-explained.
6. Group compatible fixes into one signed/DCO commit, push, wait for reviews on the new head, and repeat until no unresolved actionable threads remain and required checks are green.
7. Do not merge as part of this automated iteration. Merge only after a separate explicit human instruction.
