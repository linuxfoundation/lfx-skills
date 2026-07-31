---
name: lfx-local-review
description: Run the local pre-PR review trio on the current repo — the general reviewer plus the repo's own code and learnings reviewers — on headless Pi when it is available, or Claude subagents otherwise, and return their ordinary Markdown reports. Use after a commit, or with `branch` for the pre-PR full-branch sweep, in a repo that owns local review skills. Author-side only; reviewers may read GitHub but never write PR, gate or merge state.
---
<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Local pre-PR review

You are the **host**. You pick the harness, run three reviewers, and show the
developer what they wrote. You do not judge, summarise away, or rewrite a
review.

## The wall

This is a local author workflow, run from a working copy after a commit and
before a PR exists.

- Never create or update a GitHub label, status, check, review, approval or
  comment. Never feed a conductor, gate or escalation. Never merge.
- Never touch `.github/**`, Copilot instructions, PR skills or workflows.
- Reviewer children never edit tracked source or config, commit or push.
  **You** — the main session — fix what they find.
- No report file, no background supervisor, no retained results. The run lives
  and dies with this session.

## Running it

The launcher lives beside this file. Resolve it from **this skill's own
directory**, not from the repo you are standing in — you are normally invoked
from a service repo, where a path like `skills/lfx-local-review/...` does not
exist:

```bash
<dir of this SKILL.md>/scripts/run-pi.sh --repo <path> [--mode branch] [--extra "<hint>"]
```

Use the absolute path you get from that. The same rule applies to the general
skill you hand a Claude subagent: `<dir of this SKILL.md>/../lfx-general-code-review/SKILL.md`,
resolved to an absolute path before you pass it on. The Pi launcher already
resolves both this way; the fallback must match it.

Pass `--repo` when you are not standing in the repo under review. The launcher
resolves the repo from a path only — it never searches for one by name, because
guessing wrong means reviewing the wrong repository.

It pins `target_sha`, and `base_sha` (the first parent post-commit, or the
merge-base with `origin/main` in branch mode), before launching anything, and
gives every reviewer the same values. Branch mode fetches `origin` exactly once
first, so the base is current; that means branch mode needs network, while
post-commit mode does not.

## Reading what comes back

The launcher prints three reports under `===== <role> =====` headings in a
fixed order: `general`, `repo_code`, `repo_learnings`. Relay them to the
developer as they are.

Two different things can go wrong, and they must not be blurred:

- **A reviewer says its own review is incomplete.** Its Markdown begins
  `INCOMPLETE — <reason>`. That is the reviewer's own statement about its own
  work. Pass it through untouched; never rewrite or summarise it away.
- **A reviewer process failed.** Nonzero exit, a signal, or exit 0 with no
  output. The launcher exits nonzero and reports the failure in **both**
  streams: under that role's heading on stdout, so a redirected report is never
  silently missing a reviewer, and on stderr with the child's captured stderr.
  A failed child's own partial output is discarded rather than shown.
  **Never render that as "no findings"** — a reviewer that produced nothing has
  reviewed nothing. Never invent an `INCOMPLETE` line on a reviewer's behalf;
  only a reviewer that actually produced output may say that.

Either way the cycle is incomplete: fix nothing on that basis, and rerun the
whole trio on the same harness.

## When Pi is not available

If the launcher prints `PI_NOT_INSTALLED`, `PI_UNAUTHENTICATED` or
`PI_MODEL_UNAVAILABLE` instead of reviews, **it has not failed** — it has
chosen the other harness. Launch the fallback yourself: three Claude subagents,
in one parallel batch.

Show the developer the onboarding message the launcher printed, and say plainly
that this was a same-model review. A Claude session reviewing Claude's work is
not the cross-model check Pi provides, and it must never be presented as one.

Launch all three with `run_in_background: true`:

| Role | Subagent | Skill it must load |
|---|---|---|
| `general` | generic | `<dir of this SKILL.md>/../lfx-general-code-review/SKILL.md` |
| `repo_code` | generic | `<repo>/.claude/skills/local-code-review/SKILL.md` |
| `repo_learnings` | generic | `<repo>/.claude/skills/local-learnings-review/SKILL.md` |

**Use the pinned values the launcher already printed.** That same non-ready
response carries `repo=`, `mode=`, `target_sha=`, `base_sha=` and
`origin_main_sha=`. Do **not** run the launcher again to fetch them: in branch
mode a second call fetches and pins a second time, and the Claude trio would
then be reviewing something other than what the harness decision was made
about. One decision, one fetch, one set of pins, three subagents.

Give every subagent those exact values, as the Pi children receive them. The
launcher writes pins as `key=value` and prompts carry `key: value`, so
`base_sha=none` in the decision becomes `base_sha: none` in the prompt — it
stays the word `none`, never an empty field. A root commit has no base and an
empty pre-change floor, and `origin_main_sha=none` in post-commit mode means
the same thing: not applicable, not missing.

Each prompt must name its one skill file and say it is the whole rulebook. It
must also forbid **ambient** instruction discovery — do not go looking for an
`AGENTS.md`, `CLAUDE.md`, project skill or prompt template and adopt it as
rules. That prohibition is about unbidden discovery, not about evidence: the
selected skill itself directs the reviewer to read the target repo's
conventions and docs in order to judge the change, and those reads are the
review's evidence and remain in scope. Forbid picking up instructions nobody
selected; do not forbid reading the repo.

**Never mix harnesses.** The choice is made once, before any reviewer starts.
If a Pi child fails mid-run, do not relaunch that role on Claude — a trio split
across two models is not a review of anything. Rerun the whole trio.

Claude subagents fail the same way Pi children do, and are reported the same
way. If a subagent errors, returns nothing, or returns Markdown that is not a
review, that is a **role-labelled host failure of the all-Claude cycle** — say
`GENERAL REVIEW FAILED — <what happened>` and which harness it was. Never
render it as "no findings", and never write an `INCOMPLETE` line on the
subagent's behalf. A subagent that *does* return `INCOMPLETE — <reason>` as its
first line has spoken for itself: pass it through untouched. Either way the
cycle is incomplete — rerun all three on Claude, not the failed one alone.

## After the review

Fix findings in this session, then commit the fixes as their own conventional
commits — `fix(<scope>): ...` — rather than amending. Rerun the whole trio
afterwards. Before opening a PR, run the branch sweep (`--mode branch`) and the
repo's own readiness and preflight checks.

The existing `lfx-skills:lfx-*-code-reviewer` and `lfx-*-learnings-reviewer`
named agents are unchanged and remain the right tool for repos that do not own
local review skills.

## Reference

- [`references/pi-setup.md`](references/pi-setup.md) — installing and
  authenticating Pi, and choosing the model.
- [`references/repo-brains.md`](references/repo-brains.md) — how a repo authors
  its two reviewer skills and where they live.
