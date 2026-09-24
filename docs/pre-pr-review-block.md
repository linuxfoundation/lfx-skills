<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->
<!-- Tool names in this file use Claude Code vocabulary. See docs/tool-mapping.md for other platforms. -->

# Pre-PR review block

The canonical local review lifecycle for LFX repos, as a block a repo pastes
into its own `CLAUDE.md`. Copy it verbatim, fill the placeholders, and delete
every other local-review instruction in the repo so that one block is the only
account of the lifecycle there.

This is a template to copy, not a skill to load. The review *method* is
centralised in `/lfx-skills:lfx-general-code-review`; the *lifecycle* is short
enough to live where developers and their agents already look.

Two variants: use **with knowledge base** when the repo has its own KB-review
skill (a skill that matches the change against `docs/reviews/knowledge-base/`
or equivalent); otherwise use **without knowledge base**.

Placeholders:

| Placeholder | Fill with |
| --- | --- |
| `<kb-skill>` | the repo's KB-review skill, exact slash name (for example `/my-service-learnings-reviewer`) |
| `<preflight>` | the repo's deterministic pre-PR check(s), exact command or skill invocation, non-fixing (for example `make check && make test`) |
| `<base>` | the branch the PR will target, normally `origin/main` |

## With knowledge base

```markdown
## Pre-PR review

Run **one** local review of the whole branch before opening the PR — never
after individual commits, and never again once the PR exists.

1. When the implementation is complete and committed, run `git fetch origin`
   and pin the range: `base_sha=$(git merge-base <base> HEAD)`,
   `target_sha=$(git rev-parse HEAD)`.
2. Launch **two** independent background subagents **in parallel**, one per
   skill, each with `subagent_type: general-purpose`, `model: opus` (Opus 5.5),
   `run_in_background: true`. Tell each to load exactly one skill with the
   Skill tool and follow it: one loads `/lfx-skills:lfx-general-code-review`
   (general quality plus this repo's written conventions, style and rules);
   the other loads `<kb-skill>` (this repo's review knowledge base). Give each
   the full 40-character `base_sha` and `target_sha`, the instruction to review
   exactly `git diff <base_sha> <target_sha>`, and the report-only rule: they
   never edit, commit, push or write GitHub state.
3. Wait for both reports. A failed, empty or `INCOMPLETE` report is **not** a
   clean review: fix the cause and relaunch that reviewer once; if it fails
   again, stop and tell the developer.
4. Verify every finding against the code. Address every Critical and every
   reasonable Important finding in **EXACTLY ONE fix commit** (signed and
   DCO-signed-off). No fix commit if there is nothing to fix. Never one commit
   per finding.
5. Run `<preflight>`. If it fails, fix in a further commit and rerun the
   checks — but **do not rerun the reviewers**.
6. Open the PR.

**Hard rules.** No local review runs after any individual commit. The
reviewers are **never** rerun on the fix commit. From the moment the PR is
open, **no local reviews of any kind**: iterate only on the PR's bot and human
review feedback, still running tests and checks, and batch each round of fixes
into as few commits as possible.
```

## Without knowledge base

```markdown
## Pre-PR review

Run **one** local review of the whole branch before opening the PR — never
after individual commits, and never again once the PR exists.

1. When the implementation is complete and committed, run `git fetch origin`
   and pin the range: `base_sha=$(git merge-base <base> HEAD)`,
   `target_sha=$(git rev-parse HEAD)`.
2. Launch **one** independent background subagent with
   `subagent_type: general-purpose`, `model: opus` (Opus 5.5),
   `run_in_background: true`. Tell it to load `/lfx-skills:lfx-general-code-review`
   with the Skill tool and follow it (general quality plus this repo's written
   conventions, style and rules). Give it the full 40-character `base_sha` and
   `target_sha`, the instruction to review exactly
   `git diff <base_sha> <target_sha>`, and the report-only rule: it never
   edits, commits, pushes or writes GitHub state.
3. Wait for the report. A failed, empty or `INCOMPLETE` report is **not** a
   clean review: fix the cause and relaunch once; if it fails again, stop and
   tell the developer.
4. Verify every finding against the code. Address every Critical and every
   reasonable Important finding in **EXACTLY ONE fix commit** (signed and
   DCO-signed-off). No fix commit if there is nothing to fix. Never one commit
   per finding.
5. Run `<preflight>`. If it fails, fix in a further commit and rerun the
   checks — but **do not rerun the reviewer**.
6. Open the PR.

**Hard rules.** No local review runs after any individual commit. The
reviewer is **never** rerun on the fix commit. From the moment the PR is open,
**no local reviews of any kind**: iterate only on the PR's bot and human
review feedback, still running tests and checks, and batch each round of fixes
into as few commits as possible.
```

## Why one round

The earlier lifecycle reviewed after every commit and again before the PR.
That produced long chains of review-fix commits, slow cycles, and a workflow
that was hard to follow, while the extra rounds did not catch more. One
full-branch round with a strong model, one fix commit, deterministic checks,
then PR-side review is faster, produces a cleaner history, and is easy to
explain. The PR's own reviewers see the final branch either way.

## Adopting

1. Paste the applicable variant into `CLAUDE.md` (and `AGENTS.md` if the repo
   keeps both as real files), filling the placeholders.
2. Remove every other local-review instruction in the repo: any earlier
   lifecycle section, any `## Review lifecycle configuration` declaration, any
   pointer to `/lfx-skills:lfx-local-review`, any reviewer launch after
   commits, any separate final sweep.
3. Keep the repo's own KB-review skill and knowledge base; they are unchanged
   by adoption. Repo conventions stay in the repo's `CLAUDE.md`, rules,
   checklists and docs — the general skill reads them there.
4. Keep the repo's deterministic checks as `<preflight>`; CI should run the
   same commands.

`/lfx-skills:lfx-local-review` remains available for repos that have not yet
adopted this block; it is being phased out once they have.
