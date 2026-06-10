<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Service Types: Classification (Routing-Level)

V2 services fall into three classes (native, wrapper, proxy/consumer), plus
platform services that provide shared infrastructure behavior. Classification
is the first decision before reaching for implementation guidance.

For the authoritative explanation of service classes, platform responsibilities,
and cross-service handoff points, use the `/lfx-skills:lfx-platform-architecture` skill.
For Go coding conventions, rely on the owning repo's path-scoped
`<short-repo-name>-dev` skill after routing.

| Class | Quick sense | Living examples |
| --- | --- | --- |
| Native | Owns its data in NATS JetStream KV; full CRUD via Goa | `lfx-v2-project-service` |
| Wrapper | Proxies an external system (ITX, Groups.io, Zoom) and translates | `lfx-v2-voting-service` |
| Proxy / consumer | Thin HTTP-to-NATS wrapper around platform plumbing | `lfx-v2-access-check`, `lfx-v2-auth-service` |

After classifying, hand off to the owning repo's `CLAUDE.md`, path-scoped
`<short-repo-name>-dev` skill, and the top-level `docs/` contract files
named by that repo's `CLAUDE.md` for concrete contracts and implementation
rules. Use `docs/agent-guidance/` only where `repo-map.md` explicitly lists it
as a transitional owner path.
