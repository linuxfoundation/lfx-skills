<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Service Types: Native vs Wrapper

Resource services come in two flavors. Identifying the type determines which template to
follow and what the service is responsible for.

## Native Resource Services

**Own their data** — stored in NATS JetStream KV buckets.

Examples: `lfx-v2-project-service`, `lfx-v2-committee-service`

| Aspect | Detail |
|---|---|
| Data storage | NATS JetStream KV (one or more buckets) |
| API | Full CRUD |
| External dependencies | None for data; may call other LFX services via NATS request/reply |
| NATS publishing | Both index + access messages on every write |
| Template | `lfx-v2-committee-service` (newest — use this) |

> **Do not use `project-service` as a template.** It uses the deprecated enricher pattern
> for indexing. `committee-service` is the correct reference.

### Key structures

```text
internal/
├── domain/model/         ← domain structs with Tags() method
├── domain/port/          ← reader/writer/publisher interfaces
├── infrastructure/nats/
│   ├── client.go         ← NATS connection + KV bucket initialization
│   ├── storage.go        ← KV CRUD with optimistic locking via revision
│   └── messaging_publish.go  ← publishes to indexer + fga-sync
└── service/
    ├── {resource}_writer.go  ← orchestrates writes: storage + concurrent NATS publish
    └── {resource}_reader.go
```

### Optimistic locking

Every KV read returns a revision number. Updates and deletes must pass it back:

```go
// Get returns the revision alongside the data
base, revision, err := storage.GetBase(ctx, uid)

// Update requires the same revision — fails if something else wrote in between
err = storage.Update(ctx, updatedResource, revision)
```

This is what the `If-Match` HTTP header maps to in the API design.

---

## Wrapper Resource Services

**Do not own data** — proxy to an external system (e.g. ITX) for all data operations.

Examples: `lfx-v2-meeting-service`, `lfx-v2-voting-service`, `lfx-v2-survey-service`

| Aspect | Detail |
|---|---|
| Data storage | None — external system owns it |
| API | Translates LFX Self-Service API ↔ external system API |
| NATS publishing | Index + access messages on writes (same rule as native) |
| Template | `lfx-v2-voting-service` |

### Wrapper pattern (voting-service)

Translates between the LFX Self-Service API and an external HTTP API, then publishes
NATS messages on writes:

```text
HTTP Write Request
    → VotingAPI handler
        → VoteService.Create(ctx, vote)
            → ITX proxy client (external HTTP call)
            → on success: NATSPublisher.PublishVoteEvent (index + access messages)

HTTP Read Request
    → VotingAPI handler
        → VoteService.Get(ctx, uid)
            → ITX proxy client (external HTTP call)
            → translate + return response
```

### ID mapping in wrappers

Some wrappers (like meeting-service) need to translate between LFX v2 UUIDs and legacy v1
IDs when calling the external system:

```go
idMapper = idmapper.NewNATSMapper(idmapper.Config{
    URL:     natsURL,
    Timeout: 5 * time.Second,
})

// In service calls
v1ID, err := idMapper.V2ToV1(ctx, v2UID)
```

---

## Choosing a Template

| Scenario | Use as template |
|---|---|
| New service, stores its own data | `lfx-v2-committee-service` |
| New service, wraps external system (reads + writes) | `lfx-v2-voting-service` |

---

## What All Services Share

Regardless of type, every resource service has:

- **Goa** for HTTP API design and code generation (`make apigen`)
- **Clean architecture**: `internal/domain`, `internal/infrastructure`, `internal/service`
- `/livez` (always 200) and `/readyz` (checks dependencies) health endpoints
- **Queue group** NATS subscriptions for horizontal scaling
- **25-second graceful shutdown** with NATS connection drain
- **Structured logging** with `slog` + OpenTelemetry (tracing, metrics, logs)
- **Helm chart** under `charts/` for Kubernetes deployment
- JWT validation via Heimdall JWKS endpoint
