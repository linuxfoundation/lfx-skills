<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# NATS Messaging Patterns

NATS JetStream is the message bus and KV store for the platform. This file covers
subject naming conventions and how services communicate with each other.

## Subject Naming

**There is no environment prefix** — subjects are the same in all environments.

The general patterns:

| Pattern | Purpose | Example |
|---|---|---|
| `lfx.index.{resource_type}` | Publish to indexer-service | `lfx.index.committee` |
| `lfx.fga-sync.update_access` | Publish access update to fga-sync | `lfx.fga-sync.update_access` |
| `lfx.fga-sync.delete_access` | Publish access delete to fga-sync | `lfx.fga-sync.delete_access` |
| `lfx.fga-sync.member_put` | Add a user relation via fga-sync | `lfx.fga-sync.member_put` |
| `lfx.fga-sync.member_remove` | Remove a user relation via fga-sync | `lfx.fga-sync.member_remove` |
| `lfx.{service-api}.{operation}` | Service-to-service request/reply | `lfx.committee-api.get_name` |

### Examples from the codebase

```go
// CommitteeGetNameSubject — used when another service needs the committee display name
CommitteeGetNameSubject = "lfx.committee-api.get_name"

// ProjectGetSlugSubject — used when another service needs the project slug
ProjectGetSlugSubject = "lfx.projects-api.get_slug"
```

Subject constants are defined in a shared package and imported by both the
publishing and subscribing service — never hardcode strings.

## When to Send Each Message Type

Not every write requires both an index message and an access message:

| Message | When to send |
|---|---|
| **Index message** (`lfx.index.*`) | Always — on every create, update, delete |
| **Access message** (`lfx.fga-sync.update_access` / `lfx.fga-sync.delete_access`) | Only when the resource has its own FGA type |

For example, `committee` has its own FGA type so it needs both messages. But
`meeting_rsvp` has no FGA type — it only gets an index message, and access is
inherited through the parent meeting.

The authoritative list of FGA types is in:
`lfx-v2-helm/charts/lfx-platform/templates/openfga/model.yaml`

## Service-to-Service Request/Reply

Services query each other via NATS request/reply (not HTTP). The requesting service
sends a message on the subject and waits for a response:

```go
msg, err := nc.Request(CommitteeGetNameSubject, []byte(committeeUID), 5*time.Second)
if err != nil {
    return "", fmt.Errorf("committee name lookup: %w", err)
}
name := string(msg.Data)
```

The responding service subscribes with a queue group and replies:

```go
nc.QueueSubscribe(CommitteeGetNameSubject, "committee-api", func(msg *nats.Msg) {
    name, err := svc.GetName(context.Background(), string(msg.Data))
    if err != nil {
        msg.Respond([]byte(""))
        return
    }
    msg.Respond([]byte(name))
})
```

Queue groups ensure only one instance handles each request when scaled horizontally.
All subscriptions — both inbound events and request/reply handlers — use queue groups.

## NATS JetStream KV (Native Services)

Native services store their data in JetStream KV buckets — one bucket per resource
type, initialized at startup in `infrastructure/nats/client.go`:

```go
kv, err := js.CreateOrUpdateKeyValue(ctx, nats.KeyValueConfig{
    Bucket:  "committees",
    History: 1,
})
```

Each entry is keyed by UID. Reads return a revision number used for optimistic
locking on updates — see [service-types.md](service-types.md).

## Graceful Shutdown

On shutdown, services drain the NATS connection (25-second timeout) before exiting,
ensuring in-flight messages are processed and not dropped.
