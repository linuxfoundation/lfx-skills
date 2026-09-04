<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Privacy

Empirical patterns where an example in this public repo used a real-looking
identity or an unusable placeholder. `CLAUDE.md` already requires synthetic
data; these entries are the shapes reviewers actually caught.

**Read when:** any `skills/**`, `agents/**`, `docs/**`, `CLAUDE.md`, or
`README.md` that carries an example identity, credential, UUID, phone, or
email.

---

## `privacy/real-org-domain-in-example` — Critical

**Pattern:** an example, fixture, or policy snippet embeds an email, mailbox,
or similar identifier on a real Linux Foundation domain
(`linuxfoundation.org`, `linux.com`, `lfx.dev`) rather than a reserved
example domain.

**Detect:** grep the changed files for `@linuxfoundation.org`, `@linux.com`,
and `@lfx.dev` outside a `Signed-off-by:` / `Co-authored-by:` trailer or a
citation of an existing public URL. Flag a mailbox, local-part, or
"user@…" example on those domains. Do not flag a documentation link to a
real repo or marketplace.

**Empirical citation:** PR #62 `skills/lfx/references/data-privacy.md` —
Copilot — "This example embeds a plausible address on the real
`linuxfoundation.org` domain in the canonical policy itself, contradicting
the preceding rule against putting real user identifiers in documentation."
Resolved in `7367fac`.

**Failure message:** example uses a real Linux Foundation domain as a
placeholder identity.

**Fix:** replace it with a reserved-domain value such as
`user@example.com` or `user-1@example.com`.

---

## `privacy/placeholder-must-be-complete` — Important

**Pattern:** a "safe alternatives" or fixture table offers a UUID, phone, or
similar value that is not copy-pasteable because it contains an ellipsis or
is otherwise incomplete, so an agent that copies it produces invalid test
data.

**Detect:** in any table or example that claims to provide a safe fixture
value, flag a UUID containing `…` or `...`, a truncated hex string offered
as a full identifier, or a phone that is not a complete NANPA fictional
number (`+12025550100` or `555-0100` through `555-0199`).

**Empirical citation:** PR #62 `skills/lfx/references/data-privacy.md` —
Copilot — "This placeholder is not a valid UUID because the literal contains
an ellipsis. Since this table is intended to provide copyable safe fixture
values, agents may generate tests or seeds that fail UUID parsing." Resolved
in `4d33a84` with `00000000-0000-0000-0000-000000000001`.

**Failure message:** advertised safe fixture value is incomplete and will
not parse.

**Fix:** give a complete deterministic placeholder (a full UUID, a full
reserved phone, a full `user@example.com` address).
