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

S3-compatible object storage is the standard backend for LFX V2 services.
Deployed environments use AWS S3. Local development uses a `nats-s3` sidecar
over NATS Object Store.

"S3-compatible" is an app-side portability statement: the code targets the
S3 API, so any S3-compatible backend works. It is not a deployment
commitment — which backend is actually deployed is an ops concern, handled
by `/lfx-skills:lfx-object-store-ops`.

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

## Hard requirements

These are non-negotiable across all services:

1. **No presigned uploads.** All uploads go through the service API.
   Browsers never write directly to the store.
2. **Private buckets only.** Public reads are served via a CDN with origin
   authorization to the private bucket, never via bucket ACLs or public
   bucket policies.
3. **Per-file maximum size: 20 MB** (logos, meeting attachments, PDFs,
   docx).
4. **Per-service bucket ownership.** Each service manages its own
   bucket(s) — potentially more than one, if the service has distinct
   public (CDN-fronted) and private use cases. FGA relation shapes, allowed
   content types, and access semantics differ per service. There is no
   shared attachment service.
5. **Metadata/payload separation.** Binary payloads never appear in Query
   Service indexed objects, list responses, or NATS events. Only metadata
   (filename, content type, size, uploader, timestamps, download URL) is
   indexed or published.

## API patterns

### Singleton file (exactly one file of a type per resource)

```text
POST   /resources/{uid}/logo-upload      Upload or replace (multipart/form-data)
GET    /resources/{uid}/logo-download    Download
DELETE /resources/{uid}/logo             Remove
```

The download route is not "public" by contract — access is whatever the
Heimdall ruleset says for that route. Set `Cache-Control` on the response to
match the ruleset (`public, ...` when the ruleset allows anonymous reads;
`private, ...` otherwise).

### Collection (multiple files per resource)

```text
POST   /resources/{uid}/documents                     Upload (multipart/form-data)
GET    /resources/{uid}/documents/{doc_uid}            Fetch metadata (including CDN URL, if applicable)
GET    /resources/{uid}/documents/{doc_uid}/download   Download binary
DELETE /resources/{uid}/documents/{doc_uid}            Delete
```

There is no collection-listing REST endpoint. Listing multiple attachments
(or the parent resources that carry a singleton file as an attribute) is a
Query Service concern, not a service API concern. Set `Cache-Control` on the
download response per the ruleset, same as the singleton case.

### Upload flow

1. Validate the JWT via Heimdall middleware. The ruleset enforces
   authorization for the route; there is no separate access-check step here.
2. Validate the file: allowed content types, size ≤ 20 MB.
3. Write to the S3 bucket (standard `PutObject`), setting `Content-Type` and
   `Cache-Control` object metadata.
4. Publish standard NATS indexing events (metadata only, no binary).
5. Return `201`/`204` with metadata, including `public_url` when
   `CDN_URL_PREFIX` is configured.

### Download flow

The service API and the CDN are mutually exclusive paths per file, not
alternate paths for the same file:

- **CDN-fronted files** (public assets such as logos and avatars): served
  directly by the CDN from the private bucket via origin authorization — no
  service involvement, and not served through the service's own download
  route. Use a cache-busting query parameter (not a path segment) for the
  version/hash, since this is a hint, not a guarantee that old versions
  remain hosted.
- **Service-API-only files** (attachments, legal docs): never CDN-fronted.
  The service streams from S3 after the ruleset authorizes the request, with
  `Content-Disposition: attachment` and `Range` header pass-through (`206
  Partial Content`) for PDF viewer compatibility.

### Gateway sizing

Upload routes must accommodate 20 MB request bodies plus multipart overhead
(boundaries, part headers): Traefik `maxRequestBodyBytes` should be set
above `20971520`, with margin for the overhead, not exactly at it. Upload
timeout 120s. Download routes should set `responseBuffering: false`.

## Go code patterns

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
- **No client-facing listing.** `ListObjectsV2` is useful internally (for
  example, to traverse a bucket for maintenance), but it is not how a
  service serves a list of files to a client — that's a Query Service
  concern (see "API patterns" above).
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
  chart renders a locally generated SigV4 key pair into a
  `credentials.json` Secret mounted at `/etc/nats-s3` and injects the same
  pair as AWS env vars into the service container — for example:

  ```yaml
  natsS3:
    enabled: true
    credentials:
      accessKey: "local-dev-access-key"
      secretKey: "local-dev-secret-key"
  ```

- **`cdnURLPrefix` value** mapped to `CDN_URL_PREFIX`.

A service may need more than one bucket (and CDN prefix), especially when it
has both a CDN-fronted public use case and a service-API-only private use
case. Repeat the above per bucket.

The platform umbrella chart (`lfx-v2-helm`) sets the nats-s3 sidecar values
as the local-mode default for service charts; deployed values (IRSA role
ARN, real bucket name, CDN prefix) come from `lfx-v2-argocd`.

## Local development stack

No AWS account required. Two components:

1. **nats-s3 sidecar** (per service pod): the S3-compatible write/read
   backend at `http://localhost:5222`, backed by NATS Object Store in the
   local cluster. Requires a locally generated SigV4 credential pair (see
   above) — not an AWS account, but not "zero credentials" either.
2. **nginx-s3-gateway** (umbrella chart): a local stand-in for the
   production CDN shape, demonstrating the `public_url` pattern end to end.

### Local CDN model (nginx-s3-gateway)

The umbrella chart deploys a standalone pair, independent of any service's
sidecar:

- A dedicated, cluster-reachable **nats-s3 instance** (Deployment+Service)
  per bucket needing a CDN-fronted public URL locally — the "private
  bucket" the local CDN gateway fronts. (Separate from service sidecars,
  which are loopback-only.) A service with more than one CDN-fronted bucket
  needs one of these per bucket.
- An **nginx-s3-gateway** Deployment that proxies unauthenticated `GET`
  requests to that backend, signing them with SigV4 on the way through —
  matching the private-origin, signing-proxy, edge-cache shape used in
  deployed environments, without naming a specific deployed CDN product
  here.

`CDN_URL_PREFIX` points at the gateway's in-cluster Service name; the
service interpolates it into `public_url` on upload/fetch responses.
Setting `CDN_URL_PREFIX=""` omits `public_url` entirely and clients fall
back to the service's authenticated download route — a valid degraded mode.

Example gateway container env, illustrating the required variables:

```yaml
env:
  - name: S3_BUCKET_NAME
    value: "my-service-objects"
  - name: S3_SERVER
    value: "my-service-nats-s3.my-namespace.svc.cluster.local" # FQDN required
  - name: S3_SERVER_PORT
    value: "5222"
  - name: S3_SERVER_PROTO
    value: "http"
  - name: S3_REGION
    value: "us-east-1"
  - name: S3_STYLE
    value: "path"
  - name: S3_SERVICE
    value: "s3"
  - name: ALLOW_DIRECTORY_LIST
    value: "false"
  - name: AWS_SIGS_VERSION
    value: "4"
  - name: CORS_ENABLED
    value: "false"
  - name: AWS_ACCESS_KEY_ID # must match the fronted nats-s3 instance's pair
    value: "local-dev-access-key"
  - name: AWS_SECRET_ACCESS_KEY
    value: "local-dev-secret-key"
  # No DNS_RESOLVERS: the image auto-detects the in-cluster resolver: an
  # explicit value must be an IP, and a Service DNS name here breaks it.
```

Notes on the fields above:

- Image: `ghcr.io/nginx/nginx-s3-gateway/nginx-oss-s3-gateway` (the org
  moved from `nginxinc`); use an `unprivileged-oss-*` tag (non-root, port
  8080).
- `S3_SERVER` must be the fully qualified in-cluster name — nginx's async
  resolver does not apply `/etc/resolv.conf` search suffixes the way
  libc-based tools do, so a short Service name resolves via `kubectl exec
  ... curl` but fails inside nginx itself.
- Use `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`, not the deprecated
  `S3_ACCESS_KEY_ID` / `S3_SECRET_KEY`.

## Environment variable contract

The values/env contract every object-storing service chart exposes (per
bucket, if a service owns more than one):

| Variable                                      | Required   | Description                                                                                                                      |
|-----------------------------------------------|------------|----------------------------------------------------------------------------------------------------------------------------------|
| `S3_BUCKET`                                   | yes        | Bucket name. Local default may be chart-derived; deployed value comes from `lfx-v2-argocd`.                                      |
| `AWS_REGION`                                  | yes        | AWS region. Any non-empty string is accepted by nats-s3; `us-east-1` is the conventional local default.                          |
| `S3_ENDPOINT_URL`                             | no         | Endpoint override. Local: `http://localhost:5222` (sidecar). Empty: real AWS S3.                                                 |
| `CDN_URL_PREFIX`                              | no         | Public CDN base URL interpolated into `public_url` responses. Local: the nginx-s3-gateway Service URL. Empty: omit `public_url`. |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | local only | Injected by the chart in static-credential mode. Never set in deployed environments (IRSA).                                      |

This is a **contract**, not an implementation recipe: env vars injected via
the chart's `env:` block are the platform standard, but how the service
reads them (plain `os.Getenv`, koanf, viper, etc.) follows the owning
repo's local conventions.

## What this skill is not

- Not a provisioning guide. Buckets, CloudFront, wildcard certs, and IRSA
  roles are provisioned via `/lfx-skills:lfx-object-store-ops`.
- Not an FGA modeling guide. Relation shapes per service live in the owning
  service's FGA contract docs.
- Not a Goa or Go conventions guide. The owning repo's path-scoped dev skill
  governs implementation style.
- Not a NATS Object Store guide. NATS Object Store should not be used
  directly (other than as the backend to nats-s3) for object storage in
  LFX.

## Handoff boundary

Once routed to the owning service repo, its local `AGENTS.md`/`CLAUDE.md`,
`docs/`, and repo-local skills control implementation detail. For backend
provisioning (bucket, CDN, IAM), hand off to
`/lfx-skills:lfx-object-store-ops`.
