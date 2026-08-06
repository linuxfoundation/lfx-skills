---
name: lfx-v2-secrets
description: >
  Guide an agent through wiring up secrets for LFX V2 microservices using External Secrets
  Operator (ESO) + IRSA. Handles both new services (full infrastructure setup) and existing
  services (add a secret to an already-configured service) by checking whether the ESO
  objects exist before deciding which steps to run. Use this skill whenever someone says
  "set up secrets", "wire up ESO", "add a secret to this service", "IRSA configuration",
  "External Secrets for V2", or any mention of AWS Secrets Manager integration with
  Kubernetes for LFX V2 services.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion, WebFetch
---

<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->
<!-- Tool names in this file use Claude Code vocabulary. See docs/tool-mapping.md for other platforms. -->

# LFX V2 Secrets Setup Guide

Secrets for LFX V2 microservices are managed through **External Secrets Operator (ESO)**
combined with **IAM Roles for Service Accounts (IRSA)** on AWS. This provides a secure,
GitOps-driven way to sync secrets from **AWS Secrets Manager (SM)** into Kubernetes.

---

## Understanding the Architecture

### How It Works

1. Local development: secret values are supplied directly — ESO is not involved.
   See [Local Testing Before Committing](#local-testing-before-committing).
2. A **Kubernetes ServiceAccount** is annotated with an **IRSA role ARN**
3. ESO's **SecretStore** uses that ServiceAccount's JWT token to authenticate to AWS
4. ESO watches **ExternalSecret** manifests and syncs matching secrets from AWS Secrets Manager into K8s Secrets
5. Application deployments reference the K8s Secret via environment variable or volume mount

### Key Constants

These values are fixed and apply across all V2 services:

| Item | Value |
|------|-------|
| AWS Region | `us-west-2` |
| K8s Secret name | `<service>-secrets` (e.g., `lfx-v2-committee-service-secrets`) |
| SecretStore name | `<service>` — matches `metadata.name` in `SecretStore.yaml` and `spec.secretStoreRef.name` in `ExternalSecret.yaml` |
| IAM account — dev | `788942260905` |
| IAM account — staging | `844790888233` |
| IAM account — prod | `372256339901` |
| IRSA role ARN pattern | `arn:aws:iam::<account-id>:role/<service>` |
| AWS Secrets Manager path pattern | `<3rd-party-service>/<lfx-v2-service-name>/[<secret_type>]` |
| AWS Secrets Manager path prefix | `/cloudops/managed-secrets` — applied automatically to every `path:` in `lfx-secrets-management`; see `secrets/lfx/.config.yml` |
| ServiceAccount annotation key | `eks.amazonaws.com/role-arn` |
| ESO JWT auth field | `spec.provider.aws.auth.jwt.serviceAccountRef` |

---

## Local Testing Before Committing

Before opening any PR, validate that the service reads the values correctly under the exact
key names you intend to use in AWS Secrets Manager. Getting a field name wrong after the fact means a second
round of PRs across `lfx-secrets-management` and `lfx-v2-argocd` — cheaper to catch it now.

### Option A: Local `.env` backed by `op item get`

Resolve values at load time by shelling out to the 1Password CLI, so no secret material is
ever written to disk.

Before writing `.env`, verify it's gitignored — check with `git check-ignore .env`, and if that
reports nothing, append `.env` to `.gitignore` first. Even though `.env` holds `op item get`
commands rather than resolved values, a committed copy still leaks 1Password item/vault/field
names.

```bash
# .env — resolved via `set -a && source .env`, never committed
SUPABASE_API_KEY=$(op item get "LFX v2 supabase" --vault "LFX V2 - Development" --fields api_key --reveal)
AUTH0_CLIENT_ID=$(op item get "auth0 LFX V2 Committee Service" --vault "LFX V2 - Development" --fields auth0_client_id --reveal)
```

- Requires `op signin` first.
- `--reveal` is needed for concealed/password fields, or `op` returns a masked value.
- `--vault` should be the environment vault you're targeting (`LFX V2 - Development` for normal
  local work).
- The item and field names passed to `op` are the same strings that go in the `item:` and
  `fields:` keys in [Step 4](#step-4-add-entry-to-lfx-secrets-management) — a typo here surfaces
  now instead of after a merge.

### Option B: Hand-created K8s Secret

For running the service in a **local cluster** where the deployment already reads from
`secretKeyRef`:

```bash
kubectl create secret generic <service>-secrets \
  --namespace <service-namespace> \
  --from-file=<field_name_1>=<(op item get "<1Password item name>" --vault "LFX V2 - Development" --fields <field_name_1> --reveal) \
  --from-file=<field_name_2>=<(op item get "<1Password item name>" --vault "LFX V2 - Development" --fields <field_name_2> --reveal)
```

- Requires `op signin` first (same as Option A).
- Piping through `op` via process substitution keeps the value out of shell history and
  `kubectl`'s process arguments — never use `--from-literal` with a real secret value.
- A single `kubectl create secret generic` invocation must cover every field: `kubectl create
  secret generic` errors with `AlreadyExists` if run again for the same Secret, so add one
  `--from-file=<field_name>=<(op item get ...)>` per key in the same command rather than
  repeating the command per field.
- Name the Secret and its keys exactly as the `ExternalSecret` will produce them
  (`<service>-secrets`, and field names matching the `fields:`/`rename_fields:` values from
  Step 4) so the `environment` block written in [Step 5](#step-5-wire-secrets-into-service-environment-in-lfx-v2-argocd)
  needs no edits once ESO takes over.
- Delete the hand-created Secret before ESO is deployed to the same namespace — ESO's
  `creationPolicy: Owner` will otherwise conflict with a Secret it did not create.

Once the service works against locally supplied values, proceed to
[Step 1](#step-1-gather-information-from-the-user) with the field names confirmed.

---

## Branching

Before making any changes, create a branch in each repo being modified. Use the format
`<username>/<secret-name>`. Never commit directly to `main`. The username is the git
username (typically the part before `@` in the email). Always sign off commits.

---

## Step 1: Gather Information from the User

Identify `<service>` — the fully qualified service name including the `lfx-v2-` prefix (e.g.,
`lfx-v2-committee-service`). If the user did not include it in their request, ask for it now
before proceeding. This is used directly in all resource names: K8s Secret is `<service>-secrets`,
role ARN ends in `<service>`, etc.

If not already provided in the initial request, ask the user for:

1. **List of secrets** — LFX V2 secrets come from either 1Password or Auth0:

   **1Password sources** (e.g., API keys, SMTP credentials):
   - **Secret name** (e.g., "LinkedIn Credentials", "SMTP Credentials")
   - **Third-party service** that provides the secret (e.g., `litellm`, `github`)
   - **1Password item name** — exact name as it appears in the vault
   - **Field names in 1Password** — the exact field names as they appear in the source vault

   **Auth0 sources** (e.g., M2M client credentials, BFF client secrets):
   - **Auth0 client name** — exact display name in Auth0 (e.g., `LFX V2 Invite Service`)
   - **Credential type** — `auth0` (produces `client_id` + `client_secret`) or `auth0_jwt`
     (produces `client_id` + `client_public_key` + `client_private_key`; standard for LFX V2
     microservices)
   - **Auto-rotate** — yes/no; default `true` for `auth0_jwt` V2 services
   - **AWS Secrets Manager path** — follows `auth0/<ClientName_With_Underscores>` convention
     (e.g., `auth0/LFX_V2_Invite_Service`)

   > Field renames are applied automatically — always prefix with `auth0_` (e.g., `client_id` →
   > `auth0_client_id`, `client_secret` → `auth0_client_secret`, `client_private_key` →
   > `auth0_client_private_key`). Do not ask the user for these.

2. **Which environments need this secret** — `development`, `staging`, `production`

**1Password example:**

```text
Service: lfx-v2-invite-service
Namespace: invite-service
Secrets:
  - Atlassian API Key (3rd party service: atlassian, 1Password field: atlassian_api_key) - all envs
  - Supabase API Key (3rd party service: supabase, 1Password fields: url, api_key) - all envs
```

**Auth0 examples:**

`auth0` (client_secret, simpler M2M or BFF clients):

```text
Service: lfx-v2-committee-service
Namespace: committee-service
Auth0 secrets:
  - Committee Service BFF
      type: auth0
      client: "LFX V2 Committee BFF"
      path: auth0/LFX_V2_Committee_BFF
```

`auth0_jwt` (JWT private key, standard for LFX V2 microservices):

```text
Service: lfx-v2-committee-service
Namespace: committee-service
Auth0 secrets:
  - Committee Service M2M
      type: auth0_jwt
      client: "LFX V2 Committee Service"
      auto_rotate: true
      path: auth0/LFX_V2_Committee_Service
```

---

## Step 2: Check Whether ESO Is Already Configured

Before making any changes, look up the service's infrastructure details and determine whether
the IAM entry, `SecretStore`, and `ExternalSecret` objects already exist. `lfx-v2-argocd` and
`lfx-v2-opentofu` are **private repos** — an unauthenticated `raw.githubusercontent.com` request
against a private repo returns 404 whether or not the file exists, so 404 cannot be trusted as
"missing" for those two checks. Use an authenticated method instead: `gh api
repos/linuxfoundation/<repo>/contents/<path>` (exit code / 404 from `gh` reflects the real repo
state), or a local checkout if one is available. Only the public service-repo fetch
(`serviceaccount.yaml`) may treat an unauthenticated raw 404 as "missing".

### 2a. Fetch IAM service account definitions

Check `iam-service-account-definitions.yaml` in `lfx-v2-opentofu` (private — use `gh api` or a
local checkout, not an unauthenticated raw fetch):

```bash
gh api repos/linuxfoundation/lfx-v2-opentofu/contents/iam-service-account-definitions.yaml \
  --jq '.content' | base64 -d
```

If this fails for a reason other than "file/entry not found" (e.g., auth error), ask the user to
provide the service's namespace and eso_service_tag.

Look up the entry for `<service>`:

- **`namespace`** — note the value; defaults to `<service>` if not set. Confirm with the user
  only if the entry is missing entirely.
- **`service_account`** — note the value; defaults to `<service>` if not set. This is the
  actual K8s ServiceAccount name and **must** be used (not `<service>`) everywhere a
  ServiceAccount is named or referenced in Steps 3b/3c below, or ESO authenticates as the
  wrong ServiceAccount and AWS auth fails.
- **`eso_service_tag`** — note the value; defaults to `<service>` if not set. If the file is
  inaccessible or the entry is missing, ask the user to confirm the tag (suggest `<service>` as
  the default).
- **Record whether the entry exists at all** — this feeds the per-item gate below, independent
  of the 2b checks.

### 2b. Check for existing ESO objects

Determine whether `SecretStore` and `ExternalSecret` objects already exist for this service.
The service repo name matches the service name (e.g., `lfx-v2-committee-service`
lives at `github.com/linuxfoundation/lfx-v2-committee-service`).

```bash
# SecretStore / ExternalSecret in lfx-v2-argocd (private — use gh api, not raw fetch)
gh api repos/linuxfoundation/lfx-v2-argocd/contents/custom-resources/<service>/SecretStore.yaml
gh api repos/linuxfoundation/lfx-v2-argocd/contents/custom-resources/<service>/ExternalSecret.yaml

# ServiceAccount in the service Helm chart (public repo — raw fetch is fine; 404 means missing)
https://raw.githubusercontent.com/linuxfoundation/<service>/main/charts/<service>/templates/serviceaccount.yaml
```

If a `gh api` call fails for a reason other than "not found" (auth error, no `gh` available),
fall back to checking the local filesystem if the repo is checked out, or ask the user whether
ESO is already configured for this service.

**Evaluate each of the four items independently** — the 2a IAM entry, the Helm
`serviceaccount.yaml`, `SecretStore.yaml`, and `ExternalSecret.yaml`:

- **Present** → leave it alone; do not re-run that item's Step 3 sub-step.
- **Missing** → run 2c *before* concluding this means "run Step 3c" — an absent
  `SecretStore.yaml`/`ExternalSecret.yaml` in `custom-resources/` can mean either "not set up
  yet" or "this service uses a different, chart-owned pattern." Only the former runs 3c.

**If all four are present** → skip Step 3 entirely and go to
[Step 4](#step-4-add-entry-to-lfx-secrets-management).

### 2c. Confirm the service follows the standard pattern

Run this whenever 2b found `SecretStore.yaml` and/or `ExternalSecret.yaml` missing, before
concluding they need to be created. Some services own ESO from inside their Helm chart instead
of via static CRs in `lfx-v2-argocd/custom-resources/<service>/` — for those, "missing" is
expected and Step 3c must **not** run.

Check both signals:

1. **Chart-owned templates** — does the service chart have
   `charts/<service>/templates/secretstore.yaml` or `externalsecret.yaml`?
   ```bash
   gh api repos/linuxfoundation/<service>/contents/charts/<service>/templates/secretstore.yaml
   gh api repos/linuxfoundation/<service>/contents/charts/<service>/templates/externalsecret.yaml
   ```
   Presence of either means the chart owns ESO — driven by an
   `externalSecretsOperator.*` block in `values.yaml`, typically with an explicit `data:` list
   rather than tag-based discovery.
2. **`customResources` flag** — does this service's entry in
   `apps/<env>/lfx-v2-applications.yaml` set `customResources: true`? This flag is what actually
   gates whether `custom-resources/<service>/` is applied at all
   (`apps/dev/lfx-v2-applications.yaml` wraps that source in `{{- if .customResources }}`).
   Without it, anything in `custom-resources/<service>/` is inert regardless of what's in the
   directory — the inverse of the chart-owned case, and worth flagging if you find it.

**If either signal indicates chart-owned ESO**: stop. Do not run Step 3c. Report the deviation
to the user plainly — this service diverges from the standard tag-based `custom-resources/`
pattern the rest of this skill assumes — and ask how they want to proceed before touching
`ExternalSecret.yaml`, Step 5's wiring, or anything else downstream that assumes the standard
shape. Creating the standard CRs here would produce a second, competing ESO setup.

**If neither signal fires** → the absence is real; proceed to Step 3c as normal.

---

## Step 3: Set Up ESO Infrastructure (Missing Items Only)

Each sub-step below runs **only if Step 2 found that specific item missing** — a partially
configured service (e.g., IAM entry present but `ExternalSecret.yaml` missing) runs only the
sub-steps for what's actually absent, not the whole of Step 3. This can touch up to three repos.

### Step 3a: Add IAM Service Account Entry in `lfx-v2-opentofu`

Run only if 2a found no entry for `<service>`.

In the [lfx-v2-opentofu](https://github.com/linuxfoundation/lfx-v2-opentofu) repo,
edit `iam-service-account-definitions.yaml` and add:

```yaml
service_account_roles:
  <service>:
    namespace: "<service-namespace-name>"
```

Example for committee service:

```yaml
service_account_roles:
  lfx-v2-committee-service:
    namespace: "committee-service"
```

> **Defaults**: All fields default to the role key (i.e., `<service>`): `namespace`,
> `service_account`, and `eso_service_tag`. Only specify a field when its value differs
> from the role key.

### Step 3b: Create ServiceAccount in the Service Helm Chart

Run only if 2b found `charts/<service>/templates/serviceaccount.yaml` missing in the service repo.

In the service repo's Helm chart (e.g., `lfx-v2-invite-service`), create
`charts/<service>/templates/serviceaccount.yaml`:

```yaml
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
{{- if .Values.serviceAccount.create }}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ .Values.serviceAccount.name | default .Chart.Name }}
  namespace: {{ .Release.Namespace }}
  labels:
    app: {{ .Chart.Name }}
  {{- with .Values.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
automountServiceAccountToken: {{ .Values.serviceAccount.automountServiceAccountToken }}
{{- end }}
```

Add to `charts/<service>/values.yaml`:

```yaml
serviceAccount:
  create: true
  name: "<service_account>"
  annotations: {}
  automountServiceAccountToken: true
```

Use the `service_account` value read in 2a (defaults to `<service>` — only substitute a
different literal if that field was explicitly overridden in `iam-service-account-definitions.yaml`).

### Step 3c: Create Custom Resources in `lfx-v2-argocd`

The `SecretStore` and `ExternalSecret` are **static YAML files** (not Helm templates) placed in
`lfx-v2-argocd/custom-resources/<service>/`. Create only the file(s) 2b found missing — if one
already exists, leave it as-is.

Create `custom-resources/<service>/SecretStore.yaml` (only if missing):

```yaml
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
---
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: <service>
  namespace: <service-namespace>
spec:
  provider:
    aws:
      auth:
        jwt:
          serviceAccountRef:
            name: <service_account>
      region: us-west-2
      service: SecretsManager
```

`serviceAccountRef.name` must be the actual K8s ServiceAccount name — the `service_account`
value from 2a (defaults to `<service>`), not always `<service>` itself. A mismatch here means
ESO requests a token for the wrong ServiceAccount and AWS authentication fails.

Create `custom-resources/<service>/ExternalSecret.yaml` (only if missing):

```yaml
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: <service>
  namespace: <service-namespace>
spec:
  secretStoreRef:
    kind: SecretStore
    name: <service>
  target:
    creationPolicy: Owner
    name: <service>-secrets
  refreshInterval: 10m
  dataFrom:
    - find:
        conversionStrategy: Default
        decodingStrategy: None
        tags:
          service-<eso_service_tag>: enabled
      rewrite:
        - merge:
            conflictPolicy: Error
            into: ''
            strategy: Extract
```

> **Tag-based discovery**: ESO finds and merges all AWS Secrets Manager secrets tagged
> `service-<eso_service_tag>: enabled` into a single Kubernetes Secret named
> `<service>-secrets`. No manual `data` list is needed — new secrets are picked up
> automatically after the next sync.

### Step 3d: Add IRSA Annotation in `lfx-v2-argocd` Per-Environment Values

In `values/dev/<service>.yaml` (repeat for staging and prod with the matching account ID):

```yaml
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
---
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::788942260905:role/<service>
  automountServiceAccountToken: true
```

| Environment | Account ID | File |
|-------------|-----------|------|
| Development | `788942260905` | `values/dev/<service>.yaml` |
| Staging | `844790888233` | `values/staging/<service>.yaml` |
| Production | `372256339901` | `values/prod/<service>.yaml` |

---

## Step 4: Add Entry to `lfx-secrets-management`

In the [lfx-secrets-management](https://github.com/linuxfoundation/lfx-secrets-management) repo,
add an entry for each secret to `secrets/lfx/<service>.yml` — one file per LFX V2 service.
If the file doesn't exist yet, create it. If it already exists, append the new entry.

> **Important**: All secrets must be stored as JSON in AWS Secrets Manager, even single-field ones.
> Two equivalent ways to express this:
>
> ```yaml
> # implicit JSON (list form)
> fields:
>   - <field_name>
>
> # explicit JSON (scalar + flag)
> fields: <field_name>
> store_as_json: true
> ```

**1Password template:**

```yaml
<Secret Name>:
  tags: [lfx_v2, <service_tag>, <3rd_party_service_tag>]
  envs: [development, staging, production]
  source:
    onepassword:
      vaults:
        development: LFX V2 - Development
        staging: LFX V2 - Staging
        production: LFX V2 - Production
      item: <1Password Item Name>
      fields:
        - <field_name>
  destinations:
    - aws_secretsmanager:
        tags:
          service-<eso_service_tag>: enabled
        path: <3rd-party-service>/<service>
```

Example for Supabase API key:

```yaml
Supabase API Key:
  tags: [lfx_v2, lfx-self-serve, supabase]
  envs: [development, staging, production]
  source:
    onepassword:
      vaults:
        development: LFX V2 - Development
        production: LFX V2 - Production
        staging: LFX V2 - Staging
      item: LFX v2 supabase
      fields:
        - url
        - api_key
  destinations:
    - aws_secretsmanager:
        tags:
          service-pcc: enabled
        path: supabase/lfx-self-serve
```

> **Tips**:
>
> - Each secret becomes a separate AWS Secrets Manager path entry
> - The `path` must include the service name: `<3rd-party-service>/<service>`
>   (e.g., `atlassian/lfx-v2-committee-service`)
> - The `tags` list must include the fully qualified service name (`<service>`) so the secret is identifiable
> - Use the `envs` list to sync to all three environments in parallel
> - The `source.onepassword.item` should match exactly the name in 1Password vaults
> - Field names should be descriptive enough to avoid duplicates (`litellm_api_key`, not just `api_key`)
> - The `path:` value here is relative — `lfx-secrets-management` applies the
>   `path_prefix` from `secrets/lfx/.config.yml` (currently `/cloudops/managed-secrets`)
>   automatically. `path: <3rd-party>/<service>` therefore lands in AWS at
>   `/cloudops/managed-secrets/<3rd-party>/<service>`. Use the **full prefixed path** when
>   writing `remoteRef.key` in Step 5, running `aws secretsmanager describe-secret`, or
>   debugging a failed ExternalSecret sync — the relative `path:` will not resolve there.

**Auth0 template** (`auth0` — client_secret):

> For LFX V2 services, always rename fields to a descriptive name prefixed with `auth0_`
> (e.g. `auth0_client_id`, `auth0_client_secret`) so keys are unambiguous in the merged K8s Secret.

```yaml
<Secret Name>:
  tags: [auth0, <service_tag>]
  envs: [development, staging, production]
  source:
    auth0:
      client_name: <Auth0 Client Name>
      rename_fields:
        client_id: auth0_client_id
        client_secret: auth0_client_secret
  destinations:
    - onepassword:
        item: auth0 <Service Name>
        field_types:
          auth0_client_id: text
          auth0_client_secret: password
    - aws_secretsmanager:
        path: auth0/<ClientName_With_Underscores>
        tags:
          service-<eso_service_tag>: enabled
```

**Auth0 template** (`auth0_jwt` — JWT private key):

```yaml
<Secret Name>:
  tags: [auth0_jwt, <service_tag>]
  envs: [development, staging, production]
  auto_rotate: true
  source:
    auth0_jwt:
      client_name: <Auth0 Client Name>
      rename_fields:
        client_id: <renamed_client_id>
        client_public_key: <renamed_client_public_key>
        client_private_key: <renamed_client_private_key>
  destinations:
    - onepassword:
        item: auth0 <Service Name>
        field_types:
          <renamed_client_id>: text
          <renamed_client_public_key>: text
          <renamed_client_private_key>: password
    - aws_secretsmanager:
        path: auth0/<ClientName_With_Underscores>
        tags:
          service-<eso_service_tag>: enabled
```

> **Naming review**: Before finalising the entry, review the secret name, tags, and
> destination path against this test: could a reasonable person look at each value and
> have a reasonable idea of what the secret is and where it came from — without needing
> to read the source or ask anyone? If not, rename before proceeding. For example:
> - Secret name: `Atlassian API Key` ✓ — `Key` ✗
> - Tags: `[lfx_v2, atlassian, lfx-v2-committee-service]` ✓ — `[lfx_v2, key]` ✗
> - Path: `atlassian/lfx-v2-committee-service` ✓ — `api_key` ✗

> **Important**: After the `lfx-secrets-management` PR is merged, the secret must be deployed
> to AWS Secrets Manager before the `lfx-v2-argocd` PR can merge — ArgoCD will fail to sync if the secret
> doesn't exist yet.
>
> **For 1Password secrets**: trigger the
> [Deploy workflow](https://github.com/linuxfoundation/lfx-secrets-management/actions/workflows/deploy.yml)
> manually:
> 1. Go to the Deploy workflow page linked above
> 2. Click **Run workflow**
> 3. In the tag field, enter the most specific tag from the `tags:` field in your YAML entry
>    (e.g. `litellm`, `atlassian`) — not the AWS resource tag — to avoid re-deploying or
>    rotating unrelated secrets
> 4. Confirm the workflow completes successfully before merging the `lfx-v2-argocd` PR
>
> If you're not comfortable triggering the workflow yourself, ask the Platform Engineering team
> to run it for you.
>
> **For Auth0 JWT secrets** (`auth0_jwt` source type): do not trigger the workflow yourself —
> these secrets are rotated on every deploy. Ask the Platform Engineering team to deploy it
> and coordinate the timing so only the intended service's credentials are rotated.

---

## Step 5: Wire Secrets into Service Environment in `lfx-v2-argocd`

Add an `environment` block (or extend the existing one) that maps each secret field to an
environment variable. Reference the Kubernetes Secret created by the ExternalSecret
(`<service>-secrets`) and use the field name as the key.

- If the secret is deployed to **all environments**, add it to `values/global/<service>.yaml`
- If the secret is deployed to **specific environments only**, add it to each relevant
  per-environment file (`values/dev/<service>.yaml`, `values/staging/<service>.yaml`,
  `values/prod/<service>.yaml`) instead

> **Warning — Helm replaces lists, it does not merge them.** ArgoCD loads
> `values/global/<service>.yaml` then `values/<env>/<service>.yaml`. Helm's `-f` layering
> merges *maps* across those files but **replaces list values wholesale** — a per-env file
> that redeclares a list-valued key (e.g. an `externalSecret.data:` list on a chart-owned
> service) silently drops every entry global contributed, it does not append to them. Prefer
> putting list-valued secret config in `values/global/` for anything needed everywhere; if a
> per-env override is unavoidable, restate the **full** list, not just the new entries. This
> failure is silent and can be delayed — losing an RDS credential entry this way doesn't show
> up until the next rotation (often weeks later) because `deletionPolicy: Retain` keeps the
> stale Secret serving in the meantime.

> Before writing `secretKeyRef.name`, verify the K8s Secret name from `ExternalSecret.yaml`
> in `lfx-v2-argocd/custom-resources/<service>/` — check `spec.target.name`. It is typically
> `<service>-secrets` but must match exactly. Field names here should already match what was
> exercised in [Local Testing Before Committing](#local-testing-before-committing).

> Tag-based discovery means new secrets are picked up automatically — no changes to
> `ExternalSecret.yaml` are needed as long as the AWS Secrets Manager tag matches the service.

> **lfx-self-serve**: If the service is `lfx-self-serve` and `values/dev/lfx-self-serve.yaml`
> or `values/global/lfx-self-serve.yaml` are modified, apply the same change to
> `values/dev/lfx-self-serve-branch.yaml` as well. The K8s Secret for `lfx-self-serve`
> is named `pcc-secrets` — use that as `secretKeyRef.name` instead of `lfx-self-serve-secrets`.
> Note: the `eso_service_tag` for `lfx-self-serve` is `pcc` (so the AWS Secrets Manager resource tag is
> `service-pcc: enabled` and the K8s Secret is `pcc-secrets`), but the service tag in the
> `tags:` list should be `lfx-self-serve` — the human-readable service name.

```yaml
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
---
environment:
  SECRET_NAME:
    valueFrom:
      secretKeyRef:
        name: <service>-secrets
        key: <field_name>
  ANOTHER_SECRET_NAME:
    valueFrom:
      secretKeyRef:
        name: <service>-secrets
        key: <another_field_name>
```

> **Note**: The `environment:` block is always named `environment`, but its nesting varies —
> some services have it at the top level, others under `app:`. Always check the existing
> values file before adding entries and match the structure already in use.

---

## Verification Checklist

After completing all applicable steps, verify the setup:

**File checklist — all repos involved:**

- [ ] `lfx-v2-opentofu`: `iam-service-account-definitions.yaml` has service entry *(new services only)*
- [ ] `lfx-secrets-management`: appropriate file under `secrets/lfx/` has sync entry for each
      secret; Deploy workflow run after merge
- [ ] Service Helm chart *(new services only)*:
  - [ ] `templates/serviceaccount.yaml` created
  - [ ] `values.yaml` has `serviceAccount` block
- [ ] `lfx-v2-argocd`:
  - [ ] `custom-resources/<service>/SecretStore.yaml` created *(new services only)*
  - [ ] `custom-resources/<service>/ExternalSecret.yaml` created *(new services only)*
  - [ ] `values/dev/<service>.yaml` has IRSA role ARN + `automountServiceAccountToken: true` *(new services only)*
  - [ ] `values/staging/<service>.yaml` has IRSA role ARN + `automountServiceAccountToken: true` *(new services only)*
  - [ ] `values/prod/<service>.yaml` has IRSA role ARN + `automountServiceAccountToken: true` *(new services only)*
  - [ ] `environment` block with `secretKeyRef` entries exists for each secret — in
        `values/global/<service>.yaml` for all-environment secrets, or in each relevant
        per-environment file (`values/dev|staging|prod/<service>.yaml`) for scoped secrets
  - [ ] **lfx-self-serve only**: `lfx-self-serve-branch` updated alongside any `lfx-self-serve` values file change

**Configuration checks:**

- [ ] IRSA role ARN format is correct: `arn:aws:iam::<account-id>:role/<service>`
- [ ] All account IDs are correct (dev=`788942260905`, staging=`844790888233`, prod=`372256339901`)
- [ ] AWS Secrets Manager secret config tags (`tags:` field) are specific enough to scope the deploy workflow run
- [ ] AWS Secrets Manager resource tag on each secret matches `eso_service_tag`: `service-<eso_service_tag>: enabled`
- [ ] All secrets are stored as JSON (list form fields or `store_as_json: true`)
- [ ] `ExternalSecret` target name is `<service>-secrets` and `secretKeyRef` names match
- [ ] Field names were exercised locally (see Local Testing) and match the `fields:`/`rename_fields:` values

**1Password setup** *(1Password sources only)*:

- [ ] Items exist in all required vaults (LFX V2 - Development/Staging/Production)
- [ ] Item names match exactly what's in the `lfx-secrets-management` `item:` field
- [ ] Field names match exactly what's in the `fields:` list

---

## Reference Implementations

Real examples in the codebase:

| Service | What It Added | References |
|---------|---------------|-----------|
| Email Service | SMTP credentials | `lfx-v2-email-service` chart, lfx-v2-argocd values |
| Invite Service | JWT secret | `lfx-v2-invite-service` chart (LFXV2-1783), lfx-v2-argocd values |
| Committee Service | Auth0 JWT client secret (`auth0_jwt`, auto-rotate, renamed fields) | `secrets/lfx/lfx-v2-committee-service.yml` in lfx-secrets-management |

Check these repos for the exact file structure and conventions used in production.

---

## Common Workflows

### Adding a JWT secret to a new service

1. User asks: "Set up JWT secret for invite-service"
2. Collect: service name, 1Password item name, field names, environments (Step 1)
3. Check for existing ESO objects — none found, proceed with Step 3
4. Follow Steps 3–5 in order
5. Verify using the checklist above
6. Open PRs for `lfx-v2-opentofu`, `lfx-secrets-management`, service Helm chart, and `lfx-v2-argocd`
7. Merge `lfx-secrets-management` PR, trigger Deploy workflow, then merge remaining PRs

### Adding SMTP credentials to an existing service

1. User asks: "Add SMTP secret to email-service"
2. Collect: service name, 1Password item name, field names, environments (Step 1)
3. Check for existing ESO objects — found, skip Step 3
4. Follow Steps 4–5
5. Verify using the checklist above
6. Open PRs for `lfx-secrets-management` and `lfx-v2-argocd`
7. Merge `lfx-secrets-management` PR, trigger Deploy workflow, then merge `lfx-v2-argocd` PR

### Adding an Auth0 client key pair to an existing service

1. User asks: "Add the LFX V2 Persona Service auth0 client to lfx-v2-persona-service"
2. Check for existing ESO objects — found, skip Step 3
3. Add sync entry in lfx-secrets-management (Step 4)
4. Coordinate with the Platform Engineering team to deploy the auto-rotated secret
5. Wire into deployment in values charts (Step 5)
6. Verify using the checklist above
7. Submit argocd PR

### Debugging: "Pods can't read the secret"

Check in order:

1. **Pod events** — `kubectl describe pod <pod>` to see if the SecretStore mounted
2. **ESO logs** — `kubectl logs -n external-secrets-system deployment/external-secrets`
3. **AWS Secrets Manager permissions** — verify IRSA role has `SecretsManager:GetSecretValue` on the path
4. **Secret exists in AWS Secrets Manager** — lfx-secrets-management automation has synced the secret
5. **ExternalSecret status** — `kubectl describe externalsecret <name>` shows sync status
6. **Topology/firewalling** — pod can reach AWS API endpoint (check SecurityGroup, NACL, DNS)

---

## Communication Style

This skill serves both platform engineers and application developers:

- **For experienced infrastructure engineers**: Use technical terms freely (IRSA, JWT auth, ESO).
- **For application developers touching secrets for the first time**: Explain what ESO is
  (*"it automatically copies secrets from AWS into Kubernetes"*) and IRSA (*"it proves
  your pod is who it claims to be when talking to AWS"*).
- **For non-technical users**: Avoid "Kubernetes", "IRSA", "operator", "manifest". Instead say
  "cloud setup", "permissions", "secure secret storage", "automated sync".

Always finish with the verification checklist so the user can confirm everything is wired correctly.
