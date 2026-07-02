<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# False Positive Reduction Patterns

Reduce scan noise without missing real vulnerabilities by understanding context
and framework conventions. Load this reference when interpreting Phase 1 scan
output to downgrade or suppress findings.

## Test File Recognition

**Safe to skip or reduce severity:**

- Files matching `**/*.spec.ts`, `**/*.test.ts`, `**/*_test.go`, `**/test_*.py`
- Directories: `tests/`, `__tests__/`, `spec/`, `fixtures/`, `mocks/`, `__mocks__/`
- Files containing `@jest.mock()`, `mock.Setup()`, `unittest.TestCase`

**What to check anyway:**

- Auth mocking patterns — are test mocks too permissive?
- Secret handling in tests — even test secrets should use env vars, not hardcoded strings in source control

## Mock Data vs Real Secrets

**Likely synthetic (lower severity):**

- API keys: `sk-test-...`, `pk_test_...`, `test_key_...`, `fake-api-key`
- Passwords in examples: `password123`, `changeme`, `example-password`
- JWTs with payload `{"sub":"test-user"}` or expiry in the past
- Database connection strings with `localhost`, `127.0.0.1`, or `example.com`

**Likely real (flag as critical):**

- Keys matching live service patterns: `sk_live_...`, `AIza[0-9A-Za-z-_]{35}`, `ghp_[0-9a-zA-Z]{36}`
- AWS keys: `AKIA[0-9A-Z]{16}`
- Connection strings with production domains or cloud database hosts

## Example and Config Files

**Safe to ignore:**

- Files named `*.example`, `*.sample`, `*.template`
- Comment blocks labeled `// Example:` or `# Sample configuration:`
- README code blocks and documentation

**Not safe:**

- `.env` files (even if named `.env.example` but containing real-looking secrets)
- Config files in production directories (`/etc/`, `/config/prod/`)

## Framework-Aware Safe Patterns

### ORM Parameterization

**Safe — frameworks handle escaping:**

```typescript
// TypeORM (safe, parameterized by default)
await repository.findOne({ where: { id: userId } });

// Prisma (safe, always parameterized)
await prisma.user.findUnique({ where: { id: userId } });

// Gorm (safe when using struct or map)
db.Where(&User{ID: userId}).First(&user)
```

**Unsafe — raw SQL without parameters:**

```typescript
// Dangerous
db.query(`SELECT * FROM users WHERE id = ${userId}`);
db.Raw(`DELETE FROM sessions WHERE user_id = ` + userId);
```

### Template Engine Auto-Escaping

**Safe — auto-escaped by framework:**

```html
<!-- Angular (safe, auto-escaped) -->
<div>{{ userInput }}</div>

<!-- React (safe, auto-escaped) -->
<div>{userInput}</div>

<!-- Go templates (safe with html/template) -->
{{.UserInput}}
```

**Unsafe — explicit bypass:**

```html
<!-- Dangerous -->
<div [innerHTML]="userInput"></div>
<div dangerouslySetInnerHTML={{__html: userInput}}></div>
{{.UserInput | safeHTML}}
```

### Framework Security Helpers

**Recognize framework-provided security:**

```typescript
// Angular DomSanitizer (acceptable when validated)
constructor(private sanitizer: DomSanitizer) {}
safeHtml = this.sanitizer.sanitize(SecurityContext.HTML, trustedSource);

// Express helmet (CSP, HSTS, etc.)
app.use(helmet());

// Go Goa security middleware (OpenAPI-aware)
app.Use(middleware.RequestID())
```

## Suppression Comments

Support inline suppression for unavoidable false positives with mandatory justification.

### Syntax

```typescript
// security-ignore: [reason] - [ticket/discussion reference]
const apiKey = process.env.DEMO_API_KEY; // security-ignore: demo key for docs, not a real secret - see PR #123
```

```go
// security-ignore: test fixture for integration test - safe to commit
const testJWT = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

### Rules for Suppression

**Valid reasons:**

- Test fixture or mock data clearly labeled
- False positive from framework convention (e.g., ORM auto-escaping)
- Approved exception with security team sign-off (link to discussion)

**Invalid reasons:**

- "I checked it" (explain what you checked and why it's safe)
- "TODO: fix later" (fix now or create a tracked issue)
- No reason provided (suppression requires justification)

**When scanning:**

1. Recognize `security-ignore:` comments on the same line or line above finding
2. Still mention the suppressed finding in report but mark as `[SUPPRESSED]`
3. Validate suppression reason is present and not a placeholder
4. Suggest removing stale suppressions if code has changed

## Smart PII Detection

### Likely Test Data (lower severity)

```typescript
const user = { email: "test@example.com", name: "Test User" };
const phone = "555-0100"; // North American fictional number
const ssn = "000-00-0000"; // Invalid SSN format
```

### Likely Real PII (flag as critical)

```typescript
const email = "john.doe@company.com"; // real domain
const phone = req.body.phone; // user-provided
const ssn = customer.ssn; // fetched from database
```

### Logging Patterns

**Safe (no PII):**

```typescript
logger.info(`User ${userId} logged in`); // ID, not email
logger.debug(`Request completed`, { requestId, duration });
```

**Unsafe (PII exposure):**

```typescript
logger.info(`User ${email} logged in`); // email in logs
logger.debug(`Request body: ${JSON.stringify(req.body)}`); // could contain PII
```

## Implementation Guidance

1. **Priority order:** Real vulnerabilities > potential issues > false positives
2. **When in doubt, flag it:** Better to have a false positive with explanation than miss a real issue
3. **Provide context:** If suppressing or downgrading, explain why in the report
4. **Learn from feedback:** Track which patterns cause false positives and refine detection
