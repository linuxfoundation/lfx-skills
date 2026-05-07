<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Service Helm Chart

Every LFX Self-Service resource service ships its own Helm chart under `charts/`.
This chart is deployed by ArgoCD and wires the service into the platform: routing,
authentication, authorization, and storage.

## Chart Structure

```text
charts/{service-name}/
├── Chart.yaml
├── values.yaml
└── templates/
    ├── deployment.yaml          ← Deployment + env vars + health probes
    ├── service.yaml             ← ClusterIP Service
    ├── httproute.yaml           ← Gateway API HTTPRoute (Traefik ingress)
    ├── heimdall-middleware.yaml ← Traefik ForwardAuth middleware (usually shared)
    ├── ruleset.yaml             ← Heimdall RuleSet — one rule per endpoint
    ├── nats-kv-buckets.yaml     ← NATS JetStream KV buckets (native services only)
    ├── externalsecret.yaml      ← ExternalSecret from AWS Secrets Manager (wrapper services)
    ├── secretstore.yaml         ← SecretStore config for External Secrets Operator
    └── serviceaccount.yaml      ← ServiceAccount with IRSA annotation for AWS access
```

Native services (e.g. committee-service) have `nats-kv-buckets.yaml` but no
secrets templates. Wrapper services (e.g. voting-service) have the secrets
templates but no KV buckets.

---

## deployment.yaml

Runs the container and injects runtime config as environment variables.

**Standard env vars every service gets:**

| Env var | `values.yaml` key |
| --- | --- |
| `NATS_URL` | `nats.url` |
| `JWKS_URL` | `heimdall.jwksUrl` |
| `JWT_AUDIENCE` | `app.audience` |
| `LOG_LEVEL` | `app.logLevel` |

**Adding a new env var** — for a plain value, add directly in `deployment.yaml`:

```yaml
- name: MY_SETTING
  value: {{ .Values.app.mySetting | quote }}
```

Or use `app.extraEnv` in `values.yaml` for ad-hoc injection without touching the
template:

```yaml
app:
  extraEnv:
    - name: FEATURE_FLAG
      value: "true"
```

For secrets sourced from AWS, reference the Kubernetes Secret created by
ExternalSecret (see below):

```yaml
- name: ITX_CLIENT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ .Chart.Name }}
      key: ITX_CLIENT_SECRET
```

Health probes are pre-wired to `/livez` (liveness) and `/readyz` (readiness +
startup) — do not change these.

OpenTelemetry env vars (`OTEL_*`) are conditionally injected from `app.otel.*`
values — configure them in `lfx-v2-argocd` values files for deployed environments.

---

## httproute.yaml

Kubernetes Gateway API `HTTPRoute` — tells Traefik which paths to forward to this
service and attaches the Heimdall auth middleware.

```yaml
spec:
  hostnames:
    - "lfx-api.{{ .Values.lfx.domain }}"
  rules:
    - matches:
        - path:
            type: Exact
            value: /committees
        - path:
            type: PathPrefix
            value: /committees/
      filters:
        - type: ExtensionRef
          extensionRef:
            group: traefik.io
            kind: Middleware
            name: heimdall-forward-body
      backendRefs:
        - name: {{ .Chart.Name }}
          port: {{ .Values.service.port }}
```

**When to update**: only when the service starts serving a new path prefix. Add a
new `path` entry under `matches`.

**Two middleware variants:**

- `heimdall-forward-body` — forwards the request body to Heimdall. Use this when
  any ruleset rule reads from the request body (e.g. `project_uid` on a POST).
- `heimdall` — no body forwarding. Use for routes where body inspection is not
  needed.

The middleware itself is defined in `heimdall-middleware.yaml` and is only created
when `heimdall.add_middleware: true`. It is usually owned by the umbrella chart in
`lfx-v2-helm`, so this is typically `false` per-service.

---

## ruleset.yaml — Heimdall authorization rules

**One rule per Goa endpoint.** This is the file to update whenever you add or
change an endpoint's authorization.

### Rule anatomy

```yaml
apiVersion: heimdall.dadrus.github.com/v1alpha4
kind: RuleSet
spec:
  rules:
    - id: "rule:lfx:{service}:{resource}:{action}"
      allow_encoded_slashes: 'off'
      match:
        methods: [GET]
        routes:
          - path: /committees/:uid   # :param captures a path segment
      execute:
        - authenticator: oidc
        - authenticator: anonymous_authenticator
        {{- if .Values.app.use_oidc_contextualizer }}
        - contextualizer: oidc_contextualizer
        {{- end }}
        {{- if .Values.openfga.enabled }}
        - authorizer: openfga_check
          config:
            values:
              relation: viewer
              object: "committee:{{ "{{- .Request.URL.Captures.uid -}}" }}"
        {{- else }}
        - authorizer: allow_all    # only for local dev with openfga.enabled: false
        {{- end }}
        - finalizer: create_jwt
          config:
            values:
              aud: {{ .Values.app.audience }}
```

### Choosing the relation

| Operation | Relation |
| --- | --- |
| Read resource | `viewer` |
| Read sensitive data (settings, member list, audit info) | `auditor` |
| Create / Update / Delete | `writer` |
| Self-service (join, accept invite, submit application) | `viewer` |

### Sourcing the FGA object

**From a URL path param** (most common):

```yaml
object: "committee:{{ "{{- .Request.URL.Captures.uid -}}" }}"
```

**From the request body** (e.g. POST where the parent UID is in the payload):

```yaml
- authorizer: json_content_type   # must come before openfga_check when reading body
- authorizer: openfga_check
  config:
    values:
      relation: writer
      object: "project:{{ "{{- .Request.Body.project_uid -}}" }}"
```

Always add `- authorizer: json_content_type` before `openfga_check` when sourcing
the object from the body.

### Public / anonymous endpoints

For endpoints that require no FGA check (e.g. OpenAPI spec endpoints):

```yaml
execute:
  - authenticator: oidc
  - authenticator: anonymous_authenticator
  - contextualizer: oidc_contextualizer
  - authorizer: allow_all
  - finalizer: create_jwt
    config:
      values:
        aud: {{ .Values.app.audience }}
```

Health endpoints (`/livez`, `/readyz`) do not need a rule — they are not routed
through Heimdall.

### Adding a rule for a new endpoint

1. Add the endpoint in the Goa design and run `make apigen`
2. Add a path entry to `httproute.yaml` if it's a new prefix
3. Add a rule to `ruleset.yaml` with the correct `relation` and `object`

---

## nats-kv-buckets.yaml (native services only)

Creates NATS JetStream KV buckets via the `nack` operator.

```yaml
apiVersion: jetstream.nats.io/v1beta2
kind: KeyValue
metadata:
  name: committees
  annotations:
    "helm.sh/resource-policy": keep   # survives helm uninstall — always set this
spec:
  bucket: committees
  history: 20           # revisions per key
  storage: file
  maxValueSize: 10485760    # 10MB per entry
  maxBytes: 1073741824      # 1GB total
  compression: true
```

Add a new bucket entry (and its corresponding block in `values.yaml`) when the
service needs to store a new top-level resource type in NATS KV.

---

## External secrets (wrapper services only)

Wrapper services that call external APIs need credentials at runtime. Three
templates work together to pull them from AWS Secrets Manager:

**`serviceaccount.yaml`** — ServiceAccount with an IRSA annotation granting AWS
access:

```yaml
annotations:
  eks.amazonaws.com/role-arn: arn:aws:iam::...
```

**`secretstore.yaml`** — tells the External Secrets Operator to use AWS Secrets
Manager with IRSA auth.

**`externalsecret.yaml`** — maps remote secret keys to a Kubernetes Secret:

```yaml
data:
  - secretKey: ITX_CLIENT_SECRET        # key in the Kubernetes Secret
    remoteRef:
      key: /lfx/voting-service/prod     # path in AWS Secrets Manager
      property: ITX_CLIENT_SECRET       # field within the secret JSON
```

The resulting Kubernetes Secret is named after the chart and referenced from
`deployment.yaml` via `secretKeyRef`. The whole mechanism only activates when
`externalSecretsOperator.enabled: true` and `global.awsRegion` is set — both are
off for local dev.

---

## values.yaml conventions

`values.yaml` holds safe local-dev defaults. Environment-specific overrides
(replica counts, image tags, OTEL config, domain) live in
`lfx-v2-argocd/values/{env}/{service}.yaml` — not here.

Key top-level sections every service has:

```yaml
replicaCount: 3
image:
  repository: ghcr.io/linuxfoundation/{service}/{binary}
  tag: ""         # overridden by ArgoCD at deploy time
openfga:
  enabled: true   # set false only for local dev without FGA
heimdall:
  enabled: true
  add_middleware: false   # middleware usually owned by umbrella chart
app:
  audience: {service-name}   # must match JWT_AUDIENCE and ruleset finalizer aud
  use_oidc_contextualizer: true
  extraEnv: []
  otel: { ... }
```
