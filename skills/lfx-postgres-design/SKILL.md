---
name: lfx-postgres-design
description: >
  Central explainer for adding a PostgreSQL database to an LFX V2 service.
  Covers the three-mode Helm chart contract (`database.mode`: `external`,
  `database`, `cluster+database`) and its defaults, the
  `database.cloudNativePG.*` and `database.external.*` value shapes, the
  env var / Secret contract (PG* fields vs a single DATABASE_URL, the
  standard RDS credential JSON layout), schema-ownership-driven tooling
  guidance (golang-migrate + sqlc by default; bun when another system owns
  the schema), and the CloudNativePG-based local development story.
  Fires on prompts like "add postgres", "database for the service",
  "database.mode", "CloudNativePG", "Database CR", "DATABASE_URL",
  "PGHOST", "sqlc", "golang-migrate", "postgres Helm values", "connect to
  RDS", "postgres secret", "local postgres". Read-only; routes
  implementation work to the owning service repo and provisioning
  (RDS databases, credentials, operators) to `/lfx-skills:lfx-postgres-ops`.
allowed-tools: Read, Glob, Grep
---

<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# LFX Postgres Design

How an LFX V2 service adds a PostgreSQL database: the Helm chart
`database.mode` contract, the env var / Secret contract the chart renders,
the code-level query and migration tooling guidance, and the local
development story. This is the shared design baseline; service repos own
their implementation.

PostgreSQL is the standard relational store for LFX V2 services. Deployed
environments use the shared AWS RDS instance (provisioned via
`/lfx-skills:lfx-postgres-ops`). Local development uses a
CloudNativePG-managed cluster provisioned by the platform umbrella chart.

## When to invoke

- A service is adding a PostgreSQL database, or its chart needs
  `database.*` values, CloudNativePG resources, or external-Secret wiring.
- Questions about `database.mode`, `DATABASE_URL` vs split `PG*` fields,
  migration tooling (golang-migrate), query layers (sqlc, bun), or local
  Postgres development.

Do **not** invoke for:

- Provisioning RDS databases, credentials, rotation, or the CloudNativePG
  operator (`/lfx-skills:lfx-postgres-ops`).
- Schema modeling or table design detail (owning service's docs).

## The `database.mode` contract

Every Postgres-backed service chart exposes a `database.mode` value
selecting the deployment/connection topology. Three modes:

| Mode               | What it does                                                                                                    | When                                                                              |
|--------------------|-----------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------|
| `external`         | Connect to an externally managed Postgres (for example RDS) via a Kubernetes Secret supplied outside the chart. | All deployed environments (dev/staging/prod via `lfx-v2-argocd`).                 |
| `database`         | Render a CloudNativePG `Database` CR against an **existing** CloudNativePG `Cluster` (umbrella-provisioned).    | **Default** — local development, both under the umbrella and standalone installs. |
| `cluster+database` | Render both a CloudNativePG `Cluster` CR and a `Database` CR.                                                   | Non-default: the rare, genuinely cluster-less standalone case.                    |

Default rules:

- **Both** the umbrella chart's component values **and** a service's
  standalone chart default to `database` mode. Even a developer installing
  a single service chart on its own is expected to already have a
  CloudNativePG cluster available — typically from having stood up the
  umbrella chart at least once for pre-existing/global services, mirroring
  how NATS resources already assume a pre-existing operator.
  `cluster+database` is **not** the standalone default; it stays available
  as an explicit opt-in for the cluster-less case.
- ArgoCD-managed environments always override to `external` and disable any
  chart-rendered Cluster resources, regardless of chart defaults.

`database.mode` is deployment/connection topology only. It is independent
of the code-level query/migration tooling axis below — do not conflate the
two (a service's Go code neither knows nor cares which mode rendered its
connection Secret).

## Helm chart contract

The chart values shape (defaults shown for the local `database` mode):

```yaml
database:
  # external | database | cluster+database — see the mode table above.
  mode: database
  cloudNativePG:
    # Name of the existing CloudNativePG Cluster ("database" mode) or the
    # Cluster this chart renders ("cluster+database" mode).
    clusterName: ""
    databaseName: my-service
    # Used only in "cluster+database" mode.
    cluster:
      instances: 1
      storage:
        size: 1Gi
  external:
    # Name of the externally supplied Kubernetes Secret.
    secretName: ""
    # "url": the Secret carries a single connection-string key.
    # "fields": the Secret carries split host/port/username/password/dbname
    # keys — the standard RDS credential layout (see below).
    shape: url
    secretKey: url
    # Key mapping for shape "fields". These defaults match the standard
    # AWS RDS credential JSON layout.
    keys:
      host: host
      port: port
      username: username
      password: password
      dbname: dbname
```

Rendering requirements per mode:

- **`database` / `cluster+database`**: render a CloudNativePG `Database` CR
  (`apiVersion: postgresql.cnpg.io/v1`) named for `databaseName`, owned by
  the cluster's `app` role, referencing `clusterName`. In
  `cluster+database` mode additionally render the `Cluster` CR with
  `instances` and `storage.size`. Inject connection env vars from the
  operator-generated app Secret (`<clusterName>-app`).
- **`external`**: inject connection env vars from
  `database.external.secretName`, per `shape`. The Secret itself is created
  outside the chart (in deployed environments, by `lfx-v2-argocd`
  deployment values).
- **CloudNativePG chart dependency**: a chart that can render CloudNativePG
  CRs (`database` / `cluster+database` modes) must declare the upstream
  `cloudnative-pg` Helm chart as a conditional `dependencies:` entry in
  `Chart.yaml` (or document the operator as an explicit install-first
  prerequisite) — the CRs are useless without the operator and its CRDs
  present. See "Local development" below for the CRD ordering caveat.

Spell out `cloudNativePG` in value names, comments, and identifiers being
newly chosen; never abbreviate to a four-letter acronym. Externally fixed
strings (`postgresql.cnpg.io/v1`, the upstream `cloudnative-pg` chart name)
are used unchanged.

## Environment variable / Secret contract

Two equivalent shapes; the chart maps either onto the container:

- **Split fields** (`PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`,
  `PGDATABASE`): each injected via `secretKeyRef`. In the CloudNativePG
  modes these come from the operator's `<clusterName>-app` Secret (with
  `PGDATABASE` set as a plain value from `databaseName`); in `external`
  mode with `shape: fields` they come from the supplied Secret via the
  `keys` mapping. The app composes its own connection string in-process —
  do **not** assemble it with `$(PGPASSWORD)`-style env interpolation in
  the pod spec, which leaks the password into the rendered manifest.
- **Single URL** (`DATABASE_URL`): `external` mode with `shape: url`, one
  `secretKeyRef` to `secretKey`.

Deployed environments use `external` + `shape: fields`, with the referenced
Secret supplied by deployment values (how it is provisioned and kept in
sync is `/lfx-skills:lfx-postgres-ops`). The credential rotates, so
services must tolerate password changes — reconnect on auth failure rather
than caching credentials for the process lifetime, and read the Secret via
env at pod start (rotation plus a rolling restart is the baseline;
long-lived pools should expect eventual auth errors and re-resolve).

This is a **contract**, not an implementation recipe: how the service reads
the env vars (plain `os.Getenv`, koanf, viper, etc.) follows the owning
repo's local conventions.

## Query and migration tooling (schema ownership)

This axis is about who owns the schema — independent of `database.mode`.

- **Default — the service owns its schema.** Use **golang-migrate** for
  schema/migration management, with **sqlc** as a thin, compile-time-checked
  query layer over hand-written SQL — a safety layer, not a full ORM.
  Configure sqlc with `sql_package: "pgx/v5"` so the generated code targets
  the **pgx** driver natively rather than `database/sql`. Keeping
  golang-migrate uniform across services means migration mechanics stay
  consistent regardless of query layer.
- **Recognized exception — another system owns the schema.** When a service
  is a read-only or read-mostly client of a schema owned and migrated
  elsewhere (for example, direct queries against the v1 platform database),
  the service has no migration authority regardless of tooling, and a
  fuller ORM/query builder such as **bun** is a reasonable,
  explicitly-sanctioned alternative for query convenience. Run bun over a
  **pgx**-backed `*sql.DB` (`stdlib.OpenDB(...)` from
  `github.com/jackc/pgx/v5/stdlib`), not bun's own `pgdriver`, so the
  connection layer stays on the platform-standard pgx driver. This is a
  named exception, not a contradiction of the default — and it applies per
  schema: the same service using bun against a foreign schema still uses
  the default stack for tables it owns itself.

## Local development

The platform-local shape:

- The umbrella chart (`lfx-v2-helm`) provisions the CloudNativePG operator
  and a shared single-instance `Cluster` — no backup configuration, minimal
  resources — that every service's `database`-mode `Database` CR targets.
- Service charts default to `database` mode (see the default rules
  above), whether installed via the umbrella or standalone.
- **Two-step install caveat**: CloudNativePG's CRDs are chart-templated, so
  a one-shot install that renders both the operator and `Database`/`Cluster`
  CRs fails CRD validation. Locally: install with the operator subcharts
  enabled first, then upgrade with everything else. (Deployed environments
  solve the same ordering with an ArgoCD pre-sync CRD step.)
- Third-party charts that carry their own Postgres wiring (for example
  OpenFGA) integrate with the shared cluster by rendering a CloudNativePG
  `Database` CR through the chart's `extraObjects`-style escape hatch, not
  by patching the chart's bundled Postgres values.

A plain Postgres container (Docker/compose or a bare Deployment) remains a
valid quick option for running a single service's tests outside the
platform stack — it exercises the same `external` + `DATABASE_URL` path —
but the CloudNativePG cluster is the platform-local default because it
exercises the real chart contract end to end.

## What this skill is not

- Not a provisioning guide. RDS databases, credentials/rotation, pgvector
  enablement, and CloudNativePG operator provisioning are
  `/lfx-skills:lfx-postgres-ops`.
- Not a schema-design or SQL style guide. Table design, indexes, and query
  conventions live in the owning service's docs.
- Not a Goa or Go conventions guide. The owning repo's path-scoped dev
  skill governs implementation style.
- Not an FGA modeling guide. Relation shapes per service live in the owning
  service's FGA contract docs.

## Handoff boundary

Once routed to the owning service repo, its local `AGENTS.md`/`CLAUDE.md`,
`docs/`, and repo-local skills control implementation detail. For backend
provisioning (the RDS database entry, credentials, pgvector, the
CloudNativePG operator/cluster), hand off to
`/lfx-skills:lfx-postgres-ops`. Deployed connection values (the External
Secrets wiring and `database.mode: external` overrides) land in
`lfx-v2-argocd`.
