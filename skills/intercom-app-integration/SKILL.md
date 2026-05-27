---
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
name: intercom-app-integration
description: Use for any Intercom work at LFX. Two paths. (1) Code integration: add the Intercom widget to a consumer app, fix an existing app-side integration, or standardize the boot/identity/shutdown lifecycle. Current code consumers are `insights` (Vue/Nuxt) and `crowd.dev` (Vue/Vite); `lfx-self-serve` is NOT a code consumer. Code path covers JWT identity verification via the http://lfx.dev/claims/intercom Auth0 claim, anonymous + identified boot, CSP origin list, environment variables, and coordination with auth0-terraform, identity-cookie-helper, and lfx-v2-argocd. Angular reference kept for future consumers. (2) Fin AI optimization (support/CX, no code): Fin Guidance writing, Help Center content quality, resolution rate, escalation patterns, Topics Explorer, Fin Attributes, Copilot tips, daily review rituals, content quality framework, benchmarks. Triggers include "add Intercom", "Intercom widget", "Intercom boot", "intercomSettings", "intercom_user_jwt", "fix Intercom integration", "Intercom identity verification", "Fin tips", "improve Fin", "Fin guidance", "Fin resolution rate", "Help Center optimization", "Copilot tips", "Fin re-engagement", "Fin handoff", "Fin Attributes".
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# Intercom App Integration

This skill covers both Intercom workflows at LFX. Pick the path based on what the user needs.

**Code integration (developer path).** Add or fix the Intercom widget in a consumer app. Continue with the sections below.

**Fin AI optimization (support/CX path).** Improve Fin Agent resolution rates, Fin Guidance writing, Help Center content quality, escalation paths, Copilot, Fin Attributes, daily review rituals, content quality framework. No code work required. Read `references/fin-best-practices.md` and advise from there.

---

You are adding or fixing the Intercom widget in an LFX consumer app. The pattern is the same regardless of framework: load the Intercom script, set `window.intercomSettings`, boot anonymously for public-page apps, upgrade to identified using the Auth0-issued JWT claim, and shut down cleanly on logout.

**Current consumers (verified):**
- `insights` — Vue/Nuxt, plugin at `frontend/app/plugins/intercom.ts`.
- `crowd.dev` — Vue/Vite, utility at `frontend/src/utils/intercom/index.ts`.

**Not a consumer:** `lfx-self-serve` was verified to have no Intercom integration. Do not add Intercom to lfx-self-serve unless explicitly requested as a new feature.

This skill is intentionally central. Consuming apps are not required to vendor a local copy of the template; activating this skill in the consuming app's session is enough. If a consuming app later wants to localize, copy the framework-specific reference into the app's own `.claude/skills/intercom-app/SKILL.md`.

## The four boundaries

| Boundary | Owner | What it owns |
|---|---|---|
| Control plane | `auth0-terraform` | The `custom_claims` Action that emits the `http://lfx.dev/claims/intercom` JWT (HS256, 12h expiry, `{user_id, email, name?}` payload), HMAC deprecation policy, App ID constants. |
| Identity bridge | `identity-cookie-helper` | OAuth2/OIDC flow, identify-page rendering, route-specific CSP, Intercom Admin hostname allow-list coordination. |
| App-side widget | The consuming app repo | Script load, `window.Intercom` boot/shutdown lifecycle, JWT pre-set in `intercomSettings`, app-side CSP, env vars. **This skill operates here.** |
| Deployed values | `lfx-v2-argocd` | `AUTH0_*`, `INTERCOM_APP_ID`, ExternalSecret refs under `values/{env}/` and `custom-resources/<app>/`. |

## Workflow

1. **Gather context.** Ask the user:
   - Goal: fresh install or fix/standardize an existing integration?
   - Exact Auth0 client name (must match the `case` in `custom_claims` Action exactly).
   - Public-pages app or auth-only app? (Public-pages apps need an anonymous boot so banners show to visitors.)
   - Framework: Angular (6 ngrx or 14+ standalone/signals), Vue/Nuxt, or Vue/Vite.
   - LaunchDarkly in use? If yes, gate Intercom behind `enable-intercom`.
   - App ID confirmation: Dev `mxl90k6y`, Prod `w29sqomy` (shared across all LFX apps).

2. **Pick the framework reference.**
   - **Vue/Nuxt (current consumer: `insights`)** → use `insights/frontend/app/plugins/intercom.ts` as the working reference. It is the current canonical Vue/Nuxt implementation (anonymous boot via `requestIdleCallback` for CLS safety, upgrade on `useAuth` watch, full shutdown on logout). Adapt the same lifecycle: stub, load script, set `intercomSettings` with the JWT, call `Intercom('boot', { app_id, user_id, name, email })`, call `Intercom('shutdown')` on logout.
   - **Vue/Vite (current consumer: `crowd.dev`)** → use `crowd.dev/frontend/src/utils/intercom/index.ts` as the working reference. Same lifecycle; auth wiring lives in `src/modules/auth/store/auth.actions.ts`; config in `src/config.js`.
   - **Angular (for future consumers; no current Angular consumer)** → read `references/angular-template.md` and follow Steps 1-7. Covers Angular service shape, app-component wiring, anonymous→identified upgrade, public vs auth-only apps. Note: `lfx-self-serve` is the only LFX Angular app and currently does NOT use Intercom; this reference is preserved for future Angular consumers.

3. **Audit the existing integration before writing code.** Search the repo and produce a gap report. The Angular template Step 2 has a complete checklist that translates 1:1 to Vue. Key checks regardless of framework:

   - Direct script injection (not the `@intercom/messenger-js-sdk` npm package).
   - Stub function that queues commands before the script loads.
   - JWT pre-set in `window.intercomSettings.intercom_user_jwt` *before* `Intercom('boot')`.
   - JWT stripped from the boot options payload.
   - Anonymous boot in app init (for public-pages apps).
   - Anonymous→identified upgrade using a `bootedWithIdentity` flag and a re-boot via `shutdown` then `boot`.
   - `Intercom('shutdown')` on logout, JWT cleared from settings, anonymous re-boot for public-pages apps.
   - Auth0 claim URL: `http://lfx.dev/claims/intercom` (the JWT claim, not the deprecated HMAC).
   - CSP includes all Intercom origins, including the `wss://` WebSocket entries (see canonical list below).

4. **Add env vars / runtime config.** Four fields per environment:
   - `intercomId` (or framework-specific: `intercomId` in Nuxt runtime config, `VUE_APP_INTERCOM_APP_ID` in Vite env, `intercomId` in Angular `environment.ts`).
   - `intercomApiBase`: `https://api-iam.intercom.io`.
   - `auth0IntercomClaim`: `http://lfx.dev/claims/intercom`.
   - `auth0UsernameClaim`: `https://sso.linuxfoundation.org/claims/username`.

5. **Implement the lifecycle.** Use the framework-appropriate reference (Step 2). The boot lifecycle is identical across frameworks:
   - Public-pages app: page load → anonymous boot → on login, shutdown + re-boot with identity → on logout, shutdown + re-boot anonymous.
   - Auth-only app: page load → wait → on login, boot with identity → on logout, shutdown.

6. **Coordinate with Auth0 (REQUIRED).** Confirm the consuming app is in the `custom_claims` Action switch in `auth0-terraform`. If not, route the Auth0 change to the `auth0-intercom-claim` skill in `auth0-terraform`. Without this step, `http://lfx.dev/claims/intercom` is missing from the ID token and identity verification silently fails.

7. **Coordinate hostname allow-listing (if deploying to a new domain).** Intercom enforces a workspace hostname allow-list. New domains, subdomains, and preview environments must be added by the Intercom Admin (Heather's team). The chat bubble silently fails on unlisted hostnames even when the JWT is correct. The identity-bridge side of this coordination is owned by `identity-cookie-helper`; reference its `intercom-identity-bridge.md` for the full workflow.

8. **Verify.**
   - Decode a fresh ID token (e.g. `jwt.io`) and confirm `http://lfx.dev/claims/intercom` is present with `user_id` and `email`.
   - Run the app on `127.0.0.1` locally (Intercom does not work on `localhost`).
   - Anonymous visitor: banners/popups visible before login.
   - Logged-in user: chat bubble shows identity in the Intercom dashboard.
   - Logout: clean shutdown, anonymous session re-boots (public-pages apps).
   - `window.Intercom('getVisitorId')` returns a string in the console.

## Canonical CSP origin list

Add ALL of these to the app's Content Security Policy. The `wss://` WebSocket entries are required for real-time chat. The identity bridge in `identity-cookie-helper` uses the same canonical list for its identify page; keep these in sync.

```text
script-src   https://widget.intercom.io https://*.intercomcdn.com
connect-src  https://*.intercom.io https://*.intercomcdn.com https://*.intercom-messenger.com
             wss://*.intercom-messenger.com wss://*.intercom.io
style-src    https://*.intercomcdn.com
font-src     https://*.intercomcdn.com
img-src      https://static.intercomassets.com https://*.intercomcdn.com
frame-src    https://*.intercom.io https://*.intercom-messenger.com https://intercom-sheets.com
media-src    https://js.intercomcdn.com
```

## Do Not

- Do not use an npm Intercom package. LFX uses direct script injection consistently.
- Do not create a new Intercom workspace or App ID. Dev (`mxl90k6y`) and Prod (`w29sqomy`) are shared across every LFX app.
- Do not boot identified Intercom without the JWT. Booting without it allows impersonation.
- Do not put JWT values in logs, commits, or PR descriptions.
- Do not modify Auth0 Action code from the consuming app repo. Route Auth0 changes to `auth0-terraform`.
- Do not modify identity-bridge behavior from the consuming app repo. Route bridge changes to `identity-cookie-helper`.

## References

- Fin AI optimization (support/CX, no code): `references/fin-best-practices.md` — Fin Guidance writing, Help Center content quality, escalation patterns, Topics Explorer, Fin Attributes, Copilot tips, content quality framework, real-world benchmarks.
- Current Vue/Nuxt working reference (insights): `insights/frontend/app/plugins/intercom.ts`.
- Current Vue/Vite working reference (crowd.dev): `crowd.dev/frontend/src/utils/intercom/index.ts`.
- Angular template (for future consumers; no current Angular consumer): `references/angular-template.md` — complete Angular service + app-component wiring, audit checklist, lifecycle for public-pages and auth-only apps.
- Auth0 control-plane mechanics: `auth0-terraform/docs/agent-guidance/intercom-auth0-claims.md`.
- Identity bridge: `identity-cookie-helper/docs/agent-guidance/intercom-identity-bridge.md`.
- Deployed values: `lfx-v2-argocd/docs/agent-guidance/auth0-intercom-deployed-values.md`.

## Maintenance

The canonical reference Angular app for this pattern is **LFX Mentorship** (`jobspring` / `lfx-mentorship-upgrade` repo). When in doubt about what "correct" looks like for the Angular path, check how Mentorship implements it; Crowdfunding and PCC follow the same pattern and can be used for cross-validation.

If you find this skill is outdated, update it in the same PR where you fix the consuming app. The skill is wrong for everyone until it is fixed.
