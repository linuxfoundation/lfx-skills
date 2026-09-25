<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Pre-PR review block

The review round lives in one place, `/lfx-skills:lfx-pre-pr-review`. A repo
adopts it by pasting this short block into its own `CLAUDE.md`, in the section
that describes the local work cycle. The block states the three steps between
"implementation committed" and "PR open" — the review round, the repo's own
checks, the PR — with the rules that must not be forgotten, and carries the
two values that belong to the repo. Nothing else about the lifecycle is
written in the repo.

Copy it verbatim and fill the two values:

```markdown
## Pre-PR review

> **IMPORTANT — follow this exactly.** When the implementation is complete
> and committed and you are about to open a PR:
>
> 1. **Review once.** Load `/lfx-skills:lfx-pre-pr-review` with the Skill
>    tool and follow it: it tells you how to launch the reviewers. You run
>    **one** review round of the whole branch and land **all accepted
>    findings in exactly one fix commit** (none if there is nothing to fix).
>    Do not work from memory: **load the skill before launching the
>    reviewers**.
> 2. **Preflight.** Run the `Preflight` value below and make it pass. It is
>    deterministic checks, not a review: fix what it reports in its own
>    commit(s), as many as it takes, and rerun it — never the reviewers.
> 3. **Open the PR.** From then on there are **no local reviews of any
>    kind** — iterate only on the PR's bot and human feedback, still running
>    tests and checks.

- KB review skill: `<kb-skill>`
- Preflight: `<preflight>`
```

| Value | Fill with |
| --- | --- |
| `<kb-skill>` | the repo's knowledge-base review skill, exact slash name (for example `/committee-service-learnings-reviewer`), or `none` when the repo has no `docs/reviews/knowledge-base/`; the only value the skill reads |
| `<preflight>` | the repo's deterministic pre-PR checks — an exact command (for example `make check && make test`) or the repo's own check skill invocations, in order; the same checks CI runs. Step 2 of the block runs it; the review skill does not |

## Adopting

1. Paste the block into `CLAUDE.md` where the work cycle is described (and
   into `AGENTS.md` only if that is a separate real file the repo keeps in
   sync). Fill the two values.
2. Remove every other local-review instruction in the repo: earlier lifecycle
   sections, a `## Review lifecycle configuration` declaration, pointers to
   `/lfx-skills:lfx-local-review`, reviewer launches after commits, separate
   final sweeps, and any checklist item about a reviewer trio.
3. Keep the repo's knowledge-base review skill and `docs/reviews/knowledge-base/`;
   they are unchanged by adoption. Retire the repo's conventions-review skill:
   the general skill now reads the repo's written conventions itself, from
   `CLAUDE.md`, `.claude/rules/`, checklists and the docs they name. Before
   deleting it, salvage only what is expertise rather than a restatement of the
   repo's docs or code — known false positives and "never a finding" items go
   into the repo's `docs/reviews/knowledge-base/known-false-positives.md`;
   a genuine convention documented nowhere else goes into the repo's rule
   surface, path-scoped under `.claude/rules/`.
4. Keep the repo's deterministic checks as `<preflight>`; CI should run the
   same commands. Where the repo has its own readiness/preflight check
   skills, the value is their invocations in order; none of them may
   restate the review round or require it to be rerun.

## Why this shape

The review round has one authoritative home, so a fix to it is one change
here, not nine. The block is short enough to sit where developers and their
agents already read, and it states in place the sequence and the two rules
that a pointer alone would let drift out of mind: one batched fix commit for
the round, no local reviews once the PR exists. Preflight is the repo's own
deterministic gate and stays in the repo's hands — the review skill neither
runs it nor folds its remedies into the review fix commit. The two values are
the only facts that belong to the repo.

`/lfx-skills:lfx-local-review` remains for repos that have not yet adopted
this block; it is removed once they all have.
