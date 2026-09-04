<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# lfx-skills review knowledge base

Empirical, repo-owned record of patterns that human reviewers and review bots
have flagged on `lfx-skills` PRs, distilled into mechanically detectable rules.
The repo-owned `local-learnings-review` brain matches a patch against these
patterns and emits only findings that quote a pattern entry.

This KB is the *empirical* surface. It does not duplicate:

- the central `general` review brain — generic correctness, security, and test
  intuition
- the repo-owned `local-code-review` brain — the written rule surface
  (`.github/skills/lfx-skills-code-review`, `CLAUDE.md`, `README.md`)

## Methodology

Corpus: merged PRs with inline review threads that a developer then fixed by
an observable commit, plus maintainer-blocking comments that produced a code
change. Promotion gate: repo-specific, mechanically detectable, currently
relevant, and not already enforced by CI.

First build: 2026-09-03. Sampled PRs 59, 62, 63, 64, 65, 66, 67, 69, and 71.

## Categories

| File | Patterns | Read when |
| --- | --- | --- |
| `consistency.md` | 2 (both Critical) | always — sibling-surface contradictions can hit any skill, agent, README, or reference change |
| `inventory.md` | 1 (Important) | `README.md`, `CLAUDE.md`, `AGENTS.md`, or a new/removed `skills/<name>/` or `agents/*.md` |
| `privacy.md` | 2 (1 Critical, 1 Important) | any `skills/**`, `agents/**`, `docs/**`, `CLAUDE.md`, or `README.md` that carries an example identity, credential, UUID, phone, or email |
| `distribution.md` | 1 (Important) | `.claude-plugin/**`, `install.sh`, `update.sh`, `uninstall.sh`, or `docs/platform-install.md` |

**Total: 6 patterns** plus `known-false-positives.md` (4 entries).

The `Read when` column mirrors the routing table in
`.claude/skills/local-learnings-review/SKILL.md`. Change both tables together.

## Highest-value patterns

- `consistency/sibling-surfaces-must-not-contradict` — this repo's signature
  miss. A rule restated in a skill, its named agent, and the README drifted
  apart on PRs #63, #65, and #69, and each time the contradiction shipped
  until a reviewer caught it.
- `consistency/skill-and-named-agent-must-stay-aligned` — the same privacy
  wording had to be patched twice on PR #69 because the skill and the named
  agent are separate copies of one rule.
- `privacy/real-org-domain-in-example` — a plausible mailbox on the real
  `linuxfoundation.org` domain in the canonical privacy policy itself, on
  PR #62.

## Maintenance

Add entries as new PRs surface repo-specific, mechanically detectable,
acted-on patterns. Move noise into `known-false-positives.md`. Record a
removal with its evidence rather than deleting silently.

*First built: 2026-09-03 (PRs 59 to 71).*
