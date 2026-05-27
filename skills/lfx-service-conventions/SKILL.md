---
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
name: lfx-service-conventions
description: >
  Code-level conventions shared by every LFX V2 Go service: structured logger
  discipline with slog, pagination contract (page_size, page_token), domain
  ErrorType enum and HTTP mapping, request-context propagation
  (request-id, principal, authorization), and unit-test patterns
  (mock interfaces, table-driven tests, co-located *_test.go, one test
  function per exported method). Use whenever the work asks how to log, how
  to paginate, how to handle errors, how to propagate request context, or how
  to structure tests in a V2 Go service. Fires on prompts like "how do I
  log", "slog setup", "should I use fmt.Println", "what's the pagination
  convention", "page_size", "page_token", "next_token pagination", "how
  should I handle errors", "ErrorType pattern", "DomainError", "domain error
  to HTTP code", "request context", "request-id", "principal", "context
  keys", "what should my test look like", "table-driven tests", "mock
  interfaces", "is there a convention for request IDs". Applies to V2 Go
  services only, not Self Serve.
allowed-tools: Read, Glob, Grep
---

# LFX Service Conventions

Code-level conventions shared by every LFX V2 Go service (native, wrapper,
and proxy/consumer). Read this before writing or reviewing logger calls,
pagination wiring, error returns, request-scoped context plumbing, or unit
tests inside a V2 Go service repo.

This skill is the central reference; it does not own per-service contracts.
For an individual service's NATS subjects, KV layout, indexer envelope, FGA
emission, Helm chart values, or domain rules, route to that service's
`docs/agent-guidance/` and `docs/` truth.

## When to invoke

- Choosing between `slog`, `fmt.Println`, `log.Printf`, or a logger field set
  for any V2 Go service call site.
- Adding or auditing a list endpoint that needs pagination.
- Returning a domain error and deciding which HTTP status code it should map
  to at the Goa layer.
- Reading or writing `request-id`, `principal`, or `authorization` on a Go
  `context.Context`.
- Writing or reviewing `*_test.go` files in a V2 Go service.

If the work is in `lfx-self-serve` (Angular SSR app or Express BFF), do not
invoke this skill. Self Serve has its own logger, pagination, and test
conventions in `lfx-self-serve/.claude/skills/develop/references/` and
`.claude/rules/`.

## Scope

Applies to every active V2 Go service:

- Native resource services: `lfx-v2-project-service`, `lfx-v2-committee-service`.
- Wrapper services: `lfx-v2-voting-service`, `lfx-v2-meeting-service`,
  `lfx-v2-mailing-list-service`, `lfx-v2-survey-service`.
- Read-only / cache-backed services: `lfx-v2-member-service`.
- Platform plumbing services: `lfx-v2-indexer-service`, `lfx-v2-fga-sync`,
  `lfx-v2-query-service`, `lfx-v2-access-check`, `lfx-v2-auth-service`.

For the native vs wrapper vs proxy classification itself, see
`lfx-dev/skills/lfx/references/service-types.md`.

`lfx-v2-mockdata` is a fixture loader (not a long-lived service) and
`lfx-v2-invite-service` is a readiness skeleton with no Go service code yet;
these conventions apply once those repos grow real service code.

## Logger discipline

V2 Go services use Go's standard `log/slog` package for all logging.

- Use `slog`. Never use `fmt.Println`, `fmt.Printf`, `log.Print*`, or
  `log.Println` for runtime logging in service code.
- Logger setup lives under `internal/logging/` (or equivalent) and is
  OpenTelemetry-aware where the service already wires
  `slog-otel` so log records carry trace and span IDs.
- Standard fields per log line: `request_id`, `principal` (when
  authenticated), `object_type` and `object_id` for resource operations, and
  `action` or `operation` name.
- Pass the logger through `context.Context` or by direct injection; do not
  hold a package-level logger as the only path.
- Honor `LOG_LEVEL` (typical values: `debug`, `info`, `warn`, `error`). The
  `make debug` target is the standard local debug-logging entry point.
- Do not log PII (email, tokens, raw payload bodies) at `info` or above.
  PII at `debug` is acceptable for local development only when guarded by an
  explicit debug flag.

Per-service deviations (different field names, additional structured fields,
service-specific logger initialization) live in that service's repo.

## Pagination contract

List endpoints follow a single shared shape, modeled on the query-service
contract.

- Query parameter: `page_size` (not `limit`). Allowed range: `1` to `1000`.
  Default: `50` when the caller omits the field.
- Query parameter: `page_token` (opaque, keyset-based). Pass the value
  returned by the previous page back as `page_token` on the next request.
  Omit on the first page.
- Response field: `page_token` is returned only when more pages exist.
  Clients must treat the token as opaque (no parsing).
- Provide a separate count endpoint (for example `/.../count`) when total
  counts are cheap. Do not include a total count in every list response if
  computing it requires a second OpenSearch or upstream call.
- `next_token` is an alternate name occasionally used by upstream proxied
  systems (ITX, Groups.io). Translate inbound or outbound to the LFX
  `page_token` field at the wrapper boundary; do not leak provider-specific
  pagination field names through V2 endpoints.

The canonical query-service implementation lives in
`lfx-v2-query-service/docs/agent-guidance/query-service-patterns.md`. Read
that for OpenSearch keyset details, CEL caveats, anonymous behavior, and
date-range filtering.

Per-service exceptions (e.g., a paged endpoint that wraps an upstream system
that does not support keyset pagination) should be documented in that
service's own contract doc with the reason for the deviation.

## Error handling

V2 Go services use a domain `ErrorType` enum that maps cleanly to HTTP status
codes at the Goa layer.

- Domain error type lives in `internal/domain/errors.go` (or
  `internal/domain/<resource>/errors.go`) as `DomainError` with a `Type`
  field of enum `ErrorType`.
- Canonical enum values and HTTP mapping:

  | ErrorType            | HTTP status                   |
  | -------------------- | ----------------------------- |
  | `ErrorTypeValidation`| 400 Bad Request               |
  | `ErrorTypeNotFound`  | 404 Not Found                 |
  | `ErrorTypeConflict`  | 409 Conflict                  |
  | `ErrorTypeInternal`  | 500 Internal Server Error     |
  | `ErrorTypeUnavailable` | 503 Service Unavailable     |

- Construct errors with the typed constructors: `NewValidationError`,
  `NewNotFoundError`, `NewConflictError`, `NewInternalError`,
  `NewUnavailableError`. Wrap upstream errors as the second argument so
  `errors.Is` and `errors.Unwrap` keep working.
- At the Goa layer, classify the returned error via the helper
  (`GetErrorType` or equivalent) and translate to the Goa error response
  the design declared.
- Some older services use named sentinel errors like `ErrNotFound`,
  `ErrConflict`, or `ErrInvalidParentUID` (for example
  `lfx-v2-project-service/internal/domain/errors.go`). Treat the
  `ErrorType` enum as the target shape for new code; do not introduce more
  per-error sentinel types in fresh services.
- Never return raw upstream HTTP errors. Always normalize to a
  `DomainError` so the Goa layer can map to the right status without
  leaking provider details.

## Request-context propagation

Three values flow on every authenticated request and must be readable from
`context.Context` throughout the call stack:

- `request-id`: unique per HTTP request, set by request-ID middleware.
- `principal`: the authenticated user (or `_anonymous` when the request had
  no valid JWT), set by the JWT or Heimdall middleware.
- `authorization`: the inbound bearer token, when downstream calls need to
  forward it (for example to fga-sync, project-service NATS RPC, or another
  V2 API).

Conventions:

- Context keys live in a shared `pkg/constants/context.go` (typed
  `ContextKey` to avoid string-key collisions). Typical names:
  `RequestIDContextKey`, `PrincipalContextID`. Use these instead of bare
  string keys.
- Middleware sets the values; service-layer code reads them. Do not let
  service-layer code call into `*http.Request` to read headers directly.
- When publishing NATS messages or making NATS RPC calls, forward
  `request-id` and `principal` as headers on the message so downstream
  consumers can correlate logs and traces.

Per-service exceptions (an extra context key like `etag` for optimistic
concurrency in `lfx-v2-project-service`, mailing-list-specific principal
fields, or auth-service impersonation context) live in that service's repo
and stay there.

## Test patterns

Every V2 Go service uses the same unit-test shape so cross-service review
costs stay low.

- Mock external dependencies through interfaces. Repository, message
  publisher, FGA client, OpenSearch client, NATS request/reply, ID mapper,
  upstream proxy: each must be reachable through an interface defined in
  the `internal/domain/` (or `internal/domain/port/`) package, and the
  service layer must depend on that interface, not on a concrete struct.
- Mocks live alongside the interfaces or in
  `internal/infrastructure/mock/` and `internal/mocks/` directories. Pick
  the layout the rest of the repo uses.
- Use table-driven tests. Each row carries `name`, the inputs, a
  `setupMocks` closure that configures expectations on the mocks for that
  case, and the expected outcome (return value, error, or `wantErr` bool).
- One test function per exported method. If a function already has a
  `Test<Type>_<Method>` function, add new cases as rows in that function's
  table rather than introducing a second test function for the same
  method.
- Test files are co-located: `foo.go` is tested by `foo_test.go` in the
  same package.
- Run with race detection. The standard target is
  `go test -v -race -timeout 5m ./...` (services use varying timeouts; do
  not lower the existing value in a repo).
- Mock-friendly modes (for example `AUTH_SOURCE=mock`,
  `REPOSITORY_SOURCE=mock`, `GROUPSIO_SOURCE=mock`,
  `SEARCH_SOURCE=mock`, `ACCESS_CONTROL_SOURCE=mock`,
  `ID_MAPPING_DISABLED=true`,
  `JWT_AUTH_DISABLED_MOCK_LOCAL_PRINCIPAL=<value>`) are set by env vars,
  not by code paths inside the service. Tests configure them, they do not
  rebuild them.

### Example shape

```go
func TestMessageBuilder_SendIndexProject(t *testing.T) {
    tests := []struct {
        name       string
        payload    *projsvc.Payload
        setupMocks func(*domain.MockRepo, *domain.MockMsg)
        wantErr    bool
    }{
        // Test cases.
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            api, mockRepo, mockMsg := setupAPI()
            tt.setupMocks(mockRepo, mockMsg)
            // Test logic.
        })
    }
}
```

The example above is the shape inherited from `lfx-v2-project-service`.

## What this skill is not

- Not a per-service contract. NATS subjects, KV bucket names, indexer
  envelope fields, FGA tuple shapes, Heimdall ruleset paths, Helm chart
  values, and service-specific endpoint payloads all live in the owning
  service's `docs/agent-guidance/` and `docs/`. Route there.
- Not a Self Serve guide. Express BFF logger (`logger.startOperation`,
  `logger.success`, `logger.error`, `MicroserviceProxyService`), Angular
  signals, PrimeNG wrappers, and SSR rules all live in `lfx-self-serve`.
- Not a deployment guide. Service charts, ArgoCD values, ExternalSecrets,
  OpenFGA model edits, and platform infra routing live in
  `lfx-dev/skills/lfx/references/deployment-routing.md` and the chart-
  owning repos.
- Not an FGA, indexer, query-service, or auth-service implementation guide.
  See `lfx-v2-fga-sync`, `lfx-v2-indexer-service`, `lfx-v2-query-service`,
  and `lfx-v2-auth-service` respectively.

## Handoff

Once these conventions are clear, hand back to the owning service repo's
local setup. The service's `CLAUDE.md`, agent guidance, and contract docs
govern detail beyond these shared rules.
