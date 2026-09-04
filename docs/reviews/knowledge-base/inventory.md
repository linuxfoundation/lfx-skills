<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Inventory

Empirical patterns where a change shipped a new skill, agent, or
contributor-facing file and the human-facing listings in `README.md` did not
move with it. Discovery is automatic; listings are not.

**Read when:** `README.md`, `CLAUDE.md`, or `AGENTS.md` changed, or the range
adds or removes a `skills/<name>/` directory or an `agents/*.md` file.

---

## `inventory/readme-must-list-new-surfaces` — Important

**Pattern:** a new `skills/<name>/` directory or `agents/<name>.md` file is
added, and `README.md` does not name it in the matching skills table, agents
table, or project-structure tree.

**Detect:** for every new `skills/<name>/` directory or `agents/<name>.md`
file the range adds, confirm `README.md`'s skills table, agents table, and
project-structure tree each name it. Flag a shipped path that is absent from
the listing that covers its kind. Do not flag a pre-existing omission the
range did not introduce.

**Empirical citation:** PR #71 `CLAUDE.md` — Copilot — "the `README.md`
Project Structure tree lists root-level files but omits both new instruction
surfaces, `CLAUDE.md` and `AGENTS.md`." Resolved in `bb367cc`. Also PR #64
`README.md` — Copilot — "The central table now documents these two skill
directories, but the repository-layout tree later in this README still omits
both." Also PR #59 `README.md` — dealako — "This header says Reviewer agents
(8) and the table below lists 8, but `agents/` ships 13 files."

**Failure message:** a newly shipped skill or agent is missing from the
README listing that covers it.

**Fix:** add the new path to the matching README table and the
project-structure tree in the same change. Update the count in the section
heading if it states one.
