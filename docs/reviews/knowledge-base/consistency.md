<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Consistency

Empirical patterns where the same rule was stated in more than one shipped
surface and the copies drifted. Internal consistency is this repo's
highest-signal written finding; these entries catch the shapes that actually
recurred across PRs.

**Read when:** always. A skill, named agent, README, or reference file can
contradict a sibling without sharing a path prefix.

---

## `consistency/sibling-surfaces-must-not-contradict` — Critical

**Pattern:** a change restates a rule in one of `skills/`, `agents/`,
`README.md`, or a `references/` file, and a sibling surface that already
states the same rule now says the opposite, or uses a label the sibling
forbids.

**Detect:** for every rule sentence the patch adds or rewords in
`skills/**`, `agents/**`, `README.md`, or `skills/**/references/**`, grep the
other three surfaces for the same claim (the same label, the same
requirement, the same forbidden phrase). Flag a pair where one surface
requires or forbids what the other now contradicts. The worked cases are a
README or setup guide calling the Claude fallback a "same-model" review
while `skills/lfx-local-review/SKILL.md` forbids that label, and a privacy
bullet that treats encryption-at-rest as satisfying retention while
`skills/lfx/references/data-privacy.md` requires TTL or purge independently.

**Empirical citation:** PR #65 `README.md` — Copilot — "This repeats the
same-model classification that the host skill expressly forbids
(`skills/lfx-local-review/SKILL.md:137-139`)." Resolved in `8865748`. Also
PR #69 `skills/lfx-general-code-review/SKILL.md` — Copilot — "This makes
encryption-at-rest an alternative to a retention/lifecycle policy." Resolved
in `b76f1e0`. Also PR #63 `.github/skills/copilot-code-reviewer/SKILL.md` —
Copilot — "This directly contradicts lines 55–64, which reserve comments for
real, material issues." Resolved in `d8aaeb5`.

**Failure message:** sibling surfaces now contradict each other on the same
rule.

**Fix:** rewrite the changed surface to match the authoritative one (the
skill body for a host label, `data-privacy.md` for privacy criteria, the
signal-discipline section for review comments). Patch every copy the grep
hit, in the same change.

---

## `consistency/skill-and-named-agent-must-stay-aligned` — Critical

**Pattern:** a central review skill and its named `agents/lfx-*-reviewer.md`
counterpart state the same criterion, and the patch updates only one of
them.

**Detect:** when the range edits `skills/lfx-general-code-review/SKILL.md`
or `agents/lfx-general-code-reviewer.md` (or any other skill/agent pair that
share a method), diff the two files for the criterion the patch touched.
Flag a privacy, residency, retention, or harness-label sentence that exists
in both files and now differs.

**Empirical citation:** PR #69 `agents/lfx-general-code-reviewer.md` —
Copilot — "This makes encryption-at-rest an alternative to a
retention/lifecycle policy or purge automation." The same finding had to be
raised against the skill *and* the named agent; both were fixed in
`b76f1e0`.

**Failure message:** the named agent and its skill now disagree on a shared
criterion.

**Fix:** apply the same wording to both files in the same change.
