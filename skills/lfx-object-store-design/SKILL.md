---
name: lfx-object-store-design
description: >
  Central explainer for adding object storage capability to an LFX V2
  service. Covers the S3-compatible storage decision, hard requirements (no
  presigned uploads, private buckets only, 20 MB cap, per-service bucket
  ownership, metadata/payload separation), Go AWS SDK v2 code patterns, the
  singleton and collection API shapes, the Helm chart credential-mode
  contract (static creds for local, IRSA for deployed), the nats-s3 sidecar
  local backend, the nginx-s3-gateway local CDN model, and the
  S3_BUCKET/AWS_REGION/S3_ENDPOINT_URL/CDN_URL_PREFIX env var contract.
  Fires on prompts like "object storage", "S3", "file upload", "upload
  endpoint", "attachments", "logo upload", "bucket", "nats-s3",
  "nginx-s3-gateway", "CDN_URL_PREFIX", "presigned URL", "PutObject",
  "IRSA S3", "S3_ENDPOINT_URL", "public_url", "download endpoint",
  "multipart upload". Read-only; routes implementation work to the owning
  service repo and provisioning to `/lfx-skills:lfx-object-store-ops`.
allowed-tools: Read, Glob, Grep
---

<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# LFX Object Store Design

How an LFX V2 service adds object storage capability: upload/download
endpoints, S3-compatible backend wiring, Helm chart credential modes, and the
local development stack. This is the shared design baseline; service repos
own their implementation.

Decision record: S3-compatible object storage is the standard backend
([LFXV2-2119](https://linuxfoundation.atlassian.net/browse/LFXV2-2119),
decided 2026-07-23). Deployed environments use AWS S3. Local development uses
a `nats-s3` sidecar over NATS Object Store with zero credentials. The full
rationale, PoC, and working example live in
`lfx-architecture-scratch/2026-06-LFX-Object-Storage/` (`README.md`,
`NATS-VS-S3.md`, `SERVICES.md`, and the `s3-service/` reference
implementation).

"S3-compatible" is an app-side portability statement (the code targets the S3
API, so any S3-compatible backend works). It is not a deployment promise:
there is no Cloudflare R2 or other non-AWS deployment. Backend provisioning
belongs to `/lfx-skills:lfx-object-store-ops`.

## When to invoke

- A service is adding file upload, download, attachment, logo, avatar, or
  document storage endpoints.
- A chart needs S3 backend configuration, credential-mode values, or the
  nats-s3 sidecar.
- Questions about `CDN_URL_PREFIX`, `public_url`, presigned URLs, bucket
  ownership, or local object-storage development.

Do **not** invoke for:

- Provisioning buckets, CloudFront, IAM roles, or certificates
  (`/lfx-skills:lfx-object-store-ops`).
- FGA relation modeling detail (owning service's FGA contract docs).
- Existing NATS Object Store usage in `lfx-v2-project-service` /
  `lfx-v2-committee-service` (legacy pattern; new capability follows this
  skill).

## Hard requirements

These are non-negotiable across all services:

1. **No presigned uploads.** All uploads go through the service API.
   Browsers never write directly to the store. (The v1 presigned-URL pattern
   is explicitly deprecated.)
2. **Private buckets only.** Public reads are served via CDN (CloudFront
   with Origin Access Control), never via bucket ACLs or public bucket
   policies.
3. **Per-file maximum size: 20 MB** (logos, meeting attachments, PDFs,
   docx).
4. **Per-service bucket ownership.** Each service manages its own
   bucket(s). FGA relation shapes, allowed content types, and access
   semantics differ per service. There is no shared attachment service.
5. **Metadata/payload separation.** Binary payloads never appear in Query
   Service indexed objects, list responses, or NATS events. Only metadata
   (filename, content type, size, uploader, timestamps, download URL) is
   indexed or published.

## API patterns

### Singleton file (exactly one file of a type per resource)

```text
POST   /resources/{uid}/logo              Upload or replace (multipart/form-data)
GET    /resources/{uid}/logo              Download (public, CDN-cacheable)
DELETE /resources/{uid}/logo              Remove
```

### Collection (multiple files per resource)

```text
POST   /resources/{uid}/documents                       Upload (multipart/form-data)
GET    /resources/{uid}/documents                       List metadata
GET    /resources/{uid}/documents/{doc_uid}/download    Download binary
DELETE /resources/{uid}/documents/{doc_uid}             Delete
```

### Upload flow

1. Validate JWT via Heimdall middleware.
2. Check FGA: caller has the write relation (`editor`/`organizer`) on the
   parent entity.
3. Validate file: allowed content types, size ≤ 20 MB.
4. Write to the S3 bucket (standard `PutObject`), setting `Content-Type` and
   `Cache-Control` object metadata.
5. Publish a NATS event (metadata only, no binary).
6. Return `201`/`204` with metadata, including `public_url` when
   `CDN_URL_PREFIX` is configured.

### Download flow

- **Public assets** (logos, avatars): no service involvement — the CDN
  serves from the private bucket via OAC. Use content-addressed filenames
  (hash/version in path) with `Cache-Control: public, max-age=86400,
  immutable`; replacing a file changes the URL, forcing invalidation.
- **Private files** (attachments, legal docs): the service streams from S3
  after an FGA `viewer` check, with `Content-Disposition: attachment`,
  `Cache-Control: private, max-age=300`, and `Range` header pass-through
  (`206 Partial Content`) for PDF viewer compatibility.

### Gateway sizing

Upload routes must accommodate 20 MB request bodies: Traefik
`maxRequestBodyBytes` ≥ `20971520`, upload timeout 120s. Download routes
should set `responseBuffering: false`.

## Go code patterns

The living example is
`lfx-architecture-scratch/2026-06-LFX-Object-Storage/s3-service/` (store in
`internal/store/store.go`, startup in `cmd/s3-api/main.go`).

- **AWS SDK v2 with the default credential chain — no code branching.** The
  chain resolves static env credentials (local sidecar) or the IRSA
  web-identity token (deployed EKS) transparently. Never write
  credential-mode conditionals in service code.
- **Endpoint override:** when `S3_ENDPOINT_URL` is set, apply it via
  `config.WithBaseEndpoint`. Empty means real AWS S3.
- **Path-style addressing:** set `o.UsePathStyle = true` on the S3 client;
  required by nats-s3 and most S3-compatible endpoints.
- **Startup:** run an idempotent `EnsureBucket`
  (`HeadBucket`-then-`CreateBucket`) with a retry loop (~10 attempts, 3s
  apart) before accepting traffic — the local sidecar may not be ready
  immediately. In deployed environments the bucket pre-exists and
  `EnsureBucket` is a no-op.
- **Readiness:** back `/readyz` with a `HeadBucket` ping.
- **Delete semantics:** S3 `DeleteObject` is idempotent; `HeadObject` first
  if the API must return not-found for missing keys.
- **Listing:** `ListObjectsV2` returns only `Key` and `Size` — no
  `ContentType`. Keep content type in your own metadata store if list
  responses need it; do not issue per-key `HeadObject` fan-outs.
- **Cache-Control:** set the native `CacheControl` field on `PutObject` and
  restore it on download.

## Helm chart contract

The service chart must support both credential modes, selected purely by
values (mirroring the SDK credential chain — no code change):

| Mode               | When                     | Chart behavior                                                                                            |
|--------------------|--------------------------|-----------------------------------------------------------------------------------------------------------|
| Static credentials | Local (nats-s3 sidecar)  | `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` injected from a Secret (inline values or `existingSecret`). |
| Role-based (IRSA)  | Deployed (AWS S3 on EKS) | No credential env vars — only `AWS_REGION`. SDK discovers the projected web-identity token.               |

Chart requirements:

- **Externally managed ServiceAccount support**: `serviceAccount.create:
  false` plus `serviceAccount.name` and an `annotations` passthrough, so an
  IRSA-annotated SA provisioned outside the chart can be supplied. This is a
  prerequisite for deployed environments.
- **`s3.endpointURL` value** mapped to `S3_ENDPOINT_URL` (empty = real AWS).
- **nats-s3 sidecar block** for local mode: a second container in the
  service pod listening on `localhost:5222` (loopback only), translating
  SigV4-signed S3 calls into NATS JetStream Object Store operations. The
  chart renders the SigV4 key pair into a `credentials.json` Secret mounted
  at `/etc/nats-s3` and injects the same pair as AWS env vars into the
  service container.
- **`cdnURLPrefix` value** mapped to `CDN_URL_PREFIX`.

The platform umbrella chart (`lfx-v2-helm`) sets the nats-s3 sidecar values
as the local-mode default for service charts; deployed values (IRSA role
ARN, real bucket name, CDN prefix) come from `lfx-v2-argocd`.

## Local development stack

No AWS account or credentials required. Two components:

1. **nats-s3 sidecar** (per service pod): the S3-compatible write/read
   backend at `http://localhost:5222`, backed by NATS Object Store in the
   local cluster.
2. **nginx-s3-gateway** (umbrella chart): a local stand-in for the
   production CDN, demonstrating the `public_url` pattern end to end.

### Local CDN model (nginx-s3-gateway)

The umbrella chart deploys a standalone pair, independent of any service's
sidecar:

- A dedicated, cluster-reachable **nats-s3 instance** (Deployment+Service) —
  the "private bucket" the CDN fronts. (Separate from service sidecars,
  which are loopback-only.)
- An **nginx-s3-gateway** Deployment that proxies unauthenticated `GET`
  requests to that backend, signing them with SigV4 on the way through —
  structurally the same as CloudFront + OAC (private origin, signing proxy,
  edge cache).

`CDN_URL_PREFIX` points at the gateway's in-cluster Service name; the
service interpolates it into `public_url` on upload/list responses. Setting
`CDN_URL_PREFIX=""` omits `public_url` entirely and clients fall back to the
service's authenticated download routes — a valid degraded mode.

Gotchas when wiring nginx-s3-gateway (validated in the PoC, LFXV2-2847):

- Images are published under
  `ghcr.io/nginx/nginx-s3-gateway/nginx-oss-s3-gateway` (the org moved from
  `nginxinc`). Use an `unprivileged-oss-*` tag (non-root, port 8080).
- Required env vars: `S3_BUCKET_NAME`, `S3_SERVER`, `S3_SERVER_PORT`,
  `S3_SERVER_PROTO`, `S3_REGION`, `S3_STYLE`, `S3_SERVICE`,
  `ALLOW_DIRECTORY_LIST`, `AWS_SIGS_VERSION`, `CORS_ENABLED` — the
  entrypoint fails silently if any are missing.
- Credentials via `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` (not the
  deprecated `S3_ACCESS_KEY_ID` / `S3_SECRET_KEY`); they must match the
  fronted nats-s3 instance's SigV4 pair.
- Do **not** set `DNS_RESOLVERS` — the image auto-detects the in-cluster
  resolver, and nginx's `resolver` directive requires an IP, not a Service
  DNS name.
- `S3_SERVER` must be a fully qualified in-cluster name
  (`<svc>.<namespace>.svc.cluster.local`); nginx's async resolver does not
  apply `/etc/resolv.conf` search suffixes.

## Environment variable contract

The values/env contract every object-storing service chart exposes:

| Variable                                      | Required   | Description                                                                                                                      |
|-----------------------------------------------|------------|----------------------------------------------------------------------------------------------------------------------------------|
| `S3_BUCKET`                                   | yes        | Bucket name. Local default may be chart-derived; deployed value comes from `lfx-v2-argocd`.                                      |
| `AWS_REGION`                                  | yes        | AWS region. Any non-empty string is accepted by nats-s3; `us-east-1` is the conventional local default.                          |
| `S3_ENDPOINT_URL`                             | no         | Endpoint override. Local: `http://localhost:5222` (sidecar). Empty: real AWS S3.                                                 |
| `CDN_URL_PREFIX`                              | no         | Public CDN base URL interpolated into `public_url` responses. Local: the nginx-s3-gateway Service URL. Empty: omit `public_url`. |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | local only | Injected by the chart in static-credential mode. Never set in deployed environments (IRSA).                                      |

This is a **contract**, not an implementation recipe: env vars injected via
the chart's `env:` block are the platform standard, but how the service
reads them (plain `os.Getenv`, koanf, etc.) follows the owning repo's local
conventions.

## What this skill is not

- Not a provisioning guide. Buckets, CloudFront, wildcard certs, and IRSA
  roles are provisioned via `/lfx-skills:lfx-object-store-ops`.
- Not an FGA modeling guide. Relation shapes per service live in the owning
  service's FGA contract docs.
- Not a Goa or Go conventions guide. The owning repo's path-scoped dev skill
  governs implementation style.
- Not a NATS Object Store guide. Direct NATS Object Store usage (ObjectStore
  CRD, `project-documents` bucket) is the legacy pattern; new object storage
  capability targets the S3 API per this skill.

## Handoff boundary

Once routed to the owning service repo, its local `CLAUDE.md`, `docs/`, and
repo-local skills control implementation detail. For backend provisioning
(bucket, CDN, IAM), hand off to `/lfx-skills:lfx-object-store-ops`.
