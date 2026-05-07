<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Goa API Design Patterns

All resource services use [Goa v3](https://goa.design) for HTTP API design and code
generation. You write DSL in `cmd/{service}/design/`, run `make apigen`, and never
touch the generated code in `gen/`.

## The Golden Rule

**Never edit files under `gen/`.** They are completely overwritten by `make apigen`.
All hand-written API implementation goes in `cmd/{service}/service/` or
`internal/`.

```bash
make apigen   # re-generates gen/ from design/
```

Goa version is pinned in the Makefile (`GOA_VERSION := v3.22.6`). The command it
runs:

```bash
goa gen github.com/linuxfoundation/lfx-v2-{service}/cmd/{service}-api/design
```

---

## Design File Structure

```text
cmd/{service}-api/design/
├── {service}.go    ← API, Service, and all Method definitions
└── type.go         ← Type definitions and reusable attribute functions
```

### `{service}.go` — the top level

```go
var _ = dsl.API("committee", func() {
    dsl.Title("Committee Management Service")
})

var JWTAuth = dsl.JWTSecurity("jwt", func() {
    dsl.Description("Heimdall authorization")
})

var _ = dsl.Service("committee-service", func() {
    dsl.Description("Committee management service")

    dsl.Method("create-committee", func() { ... })
    dsl.Method("get-committee-base", func() { ... })
    // ... more methods
})
```

---

## Defining a Method

Every method follows the same structure:

```go
dsl.Method("create-committee", func() {
    dsl.Description("Create Committee")

    dsl.Security(JWTAuth)           // all endpoints require JWT

    dsl.Payload(func() {
        BearerTokenAttribute()      // always include
        VersionAttribute()          // always include (maps to ?v=1)
        // ... resource-specific attributes
        dsl.Required("name", "category", "project_uid")
    })

    dsl.Result(CommitteeFullWithReadonlyAttributes)

    dsl.Error("BadRequest", BadRequestError, "Bad request")
    dsl.Error("NotFound", NotFoundError, "Resource not found")
    dsl.Error("Conflict", ConflictError, "Conflict")
    dsl.Error("InternalServerError", InternalServerError, "Internal server error")
    dsl.Error("ServiceUnavailable", ServiceUnavailableError, "Service unavailable")

    dsl.HTTP(func() {
        dsl.POST("/committees")
        dsl.Param("version:v")                  // ?v=1
        dsl.Header("bearer_token:Authorization")
        dsl.Response(dsl.StatusCreated)
        dsl.Response("BadRequest", dsl.StatusBadRequest)
        dsl.Response("NotFound", dsl.StatusNotFound)
        dsl.Response("Conflict", dsl.StatusConflict)
        dsl.Response("InternalServerError", dsl.StatusInternalServerError)
        dsl.Response("ServiceUnavailable", dsl.StatusServiceUnavailable)
    })
})
```

### HTTP status code conventions

| Operation | Status code |
| --- | --- |
| POST (creates resource) | 201 Created |
| GET | 200 OK |
| PUT / PATCH | 200 OK |
| DELETE | 204 No Content |
| Validation failure | 400 Bad Request |
| Not found | 404 Not Found |
| Already exists / If-Match mismatch | 409 Conflict |
| Internal error | 500 Internal Server Error |
| Dependency down | 503 Service Unavailable |

### Standard headers on every method

```go
BearerTokenAttribute()          // Authorization header
VersionAttribute()              // ?v=1 query param

// In HTTP func:
dsl.Header("bearer_token:Authorization")
dsl.Param("version:v")
```

---

## Defining Types

Types and reusable attribute functions live in `type.go`.

### The attribute function pattern

Extract related attributes into a function so they can be composed across multiple
types and payloads:

```go
// CommitteeBaseAttributes lists all fields on the committee base object.
func CommitteeBaseAttributes() {
    NameAttribute()
    CategoryAttribute()
    DescriptionAttribute()
    ProjectUIDAttribute()
    PublicAttribute()
    // ...
}

// CommitteeBase is the input type (no uid, no computed fields).
var CommitteeBase = dsl.Type("committee-base", func() {
    CommitteeBaseAttributes()
})

// CommitteeBaseWithReadonlyAttributes is the response type (includes uid + computed).
var CommitteeBaseWithReadonlyAttributes = dsl.Type("committee-base-with-readonly-attributes", func() {
    CommitteeUIDAttribute()     // uid is readonly — only in responses
    CommitteeBaseAttributes()
    ProjectNameAttribute()      // computed
    TotalMembersAttribute()     // computed
})
```

**The convention**: input types omit `uid` and computed fields. Response types
include them. The `-with-readonly-attributes` suffix signals a response type.

### Defining individual attributes

```go
func NameAttribute() {
    dsl.Attribute("name", dsl.String, "Committee display name", func() {
        dsl.MaxLength(100)
        dsl.Example("Technical Advisory Committee")
    })
}

func CategoryAttribute() {
    dsl.Attribute("category", dsl.String, "Committee category", func() {
        dsl.Enum("technical", "governance", "marketing")
        dsl.Example("technical")
    })
}

func PublicAttribute() {
    dsl.Attribute("public", dsl.Boolean, "Whether the committee is publicly visible")
}
```

### Error types

All services define the same standard error types:

```go
var BadRequestError = dsl.Type("bad-request-error", func() {
    dsl.Attribute("message", dsl.String, "Error message", func() {
        dsl.Example("The request was invalid.")
    })
    dsl.Required("message")
})

// Same pattern for: NotFoundError, ConflictError, ForbiddenError,
// InternalServerError, ServiceUnavailableError
```

---

## GET — Returning ETag for Optimistic Locking

GET endpoints that return a mutable resource should include an ETag header so
clients can use `If-Match` on subsequent updates:

```go
dsl.Method("get-committee-base", func() {
    dsl.Payload(func() {
        BearerTokenAttribute()
        VersionAttribute()
        CommitteeUIDAttribute()
    })

    dsl.Result(func() {
        dsl.Attribute("committee-base", CommitteeBaseWithReadonlyAttributes)
        ETagAttribute()     // returns the KV revision as ETag
        dsl.Required("committee-base")
    })

    dsl.HTTP(func() {
        dsl.GET("/committees/{uid}")
        dsl.Param("version:v")
        dsl.Param("uid")
        dsl.Header("bearer_token:Authorization")
        dsl.Response(dsl.StatusOK, func() {
            dsl.Body("committee-base")
            dsl.Header("etag:ETag")   // maps result field → ETag response header
        })
    })
})
```

## PUT / DELETE — Accepting If-Match

Update and delete endpoints accept `If-Match` to guard against concurrent writes:

```go
dsl.Method("update-committee-base", func() {
    dsl.Payload(func() {
        BearerTokenAttribute()
        VersionAttribute()
        IfMatchAttribute()          // maps to If-Match request header
        CommitteeUIDAttribute()
        CommitteeBaseAttributes()
        dsl.Required("name", "category", "project_uid")
    })

    dsl.HTTP(func() {
        dsl.PUT("/committees/{uid}")
        dsl.Param("version:v")
        dsl.Param("uid")
        dsl.Header("bearer_token:Authorization")
        dsl.Header("if_match:If-Match")   // reads If-Match header into payload
        dsl.Response(dsl.StatusOK)
        dsl.Response("Conflict", dsl.StatusConflict)  // If-Match mismatch
    })
})
```

The service layer receives `if_match` as a string in the payload and passes it to
the storage layer as the expected revision. If the revision doesn't match, return a
`ConflictError`.

---

## Generated Code Layout

After `make apigen`, `gen/` contains:

```text
gen/
├── {service}/
│   ├── service.go         ← Service interface + all payload/result types
│   ├── endpoints.go       ← Endpoint wrappers
│   └── client.go
└── http/{service}/server/
    ├── server.go           ← HTTP handler registration
    ├── encode_decode.go    ← Request decoding + response encoding
    ├── types.go            ← HTTP body types + validation
    └── paths.go
```

Your implementation satisfies the `Service` interface defined in
`gen/{service}/service.go`. All HTTP concerns (header extraction, JSON
serialization, error encoding) are handled by the generated code — you never write
HTTP boilerplate by hand.

---

## Adding a Field to an Existing Endpoint

1. Add an attribute function in `type.go` (or add the attribute directly if it's a
   one-off)
2. Call it in the relevant `*Attributes()` function or directly in the type
3. If it's required on input, add it to `dsl.Required(...)` in the method payload
4. Run `make apigen`
5. The generated `Service` interface and payload types will now include the new
   field — wire it through in your implementation

No changes needed to `gen/` — `make apigen` handles everything.
