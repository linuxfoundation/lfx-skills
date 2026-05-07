---
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
name: lfx-preflight
description: >
  Pre-PR validation for any LFX repo — Phase 1 auto-fixes (license, format, lint, build),
  Phase 2 code review (15 report-only checks for Angular). Adapts to repo type.
  Use before submitting any PR. Pass --skip-review to skip Phase 2.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

<!-- Tool names in this file use Claude Code vocabulary. See docs/tool-mapping.md for other platforms. -->

# Pre-Submission Preflight Check

You are running a comprehensive validation before the contributor submits a pull request. Adapt checks based on the repo type.

**Two phases:**

- **Phase 1: Validation** — mechanical checks with auto-fix (all repo types)
- **Phase 2: Code Review** — 15 report-only pattern checks (Angular repos only)

**Modes:**

- **Default:** Run both phases. Phase 1 auto-fixes where possible (formatting, license headers). Phase 2 is always report-only.
- **`--skip-review`:** Run Phase 1 only, skip Phase 2. Useful during development when you just want to validate build/lint.
- **"report only" / "dry run":** Phase 1 reports without fixing. Phase 2 is unchanged (always report-only).

## Repo Type Detection

```bash
if [ -f apps/lfx-one/angular.json ] || [ -f turbo.json ]; then
  echo "REPO_TYPE=angular"
elif [ -f go.mod ]; then
  echo "REPO_TYPE=go"
fi
```

---

# Phase 1: Validation

Mechanical checks that can be auto-fixed. Runs for all repo types.

## Check 1: Working Tree Status

```bash
git status
git diff --stat origin/main...HEAD
git log --format="%h %s%n%b" origin/main...HEAD
```

**Evaluate:**

- **Uncommitted changes?** — Ask the contributor: commit now or stash?
- **No commits ahead of main?** — The branch has nothing to validate.
- **Commit messages missing JIRA ticket?** — Flag commits without `LFXV2-` references.
- **Commits missing `--signoff`?** — Flag any commits without `Signed-off-by:` lines.

## Check 2: License Headers

**Angular repos:**
```bash
./check-headers.sh
```

Every source file (`.ts`, `.html`, `.scss`) must have the license header.

**If missing headers are found (auto-fix mode):**
- For `.ts` files, prepend: `// Copyright The Linux Foundation and each contributor to LFX.\n// SPDX-License-Identifier: MIT\n\n`
- For `.html` files, prepend: `<!-- Copyright The Linux Foundation and each contributor to LFX. -->\n<!-- SPDX-License-Identifier: MIT -->\n\n`
- For `.scss` files, prepend: `// Copyright The Linux Foundation and each contributor to LFX.\n// SPDX-License-Identifier: MIT\n\n`

**Go repos:**
Check for license headers in `.go` files. The standard Go license header format varies by repo — check existing files for the pattern.

## Check 3: Formatting

**Angular repos:**
```bash
yarn format
```

This auto-fixes formatting. If files changed, report which ones were formatted.

**Go repos:**
```bash
gofmt -l .
# If files need formatting (auto-fix mode):
gofmt -w .
```

## Check 4: Linting

**Angular repos:**
```bash
yarn lint
```

**Go repos:**
```bash
go vet ./...
# If golangci-lint is available:
golangci-lint run ./...
```

**If lint errors are found (auto-fix mode):**
1. Read the error output carefully
2. For auto-fixable issues (import order, unused imports), fix them directly
3. For non-auto-fixable issues (logic errors, type mismatches), report them and ask the contributor

### Re-validation

If fixes were applied in Checks 2-4, re-run lint to confirm:

**Angular:** `yarn lint`
**Go:** `go vet ./...`

## Check 5: Build Verification

**Angular repos:**
```bash
yarn build
```

**Go repos:**
```bash
go build ./...
# If Goa design was modified:
make apigen
go build ./...
```

**If build fails:**
1. Read the error output
2. Identify the file and line
3. If it's a simple fix (missing import, typo), fix it in auto-fix mode
4. If it's a structural issue, report it with context

## Check 6: Tests (if available)

**Angular repos:**
```bash
# Check if tests exist for modified files
git diff --name-only origin/main...HEAD | grep '\.spec\.ts$'
# If test files exist:
# yarn test --watch=false (only if the user confirms — tests can be slow)
```

**Go repos:**
```bash
# Run tests for packages with changes
go test ./...
```

Report test results but don't block on test failures unless the user asks.

## Check 7: Protected Files Check

```bash
git diff --name-only origin/main...HEAD
```

**Angular repos — flag changes to:**

- `apps/lfx-one/src/server/server.ts`
- `apps/lfx-one/src/server/server-logger.ts`
- `apps/lfx-one/src/server/middleware/*`
- `apps/lfx-one/src/server/services/logger.service.ts`
- `apps/lfx-one/src/server/services/microservice-proxy.service.ts`
- `apps/lfx-one/src/server/services/nats.service.ts`
- `apps/lfx-one/src/server/services/snowflake.service.ts`
- `apps/lfx-one/src/server/services/supabase.service.ts`
- `apps/lfx-one/src/server/services/ai.service.ts`
- `apps/lfx-one/src/server/services/project.service.ts`
- `apps/lfx-one/src/server/services/etag.service.ts`
- `apps/lfx-one/src/server/helpers/error-serializer.ts`
- `apps/lfx-one/src/app/app.routes.ts`
- `.husky/*`
- `eslint.config.*`
- `.prettierrc*`
- `turbo.json`
- `apps/lfx-one/angular.json`
- `CLAUDE.md`
- `check-headers.sh`
- `package.json` / `*/package.json`
- `yarn.lock`

**Go repos — flag changes to:**

- `gen/` (should only change via `make apigen`)
- `charts/` (deployment config — review carefully)
- `go.mod` / `go.sum` (dependency changes need review)
- `Makefile` (build system changes)

## Check 8: Commit Verification

```bash
git status
git log --format="%h %s%n%b" origin/main...HEAD
```

- **All changes committed?** — If auto-fixes created uncommitted changes, prompt to commit them
- **Commit messages follow conventions?** — `type(scope): description` format
- **`--signoff` on all commits?**
- **JIRA ticket referenced?**

## Check 9: Change Summary

```bash
git diff --stat origin/main...HEAD
```

List:

1. **New files created** — with their purpose
2. **Modified files** — with what changed
3. **Shared package changes** (Angular) or **Domain model changes** (Go)
4. **Backend changes** — controllers/services/routes (Angular) or Goa design/service (Go)
5. **Frontend changes** (Angular only)
6. **Helm chart changes** (Go repos with `charts/`)

---

# Phase 2: Code Review (Angular repos only)

**Skip this entire phase for Go repos or if `--skip-review` was passed.**

These checks are **always report-only** — they never auto-fix. The transformations are not safe to do mechanically (wrapper replacements need FormGroup wiring, `!` in `.ts` can be definite assignment, `BehaviorSubject` → `signal` needs cross-file changes, `ChangeDetectorRef` removal isn't always safe).

Scope all checks to **changed files only** (`git diff --name-only origin/main...HEAD`). These catch the patterns most commonly flagged by reviewers across 20+ LFX PRs.

## Review Check 1: Raw HTML Form Elements

Search **changed `.html` files** for raw form elements that must use LFX wrappers:

| Raw Element | Required Wrapper |
| --- | --- |
| `<input` | `lfx-input-text` (or other `lfx-input-*` variant) |
| `<select` | `lfx-select` |
| `<textarea` | `lfx-textarea` |
| `<div` with `animate-pulse` class | `<p-skeleton>` from PrimeNG |

**Exceptions:** Elements inside comments, or `<input type="hidden">` are acceptable.

**Note:** LFX wrappers require `FormGroup` + `FormControl` — `ngModel` is not supported.

**Severity:** BLOCKER — reviewers will always flag this.

## Review Check 2: Dead Code

For **TypeScript-only** items, search **all changed `.ts` files** for:

- **Unused imports** — imported symbols not referenced in the file body
- **Unused providers** — `providers: [...]` entries in component metadata where the service is never injected via `inject()` or constructor
- **Unused methods** — private methods not called anywhere in the file; public methods in services not called from any changed file
- **Unused signals** — signals declared but never read (called) in the template or class

For **unbound component outputs**, search **changed `.html` templates** (and, as needed, the referenced child component's `.ts` definition to see its `@Output()`s or `output()`s) for cases where a template uses a child component (e.g., `<lfx-votes-table>`) but does not bind its emitted outputs (e.g., `viewVote`, `rowClick`, `refresh`). Missing output bindings mean user interactions silently do nothing.

**Severity:** BLOCKER for unused providers/imports and unbound outputs. DISCUSS for unused methods (may be used externally).

## Review Check 3: Component Responsibility

Search **changed `*.component.ts` files** for service injection count (count `inject()` calls and constructor injections):

- **4+ service injections** → Flag for discussion. This often means the component is doing too much.
- **Multiple independent edit workflows** in a single component (e.g., separate forms that don't share state) → Suggest extracting sub-components.

**Severity:** DISCUSS — guideline, not a hard rule.

## Review Check 4: Loading States

Search **changed `.html` templates** and **`.ts` files** for:

- **Stats or counts rendered without loading check** — interpolations like `{{ count() }}` or `{{ stats().total }}` without a surrounding `@if (loading())` guard. These show `0` during loading instead of a placeholder.
- **Missing loading branch** — components that fetch data but have no `@if (loading())` / `@else` pattern.
- **Content that jumps** — `@for` loops rendering data without a loading skeleton before data arrives.
- **Loading not reset on re-fetch** — `loading` signal set to `false` after a fetch completes, but never set back to `true` when a new fetch starts (e.g., inside `switchMap` when input changes). Fix: set `loading.set(true)` at the start of each `switchMap` callback.

Every data display that starts empty and populates asynchronously needs an explicit loading branch showing `—`, `<p-skeleton>`, or equivalent.

**Severity:** BLOCKER for showing `0` during load. DISCUSS for missing re-fetch reset.

## Review Check 5: Type Safety

Search **changed `.html` templates** for:

- **Non-null assertions (`!`)** — patterns like `data()!.field` or `item!.property` in templates. These cause runtime crashes when the value is null/undefined. Use `?.` and `@if (data(); as d)` guards instead.

Search **changed `.ts` files** for:

- **Non-null assertions (`!`)** — in `.ts` files, `!` is also used for definite assignment (`foo!: T`) and may already be runtime-guarded. Report for manual review only — do not suggest automatic replacement.
- **Falsy `||` vs nullish `??`** — using `||` where `??` is needed. `value || null` treats `0`, `""`, and `false` as falsy — hiding valid zero counts (e.g., `total_members || null` hides `0` members). Use `??` to only coalesce on `null`/`undefined`.

**Severity:** BLOCKER for `!` assertions in templates. DISCUSS for `!` in `.ts` and `||` vs `??`.

## Review Check 6: Error Handling

Search **changed `.ts` files** for:

- **Silent `catchError`** — `catchError(() => of([]))` or `catchError(() => EMPTY)` without any logging before the fallback. Every `catchError` should log via `logger` service or `console.error` at minimum.
- **Duplicate/layered error handling** — when a service method already has `catchError` that returns a default (e.g., `of([])`), a component-level `catchError` on the same stream is unreachable dead code. Handle errors in one place — either the service or the component, not both.
- **Inconsistent fallback values** — mixing `EMPTY` and `of([])` in the same service. Pick one pattern.
- **Removed error logging** — check `git diff` for removed `console.error` or `logger.error` calls that weren't replaced.

**Severity:** BLOCKER for silent or unreachable `catchError`. DISCUSS for inconsistent fallbacks.

## Review Check 7: Signal Pattern Compliance

Search **changed `*.component.ts` and `*.service.ts` files** for:

- **`BehaviorSubject` for simple state** — should use `signal()` instead. `BehaviorSubject` is only appropriate for complex async streams that need RxJS operators.
- **`cdr.detectChanges()` or `ChangeDetectorRef`** — often not required in zoneless Angular 20 when using Angular's reactive primitives (signals, `AsyncPipe`, `toSignal`, etc.), but may still be needed for integrations with non-Angular event sources or advanced `OnPush` patterns. Flag for manual review.
- **`model()` for internal state** — `model()` creates a two-way bindable input/output on the component's public API. For internal-only state (e.g., dialog visibility, drawer toggles not exposed to parents), use `signal()` instead. Only use `model()` when the parent component needs two-way binding (e.g., `[(visible)]="childVisible"`).
- **Signals not initialized inline** — per `component-organization.md`, simple `WritableSignal`s must be initialized directly (e.g., `loading = signal(false)`), not in the constructor.

**Severity:** BLOCKER for `BehaviorSubject` misuse. DISCUSS for `ChangeDetectorRef` and `model()` usage.

## Review Check 8: Upstream API Alignment

Search **changed `.ts` files** for API calls and verify:

- **Parameter names match upstream** — known divergences:
  - Meetings API uses `limit` for pagination
  - Votes/Surveys APIs use `page_size` for pagination
  - Don't mix these up
- **No invented fields** — if the code references a field in an API response, verify it exists in the upstream contract.
- **No UI for non-existent backend fields** — form fields or display elements bound to data that the API doesn't actually return.

If you cannot verify the upstream contract from the local codebase, flag for manual verification.

**Severity:** BLOCKER for clearly wrong parameter names. DISCUSS for fields needing upstream verification.

## Review Check 9: PR Description Completeness

Check the **git log and diff** for changes that need explicit documentation in the PR description:

- **Removed UI elements** — deleted components, removed buttons/fields/sections from templates.
- **Permission check changes** — modifications to FGA checks, role guards, or auth logic.
- **Error handling behavior changes** — changed fallback values, modified retry logic, altered error messages.

**Severity:** DISCUSS

## Review Check 10: Accessibility

Search **changed `.html` templates** for:

- **Missing `aria-pressed` on toggle buttons** — button groups acting as toggles must have `[attr.aria-pressed]="isActive()"`.
- **Nested interactive elements** — a clickable `<div (click)>` containing an `<lfx-button>` or `<a>`.
- **Focusable elements behind overlay/blur masks** — use `[attr.tabindex]="-1"`, `inert`, or conditionally render elements.
- **Missing `aria-label` on icon-only buttons**.

**Severity:** DISCUSS

## Review Check 11: Design Token Compliance

Search **changed `.html` templates** for hardcoded Tailwind color classes that should use LFX design tokens:

- **Hardcoded colors** — `bg-blue-50`, `text-gray-300`, `border-blue-100`, etc. Check `tailwind.config.js` for the custom LFX color palette. Raw Tailwind defaults are not design tokens.

**Severity:** DISCUSS

## Review Check 12: N+1 API Patterns

Search **changed `.ts` files** for per-item API calls inside loops:

- **Per-item fetches** — `.map(item => this.http.get('/api/' + item.id))` or `forkJoin(items.map(...))` where a batch endpoint exists.
- **Backend too:** In Express controllers, `await` inside `for`/`forEach`/`.map()` loops calling `microserviceProxy.proxyRequest()`.

**Severity:** DISCUSS

## Review Check 13: Template/Config Completeness

Search **changed `.html` templates and `.component.ts` files** for:

- **Missing `@switch` cases** — if a component defines tabs/routes/modes in a config array, every entry must have a corresponding `@case` in the template. A tab in config without a matching case renders blank content.
- **`activeTab` not constrained to visible set** — if tabs are conditionally visible, ensure `activeTab` resets to a valid tab when the visible set changes.
- **Partial feature wiring** — form controls, outputs, or config entries added but not fully connected.

**Severity:** BLOCKER for missing switch cases. DISCUSS for partial wiring.

## Review Check 14: Stale Data During Navigation

Search **changed `*.component.ts` files** for:

- **One-time initialization that should react to changes** — `if (!this.data())` guards that only load data on first render, not when route params change.
- **Early returns that skip state reset** — guard clauses that exit before resetting `loading` or `saving` signals, leaving the UI stuck.
- **`track $index` in `@for` loops** — causes unnecessary DOM churn when items reorder. Prefer `track item.uid` or a stable identifier.

**Severity:** DISCUSS

## Review Check 15: Visitor/Permission Gating

Search **changed `.html` templates** for:

- **Content visible during role loading** — `@if (!isVisitor())` evaluates to `true` while `myRoleLoading()` is still `true` (because `isVisitor()` defaults to `false`). Fix: add `!myRoleLoading()` to the guard.
- **Visitor blur bypass** — blur overlays that don't prevent keyboard/screen-reader access (see Review Check 10).
- **Permission changes not documented** — if the diff adds/removes/changes `canEdit()`, `isVisitor()`, `hasPMOAccess()` checks, flag for PR description.

**Severity:** BLOCKER for content flashing during role loading. DISCUSS for blur bypass.

---

# Results Report

**Output the two-phase report:**

```text
═══════════════════════════════════════════
PREFLIGHT RESULTS
═══════════════════════════════════════════

PHASE 1: VALIDATION
═══════════════════
✓ Working tree     — Clean, N commits ahead of main
✓ License headers  — All files have headers (2 auto-fixed)
✓ Formatting       — Applied (3 files reformatted)
✓ Linting          — No errors
✓ Build            — Succeeded
✓ Tests            — N/A (no test files for changed code)
✓ Protected files  — None modified
✓ Commits          — Conventions followed, signed off

Changes summary:
  - 2 files modified in packages/shared/
  - 3 files modified in apps/lfx-one/src/app/modules/committees/
  - 0 protected files touched

Auto-fixes applied:
  - Added license header to member-form.component.ts
  - Added license header to member-form.component.html
  - Reformatted 3 files with prettier

PHASE 2: CODE REVIEW (Angular)
══════════════════════════════
 1. ✓ Raw HTML elements     — No raw inputs/selects/textareas found
 2. ⚠ Dead code             — 2 unused imports in settings.service.ts
 3. ✓ Component size        — All components under 4 injections
 4. ✓ Loading states        — All data displays have loading guards
 5. ✓ Type safety           — No non-null assertions or || vs ?? issues
 6. ✓ Error handling        — All catchError blocks have logging
 7. ✓ Signal patterns       — No BehaviorSubject or ChangeDetectorRef issues
 8. ✓ API alignment         — Parameters match upstream contracts
 9. ✓ PR description        — Behavioral changes documented
10. ⚠ Accessibility         — Toggle buttons missing aria-pressed (discuss)
11. ✓ Design tokens         — No hardcoded color classes
12. ✓ N+1 patterns          — No per-item API calls in loops
13. ✓ Template completeness — All config entries have matching template cases
14. ✓ Stale data            — Components re-fetch on input changes
15. ✓ Visitor gating        — Permission guards include loading checks

═══════════════════════════════════════════
REVIEW READY (2 discussion items)
═══════════════════════════════════════════
```

**Legend:**

- `✓` — Pass. No issues found.
- `⚠` — Discuss. Not a blocker, but should be considered.
- `✗` — Blocker. Must be fixed before submitting the PR.

**Final verdict line:**

- All `✓` → `REVIEW READY`
- Has `⚠` only → `REVIEW READY (N discussion items)`
- Has any `✗` in Phase 1 or Phase 2 → `NOT READY — N blockers must be fixed`

### If Blockers Are Found

For each blocker, provide:

1. **File and line** where the issue occurs
2. **What's wrong** in plain language
3. **How to fix it** with a concrete example

### If Phase 1 Auto-Fixes Created Uncommitted Changes

After auto-fixing, check for uncommitted changes:

```bash
git status --porcelain
```

If there are uncommitted changes from auto-fixes, ask:
> "Preflight auto-fixed some issues (formatting, license headers). Would you like me to commit these fixes?"

### If All Checks Pass

> "Your changes look good and are ready for review! Would you like me to create the pull request?"

### If Checks Fail

Report failures in plain language, explaining what each means:
> "Found 2 issues that need attention:
> 1. **Build error**: [plain explanation of what went wrong and whether it can be auto-fixed]
> 2. **Missing signoff**: [plain explanation and what the user needs to do]
>
> Want me to fix what I can automatically?"

## Scope Boundaries

**This skill DOES:**
- Run format, lint, build checks (Phase 1, auto-fix)
- Auto-fix formatting and license headers
- Run 15 code review pattern checks for Angular repos (Phase 2, report-only)
- Report protected file changes
- Verify commit conventions
- Offer to create PR after passing

**This skill does NOT:**
- Auto-fix Phase 2 code review findings (report-only — contributor decides)
- Generate new code (use `/lfx-backend-builder` or `/lfx-ui-builder`)
- Make architectural decisions (use `/lfx-product-architect`)
- Research upstream APIs (use `/lfx-research`)
