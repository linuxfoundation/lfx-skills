#!/usr/bin/env bash
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
#
# A small deterministic guard for the central review lifecycle.
#
# It checks the few things a reader of the diff cannot check by eye, in five
# groups, and deliberately nothing else. In particular it does NOT re-assert
# the frozen lifecycle's individual properties — Opus 5, all-or-none, the merge
# boundary, the Pre-PR/Post-PR split — because the raw hash in group 1 already
# proves every byte of them. Nor does it assert the prose that explains a rule;
# only the rule.
#
# What it cannot check: the adopting repos' declarations. Those live in those
# repos, and each repo's own PR validates its declaration and its direct skill
# loading. Runtime proof comes from coordinated fresh-session smokes.
#
#   ./.github/scripts/check-review-lifecycle.sh
#   ./.github/scripts/check-review-lifecycle.sh --show-canonical
#       print the exact bytes CANONICAL_SHA256 is taken over

set -uo pipefail

cd "$(dirname "$0")/../.." || exit 2

SKILL=skills/lfx-local-review/SKILL.md
OWNERSHIP=skills/lfx-local-review/references/ownership-and-adoption.md
GENERAL=skills/lfx-general-code-review/SKILL.md
WORKFLOW=.github/workflows/review-lifecycle-check.yml

# sha256 of the RAW bytes of the lifecycle sections of $SKILL — "## Pre-PR
# review" to EOF, less the file's single terminating newline, so the constant
# is the approved source's own hash rather than one derived from it.
#
# A byte hash on purpose: a re-wrap is a real change to a frozen text. It can
# split a token, move a break inside a fenced block, or alter Markdown
# structure, and a whitespace-normalized hash accepts all three.
#
# Re-pinning this constant is the human gate. Whoever changes it is asserting
# the new text was approved, not that the check was noisy.
CANONICAL_SHA256=4674b2881d11294f36e7d9046d570a9d62be1a9b1a115bd524896b207afe30f9

fails=0
bad=()

# Substring match that ignores line wrapping. `grep -F` with a multi-line
# pattern treats each line as a SEPARATE pattern and matches if ANY of them
# hits, so a rule quoted across two lines would pass with its first line
# inverted. Flattening makes a multi-line phrase one conjunctive assertion.
has() {
  local hay want
  hay=$(tr '\n' ' ' < "$1" | tr -s ' ')
  want=$(printf '%s' "$2" | tr '\n' ' ' | tr -s ' ')
  case "$hay" in *"$want"*) return 0 ;; *) return 1 ;; esac
}

need()   { has "$1" "$2" || bad+=("$1: missing \"$2\""); }
reject() { has "$1" "$2" && bad+=("$1: must not contain \"$2\""); }
gone()   { [ -e "$1" ] && bad+=("must be deleted: $1"); }
kept()   { [ -s "$1" ] || bad+=("missing or empty: $1"); }
note()   { bad+=("$1"); }

group() { # report one line per group, listing everything that failed in it
  if [ ${#bad[@]} -eq 0 ]; then printf 'ok   %s\n' "$1"; return; fi
  printf 'FAIL %s\n' "$1"
  printf '       - %s\n' "${bad[@]}"
  fails=$((fails + ${#bad[@]}))
  bad=()
}

canonical() {
  python3 - "$SKILL" <<'CANON'
import sys
text = open(sys.argv[1], encoding='utf-8').read()
i = text.index('\n## Pre-PR review\n') + 1
section = text[i:]
if section.endswith('\n'):        # drop the file's terminating newline only
    section = section[:-1]
sys.stdout.write(section)
CANON
}

if [ "${1:-}" = "--show-canonical" ]; then canonical; exit 0; fi

# --- 1. The frozen lifecycle, byte for byte ---------------------------------
# This one hash is the whole lifecycle check. Every rule inside the frozen
# region is protected by it; do not add greps for them.
if [ -s "$SKILL" ]; then
  got=$(canonical | if command -v shasum >/dev/null 2>&1
                    then shasum -a 256; else sha256sum; fi | cut -d' ' -f1)
  [ "$got" = "$CANONICAL_SHA256" ] || note "hash is $got, want $CANONICAL_SHA256"
  lines=$(( $(canonical | wc -l) + 1 ))
  [ "$lines" = 67 ] || note "lifecycle is $lines lines, want 67"
  # Headings outside fenced blocks only: the declaration schema is a fenced
  # example that legitimately contains its own `## ` heading. The hash covers
  # everything after `## Pre-PR review`, so this is what catches a third
  # section spliced into the preamble ahead of it.
  h=$(awk '/^```/{f=!f; next} !f && /^## /{print}' "$SKILL")
  [ "$h" = "$(printf '## Pre-PR review\n## Post-PR review')" ] ||
    note "top-level sections are not exactly Pre-PR then Post-PR"
else
  note "missing or empty: $SKILL"
fi
group "frozen FINAL v10.3 lifecycle"

# --- 2. Files that must exist, and Pi/profile files that must not -----------
kept "$SKILL"; kept "$OWNERSHIP"; kept "$GENERAL"; kept "$WORKFLOW"
gone skills/lfx-local-review/scripts
gone skills/lfx-local-review/references/pi-setup.md
gone skills/lfx-local-review/references/repo-profiles.md
group "required files present, retired files absent"
[ $fails -eq 0 ] || { echo; echo "corpus unusable — later checks would be vacuous"; exit 1; }

# --- 3. The authored contract around the frozen text ------------------------
# One assertion per RULE. The rationale sentences that explain each rule are
# ordinary prose and are reviewed as prose.
TRIGGER='Load and follow `/lfx-skills:lfx-local-review` as the sole owner of the review
lifecycle. The values below configure that skill and do not replace or override
its instructions.'

# sole ownership, no central mapping
need "$SKILL"     'No repo adopting this central lifecycle may hold a second lifecycle copy'
need "$SKILL"     'Repositories that have not adopted this skill are outside that rule'
need "$OWNERSHIP" '**Central holds no per-repo mapping.**'
grep -rqF 'repo-profiles' skills/ README.md && note "a central profile table is still referenced"

# identity comes from origin, never the directory or a prompt
need "$SKILL" 'git remote get-url --all origin'
need "$SKILL" 'every derived name must be identical; if any two differ, stop'
need "$SKILL" 'Not from the checkout'"'"'s directory
name'

# the declaration: one addressable block, the trigger, five keys, from the checkout
need "$SKILL"     'find the single section whose heading is exactly
`## Review lifecycle configuration`'
need "$OWNERSHIP" 'headed exactly
`## Review lifecycle configuration`, appearing exactly once'
need "$SKILL"     'there is no `## Review lifecycle configuration` section, or more than one'
need "$SKILL"     '**Resolve every value from inside that block, and only from there.**'
need "$SKILL"     'In `<repo-root>/CLAUDE.md`, **from
that verified checkout**'
need "$SKILL"     'Not from a
prompt, which cannot supply or override it'
need "$SKILL"     "$TRIGGER"
need "$OWNERSHIP" "$TRIGGER"
need "$SKILL"     'the block does not open with the exact trigger sentence, naming exactly
  `/lfx-skills:lfx-local-review` as the sole owner of the review lifecycle'
need "$SKILL"     'any of the five keys is missing from that block, or appears more than once'
for key in 'repo code reviewer:' 'repo learnings reviewer:' \
           'readiness action:' 'preflight action:' 'post-PR extension:'; do
  need "$SKILL" "$key"; need "$OWNERSHIP" "$key"
done
# the central name is a constant, so it must not return as a declared value
reject "$SKILL"     '- lifecycle: `/lfx-skills:lfx-local-review`'
reject "$OWNERSHIP" '- lifecycle: `/lfx-skills:lfx-local-review`'

# value syntax: names become a filesystem path, actions become a command
need "$SKILL"     'either reviewer value fails `^/[A-Za-z0-9][A-Za-z0-9._-]*$`'
need "$OWNERSHIP" 'must match `^/[A-Za-z0-9][A-Za-z0-9._-]*$`'
need "$SKILL"     'the two reviewer values are identical'
need "$SKILL"     'neither exactly `none` nor a value passing that same
  syntax'
need "$SKILL"     'a non-`none` `post-PR extension` equals either reviewer value'
need "$SKILL"     'a readiness or preflight value is empty, spans more than one line, or is not
  a single terminated code span'

# the one permitted fallback is derived from the declared name, and general has none
need "$SKILL"     '/foo -> <repo-root>/.claude/skills/foo/SKILL.md'
need "$OWNERSHIP" '/foo -> <repo-root>/.claude/skills/foo/SKILL.md'
need "$SKILL"     'not an alias directory, a sibling or similarly named skill, a
cached or vendored copy, another checkout, or a legacy'
need "$SKILL"     'The central general reviewer has no file fallback at all'
need "$SKILL"     '**Fail closed.**'

# the declared extension is executed, and bounded
need "$SKILL" '**On entry to Post-PR review, load the declared extension.**'
need "$SKILL" 'only to refine and carry out canonical steps 1 through 6'

# the verification envelope: canonical shape requested, evidence-strict but
# formatting-tolerant acceptance, and whole-trio rejection
need "$SKILL" '**Ask every child for a verification envelope.**'
need "$SKILL" 'Reviewed range: <full base SHA>..<full target SHA>
Skill: /exact-skill-name'
need "$SKILL" '; read from: <exact derived path>'
need "$SKILL" '**Accept on the evidence, not the formatting.**'
need "$SKILL" 'exact
   expected full 40-character base SHA, a literal `..`, and the exact expected
   full 40-character target SHA, in that order'
need "$SKILL" 'Any explicit **conflicting**
   range or skill attestation invalidates that child'
need "$SKILL" 'Your own summary or rewrite of a child is
   never that child'"'"'s evidence'
need "$SKILL" 'Never normalize
   incompleteness into a completed review'
need "$SKILL" 'this is a claim about the **fallback**, not about
   paths in general'
need "$SKILL" 'ordinary source and evidence paths elsewhere in the review are
   unaffected'
need "$SKILL" 'The central general reviewer has no file fallback under any
   formatting.'
need "$SKILL" 'an unauthorized fallback path, or a value you could only infer'
need "$SKILL" 'tolerance is about decoration, never about supplying, guessing or
repairing a value'
need "$SKILL" 'Any invalid child invalidates the **entire trio** under the
all-or-none rule above; never accept or rerun one child alone.'

group "declaration contract, identity, fallback, report envelope"

# --- 4. Retired terms, on the shipped surface only --------------------------
# Listed by RETIRED USE, not spelling: "fallback" is not banned (the permitted
# derived-path fallback uses the word), and `.github/` is excluded — it is not
# shipped, and its Copilot reviewer legitimately says "cross-model".
OWNED=(skills/lfx-local-review skills/lfx-general-code-review README.md)
for term in run-pi pi-setup PI_READY PI_NOT_INSTALLED PI_UNAUTHENTICATED \
            PI_MODEL_UNAVAILABLE LFX_LOCAL_REVIEW_ local-review-fallback \
            local-code-review local-learnings-review earendil gpt-5 \
            cross-model same-model headless harness pi-coding-agent \
            'adoption profile' 'repo profile'; do
  grep -rniqF -- "$term" "${OWNED[@]}" && note "retired term present: $term"
done
grep -rnqE -- '(^|[^A-Za-z])Pi([^A-Za-z]|$)' "${OWNED[@]}" && note "retired term present: standalone 'Pi'"
for term in 'either harness' 'headless Pi' 'two harnesses'; do
  reject "$GENERAL" "$term"
done
group "retired Pi and profile vocabulary absent"

# --- 5. README catalogs the lifecycle, never restates it --------------------
readme=$(awk '/^### Review lifecycle skills/{f=1} f&&/^### /&&!/Review lifecycle skills/{exit} f' README.md)
if [ -z "$readme" ]; then note "README has no review-lifecycle section"; else
  rhas() { case "$(printf '%s' "$readme" | tr '\n' ' ' | tr -s ' ')" in *"$1"*) return 0 ;; *) return 1 ;; esac; }
  rhas 'The lifecycle itself is deliberately **not** described here' ||
    note "README does not disclaim describing the lifecycle"
  rhas 'skills/lfx-local-review/SKILL.md' || note "README does not link the lifecycle"
  # scoped to that section: several of these are legitimate elsewhere in the file
  for p in 'reviewed_through_sha' 'merge-base' 'origin/main' 'post-commit' 'full-branch' \
           'Mode 1' 'Mode 2' 'subagent_type' 'run_in_background' 'model: opus' \
           'base_sha' 'target_sha' 'three background' 'batch' 'Opus 5'; do
    rhas "$p" && note "README catalog restates the lifecycle: $p"
  done
fi
has README.md 'compatibility tooling for repos that have not adopted the central review lifecycle' ||
  note "README does not frame the named agents as compatibility tooling"
grep -qF 'check-review-lifecycle.sh' "$WORKFLOW" || note "$WORKFLOW does not run this checker"
group "README catalog-only, and CI runs this checker"

echo
if [ $fails -eq 0 ]; then echo "all groups passed"; exit 0; fi
echo "$fails problem(s) in the groups above"; exit 1
