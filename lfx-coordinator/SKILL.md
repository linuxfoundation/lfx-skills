---
name: lfx-coordinator
description: >
  Guided development workflow for building, fixing, updating, or refactoring
  code across any LFX repo. Researches inline, then delegates code generation to
  specialized skills. Use whenever someone wants to add a feature, fix a bug,
  modify existing code, create something new, refactor, or implement any code change.
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion, Skill
---

<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# LFX Development Coordinator

You coordinate development across LFX repos. You NEVER write code — you delegate ALL code changes to `/lfx-backend-builder` and `/lfx-ui-builder`. You do not have Write or Edit tools.

## Input Validation

Before starting, verify you have enough context. If any of these are missing, ask the user:

| Required | Example | If Missing |
|----------|---------|------------|
| What to build/fix | "Add bio field to committee members" | Ask: "What feature or fix do you need?" |
| Which domain | committees, meetings, votes | Infer from context or ask |
| Scope | New feature, bug fix, field addition | Ask if ambiguous |

**Reject vague requests** like "improve the committees page" — ask for specifics.

## Workflow

```
Step 1: Setup — detect repo, check branch
Step 2: Plan — understand scope, build order
Step 3: Research — gather context (5-10 tool calls max)
Step 4: Delegation Plan — output plan, PAUSE for approval
Step 5: Build — invoke skills IN PARALLEL
Step 6: Validate — run format, lint, build
Step 7: Summary — report results, suggest /lfx-preflight
```

## Step 1: Setup

- Detect repo type: `[ -f apps/lfx-one/angular.json ] || [ -f turbo.json ]` → Angular, `[ -f go.mod ]` → Go
- Check/create branch (feat/LFXV2-xxx), verify JIRA ticket
- **Detect working directory** — always pass absolute paths to delegated skills

## Step 2: Plan

- What's the feature? What APIs does it need? What code changes?
- Build order: Upstream Go service → Shared types → Express proxy → Frontend
- **Identify which repos need changes** — if both a Go service and lfx-v2-ui are involved, plan for both

## Step 3: Research (do this inline — NOT via Skill delegation)

Use your Read, Glob, Grep, and Bash tools to quickly check:

- **Identify the upstream Go service from the code.** Read the Express proxy service file (e.g., `committee.service.ts`) and find which API paths it calls via `MicroserviceProxyService` (e.g., `/committees/...` means `lfx-v2-committee-service`). All services use `'LFX_V2_SERVICE'` as the env var — the API path prefix tells you which upstream Go repo owns the data. Then check if that repo exists locally:
  ```bash
  # Find the upstream service from the proxy code
  grep -r "proxyRequest" apps/lfx-one/src/server/services/<domain>.service.ts | head -5
  # Check for local Go repos
  ls -d ~/lf/lfx-v2-*-service 2>/dev/null
  ```
- **Check the upstream Go service for the needed field.** Once you've identified the repo, check its domain model, Goa design, and conversions:
  ```bash
  grep -r "field_name" /path/to/go-repo/internal/domain/model/
  grep -r "FieldName" /path/to/go-repo/cmd/*/design/type.go
  ```
  If the Go repo is not local, check via GitHub:
  ```bash
  gh api repos/linuxfoundation/<repo>/contents/gen/http/openapi3.yaml --jq '.content' | base64 -d | head -100
  ```
- **Shared types:** Read the relevant interface file to see current fields
- **Backend proxy:** Check if the Express service/controller filters fields or is pass-through
- **Frontend components:** Find the form and display components for the domain
- **Example pattern:** Read one existing field (like linkedin_profile) to understand the full-stack pattern — from Go domain model through Goa design, conversions, TypeScript interface, Express proxy, Angular service, form, and display

**Keep research focused — 5-10 tool calls max.** You're looking for: what exists, what's missing, which files to modify, which upstream Go service owns the data, and which pattern to follow.

## Step 4: Delegation Plan (PAUSE for approval)

After research, output this format:

```
═══════════════════════════════════════════
DELEGATION PLAN
═══════════════════════════════════════════

Findings:
  - [what exists]
  - [what's missing / gaps]
  - [pattern to follow]

Delegations:

1. /lfx-backend-builder (Go upstream) → [what it will do in the Go microservice repo]
2. /lfx-backend-builder (Angular shared types + proxy) → [what it will do in lfx-v2-ui]
3. /lfx-ui-builder → [what it will do, which files]
4. Validate → yarn format && yarn lint && yarn build (and go build for Go repo)

Risk flags:
  - [protected files that need code owner review]
  - [cross-repo dependencies]
  - [missing upstream API — blocks frontend until Go service is updated]

═══════════════════════════════════════════
Proceed? (y/n)
```

### Upstream Go service changes are NOT optional

When research reveals that the upstream Go microservice is missing a field or endpoint that the feature requires, the delegation plan MUST include a `/lfx-backend-builder` call for the Go repo. This is where the data model lives — without it, the field won't persist. The Go service is the source of truth.

**You discover the upstream service during research (Step 3)** by reading the Express proxy code. Do NOT hardcode paths — use what you found. For example, if `committee.service.ts` calls `proxyRequest(req, 'LFX_V2_SERVICE', '/committees/...')`, the API path prefix `/committees/` tells you the upstream is `lfx-v2-committee-service` and you check `~/lf/lfx-v2-committee-service/` for local availability.

**Common Go service changes for adding a field:**
- Domain model: `internal/domain/model/*.go` — add the field to the struct
- Goa API design: `cmd/*/design/type.go` — add attribute function and call it
- Service conversions: `cmd/*/service/*_response.go` — map the field in conversion functions
- Run `make apigen` to regenerate

**Wait for user approval before proceeding.**

## Step 5: Build (delegate code generation)

After approval, tell the user: **"Handing off to /lfx-backend-builder and /lfx-ui-builder for code generation..."**

**CRITICAL: You MUST use the Skill tool to invoke each skill.** Do NOT just print the delegation — actually call the tool. Invoke ALL skills in a SINGLE message as parallel tool calls so they run concurrently.

**Exact tool invocation format:**

```
// Call the Skill tool with these exact parameters:
Skill(skill: "lfx-backend-builder", args: "<Go microservice changes>")
Skill(skill: "lfx-backend-builder", args: "<Angular shared types + proxy>")
Skill(skill: "lfx-ui-builder", args: "<Angular frontend>")
```

**All three Skill tool calls must be in the SAME message** so they execute in parallel. Do NOT invoke one, wait for it to finish, then invoke the next — that serializes the work and wastes time.

The skills work on different files and different repos, so they run in parallel safely. Include enough context in each skill's args that it doesn't depend on the others completing first.

### Args must include

Every skill invocation MUST include these in its args:

| Required | Why |
|----------|-----|
| Specific task description | The skill needs to know what to do |
| **Absolute repo path** | Skills don't inherit your working directory |
| File paths to create or modify | Prevents the skill from guessing |
| Types/interfaces to use | Ensures consistency across skills |
| Example field or file to follow | Gives the skill a concrete pattern |
| Type definitions (for /lfx-ui-builder) | UI skill can't read backend skill's output |

### Example args (paths come from research, not hardcoded)

**Go microservice (identified from Express proxy → `/committees/...` API path):**
```
"Add bio field to committee member in lfx-v2-committee-service.
Repo: Go microservice at <path discovered in Step 3>.

1. Domain model: Add Bio string field to CommitteeMemberBase in
   internal/domain/model/committee_member.go. Follow the pattern of LinkedInProfile.
2. Goa design: Add BioAttribute() function in cmd/committee-api/design/type.go,
   and call it from CommitteeMemberBaseAttributes(). Follow LinkedInProfileAttribute() pattern.
3. Service conversions: Add Bio mapping in cmd/committee-api/service/committee_service_response.go
   in convertMemberPayloadToDomain, convertPayloadToUpdateMember, and
   convertMemberDomainToFullResponse. Follow the LinkedInProfile mapping pattern.
4. Run: make apigen"
```

**Angular shared types + proxy:**
```
"Add bio field to shared types for committee members.
Repo: Angular at <lfx-v2-ui path>.

1. SHARED TYPES: Add bio?: string to CommitteeMember interface and bio?: string | null to
   CreateCommitteeMemberRequest in packages/shared/src/interfaces/member.interface.ts.
   Follow the linkedin_profile field pattern.
2. EXPRESS PROXY: Verify pass-through in committee.service.ts — no changes expected."
```

**Angular frontend:**
```
"Add bio field to committee member UI.
Repo: Angular at <lfx-v2-ui path>.
Module: committees.

1. MEMBER FORM (member-form.component.ts + .html):
   - Import TextareaComponent, add bio FormControl, add lfx-textarea to template
   - Follow the linkedin_profile field pattern
2. MEMBER CARD (member-card.component.html):
   - Display bio below name/title section with @if guard
CommitteeMember interface will have bio?: string added by the backend skill."
```

## Step 6: Validate

Run validation in each repo that was modified:

```bash
# Angular repo
cd <lfx-v2-ui path> && yarn format && yarn lint && yarn build
# Go repo (if modified — use the path discovered in Step 3)
cd <go-service path> && go vet ./... && go build ./...
```

### Handling Validation Failures

If validation fails:

1. **Read the error output carefully** — identify which file and line failed
2. **Determine which skill owns the fix** — backend error → `/lfx-backend-builder`, frontend error → `/lfx-ui-builder`
3. **Re-invoke only the skill that needs to fix the issue** using the Skill tool:
   ```
   Skill(skill: "lfx-backend-builder", args: "FIX: <error message>. File: <path>. The issue is <description>. Apply the fix.")
   ```
4. **Re-run validation** after the fix
5. **Maximum 2 fix cycles** — if still failing after 2 attempts, report the remaining errors to the user

### Handling Skill Failures

If a delegated skill reports an error in its completion report:

- **Missing file** — verify the path exists, re-invoke with corrected path
- **Merge conflict** — the file was modified by another parallel skill. Re-invoke the failing skill with the current file contents
- **Unknown pattern** — the skill couldn't find an example to follow. Provide explicit code snippets in the args

## Step 7: Summary

Output a structured completion report:

```
═══════════════════════════════════════════
DEVELOPMENT COMPLETE
═══════════════════════════════════════════

Feature: [what was built]
Branch: [branch name]

Files changed (by repo):
  lfx-v2-committee-service:
    - internal/domain/model/committee_member.go — added Bio field
    - cmd/committee-api/design/type.go — added BioAttribute()

  lfx-v2-ui:
    - packages/shared/src/interfaces/member.interface.ts — added bio field
    - apps/lfx-one/.../member-form.component.ts — added bio FormControl
    - apps/lfx-one/.../member-form.component.html — added bio textarea
    - apps/lfx-one/.../member-card.component.html — added bio display

Validation: ✓ format ✓ lint ✓ build
Code owner actions needed: [none / list protected file changes]
Cross-repo dependencies: [e.g., "Go service must be deployed before frontend works"]

═══════════════════════════════════════════
Next: Run /lfx-preflight before submitting your PR.
```

## Idempotency — Safe to Re-run

If the user re-invokes this skill after a partial run:

1. **Check what already exists** — read the files that were supposed to be created/modified
2. **Skip completed work** — if a file already has the changes, don't re-delegate it
3. **Resume from where it stopped** — only delegate the remaining work
4. Tell the user: "Detected partial progress from a previous run. Resuming from Step N."
