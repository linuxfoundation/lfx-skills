<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Data Privacy Hard Rules

Canonical rules for handling personally identifiable information (PII) when
generating code, tests, examples, logs, or persisted data anywhere in the LFX
codebase. Applies to every LFX skill and reviewer agent in this plugin, and to
per-repo skills that route through `/lfx-skills:lfx`.

The Linux Foundation processes data on behalf of projects, members, and
end-users. Real user data has both regulatory (GDPR, CCPA, contractual DPAs)
and reputational cost. Treat these rules as non-negotiable defaults; the
narrow exceptions are called out explicitly below.

## Scope: when these rules apply

Apply the rules in this doc any time the AI is about to:

- Generate **test data, fixtures, seed data, factory helpers, mock responses,
  Postman/HTTPie/curl examples, dbt seeds, unit-test inputs, or Snowflake
  sample rows** that a developer will commit, share, or paste into a chat.
- Write or modify code that **logs a request, response, error, event, message,
  NATS payload, KV value, indexer document, or FGA tuple** that includes user
  identity fields.
- Persist a value into a datastore (Postgres, Snowflake, NATS JetStream KV,
  OpenSearch index, OpenFGA tuple store, Redis, S3, browser storage) that
  represents or references an individual user.
- Draft a **Jira ticket, PR description, commit message, code comment,
  reproduction step, screenshot caption, or Slack message** that references a
  specific individual or their contact info.

## The hard rules

1. **Never use real user PII in test data.** Fabricate every value. See
   *Safe alternatives* below.
2. **Never log PII in plaintext** by default. See *Logging exception* for the
   narrow audit case.
3. **Never persist PII to a datastore unless the resource contract requires
   that specific field.** If the value is not part of the resource's owned
   schema, it does not belong in KV, index docs, FGA tuples, or Postgres.
4. **Never paste, embed, or hard-code any real user PII — including
   identifiers, images, precise geolocation, financial data, and
   authentication material (as defined in *What counts as PII* below) —
   into documentation, PRs, Jira tickets, commit messages, code comments,
   reproduction steps, screenshot captions, or Slack / external
   messages.** Redact or replace before submitting. Two narrow exceptions
   apply, each scoped tightly:
   - *DCO trailer (contribution requirement).* The commit author's own
     `Signed-off-by: <name> <email>` trailer required by the Developer
     Certificate of Origin is permitted and required on every commit (see
     `skills/lfx-git-setup/SKILL.md`). `Co-authored-by:` is a GitHub
     attribution convention and is **not** a DCO trailer — do not conflate
     the two, and do not use `--signoff` to justify `Co-authored-by:`.
   - *Author attribution (git author + optional coauthors).* The commit's
     own git-author identity (name + email) is permitted. `Co-authored-by:
     <name> <email>` trailers are permitted only for individuals who
     actually co-authored the change and who have consented to being
     attributed under their real identity on this commit; the coauthor's
     own `Signed-off-by:` is required alongside their `Co-authored-by:`
     line when they participated as a contributor. Do not use
     `Co-authored-by:` as a workaround to reference a third party's PII.
   Neither exception permits including a *non-contributor's* PII (support
   contact, end user affected by a bug, member org's staff, etc.) in a
   commit message, PR body, ticket, or code comment. When such a reference
   is needed for context, use a role-based stand-in ("the affected
   committee chair," "the reporter of ticket X") and omit the identity.
5. **When in doubt, stop and ask the user.** A short question costs seconds.
   A shipped PII leak costs hours of remediation, a customer notice, and
   erodes trust. Remind them that logging, storing, or using real user data
   without an explicit business justification violates LFX data-privacy
   policy.

## What counts as PII

Treat these as PII by default:

- Full name, first name, middle name, last name
- Email addresses (personal, corporate, LFID-linked)
- Phone numbers
- Physical or mailing addresses
- Government or national IDs (SSN, passport, tax ID)
- Financial data (payment cards, bank accounts, invoice IDs tied to a person)
- Authentication material (passwords, API keys, JWTs, session cookies, MFA
  seeds, RSA private keys) — **stricter than the rest of this taxonomy: the
  narrow *Logging exception* below does NOT apply. Authentication material
  must never appear in any log sink (application, audit, error, metrics,
  tracing) in plaintext or reversible form. Redact, omit, or replace with a
  fixed masked token (`****`); when correlation is required, use a keyed
  HMAC of the credential's ID, never the credential itself.**
- Precise geolocation, and IP addresses. **LFX operational default:** treat
  every raw client IP as personal data — regardless of whether it is paired
  with an account — because operationally it is safer to redact by default
  than to reason about linkability per emission site. This default is
  broader than the strict legal test in either regime: under GDPR the CJEU
  held in Breyer (C-582/14, 2016) that a dynamic IP is personal data for an
  operator when it has legal means reasonably likely to identify the person
  (typically via ISP-held subscriber data); the CCPA / CPRA classifies an
  IP as personal information when it is reasonably capable of being
  associated with a consumer or household. Because LFX systems routinely
  hold or can request linkage data (account records, session logs, support
  correspondence), the reasonable-linkability threshold is almost always
  met in practice — so the safer operational default of "always treat raw
  IPs as personal data" is adopted and enforced by this policy.
- Photo, avatar, or signature images tied to an individual
- Date of birth, and other precise dates that uniquely identify a person
  (date of death, exact hire date when combined with role, exact
  membership start date when combined with org)
- **Biometric identifiers** (fingerprints, facial-recognition templates,
  voiceprints, retinal/iris scans, gait patterns, keystroke dynamics) —
  GDPR Article 9 special category of personal data; requires explicit
  consent and is not permitted in logs, fixtures, indexes, or caches
  under any exception in this policy. If a system genuinely needs to
  process biometrics, the design must be reviewed separately by the LFX
  security team.
- **Health information** (medical conditions, diagnoses, prescriptions,
  insurance records, mental-health notes, disability status, genetic
  data) — GDPR Article 9 special category; US HIPAA-scope data when
  the source is a covered entity. Same treatment as biometrics: never
  in logs, fixtures, indexes, caches, or generated docs under any
  exception in this policy.
- **Linked pseudonyms**: LFID, GitHub username, Discord user ID, Slack user
  ID, Auth0 `sub`, Snowflake login, or any handle that can be joined back to
  a real person via internal systems

Aggregated counts, event types with no user reference, and structural IDs
(project slug, meeting UID, committee UID) are not PII on their own. Adding a
user identifier to any of those makes the row PII.

## Safe alternatives for test data

Use structural placeholders that are obviously fake, easy to grep for, and
domain-appropriate:

| Use case | Prefer | Do not use |
| --- | --- | --- |
| Email in unit/integration tests | `user-1@example.com`, `alice@example.test`, `qa+bug-123@example.com` | Real coworker or user emails |
| Full name | `Test User 1`, `Alice Example`, `Committee Chair` | Real names from Salesforce, Auth0, LFID directory |
| Username / LFID | `testuser01`, `lf-fixture-alice`, `qa-writer-1` | Real GitHub, LFID, or Discord handles |
| Phone | `+12025550100` .. `+12025550199` (valid NPA `202` + NANPA fictional-use exchange range `555-0100`..`555-0199`; NPA `555` is not an assigned area code and can be rejected by strict phone validators) | Real numbers, and avoid `+1-555-555-01XX` in code paths that validate the NPA |
| Address | `1 Test Way, Springfield` | Real customer addresses |
| Org / company | `Example Foundation`, `Acme Test Org` | Real member organization names |
| UUID / IDs | `uuid.NewString()` or a fixed valid UUID such as `00000000-0000-0000-0000-000000000001` | Copy-pasted production UUIDs from a real record |
| Faker / factory | Language-native fakers (`faker.Name()`, `@faker-js/faker`, `factory_bot`, dbt seed generators) **only when contact-data providers are overridden to the reserved patterns above**: pin email domain to `example.com` / `example.test` (do NOT rely on the default `internet.email()` — many implementations use real mail providers like `gmail.com` / `hotmail.com`); pin phone to the reserved NANPA range `+1-202-555-0100..0199` (default `phone.number()` produces numbers outside the reserved block); constrain the name provider to an obviously-fake list; seed with a fixed value for determinism. Bare defaults are NOT safe. | Snapshots of real production rows; unconfigured `faker.internet.email()` / `faker.phone.number()`; any faker output that has not been constrained to the reserved ranges |

For dbt seeds and bronze-layer examples, follow the PII tagging and filtering
rules in `skills/lfx-data-engineer/SKILL.md` and its
`references/testing-patterns.md`.

## Logging exception (narrow)

The default is: **PII does not appear in log output.** The only permitted
exception is an explicit audit-log path where the raw identifier is part of
the audit record's schema and the field is required to satisfy a stated audit
requirement (regulatory, security investigation, or contract obligation).

When emitting to an audit path:

- The code MUST be on a code path clearly named for audit (`internal/audit/`,
  `audit_log`, `AuditLogger`, a dedicated audit NATS subject, etc.) — not the
  general application logger.
- A code comment on the emission MUST cite the **specific policy or
  requirement that mandates the raw field**, by policy identifier and
  section (for example, the shape is
  `// <policy-id> §<section>: <mandate that names this exact field>`, not
  a vague reference to "the audit trail"). The agent authoring the code
  MUST verify that the cited policy actually mandates *this specific raw
  field* (not merely "log audit events" — that is generic and does not
  justify raw PII). If the policy only mandates "an identifier for the
  actor" without specifying which one, prefer a pseudonymized identifier
  or a non-user resource UID and skip the exception. Do not copy example
  policy citations from documentation into code; look up and cite the
  policy that actually applies to the emitting service.
- The value MUST NOT also flow to the general application log, error log,
  metrics, tracing spans, or user-visible error responses.

Structured logs on the general application logger use non-PII identifiers:
request ID, correlation ID, trace ID, or a **non-user** resource UID
(project UID, meeting UID, committee UID, mailing-list UID, etc.). User-linked
UIDs (user UID, member UID, persona UID, LFID, Auth0 `sub`, GitHub user ID,
Discord user ID) are linked pseudonyms per the PII taxonomy above and are
**not** safe to log raw. Resource UIDs that reference a natural person or
their financial relationship (invoice UID, subscription UID, order UID,
membership UID) are also linked pseudonyms — treat them like user UIDs and
do not log them raw. When a user reference is truly needed for correlation,
emit a **pseudonymized** identifier — not the raw value.

Do NOT use plain hashes such as `sha256(email)` or its truncation as a
pseudonym. Email addresses have a small, enumerable input space; unsalted
hashes are dictionary-reversible and enable cross-system correlation across
any service that uses the same digest. Instead:

- Compute the pseudonym as a **service-specific keyed HMAC**, for example
  `hmac_sha256(key = per_service_secret, msg = normalized_email)`, and read
  the key from the service's secret store (never a constant in code).
- Use a distinct key per service so the resulting identifier cannot be
  joined across service boundaries.
- Treat the pseudonymous identifier itself as sensitive: apply the same
  retention window as the underlying PII, restrict it to the log/metrics
  pipeline that needs it, and rotate the HMAC key on any suspected
  compromise (rotation invalidates prior-window correlation, which is the
  desired property).

## When in doubt: ask, then remind

If any of the following is unclear, stop and ask the user:

- Whether a field the AI is about to log, store, or emit is PII.
- Whether the code path qualifies for the audit exception above.
- Whether a test data value the user pasted came from a real system.
- Whether a Jira ticket reproduction step should include the actual user's
  email or a redacted stand-in.

When asking, remind the user of the policy in one sentence, offer a safe
default, and wait. For example (assume the user pasted a real corporate
email into the draft reproduction steps — describe it generically, then
show only the reserved-domain replacement):

> "That reproduction step includes a real staff email address. LFX
> data-privacy policy (hard rule 4) says we don't put real user identifiers
> in tickets, PRs, commit messages, or code comments — there is no audit
> exception for those surfaces (the narrow audit-log exception applies only
> to a dedicated audit-log code path). I can replace it with
> `user-a@example.com` and note the affected user role instead — okay?"

## Handling real user data the user pasted

If the user pastes real PII into the chat (a Snowflake query result, a support
ticket, a Slack thread, a screenshot transcript):

- Use it in-session only to reason about the problem.
- Do not embed those values into generated code, tests, docs, or persisted
  files.
- Substitute a safe alternative from the table above before writing to disk
  or committing.
- Do not echo the raw values back in a summary any more than needed to
  answer the immediate question.

## Related repo-level rules

Per-repo guidance may add stricter rules (for example, a service that owns
member data may forbid logging even the resource UID). When a repo's
`CLAUDE.md`, `AGENTS.md`, or `.claude/rules/` conflicts with this doc, the
repo-owned rule wins — but never in the direction of weakening the hard
rules above.
