<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Repo reviewer skills

Local review runs three reviewers. Central owns one of them; **the repo owns
the other two**, because they encode things only that repo knows.

| Role | Owner | What it knows |
|---|---|---|
| `general` | central | language-agnostic correctness, security, testing, performance |
| `repo_code` | the repo | its own written conventions, contracts and architecture |
| `repo_learnings` | the repo | patterns extracted from its own past PR review comments |

That split is the point. A repo's conventions live with the code they govern
and change with it; central would only hold a stale copy.

## Where they live

```text
<repo>/.claude/skills/local-code-review/SKILL.md
<repo>/.claude/skills/local-learnings-review/SKILL.md
```

Override per run when a repo keeps them elsewhere:

```bash
LFX_LOCAL_REVIEW_CODE_SKILL=path/to/code/SKILL.md \
LFX_LOCAL_REVIEW_LEARNINGS_SKILL=path/to/learnings/SKILL.md \
  skills/lfx-local-review/scripts/run-pi.sh --repo <path>
```

Paths are relative to the repo root. A missing skill is a plain failure before
any reviewer starts: a repo without them is not set up for local review, and
running two reviewers out of three would quietly produce a weaker review that
looks like a complete one.

## What the launcher gives your skill

Every reviewer receives the same pinned values:

- `target repo` — an absolute path
- `mode` — `post-commit` or `branch`
- `target_sha` — the commit under review
- `base_sha` — the first parent (post-commit) or the merge-base with
  `origin/main` (branch). **A root commit has none**, which is normal.
- `origin_main_sha` — branch mode only
- `extra` — an optional caller hint

Use those values. Do not re-derive them from `HEAD`: three reviewers reading a
moving `HEAD` can disagree about what they reviewed.

Read evidence at the pinned revision — `git show <target_sha>:<path>`,
`git grep <pattern> <target_sha>`, `git ls-tree <target_sha>` — so what you
quote is what you reviewed.

## The false-positive floor is read at `base_sha`

If your learnings skill applies a floor from
`docs/reviews/knowledge-base/known-false-positives.md`, **read it from
`base_sha`, never from `target_sha`.**

This is not a detail. Reading it at the target would let a patch that adds a
waiver suppress a finding *about that same patch* — the reviewed change
approving itself. Reading at base also means a waiver deleted in the range
still applies, which is the correct pre-change state.

Distinguish "absent" from "unreadable", and do not treat one `git show` failure
as absence:

1. `git ls-tree <base_sha> -- docs/reviews/knowledge-base/known-false-positives.md`
   - exit 0, empty output → the floor is legitimately absent. An empty floor is
     valid, including at a root commit and at the file's first introduction.
   - exit 0, entry is not a regular `blob` → `INCOMPLETE — <reason>`
   - nonzero → `INCOMPLETE — <reason>` (the host validated the base before
     launch, so a failure here is a genuine read problem)
2. Read the blob. Unreadable → `INCOMPLETE — <reason>`. Empty content → a valid
   empty floor. Otherwise apply it.

**Never fall forward to the target floor** after any base-floor problem.

Ordinary knowledge-base pattern files are read at `target_sha` as usual — only
the floor comes from base.

## Writing the skills

Each is one physical `SKILL.md` with frontmatter and prose. Both harnesses load
the same file, so write nothing that assumes a particular one.

**Do not state capability facts.** Reviewers run with ordinary local-user
capability in both harnesses — shell, git, builds and tests, read-only GitHub
inspection. Do not write "you have read-only tools" or "you have no shell":
they are false, and a reviewer that catches its instructions being wrong about
its own situation has reason to doubt the rest. State *obligations* instead:

> Do not edit tracked source or config, run auto-fix formatters or generators,
> commit, reset, or push. Report what you find; the developer's session fixes
> it. Ordinary non-fixing builds, tests and linters are fine even when they
> leave caches or binaries behind. Never post to GitHub or touch a PR, gate or
> merge.

Both roles should also observe the shared bar: confidence floor 80, severities
limited to critical / important, no nits, and evidence with a repo-relative
path, real line numbers and a verbatim excerpt.

Return ordinary Markdown. If you cannot complete the review — required evidence
missing or unreadable — make the **first line** exactly
`INCOMPLETE — <reason>`. That line is yours alone; the host never writes it for
you, and a process that crashes or prints nothing is reported separately as a
host failure.

## Checklist for a repo adopting local review

- [ ] `.claude/skills/local-code-review/SKILL.md`, citing the repo's own rules
- [ ] `.claude/skills/local-learnings-review/SKILL.md`, citing
      `docs/reviews/knowledge-base/`
- [ ] The floor is read at `base_sha`, with the two-step absent/unreadable
      distinction above
- [ ] Obligations, not capability claims
- [ ] Ordinary Markdown out; `INCOMPLETE — <reason>` as a first line when
      required evidence is missing
- [ ] The repo's `CLAUDE.md` invokes the review from inside the repo, or passes
      a resolved `--repo <path>` — never a bare repo name for the launcher to
      look up
