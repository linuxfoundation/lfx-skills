<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Security Review Report Template

Use this template when generating the final security review report.

## Report Structure

```text
═══════════════════════════════════════════
🛡️  LFX SECURITY REVIEW RESULTS
═══════════════════════════════════════════

Repository: [repo-name]
Branch: [branch-name]
Files scanned: [N] changed files
Scan duration: [X.X]s

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔴 CRITICAL FINDINGS ([count])

[For each critical finding, use the detailed format below]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🟡 WARNINGS ([count])

[For each warning, use a compact format:]
⚠️  [Brief description] at [file:line]
    [One-line explanation and recommendation]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ PASSED CHECKS ([count])

✓ [Check name]
✓ [Check name]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 SUMMARY

  Status: [✅ APPROVED | ⚠️ REVIEW NEEDED | 🔴 BLOCKERS FOUND]

  [N] critical issues must be fixed before merge
  [N] warnings should be addressed (recommend fixing before merge)

  Overall security posture: [assessment]

  Next steps:
  1. [Action item 1]
  2. [Action item 2]
  3. Re-run: /lfx-security-engineer
  4. [Request review if needed]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Exit code: [0 = pass, 1 = warnings, 2 = blockers]
```

## Detailed Finding Format

For each 🔴 CRITICAL finding:

```text
FINDING: [Check name]
File: [path/to/file.ts:42]
Severity: CRITICAL
What: [Plain-language description of the vulnerability]
Risk: [What an attacker could do if exploited]
Fix: [Concrete remediation with code example]
Reference: OWASP [A0X] — [https://owasp.org/Top10/...]
Next steps:
  1. [Specific action 1]
  2. [Specific action 2]
  3. Re-run this scan to verify fix
```

## OWASP References

Include direct links to the relevant OWASP documentation for each check:

- A01: https://owasp.org/Top10/2025/A01_2025-Broken_Access_Control/
- A04: https://owasp.org/Top10/2025/A04_2025-Cryptographic_Failures/
- A05: https://owasp.org/Top10/2025/A05_2025-Injection/
- A07: https://owasp.org/Top10/2025/A07_2025-Authentication_Failures/
- A09: https://owasp.org/Top10/2025/A09_2025-Security_Logging_and_Alerting_Failures/

## Severity Indicators

- 🔴 **CRITICAL** — Must be fixed before merge (exit code 2)
- 🟡 **WARNING** — Should be addressed (exit code 1)
- ✅ **PASSED** — Check passed, no issues found

## File References

Always use clickable format: `File: src/config/db.ts:15`

## Exit Codes for CI/CD

- **Exit code 0** — All checks passed, security approved
- **Exit code 1** — Warnings found, recommend review before merge
- **Exit code 2** — Critical blockers found, CI should fail

## Suppressed Finding Format

```text
🟡 WARNING [SUPPRESSED]

⚠️  Potential secret at tests/fixtures/auth.ts:15
    Pattern matches API key format, but suppressed with reason: "[inline reason]"
    Verify: Confirm this is actually test data and not a committed secret.
```
