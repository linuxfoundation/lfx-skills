---
name: lfx-object-store-ops
description: >
  Provisioning requirements for LFX object storage backends in deployed
  environments (prod, staging, shared dev): private S3 buckets, CloudFront
  with Origin Access Control, shared wildcard certificate, and IRSA write
  access, all in `lfx-v2-opentofu`. Written for the linuxfoundation
  GitHub org's ops audience — see the `-ops` skill convention in
  `/lfx-skills:lfx`. Fires on prompts like "provision a bucket", "object
  storage backend", "CloudFront for uploads", "S3 bucket opentofu",
  "IRSA for S3", "object store CDN", "bucket policy", "wildcard cert
  uploads". Requirements only; the implementing agent owns the HCL.
allowed-tools: Read, Glob, Grep
---

<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# LFX Object Store Ops

How the object storage backend is provisioned for deployed environments.
This is a requirements stub, deliberately non-prescriptive: it captures the
constraints the Ops team has agreed to, points at the existing conventions
in `lfx-v2-opentofu`, and leaves the HCL to the implementing agent.

Audience: linuxfoundation GitHub org members. This skill is written for
that ops audience and assumes org membership; it does not itself enforce
it (see the `-ops` skill convention in `/lfx-skills:lfx` for how the router
handles routing when membership is unconfirmed). Application-side design
(endpoints, SDK usage, chart contract, local dev) is
`/lfx-skills:lfx-object-store-design`.

## Where

All resources live in
[`lfx-v2-opentofu`](https://github.com/linuxfoundation/lfx-v2-opentofu):

- Environments are OpenTofu **workspaces** (`dev`, `staging`, `prod`), not
  directories. Resource names interpolate `${terraform.workspace}` (see
  `s3.tf` for existing examples).
- Workflow via the repo `Makefile` (`make init/plan/apply`); read the repo
  `README.md` before planning.

## Pattern

Data-driven flat `for_each`, matching the postgres convention
(`postgres-database-definitions.yaml` + `postgres.tf`). **No new module** —
the Ops team prefers flat loops over YAML definitions; modules are reserved
for cases that would otherwise require nested loops (see
`modules/eks-service-account-role/`).

- New `object-store-definitions.yaml` holding one entry per service bucket,
  including a boolean flag marking whether the bucket is public
  (CDN-fronted) — the design skill requires public and private files in
  separate buckets, so this is a per-bucket property, never mixed.
- New `object-storage.tf` with one `for_each` per resource type. Bucket
  resources loop over every entry: `aws_s3_bucket` (+ versioning, SSE,
  lifecycle, public-access-block). CDN resources — `aws_cloudfront_origin_access_control`,
  `aws_cloudfront_distribution`, `aws_s3_bucket_policy` (OAC read policy),
  and the DNS alias records — loop over a filtered
  `{ for k, v in local.object_stores : k => v if v.public }` so a
  distribution is only ever attached to explicitly public buckets.
  Attaching CloudFront/OAC to a service-API-only bucket would make its
  private objects anonymously retrievable. Still flat 1:1 loops, no
  nesting.

## Requirements

### Buckets

- **Private only.** Public access block enabled; no public-read bucket
  policies. The existing `lfx-one-project-logos-png-*` buckets in `s3.tf`
  are a legacy anti-pattern — do not copy them.
- Versioning and SSE enabled; names interpolate `${terraform.workspace}`.
- **Lifecycle rules are mandatory alongside versioning.** With versioning
  on, `DeleteObject` only adds a delete marker and every overwrite retains
  the prior payload as a noncurrent version — without lifecycle
  expiration, storage grows unboundedly and user-"deleted" content is
  retained indefinitely (a data-retention problem, not just a cost one).
  Each bucket gets an `aws_s3_bucket_lifecycle_configuration` (1:1, same
  flat loop) that: expires noncurrent versions after **30 days**, removes
  expired object delete markers, and aborts incomplete multipart uploads
  after **7 days**.

### CloudFront

- **Origin Access Control (OAC)** with a `SourceArn`-conditioned bucket
  policy. Not the legacy OAI (`aws_cloudfront_origin_access_identity`) or
  `forwarded_values` patterns — the ITX
  `cloudfront-distribution-with-s3` module is a structural reference only
  and must not be copied (deprecated OAI, `forwarded_values`, TLSv1).
- Managed cache and origin-request policies that honor the origin
  `Cache-Control` header (services set it per object at upload). The
  design skill's cache-busting query parameter (see
  `/lfx-skills:lfx-object-store-design`) must be included in the cache
  key — a managed policy that strips query strings (such as the default
  `CachingOptimized` policy) will keep serving a stale object after the
  version parameter changes. Use a custom cache policy that forwards that
  parameter if the default managed policies exclude it.
- One standardized `default_cache_behavior` (GET/HEAD); no per-path
  `ordered_cache_behavior` blocks — this keeps dynamic blocks out of the
  loop.

### Certificates

- One shared **wildcard certificate**; distribution aliases are shaped
  `{bucket}.{vanity-domain}` (vanity domain TBD, e.g.
  `*.lfxuseruploads.com` or `*.downloads.lfx.community`). This keeps ACM
  issuance and DNS validation — the one real nested-loop hazard — out of
  the per-bucket loop.
- The certificate must be in `us-east-1` (CloudFront requirement).

### DNS

- The alias and certificate alone do not publish the hostname: each
  `{bucket}.{vanity-domain}` name needs **Route 53 alias A and AAAA
  records** pointing at its CloudFront distribution, in the vanity
  domain's hosted zone. Enable IPv6 on the distribution
  (`is_ipv6_enabled = true` — it defaults to false) so the AAAA record is
  actually served. This is a per-public-bucket 1:1 resource — include it
  in the same filtered public-bucket loop as the distribution. Without it
  the `CDN_URL_PREFIX` handed off below will not resolve.

### Write access (IRSA)

- Service access via the existing IRSA mechanism: an entry in
  `iam-service-account-definitions.yaml` with an inline policy scoped to
  the service's bucket ARN(s), reconciled through
  `modules/eks-service-account-role/`. See
  `lfx-v2-opentofu/docs/service-accounts.md`.
- The policy needs bucket-level `s3:ListBucket` (used by the service's
  `HeadBucket` readiness check and, if applicable, any internal listing —
  see `/lfx-skills:lfx-object-store-design`) plus object-level
  `s3:GetObject`, `s3:PutObject`, and `s3:DeleteObject` on
  `{bucket-arn}/*`. Do **not** grant `s3:CreateBucket` to a deployed role —
  the bucket is provisioned by this ops flow, not by the service at
  startup.
- Bucket definition entries do **not** own IAM; keep the concerns separate.

### Prohibitions

- No public-read buckets or bucket ACLs.
- No static credentials in deployed environments (IRSA only).
- No Cloudflare R2 or other non-AWS deployments. "S3-compatible" in the
  design skill is app-side portability wording only.

## Handoffs

After provisioning, hand these to `lfx-v2-argocd` environment values:

- The IRSA role ARN. `lfx-v2-argocd` creates the ServiceAccount itself in
  its deployment manifests, carrying the `eks.amazonaws.com/role-arn`
  annotation; the service chart is configured with `serviceAccount.create:
  false` and `serviceAccount.name` to reference that externally created
  account (the chart does not render or annotate the SA in this mode).
- The bucket name(s) (`S3_BUCKET`, or the purpose-prefixed variants from
  the design skill's multi-bucket namespacing) — one per bucket — plus the
  region (`AWS_REGION`) once: it is process-wide, and all of a service's
  buckets are provisioned in the environment's single region.
- The CDN hostname (`CDN_URL_PREFIX`, e.g. `https://{bucket}.{vanity-domain}`)
  — one per CDN-fronted bucket.

## Handoff boundary

The implementing agent in `lfx-v2-opentofu` owns the HCL, plan review, and
apply workflow under that repo's local conventions. Application-side chart
and code changes belong to the owning service repo per
`/lfx-skills:lfx-object-store-design`.
