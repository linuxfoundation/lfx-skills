---
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
name: lfx-doctor
description: >
  Bootstrap wrapper for the LFX Skills doctor helper in this source repo. Use to
  diagnose agents.md installs and legacy Claude symlink installs from inside the
  lfx-skills clone.
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion
---

# LFX Doctor Bootstrap

This is a repository-local bootstrap skill. Read `skills/lfx-doctor/SKILL.md`
from the LFX Skills repo root and follow that canonical skill exactly.

Do not use this wrapper as the source of truth. The canonical implementation is:

```text
skills/lfx-doctor/SKILL.md
```
