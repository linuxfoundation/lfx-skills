---
name: lfx-skills-code-review
description: >-
  How to judge an lfx-skills pull request: what makes a skill or reviewer
  agent sound (frontmatter, triggers, internal consistency, reference
  accuracy) and whether the change respects the central-vs-repo boundary of
  the LFX skills fanout architecture. Use on every PR that changes skills,
  agents, references, or distribution files; this is the reviewer's
  repo-specific lens.
---

<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# LFX Skills Code Review

Reviewer scope and signal discipline are owned by the `copilot-code-reviewer`
skill (`.github/skills/copilot-code-reviewer/SKILL.md`); this skill owns the
repo-specific method: what a sound skill looks like, and which side of the
central-vs-repo boundary content belongs on.

## What makes a skill sound

- **Frontmatter.** The `name:` matches the skill's directory name (skill
  resolution breaks otherwise). The `description:` is the only surface an
  agent sees when deciding whether to load the skill, and agents undertrigger
  by default — so it must carry the whole when-to-use story: what the skill
  does plus concrete positive triggers ("Use when…", trigger phrases) and,
  when a nearby skill could plausibly fire on the same prompt, explicit
  negative triggers ("Do not fire for…"). A description that is vague, that
  collides with another skill's triggers, or that leaves when-to-use
  information buried in the body (where it cannot influence triggering) is a
  finding. `allowed-tools:` lists only tools the body actually uses.
- **Header placement.** The two MIT license comment lines sit directly below
  the frontmatter, never inside it. Skills that name tools carry the
  tool-vocabulary note pointing at `docs/tool-mapping.md` and use Claude Code
  tool names in the body.
- **Internal consistency.** The highest-signal finding this repo produces: a
  value, rule, or recommendation stated in one section and contradicted,
  forbidden, or defined differently in another section of the same file. An
  agent following the skill hits both statements; it cannot resolve them.
- **Reference accuracy.** Every cross-reference resolves: `references/` files
  the skill links, other skills it names, repo paths and commands it tells an
  agent to use, and external facts it cites (an RFC, an API, a repo name).
  A skill that points an agent at something that does not exist misdirects
  every consumer.
- **Actionable instructions.** A skill is instructions an agent must be able
  to execute. A rule an agent cannot act on ("be careful", "use good
  judgment" with no criteria) is a finding against the skill; so is a
  procedure whose steps cannot be followed in order.
- **Explained, not commanded.** Good skills state the why behind their rules,
  so an agent can generalize to cases the author did not foresee; a skill is
  invoked across many repos and prompts, not just the case it was written
  from. Walls of ALL-CAPS MUSTs with no reasoning, rigid structure for its
  own sake, and rules overfitted to a single past incident are findings
  against the skill's durability.
- **Progressive disclosure.** A `SKILL.md` body loads in full on every
  trigger, so it stays lean — a body approaching several hundred lines
  should push depth into `references/` files, each with explicit guidance on
  when to read it. A deterministic, repeated procedure spelled out as prose
  the agent must re-derive every run is better shipped as a bundled script.
- **Placeholder data only.** Examples use placeholder identities and
  credentials (`user@example.com`-style, reserved ranges, fixed sample UUIDs)
  — never real emails, names, tokens, or keys.

## The fanout boundary

This repo implements the LFX skills fanout architecture. Its core principle:
**central finds the right owners and explains the shared platform; each repo
explains itself.** A skills PR is judged against that boundary, because the
boundary is what keeps the central plugin from growing back into the stale
central rulebook it replaced.

The boundary is a judgment call, not a checklist. The operative question for
any added or expanded content is: **does this help agents across multiple
repos, or does it serve a single repo?** Content that guides work spanning
repos belongs central; implementation truth that one repo owns belongs in
that repo, with central pointing to it. Ground the call in evidence rather
than intuition: `skills/lfx/references/repo-map.md` is the ownership index —
when it (or the router's other topology references) shows a single repo
owning the surface a change teaches, that is the tell that the content
belongs there.

Common shapes of genuinely multi-repo content: architecture and topology
(where things live, which repo owns a surface), workflows useful across all
or most repos (git setup, PR catch-up, cross-repo journey testing),
audiences that are not repo contributors (e.g. access-request flows for the
wider LF workforce), GitHub-generic mechanics, the reviewer agents each
repo's work cycle launches, and the plugin's own distribution machinery.
Treat these as recognizable shapes, not an exhaustive gate.

Flag placement only when it is clearly wrong: a central skill growing
repo-specific implementation teaching — framework conventions, codegen or
endpoint recipes, authorization-model details, repo-specific setup,
preflight, test, build, or deploy commands — for a surface repo-map shows a
single repo owning. The fix is a pointer to the owning repo, not a better
central write-up. When the multi-repo value is genuinely arguable, it is the
maintainers' call, not a finding.

Two refinements to that rule:

- **Reviewer agents are the deliberate exception** to repo-local packaging:
  they live centrally under `agents/` even when repo-specific, because they
  are named workers repos launch explicitly. But they must direct the agent
  to read the owning repo's own docs (`CLAUDE.md`, rules, checklists,
  knowledge base) as the source of truth at runtime. A reviewer agent that
  inlines a copy of a repo's rulebook centrally is drift — flag it.
- **`repo-map.md` is the primary repo classifier.** The map is an index, not a
  mirror: entries name the owner and the handoff boundary. It is not the only
  ownership reference — the central skills deliberately delegate finer-grained
  questions to specialized ones, so updating those is normal work and not
  duplication. What is a finding is a *new* parallel source for the same
  question the map already answers, or a map entry grown into a reading order
  that duplicates the owning repo's docs.

## Distribution mechanics

Both distribution paths — the marketplace manifest (`.claude-plugin/`
declares `"skills": "./skills/"`) and the `install.sh` symlink flow —
auto-discover any `skills/<name>/` directory that contains a `SKILL.md`, so
a skill whose instructions live at a non-standard path is invisible to both.
Changes to `.claude-plugin/` or the installer scripts alter how every
consumer receives the plugin; judge them against both paths. Files under
`.github/` are not shipped in the plugin.
