---
name: lfx-intercom
description: >
  Everything Intercom for LFX — Angular app integration (code) and Fin AI optimization (support/CX).
  Use this skill for: adding or fixing Intercom in an LFX Angular app, auditing integrations against
  the LFX canonical pattern, correcting missing JWT pre-set, broken shutdown, missing Auth0 claim,
  wrong app IDs, or absent CSP entries — AND for Fin Guidance writing, Help Center optimization,
  resolution rate improvement, Fin escalation patterns, Copilot tips, Topics Explorer, Fin Attributes,
  daily review rituals, and Fin best practices. Routes to the right section based on context.
  Trigger on: any Intercom question, "Fin tips", "improve Fin", "Fin guidance", "Fin resolution rate",
  "Help Center optimization", "Copilot tips", "Angular Intercom", "IntercomService", "JWT Intercom",
  "Fin re-engagement", "Fin handoff", or any Intercom-related support or development question.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->
<!-- Tool names in this file use Claude Code vocabulary. See docs/tool-mapping.md for other platforms. -->

# LFX Intercom Skill

This skill covers everything Intercom at LFX — both Angular app integration and Fin AI optimization.

## Step 0 — Detect Context

Before proceeding, determine what the user needs based on what they said. Only ask if genuinely ambiguous.

**Code Integration (developer path)**
Adding, fixing, or auditing Intercom in an LFX Angular app → continue with the steps below.

**Fin & Content Optimization (support/CX path)**
Writing Fin Guidance, improving resolution rates, Help Center content, escalation patterns,
Copilot, Fin Attributes, or Fin best practices → read `references/fin-best-practices.md` and advise from there.

---

## Code Integration

You are bringing Intercom up to the LFX standard in an Angular application. This
skill handles both fresh installs and fixing/standardizing existing integrations.
