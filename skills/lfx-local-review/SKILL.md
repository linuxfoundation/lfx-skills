---
name: lfx-local-review
description: Run the local pre-PR review trio on the current repo — the general reviewer plus the repo's own code and learnings reviewers — on headless Pi when it is available, or Claude subagents otherwise, and return their ordinary Markdown reports. Use after a commit, in a repo that owns local review skills. Author-side only; reviewers may read GitHub but never write PR, gate or merge state.
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

**Probe, announce, then launch in the background.** Three steps, in this order.
Never launch a review in the foreground: it blocks this session for minutes,
and the developer sees nothing while it happens.

The launcher lives beside this file. Resolve it from **this skill's own
directory**, not from the repo you are standing in — you are normally invoked
from a service repo, and the developer may have no `lfx-skills` checkout at
all. Every path you print must be one the installed plugin actually has.

### 1. Probe

```bash
<skill dir>/scripts/run-pi.sh --readiness --repo <repo>
```

This launches no reviewers. It answers one question — which harness is going to
run — and prints the pins with it: `repo=`, `target_sha=`, `base_sha=`, plus
`provider=`, `model=` and `thinking=` so you can tell the developer what is
about to review their code.

Pass `--repo` when you are not standing in the repo under review. The launcher
resolves a repo from a path only — it never searches by name, because guessing
wrong means reviewing the wrong repository.

### 2a. If it prints `PI_READY` — announce, then launch Pi in the background

Run:

```bash
<skill dir>/scripts/run-pi.sh --repo <repo> --commit <target_sha from the probe>
```

**as a background task**, and tell the developer it is running. Background is
for keeping this session responsive while a review takes minutes. Pi does not
save a session, and the run keeps nothing beyond the reports it prints.

Pass `--commit` with the `target_sha` the probe printed. `HEAD` can move between
the probe and the launch — the developer commits again in another terminal — and
`--commit` turns that into a loud failure instead of a review of something other
than what you announced.

**If the launch prints a harness decision instead of reports.** The launcher
checks readiness again before it starts any child, because a launch can also be
run with no probe before it and starting three children blind is worse. So the
harness can lapse in the gap — a token expires, someone runs `pi logout` in
another terminal — and then this second call prints `PI_NOT_INSTALLED`,
`PI_UNAUTHENTICATED` or `PI_MODEL_UNAVAILABLE` with the pins and the onboarding
message, exits 0, and starts nothing.

That is the harness decision being remade, not a failed review. **No Pi child
ran**, so nothing is mixed and nothing needs rerunning. Tell the developer Pi
went away between the probe and the launch, then follow **2b** using the pins
*this* call printed — they are the current ones, and you do not probe a third
time. Never report the Pi run as finished, and never read a decision block as a
review that found nothing.

### 2b. Otherwise — say Pi would be better, then launch the fallback in the background

`PI_NOT_INSTALLED`, `PI_UNAUTHENTICATED` and `PI_MODEL_UNAVAILABLE` are not
failures. They are the other harness being chosen.

Relay the launcher's onboarding message, which tells the developer how to
install Pi and log in with GitHub Copilot for the cross-model review. Then
launch the three Opus subagents **in the background** as described in **When Pi
is not available**, using the pins the probe already printed. Do not re-run the
probe to get them.

### Getting the review back

Running in the background must never mean the review is lost.

- **Keep the background task handle.** Return control to the developer after
  starting it; do not poll, and do not build a supervisor or a report store.
- **When the harness notifies you the task finished**, retrieve its output and
  relay the three reports in the fixed order — or the host failure, exactly as
  **Reading what comes back** describes.
- **For the Opus fallback**, the same rule for all three subagents: collect
  every one of the three results, then relay or fail as already defined. Two
  results out of three is an incomplete cycle, not a review with a gap.

### Optional arguments

`--base <sha>` widens the range past the first parent; the host never derives a
base itself. `--extra "<hint>"` passes a caller hint through to every reviewer.

**`--base` goes to the probe as well as the launch.** The probe is where the
pins you announce come from, and where the Claude fallback gets its pins — so a
`--base` given only at launch makes you announce the first-parent range while
Pi reviews a wider one, and hands the fallback trio a base the caller never
asked for. Both calls or neither.

**Pass the caller's value to the probe, and the probe's `base_sha` to the
launch.** Not the same token twice: `--base` may be a movable ref, and
`--base main` resolves at each call, so the probe can print one commit and the
launch resolve a different one after a fetch in another terminal. `--commit`
guards only the target. Forwarding the resolved `base_sha` pins both ends of
the range to what you announced, exactly as `--commit` does for the target.

**`--extra` is yours to carry in the fallback arm.** Passing it to the launcher
reaches the Pi children; if the harness decision is Claude, put the same hint in
each subagent's prompt yourself, because no launcher runs to do it for you.

Reviews are pinned to one commit: `target_sha` is `HEAD`, `base_sha` its first
parent, and every reviewer gets the same values and the same explicit
`git diff base target` range. **Resolving that range never fetches and never
consults a remote**, so the pinning works offline. That is a claim about the
range, not about the whole review: reviewers may read GitHub and fetch for
context where it genuinely helps, so do not tell a developer the review itself
runs offline.

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

A launch that prints a harness **decision** instead of reports is neither of
these, and is not a reason to rerun anything — see **2a**: no reviewer started,
so the decision simply stands and the fallback runs.

## When Pi is not available

If the launcher prints `PI_NOT_INSTALLED`, `PI_UNAUTHENTICATED` or
`PI_MODEL_UNAVAILABLE` instead of reviews, **it has not failed** — it has
chosen the other harness. Launch the **Claude Opus fallback** yourself: three
generic subagents in one parallel batch, all three using model `opus`.

Show the developer the onboarding message the launcher printed, and say plainly
that this is not the intended review. Pi with GitHub Copilot GPT-5.6 Sol at
thinking high is the cross-model check; a Claude trio is not, and must never be
presented as one. Do not call it a *same-model* review either — the subagents
are explicitly Opus and the session hosting them may be a different model, so
that claim is not yours to make.

Launch all three with `run_in_background: true`, model `opus` for every one:

| Role | Subagent | Model | Skill to load |
|---|---|---|---|
| `general` | generic | `opus` | the central general reviewer, declared `lfx-general-code-review` |
| `repo_code` | generic | `opus` | the repo's declared code-review skill name |
| `repo_learnings` | generic | `opus` | the repo's declared learnings-review skill name |

One model for the whole batch. A trio split across models is not a trio.

**Name each skill the way this session lists it.** The two repo brains are
project skills and are registered under exactly their declared names. The
general reviewer arrives through a **plugin**, and a session surfaces plugin
skills namespaced — `lfx-skills:lfx-general-code-review` rather than the bare
`lfx-general-code-review`. Read the name off your own skill list instead of
assuming a form; an unregistered name fails that role loudly, which is the
right outcome but a wasted cycle.

Nothing in the Pi arm tells you whether you got this right. Pi is handed the
general skill by absolute path and never uses a name at all, so a Pi run that
worked perfectly is no evidence at all about the fallback's naming. The two
arms have to be judged separately.

**Prefer the repo's own fallback orchestrator when it has one.** If
`<repo>/.claude/skills/local-review-fallback/SKILL.md` exists, load and follow
it: it names the three skills for its own repo. Fall back to the table above
only when the repo has no such skill.

**Use the pinned values the launcher already printed.** That same non-ready
response carries `repo=`, `target_sha=` and `base_sha=`. Do **not** run the
launcher again to get them: `HEAD` can move between two calls, and the Claude
trio would then review something other than what the harness decision was made
about. One decision, one set of pins, three subagents.

Give every subagent those exact values, as the Pi children receive them,
including the explicit `git diff <base> <target>` range. The launcher writes
pins as `key=value` and prompts carry `key: value`, so `base_sha=none` becomes
`base_sha: none` in the prompt — it stays the word `none`, never an empty
field. A root commit has no base, and its range is the tree the root
introduced.

Tell each subagent: load the named skill and follow it exactly; review only the
supplied range; return an ordinary Markdown review.

This works because the developer runs Claude from the service repo with the
central plugin loaded, so all three skills are registered in that session. If a
named skill is unavailable, that role fails loudly and the whole Claude cycle is
invalid — the remedy is to start Claude from the repo with the right plugin and
project skills registered.

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
afterwards, and run the repo's own readiness and preflight checks before opening
a PR.

The existing `lfx-skills:lfx-*-code-reviewer` and `lfx-*-learnings-reviewer`
named agents are unchanged and remain the right tool for repos that do not own
local review skills.

## Reference

- [`references/pi-setup.md`](references/pi-setup.md) — installing and
  authenticating Pi, and choosing the model.
- [`references/repo-brains.md`](references/repo-brains.md) — how a repo authors
  its two reviewer skills and where they live.
