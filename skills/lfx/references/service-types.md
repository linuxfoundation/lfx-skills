<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Service Types: Classification (Routing-Level)

V2 services fall into three classes (native, wrapper, proxy/consumer).
Classification is the first decision before reaching for an implementation
template.

For the **authoritative explanation** (definitions, examples, picking a
template, where the canonical native/wrapper template docs live), use the
`/lfx-platform-architecture` skill.

| Class | Quick sense | Canonical template repo |
| --- | --- | --- |
| Native | Owns its data in NATS JetStream KV; full CRUD via Goa | `lfx-v2-project-service` |
| Wrapper | Proxies an external system (ITX, Groups.io, Zoom) and translates | `lfx-v2-voting-service` |
| Proxy / consumer | Thin HTTP-to-NATS wrapper around platform plumbing | `lfx-v2-access-check`, `lfx-v2-auth-service` |

After classifying, hand off to `/lfx-platform-architecture` for the platform
shape and to the template repo's `docs/agent-guidance/` for implementation
patterns.
