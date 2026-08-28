---
name: lfx-postgres-ops
description: >
  Provisioning requirements for LFX PostgreSQL backends in deployed
  environments (prod, staging, shared dev): per-service databases and roles
  on the shared RDS instance via `postgres-database-definitions.yaml` +
  `postgres.tf` in `lfx-v2-opentofu`, Secrets Manager credential rotation,
  the pgvector flag, and Datadog database monitoring. Deployed environments
  never run the CloudNativePG operator — that only exists for local
  development, owned by `lfx-v2-helm`. Written for the linuxfoundation
  GitHub org's ops audience — see the `-ops` skill convention in
  `/lfx-skills:lfx`. Fires on prompts like "provision a postgres database",
  "add a database to RDS", "postgres opentofu", "database credentials
  rotation", "pgvector", "postgres secret ARN", "RDS role for a service".
  Requirements only; the implementing agent owns the HCL.
allowed-tools: Read, Glob, Grep
---

<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# LFX Postgres Ops

How PostgreSQL backends are provisioned for deployed environments. Unlike
its object-store sibling, this is settled, in-production practice: the
conventions below already exist in `lfx-v2-opentofu` and new databases
follow them as-is.

Audience: linuxfoundation GitHub org members. This skill is written for
that ops audience and assumes org membership; it does not itself enforce
it (see the `-ops` skill convention in `/lfx-skills:lfx` for how the router
handles routing when membership is unconfirmed). Application-side design
(chart contract, env var contract, tooling, local dev) is
`/lfx-skills:lfx-postgres-design`.

## Where

All resources live in
[`lfx-v2-opentofu`](https://github.com/linuxfoundation/lfx-v2-opentofu):

- Environments are OpenTofu **workspaces** (`dev`, `staging`, `prod`), not
  directories.
- The shared RDS instance (`aws_db_instance.lfv_v2`, `rds.tf`) hosts every
  service's database; per-service resources live in `postgres.tf`, driven
  by `postgres-database-definitions.yaml`.
- Workflow via the repo `Makefile` (`make init/plan/apply`); `plan`/`apply`
  connect through an RDS proxy port-forward — read the repo `README.md`
  and `AGENTS.md` before planning. CI owns plan/apply for real changes.

## Pattern

Data-driven flat `for_each` over a YAML definitions file. No modules; flat
1:1 loops per resource type.

Adding a database for a new service is one YAML entry:

```yaml
databases:
  my-service:
    name: my_service
    description: RDS PostgreSQL credentials for My Service
    service: lfx-v2-my-service   # Secrets Manager service tag
    vector: true                 # optional; enables pgvector (default false)
```

`postgres.tf` then loops that entry through every resource below — no new
HCL per service.

## What one entry provisions

- **Credentials**: a `random_password`, stored in AWS Secrets Manager at
  `/cloudops/rds-managed/lfx-v2/<key>` using the standard RDS rotation JSON
  layout (`engine`/`host`/`username`/`password`/`dbname`/`port`), tagged
  with the entry's `service` value (`service-<name>: enabled`) so tag-based
  External Secrets lookups work.
- **Rotation**: `aws_secretsmanager_secret_rotation` every **30 days**, via
  the shared `SecretsManagerRDSPostgreSQLRotationSingleUser` Lambda
  (deployed once from the Serverless Application Repository). Terraform
  ignores subsequent password drift (`ignore_changes`) — the Lambda is the
  source of truth after creation. Consequence for services: credentials
  change under them; the design skill's contract requires tolerating that.
- **Role and database**: a `postgresql_role` (login, no createdb/createrole)
  and a `postgresql_database` owned by that role, both named `name`.
- **Extensions**: `pg_stat_statements` in every database; `vector`
  (pgvector) only where the entry sets `vector: true`.
- **Datadog database monitoring**: a shared `datadog_dbm` role (IAM
  authentication — `pg_monitor` + `rds_iam`, no password), plus a `datadog`
  schema and USAGE grants in every application database. This ships
  automatically with the loop; nothing per-service to request.

The single-user rotation pattern assumes the service fully owns its
database. Auxiliary credentials with different lifecycles (for example a
third-party read-only replication user) are deliberately kept **outside**
`local.databases` and hand-written — a rotating secret would silently break
a credential saved in an external system's config. See the Fivetran
crowdfunding reader in `postgres.tf` for the precedent.

## Sizing

The shared RDS instance is sized per workspace via variables; individual
databases don't reserve storage. As a concrete data point for in-cluster
(CloudNativePG) sizing decisions: a ~38M-row / ~5.8 GiB live dataset fits
comfortably in a single 25Gi volume with room to grow.

## CloudNativePG operator

There is **no CloudNativePG operator in deployed environments**. ArgoCD
values always set `database.mode: external` (RDS via the resources above)
and disable the umbrella chart's CloudNativePG operator and `Cluster`
resources. The in-cluster modes (`database` / `cluster+database` in the
design skill's contract) and the umbrella-provisioned operator/cluster
exist for local development only, owned by `lfx-v2-helm` — nothing for
this repo, or ops generally, to provision. Deny requests to "install
CloudNativePG in dev/staging/prod" — deployed environments use RDS,
period.

## Handoffs

After provisioning, hand these to `lfx-v2-argocd` environment values:

- The Secrets Manager secret path
  (`/cloudops/rds-managed/lfx-v2/<key>`) and/or its `service` tag.
  `lfx-v2-argocd` owns the External Secrets Operator resources that
  materialize it into the cluster Secret — either per-key `data` entries
  mapping the five RDS JSON properties (the shape the design skill's
  `shape: fields` contract expects), or a tag-based `dataFrom` find.
- The service's chart values override: `database.mode: external`,
  `database.external.secretName` pointing at the materialized Secret, and
  `shape: fields` with the default `keys` mapping.
- The IRSA prerequisite: the ExternalSecret's SecretStore assumes the
  service's IRSA role, so the service needs an
  `iam-service-account-definitions.yaml` entry with Secrets Manager read
  scoped to its secret (same mechanism as
  `/lfx-skills:lfx-object-store-ops`'s write-access section).

## Handoff boundary

The implementing agent in `lfx-v2-opentofu` owns the HCL, plan review, and
apply workflow under that repo's local conventions. Application-side chart
and code changes belong to the owning service repo per
`/lfx-skills:lfx-postgres-design`; External Secrets and environment values
belong to `lfx-v2-argocd`.
