<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Pre-PR review block

The lifecycle lives in one place, `/lfx-skills:lfx-pre-pr-review`. A repo
adopts it by pasting this short block into its own `CLAUDE.md`, in the section
that describes the local work cycle. The block points at the skill, repeats the
two rules that must not be forgotten, and carries the two values the skill
reads from the repo. Nothing else about the lifecycle is written in the repo.

Copy it verbatim and fill the two values:

```markdown
## Pre-PR review

> **IMPORTANT — follow this exactly.** When the implementation is complete
> and committed and you are about to open a PR, load
> `/lfx-skills:lfx-pre-pr-review` with the Skill tool and follow it. It runs
> **one** review round of the whole branch — general, security and
> knowledge-base reviewers in parallel — once, right before the PR. Two rules
> bear repeating here: **all accepted findings from that round land in
> exactly one fix commit** (none if there is nothing to fix); and **once the
> PR is open there are no local reviews of any kind** — iterate only on the
> PR's bot and human feedback, still running tests and checks. Do not work
> from memory: **reload the skill before each step** of the round — before
> launching the reviewers, before the fix commit, before opening the PR.

- KB review skill: `<kb-skill>`
- Preflight: `<preflight>`
```

| Value | Fill with |
| --- | --- |
| `<kb-skill>` | the repo's knowledge-base review skill, exact slash name (for example `/committee-service-learnings-reviewer`), or `none` when the repo has no `docs/reviews/knowledge-base/` |
| `<preflight>` | the repo's deterministic, non-fixing pre-PR check — an exact command (for example `make check && make test`) or skill invocation; the same checks CI runs |

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
   same commands.

## Why this shape

The procedure has one authoritative home, so a fix to the lifecycle is one
change here, not nine. The block is short enough to sit where developers and
their agents already read, and it states in place the two rules that a
pointer alone would let drift out of mind. The two values are the only facts
that belong to the repo.

`/lfx-skills:lfx-local-review` remains for repos that have not yet adopted
this block; it is removed once they all have.
