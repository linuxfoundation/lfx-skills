---
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
name: lfx-install
description: >
  Bootstrap wrapper for the LFX Skills install helper in this source repo. Use
  when the user has just cloned lfx-skills and wants to set up agents.md-compatible
  tools, or needs the Claude Code plugin install path explained.
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion
---

# LFX Install Bootstrap

This is a repository-local bootstrap skill. Read `skills/lfx-install/SKILL.md`
from the LFX Skills repo root and follow that canonical skill exactly.

Do not use this wrapper as the source of truth. The canonical implementation is:

```text
skills/lfx-install/SKILL.md
```
