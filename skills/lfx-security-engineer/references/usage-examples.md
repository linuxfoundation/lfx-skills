<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Usage Examples

Load this reference when the user asks for help or examples.

## Example 1: Quick Pre-Commit Check (Beginner)

**Scenario:** You're about to commit auth-related changes and want a fast security check.

```bash
/lfx-security-engineer --scan-only
```

Runs Phase 1 automated scan only on changed files (fast, mechanical checks). Skips Phase 2 security review. Ideal for rapid feedback before `git commit`.

## Example 2: Full Security Review Before PR (Standard)

**Scenario:** You're ready to submit a PR touching auth, permissions, or data handling.

```bash
/lfx-security-engineer
```

Runs both Phase 1 (automated scan) and Phase 2 (judgment-based security review) on all changed files. Default mode — recommended before every PR.

## Example 3: Review a Specific File or Directory

```bash
/lfx-security-engineer --file src/services/auth.service.ts
```

Scopes both phases to the specified file or directory.

## Example 4: Full Repository Audit

```bash
/lfx-security-engineer --full-scan
```

Runs both phases on **all files** in the repo. Warning: slow on large codebases. Use for new repos or major refactors.

## Example 5: Terraform/OpenTofu Audit

```bash
/lfx-security-engineer
```

Detects Terraform files automatically — no special flag needed.

## Example 6: Database Migration Review

```bash
/lfx-security-engineer --file db/migrations/
```

Scans migration files for plain-text password columns, hardcoded PII, broad grants, and missing audit columns.

## Example 7: Combine Multiple Flags

```bash
/lfx-security-engineer --full-scan --file src/auth/
```

Full scan scoped to auth directory.

## Pro Tips

- Start with default mode (`/lfx-security-engineer`) before every PR
- Use `--scan-only` for rapid iteration during development
- Use `--full-scan` only when onboarding a new repo or after major refactors
- Use `--all` to also see MEDIUM-severity findings (default shows CRITICAL and HIGH)
