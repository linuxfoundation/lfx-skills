<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Getting Started with LFX Self-Service Backend

## The Repository Map

There are two categories of repos to know about:

### Infrastructure repos

| Repo | Purpose |
| --- | --- |
| `lfx-v2-helm` | Umbrella Helm chart — platform infra (NATS, OpenSearch, OpenFGA, Traefik, Heimdall) + subcharts |
| `lfx-v2-argocd` | GitOps deployment — ArgoCD ApplicationSet with per-environment values for each service |

These two repos control **what runs and where**. You touch them when:

- Adding a new service to the platform (both repos)
- Updating the OpenFGA authorization model (`lfx-v2-helm`)
- Changing environment config (NATS URLs, secrets, replicas) (`lfx-v2-argocd`)

### Platform service repos

Generic infrastructure services — rarely changed when adding a new resource type:

| Repo | Role |
| --- | --- |
| `lfx-v2-indexer-service` | Consumes NATS index messages → writes to OpenSearch |
| `lfx-v2-query-service` | HTTP search API over OpenSearch with FGA access filtering |
| `lfx-v2-fga-sync` | Syncs access tuples to OpenFGA; handles access check requests |
| `lfx-v2-access-check` | HTTP wrapper around FGA access checks |

### Resource service repos

Own a specific resource type and expose a REST API:

| Repo | Resource |
| --- | --- |
| `lfx-v2-committee-service` | Committee (native — use as template for new native services) |
| `lfx-v2-project-service` | Project (native — deprecated enricher pattern, do not use as template) |
| `lfx-v2-meeting-service` | Meeting (wrapper → ITX) |
| `lfx-v2-voting-service` | Vote (wrapper → ITX, use as template for new wrapper services) |
| `lfx-v2-survey-service` | Survey (wrapper → ITX) |
| `lfx-v2-mailing-list-service` | Mailing list (wrapper → Groups.io) |
| `lfx-v2-member-service` | Member |

---

## How Deployment Works

```text
Service repo (e.g. lfx-v2-committee-service)
    contains: Helm chart at charts/
    CI builds image → pushes to GHCR

lfx-v2-argocd
    ApplicationSet entry references the service chart + its own values files:
        values/global/{service}.yaml   ← shared baseline
        values/dev/{service}.yaml      ← dev overrides
        values/staging/{service}.yaml
        values/prod/{service}.yaml
    ArgoCD syncs automatically on push
```

**To change a deployed config** (e.g. a new env var, replica count):
edit the relevant `values/{env}/{service}.yaml` in `lfx-v2-argocd`.

**To change the OpenFGA authorization model** (e.g. add a new FGA type):
edit `charts/lfx-platform/templates/openfga/model.yaml` in `lfx-v2-helm`
and bump the version in the model spec.

**To add a new service to the platform**:

1. Add it to the ApplicationSet list in `lfx-v2-argocd/apps/dev/lfx-v2-applications.yaml`
2. Create `values/global/{service}.yaml` in `lfx-v2-argocd`

---

## Local Development

The full platform stack runs locally via Helm + OrbStack.

```bash
# 1. Clone and enter the helm repo
git clone https://github.com/linuxfoundation/lfx-v2-helm
cd lfx-v2-helm

# 2. Pull all chart dependencies
helm dependency update charts/lfx-platform

# 3. Create your local values file
cp charts/lfx-platform/values.local.example.yaml charts/lfx-platform/values.local.yaml
# Edit values.local.yaml — secrets are in the LFX V2 1Password vault

# 4. Install the platform
helm install -n lfx lfx-platform ./charts/lfx-platform \
  --values charts/lfx-platform/values.local.yaml
```

Standard environment variables for running a service locally against the stack:

```bash
NATS_URL=nats://localhost:4222
OPENSEARCH_URL=http://localhost:9200
JWKS_URL=http://localhost:4457/.well-known/jwks
LFX_ENVIRONMENT=lfx.
PORT=8080
```

See the `lfx-v2-helm` README for full setup instructions including required
pre-created secrets.

---

## Where to Start for Common Tasks

| Task | Start here |
| --- | --- |
| Add a field to an existing resource | The resource's service repo (`lfx-v2-{type}-service`) |
| Build a new resource service | Clone `lfx-v2-committee-service` (native) or `lfx-v2-voting-service` (wrapper) |
| Change who can access a resource type | `lfx-v2-helm` — update OpenFGA model |
| Make a resource searchable by a new field | Resource service repo — update `IndexingConfig` in the NATS publisher |
| Debug why a user can't see a resource | See debugging sections in `fga-patterns.md` and `query-service.md` |
| Change a deployed environment config | `lfx-v2-argocd` — edit `values/{env}/{service}.yaml` |
