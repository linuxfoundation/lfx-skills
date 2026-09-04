<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Ownership and adoption

- [The sole-owner invariant](#the-sole-owner-invariant)
- [The declaration](#the-declaration)
- [The one permitted fallback path, derived not declared](#the-one-permitted-fallback-path-derived-not-declared)
- [Where the two reviewer skills live](#where-the-two-reviewer-skills-live)
- [What a reviewer receives](#what-a-reviewer-receives)
- [The false-positive floor must suppress at BOTH revisions](#the-false-positive-floor-must-suppress-at-both-revisions)
- [Writing the two skills](#writing-the-two-skills)
- [Checklist for a repo adopting this lifecycle](#checklist-for-a-repo-adopting-this-lifecycle)

Every Pre-PR batch runs three reviewers. Central owns one of them and the
lifecycle they run inside; **the repo owns the other two**, because they encode
things only that repo knows.

| Role | Owner | What it knows |
| --- | --- | --- |
| the lifecycle itself | central, in [`../SKILL.md`](../SKILL.md) | when to review, over what range, what a valid batch is, and where review stops |
| `general` | central, in `/lfx-skills:lfx-general-code-review` | language-agnostic correctness, security, data privacy, testing, performance |
| `repo_code` | the repo | its own written conventions, contracts and architecture |
| `repo_learnings` | the repo | patterns extracted from its own past PR review comments |

That split is the point. A repo's conventions live with the code they govern
and change with it; central would only hold a stale copy. The lifecycle is the
mirror image: it is identical across every adopting repo, so exactly one copy
of it exists for them to share.

## The sole-owner invariant

`/lfx-skills:lfx-local-review` **is** the canonical review lifecycle. It is not
a summary of one kept elsewhere, and **no repo adopting this central lifecycle
may hold a second lifecycle copy** to diverge from. An adopting repo's surface
carries only two things:

1. **A declaration.** One `## Review lifecycle configuration` section in
   `CLAUDE.md`: the sentence that loads this lifecycle, then five keys — the
   schema below: the repo's own two reviewers, its two checks, and its Post-PR
   extension or `none`. That sentence and those values, and nothing else: no
   ranges, no batch rules, no modes, no prose about how review works.
2. **A Post-PR extension, where its declaration names one.** Repo-specific
   detail for **Post-PR review** steps 1–6 that references the canonical
   lifecycle instead of restating it, and inherits every boundary: no local
   reviewer, no return to Pre-PR review, no merge, and no relaxation of step 7.

**Central holds no per-repo mapping.** There is no table here listing which
repos have adopted, or what each one runs — deliberately, so that adopting a
repo is a change to that repo and nothing else. The lifecycle reads the
declaration out of the verified checkout at run time. This is the whole reason
the mechanism is generic: it works for any repo that declares correctly, and
fails closed for every repo that does not, without either outcome requiring an
edit to this plugin.

The two reviewer skills are the one thing that stays genuinely repo-owned, and
they are **review content** — the repo's rules, contracts and knowledge base.
They carry no lifecycle prose and no declaration values.

This binds **adopting** repos — the ones carrying a declaration. A repository
that has not adopted this skill is outside the rule and may still carry its own
review workflow; adoption is precisely the step that retires that copy in
favour of this one. Do not read the rule as a claim about every LFX repository.

Anything else an adopting repo writes about *when* to review, *what range* to
review, *what makes a batch valid*, or *where review stops* is a fork.
Declarations configure the lifecycle; they do not own, paraphrase or override
it. Changing the lifecycle is an architecture change to the central skill, and
it is human-gated.

## The declaration

One section in the adopting repo's `CLAUDE.md`, headed exactly
`## Review lifecycle configuration`, appearing exactly once. It opens with the
trigger sentence and then holds five keys, each exactly once, each value in a
code span:

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

The heading is what makes the block addressable. A `CLAUDE.md` is a long
document that may discuss review, name skills, or quote this schema in passing,
and a key matched anywhere in the file could pick up a sentence that was never
meant as configuration. Values are resolved from inside that block and nowhere
else, so the block must contain the trigger sentence and the five values and
nothing more — prose about how review works there is a fork of the lifecycle.

- **The trigger sentence** is the block's first content and must name exactly
  `/lfx-skills:lfx-local-review` as the sole owner of the review lifecycle,
  saying that the values below configure it rather than replace or override it.
  It is what actually makes a fresh session load this skill — an imperative a
  reader acts on, which a passive `lifecycle:` key is not. That central name is
  a constant, not a repo fact, so it appears in the sentence and is not
  repeated as a value. A block that points somewhere else, or that lists values
  without invoking anything, is not an adoption of this lifecycle and fails
  closed.
- **The two reviewer values** are the exact registered names of this repo's own
  skills, and must match `^/[A-Za-z0-9][A-Za-z0-9._-]*$`: one leading slash,
  then letters, digits, dot, underscore or hyphen. No second `/`, no `:` (a
  plugin-namespaced skill — the repo's reviewers are repo skills), no
  whitespace, no shell or path metacharacter, and no reachable `..` component.
  That strictness is because these values become a filesystem path. The two
  must differ from each other.
- **The two action values** must be **non-fixing**, and each must be a single
  non-empty, single-line, terminated code span. Mode 2 runs them against a
  clean, committed `HEAD` and then has the parent apply whatever remedy each
  finding calls for. A command that rewrites tracked files — `make fmt`, a
  generator, an auto-fix linter, or an aggregate target that depends on one —
  dirties the tree the checks were supposed to describe and takes the remedy
  out of the parent's hands. Where a repo's own preflight skill fixes by
  default, declare its report-only mode; where an aggregate `make` target
  depends on a formatter, declare the underlying non-fixing targets instead.

  There is no central allowlist of commands — the repo owns what its checks
  are. **Adoption review is where this is confirmed**: a reviewer checks that
  each action is an exact, documented, non-fixing action for that repo, quoting
  the repo's own documentation. That review is the control, not a pattern.
- **`post-PR extension`** is exactly `none`, or one skill name passing the same
  syntax as the reviewers. It must differ from both reviewer values: a
  declaration naming its own local code reviewer as the extension would run a
  local reviewer after the PR opens, breaking the no-local-review boundary
  before any prose constraint could catch it. This is where an extension is
  granted, and the only place it is named; nothing is discovered at run time.

`{{REPO}}` is not declared — it is derived from the verified `origin` fetch
URLs, so a declaration cannot claim to be a repository it is not.

## The one permitted fallback path, derived not declared

A reviewer loads its skill by name with the Skill tool. Only if that exact
skill is unavailable in the child's session may it read one file instead, and
that path is **derived mechanically from the declared name**:

```text
/foo  ->  .claude/skills/foo/SKILL.md
```

Strip the leading `/`; the remainder is the skill directory under
`.claude/skills/`. The derived value is **repo-root-relative and carries no root
of its own** — the lifecycle's child prompt hands over
`<repo-root>/{{CODE_PATH}}`, joining the root exactly once, and the full path
that join produces is what a fallback attestation must name. This is why the
fallback is not a declared value: a declared path could disagree with the
declared name, and then two reviewers of the same role could read different
files. Deriving it makes that impossible.

Reaching that path is still not the same as reaching the declared skill.
Whatever file occupies the directory could declare a different `name`, and a
reviewer that followed it would work from the wrong guidance while attesting the
declared one. So a fallback file must prove its identity: its YAML frontmatter
`name` has to equal the declared name with the leading `/` removed. Absent,
unparseable or differing frontmatter means that reviewer returns INCOMPLETE —
no alias, no near match, no other file.

Nothing else may be read: not an alias directory, a sibling or similarly named
skill, a cached or vendored copy, another checkout, or a legacy
`lfx-*-code-reviewer` / `lfx-*-learnings-reviewer` agent. If the derived file
is absent, that reviewer returns `INCOMPLETE`. **The central general reviewer
has no file fallback at all** — if its skill will not load, it returns
`INCOMPLETE` rather than reviewing unguided.

So a repo's two reviewer skills must live at the path their names derive to.

## Where the two reviewer skills live

Each is one `SKILL.md` at the path its declared name derives to, loadable under
exactly that name:

```text
<repo>/.claude/skills/<declared-name>/SKILL.md
```

Do not add discovery aliases for the reviewers to find. The lifecycle never
searches: it reads the declaration, derives one path, and a name or path that
is wrong fails loudly, which is the outcome you want. A generic alias directory
beside the real skill only creates a second name that can drift from the
declared one.

## What a reviewer receives

Every reviewer gets the same pinned values from the lifecycle's shared prompt:

- `target repo` and `repo root`
- `target_sha` and `base_sha`, both full SHAs
- `review exactly:` — the explicit `git diff <base> <target>` range
- `range label` — which of the lifecycle's ranges this is

Use those values. **Do not re-derive them** from `HEAD`, `git show`, or
`origin/main`: three reviewers reading a moving `HEAD` can disagree about what
they reviewed, and the parent has already resolved the range the batch is
accountable for. If your skill tells a reviewer to derive its own range, the
shared prompt overrides that instruction — but the skill is then also wrong,
and should be fixed.

Read evidence at the pinned revisions — `git show <target_sha>:<path>` for
added and modified code, `git show <base_sha>:<path>` for deleted code, both
for a rename, and `git grep <pattern> <rev>` or `git ls-tree <rev>` for
context — so what you quote is what you reviewed. Working-tree content is not
evidence about a commit.

## The false-positive floor must suppress at BOTH revisions

Ordinary knowledge-base pattern files are read at `target_sha`, as usual. The
false-positive **floor** — `docs/reviews/knowledge-base/known-false-positives.md`
— is different: read it at **both** `base_sha` and `target_sha`, and suppress a
finding only when **both** floors would suppress that exact finding.

Neither revision alone is sufficient, because each one alone has a hole:

- **Target alone** lets a patch that *adds* a waiver suppress a finding about
  that same patch — the reviewed change approving itself.
- **Base alone** lets a waiver the change *removes* go on suppressing. Removing
  a waiver means "start flagging this again", and base-only reading ignores the
  removal entirely — so a defect introduced by the very change that removed the
  waiver stays hidden.

Requiring both closes each hole with the other:

| The range… | base floor | target floor | result |
| --- | --- | --- | --- |
| **adds** a waiver | does not suppress | suppresses | **not suppressed** |
| **removes** a waiver | suppresses | does not suppress | **not suppressed** |
| leaves it unchanged | suppresses | suppresses | **suppressed** |

Newly widened and newly narrowed coverage behave the same way: they cannot hide
a candidate unless the unchanged overlap still suppresses it at both revisions.

### When a newly added waiver starts applying

Recorded precisely, so nobody reads the delay as a defect and "fixes" it, and
nobody mistakes the later case for a loophole:

- **It cannot suppress anything in the range that adds it**, because that
  range's base does not carry it. That is the property that matters: **a change
  can never waive a finding about itself.**
- **It can apply to a later range whose base already contains it.** That is
  correct, not a leak. Relative to that change the waiver is pre-existing, both
  revisions carry it, and it is suppressing a finding about a different change
  than the one that introduced it.

### How to evaluate it

**Per candidate, semantically — never by comparing the two files.** For each
candidate finding, ask separately "would the base floor suppress *this
finding*?" and "would the target floor suppress *this finding*?", then suppress
only if both answers are yes.

Do **not** diff the two floors, and do not compare their Markdown byte for byte.
Those are different questions with different answers: if the base carries a
broad pattern and the target narrows it, a candidate matching the narrow one is
genuinely suppressed by both, and a byte or line comparison would miss that.

### Reading each floor

Read and classify each revision independently, with the same sequence, and
distinguish "absent" from "wrong type" from "unreadable". Do not treat one
failed read as absence. For each of `<base_sha>` and `<target_sha>` in turn:

1. `git ls-tree <rev> -- docs/reviews/knowledge-base/known-false-positives.md`
   - **nonzero exit** → `INCOMPLETE — <reason>`. Both revisions are real
     commits the parent pinned, so a failure here is a genuine read problem,
     not absence.
   - **exit 0, empty output** → that floor is legitimately absent, so it is
     empty. Normal at the file's first introduction. An empty floor suppresses
     nothing.
   - **exit 0, an entry** → require mode exactly `100644` and type exactly
     `blob`. Anything else — a symlink (`120000`), an executable (`100755`), a
     submodule (`160000`), a `tree` — is `INCOMPLETE — <reason>`. Do not follow
     a symlink out of the revision you are reading.
2. Read it **by the object ID that `ls-tree` printed**, not by path:
   `git cat-file blob <object-sha>`. The path was already resolved in step 1;
   re-resolving it invites reading a different object than the one you checked.
   - unreadable → `INCOMPLETE — <reason>`
   - empty content → a valid empty floor
   - otherwise, use it as that revision's floor

**Say which revision failed.** An ambiguous or failed read produces
`INCOMPLETE — <reason>` naming the revision, so a developer knows which side to
look at.

**Never substitute one floor for the other.** If the base floor cannot be read,
do not fall forward to the target floor — or the reverse. An unreadable floor
means you cannot apply the rule, not that you should apply half of it.

## Writing the two skills

Each is one `SKILL.md` at the path its declared name derives to, with
frontmatter and prose.

**Do not state capability facts.** Reviewers run as ordinary background
subagents with ordinary local-user capability — shell, git, builds and tests,
read-only GitHub inspection. Do not write "you have read-only tools" or "you
have no shell": they are false, and a reviewer that catches its instructions
being wrong about its own situation has reason to doubt the rest. State
*obligations* instead:

> Do not edit tracked source or config, run auto-fix formatters or generators,
> commit, reset, or push. Report what you find; the parent session fixes it.
> Ordinary non-fixing builds, tests and linters are fine even when they leave
> caches or binaries behind. Reading GitHub is fine — a linked issue, an
> upstream API, a referenced PR. Never *write* GitHub state: no comment,
> review, check, status, label or approval, and never gate or merge.

Both roles should also observe the shared bar: confidence floor 80, severities
limited to critical / important, no nits, and evidence with a repo-relative
path, real line numbers and a verbatim excerpt.

Return ordinary Markdown, following the report conventions the lifecycle's
shared prompt requires — the `Reviewed range:` and `Skill:` verification lines,
and `; read from: <exact path>` when the allowed file fallback was used. If you
cannot complete the review — required evidence missing or unreadable — make the
**first line** exactly `INCOMPLETE — <reason>`, followed by the same two
verification lines. That line is yours alone; the parent never writes it for
you.

## Checklist for a repo adopting this lifecycle

- [ ] A code reviewer `SKILL.md` citing the repo's own rules, contracts and
      architecture
- [ ] A learnings reviewer `SKILL.md` citing `docs/reviews/knowledge-base/`
- [ ] The false-positive floor is evaluated at **both** `base_sha` and
      `target_sha`, suppressing only when both would suppress that exact
      candidate — per candidate and semantically, never by comparing the two
      files — with the absent / wrong-type / unreadable distinction above
      applied to each revision independently
- [ ] Obligations, not capability claims
- [ ] Ordinary Markdown out, with the lifecycle's verification lines, and
      `INCOMPLETE — <reason>` as a first line when required evidence is missing
- [ ] Two deterministic **non-fixing** checks identified for the readiness and
      preflight actions, taken from the repo's own documentation
- [ ] The declaration added to the repo's `CLAUDE.md` under exactly one
      `## Review lifecycle configuration` heading: the exact trigger sentence,
      then all five keys, exactly once each, and nothing else — reviewed
      against the repo as it actually is
- [ ] Adoption review has confirmed both action values are exact, documented,
      non-fixing actions, quoting the repo's own documentation for each
- [ ] Each reviewer skill reachable at the path its declared name derives to,
      `.claude/skills/<declared-name>/SKILL.md`
- [ ] Any smoke or test clone keeps a fetch `origin` pointing at the real
      repository, with only its **push** URL removed or disabled
      (`git remote set-url --push origin no-push`). The lifecycle identifies a
      repo from `origin`'s fetch URL, so a clone with no `origin` fails closed
      and reviews nothing — which is correct, but is not what you wanted from a
      smoke test
- [ ] The repo's own surfaces reduced to that declaration — no restated
      lifecycle, no range rules, no batch-validity rules, no discovery aliases
- [ ] Nothing added to `lfx-skills`: adoption is a change to the adopting repo
      alone
