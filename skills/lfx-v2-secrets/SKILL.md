---
name: lfx-v2-secrets
description: >
  Guide an agent through wiring up secrets for LFX V2 microservices using External Secrets
  Operator (ESO) + IRSA. Supports two modes: (1) full setup for new services touching
  lfx-v2-opentofu, lfx-secrets-management, the service Helm chart, and lfx-v2-argocd;
  (2) adding secrets to existing services already configured with ESO. Use this skill
  whenever someone says "set up secrets", "wire up ESO", "add a secret to this service",
  "IRSA configuration", "External Secrets for V2", or any mention of AWS Secrets Manager
  integration with Kubernetes for LFX V2 services.
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion, WebFetch
---

<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->
<!-- Tool names in this file use Claude Code vocabulary. See docs/tool-mapping.md for other platforms. -->

# LFX V2 Secrets Setup Guide

Secrets for LFX V2 microservices are managed through **External Secrets Operator (ESO)**
combined with **IAM Roles for Service Accounts (IRSA)** on AWS. This provides a secure,
GitOps-driven way to sync secrets from AWS Secrets Manager into Kubernetes.

> **For the AI**: This skill has two modes. Mode 1 (new service) touches four repos
> and requires coordinated changes across infrastructure layers. Mode 2 (existing service)
> is much smaller. Always ask the user which applies before proceeding.

---

## Understanding the Architecture

### How It Works

1. A **Kubernetes ServiceAccount** is annotated with an **IRSA role ARN**
2. ESO's **SecretStore** uses that ServiceAccount's JWT token to authenticate to AWS
3. ESO watches **ExternalSecret** manifests and syncs matching secrets from AWS SM into K8s Secrets
4. Application deployments reference the K8s Secret via environment variable or volume mount
5. Local development skips ESO entirely and injects secret values directly via `environment` in values

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
| AWS SM path pattern | `cloud/<3rd-party-service>/<name_or_identifier>` |
| ServiceAccount annotation key | `eks.amazonaws.com/role-arn` |
| ESO JWT auth field | `spec.provider.aws.auth.jwt.serviceAccountRef` |

---

## Branching

Before making any changes, create a branch in each repo being modified. Use the format
`<username>/<secret-name>`. Never commit directly to `main`. The username is the git
username (typically the part before `@` in the email). Always sign off commits.

---

## Mode 1: New Service (Full Setup)

Use this mode when a brand-new V2 service needs secrets wired up end-to-end from scratch.
This touches **four repos** and requires changes in a specific order.

### Step 1: Prepare Information

Identify `<service>` — the fully qualified service name including the `lfx-v2-` prefix (e.g.,
`lfx-v2-committee-service`). If the user did not include it in their request, ask for it now
before proceeding. This is used directly in all resource names: K8s Secret is `<service>-secrets`,
role ARN ends in `<service>`, etc.

Then fetch `iam-service-account-definitions.yaml` directly from GitHub:
```
https://raw.githubusercontent.com/linuxfoundation/lfx-v2-opentofu/main/iam-service-account-definitions.yaml
```
If the fetch fails (e.g., auth error), ask the user to paste the relevant entry.

Look up the entry for `<service>`:
- **`namespace`** — note the value; defaults to `<service>` if not set. Confirm with the user only if the entry is missing entirely.
- **`eso_service_tag`** — note the value; defaults to `<service>` if not set. If the file is inaccessible or the entry is missing, ask the user to confirm the tag (suggest `<service>` as the default).

Then ask the user for:

1. **List of secrets** — secrets can come from several source types; the examples below cover the most common ones, but accept any source the user describes:

   **1Password sources** (e.g., API keys, SMTP credentials, JWT secrets, etc):
   - **Secret name** (e.g., "JWT Secret", "SMTP Credentials")
   - **Third-party service** that provides the secret (e.g., `litellm`, `github`)
   - **1Password item name** — exact name as it appears in the vault
   - **Field names in 1Password** — the exact field names as they appear in the source vault

   **Auth0 sources** (e.g., M2M client credentials, BFF client secrets):
   - **Auth0 client name** — exact display name in Auth0 (e.g., `LFX V2 Invite Service`)
   - **Credential type** — `auth0` (produces `client_id` + `client_secret`) or `auth0_jwt` (produces `client_id` + `client_public_key` + `client_private_key`; standard for LFX V2 microservices)
   - **Field rename mapping** (optional) — if env var names differ from defaults (e.g., `client_id` → `auth0_client_id`)
   - **Auto-rotate** — yes/no; default `true` for `auth0_jwt` V2 services
   - **AWS SM path** — follows `auth0/<ClientName_With_Underscores>` convention (e.g., `auth0/LFX_V2_Invite_Service`)

2. **Which environments need this secret** — `development`, `staging`, `production`

**1Password example:**

```text
Service: lfx-v2-invite-service
Namespace: invite-service
Secrets:
  - Atlassian API Key (service: atlassian, field: atlassian_api_key) - all envs
  - Supabase API Key (service: pcc, fields: url, api_key) - all envs
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
      rename_fields: client_id → auth0_client_id, client_private_key → auth0_client_private_key
      path: auth0/LFX_V2_Committee_Service
```

### Step 2: Create IAM Service Account in `lfx-v2-opentofu`

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

### Step 3: Create Sync Entries in `lfx-secrets-management`

In the [lfx-secrets-management](https://github.com/linuxfoundation/lfx-secrets-management) repo,
add an entry for each secret to the appropriate file under `secrets/lfx/`. Check the existing
files to find where similar secrets live — auth0 credentials go in `auth0_clients.yml`,
most one-off service credentials go in `cloud.yml`, but third-party services may have their
own file (e.g., `litellm.yml`). When unsure, grep for the third-party service name across
`secrets/lfx/`.

> **Important**: All secrets must be stored as JSON in AWS SM, even single-field ones.
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

```yaml
<Secret Name>:
  tags: [lfx_v2, <service_tag>, <type_tag>]
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
        path: <file-name>/<3rd-party-service>/<secret-type>
```

Example for Supabase API key:

```yaml
Supabase API Key:
  tags: [supabase, supabase_api_key, lfx_v2]
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
        path: cloud/supabase/api_key
```

> **Tips**:
>
> - Each secret in the lfx-secrets-management source becomes a separate AWS SM path entry
> - The `path` convention is `cloud/<3rd-party-service>/<secret-type>`
> - Use the `envs` list to sync to all three environments in parallel
> - The `source.onepassword.item` should match exactly the name in 1Password vaults
> - The field names should be descriptive enough to avoid duplicates (`litellm_api_key`, not just `api_key`)

**Auth0 template** (`auth0` — client_secret, `auth0_clients.yml`):

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

**Auth0 template** (`auth0_jwt` — JWT private key, standard for LFX V2 microservices, `auth0_clients.yml`):

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

> **Important**: After the `lfx-secrets-management` PR is merged, manually trigger the
> [Deploy workflow](https://github.com/linuxfoundation/lfx-secrets-management/actions/workflows/deploy.yml)
> to push the secret to AWS SM. Use the most specific secret config tag (the `tags:` field
> in the YAML entry, e.g. `litellm` or `pcc`) — not the AWS resource tag — to avoid
> re-deploying or rotating unrelated secrets. The `lfx-v2-argocd` PR must not merge until
> the deploy has completed — ArgoCD will fail to sync if the secret doesn't exist in AWS SM yet.
>
> **Auth0 JWT secrets** (`auth0_jwt` source type) are rotated on every deploy. Before
> triggering the workflow for any entry tagged with `auth0_jwt`, check with CloudOps to
> confirm you are only rotating the intended service's credentials.

### Step 4: Create Helm Chart and Custom Resource Files

#### 4a. `serviceaccount.yaml` in the service Helm chart

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
automountServiceAccountToken: {{ .Values.serviceAccount.automountServiceAccountToken | default true }}
{{- end }}
```

Add to `charts/<service>/values.yaml`:

```yaml
serviceAccount:
  create: true
  name: "<service>"
  annotations: {}
  automountServiceAccountToken: true
```

#### 4b. Custom resources in `lfx-v2-argocd`

The `SecretStore` and `ExternalSecret` are **static YAML files** (not Helm templates) placed in
`lfx-v2-argocd/custom-resources/<service>/`.

Create `custom-resources/<service>/SecretStore.yaml`:

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
            name: <service>
      region: us-west-2
      service: SecretsManager
```

Create `custom-resources/<service>/ExternalSecret.yaml`:

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

> **Tag-based discovery**: ESO finds and merges all AWS SM secrets tagged
> `service-<eso_service_tag>: enabled` into a single Kubernetes Secret named
> `<service>-secrets`. No manual `data` list is needed — new secrets are picked up
> automatically after the next sync.

#### 4c. IRSA annotation in `lfx-v2-argocd` per-environment values

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

> **lfx-self-serve**: If the service is `lfx-self-serve`, any update to a values file in
> `lfx-v2-argocd` must also include the corresponding update to `lfx-self-serve-branch`.

### Step 5: Wire Secrets into Service Environment in `lfx-v2-argocd`

In `values/global/<service>.yaml`, add an `environment` block that maps each secret
field to an environment variable. Reference the Kubernetes Secret created by the ExternalSecret
(`<service>-secrets`) and use the field name as the key.

> **lfx-self-serve**: If the service is `lfx-self-serve`, also update `lfx-self-serve-branch`
> whenever this values file is modified.

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

---

## Mode 2: Add Secret to Existing Service

Use this mode when adding a new secret to a service that already has ESO + IRSA configured.

### Step 1: Add Entry to `lfx-secrets-management`

**Before writing the entry**, read `iam-service-account-definitions.yaml` in `lfx-v2-opentofu`
and confirm the service's `eso_service_tag` (defaults to the role key if not set). You will need
this for the `service-<eso_service_tag>: enabled` AWS SM resource tag — do not ask the user for it.

Follow the same pattern as Mode 1, Step 3. Add an entry to the appropriate file under
`secrets/lfx/` — check existing files or grep for the third-party service name to find
the right one.

```yaml
<Secret Name>:
  tags: [lfx_v2, <service_tag>, <type_tag>]
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
        path: <file-name>/<3rd-party-service>/<secret-type>
```

**Auth0 template** (`auth0` — client_secret, `auth0_clients.yml`):

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

**Auth0 template** (`auth0_jwt` — JWT private key, standard for LFX V2 microservices, `auth0_clients.yml`):

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

> **Important**: After the `lfx-secrets-management` PR is merged, manually trigger the
> [Deploy workflow](https://github.com/linuxfoundation/lfx-secrets-management/actions/workflows/deploy.yml)
> to push the secret to AWS SM. Use the most specific secret config tag (the `tags:` field
> in the YAML entry, e.g. `litellm` or `pcc`) — not the AWS resource tag — to avoid
> re-deploying or rotating unrelated secrets. The `lfx-v2-argocd` PR must not merge until
> the deploy has completed — ArgoCD will fail to sync if the secret doesn't exist in AWS SM yet.
>
> **Auth0 JWT secrets** (`auth0_jwt` source type) are rotated on every deploy. Before
> triggering the workflow for any entry tagged with `auth0_jwt`, check with CloudOps to
> confirm you are only rotating the intended service's credentials.

### Step 2: Wire Secret into Service Environment in `lfx-v2-argocd`

In `values/global/<service>.yaml`, add the new environment variable to the existing
`environment` block:

```yaml
environment:
  NEW_ENV_VAR:
    valueFrom:
      secretKeyRef:
        name: <service>-secrets
        key: <field_name>
```

> Before writing `secretKeyRef.name`, verify the K8s Secret name from the existing
> `ExternalSecret.yaml` in `lfx-v2-argocd/custom-resources/<service>/` —
> check `spec.target.name`. It is typically `<service>-secrets` but must match exactly.

> Tag-based discovery means the new secret is picked up automatically — no changes to
> `ExternalSecret.yaml` are needed as long as the AWS SM tag matches the service.

> **lfx-self-serve**: If the service is `lfx-self-serve`, also update `lfx-self-serve-branch`
> whenever this values file is modified.

---

## Verification Checklist

After completing either mode, verify the setup:

**File checklist — all repos involved:**

- [ ] `lfx-v2-opentofu`: `iam-service-account-definitions.yaml` has service entry *(Mode 1 only)*
- [ ] `lfx-secrets-management`: appropriate file under `secrets/lfx/` has sync entry for each secret; Deploy workflow run after merge
- [ ] Service Helm chart *(Mode 1 only)*:
  - [ ] `templates/serviceaccount.yaml` created
  - [ ] `values.yaml` has `serviceAccount` block
- [ ] `lfx-v2-argocd`:
  - [ ] `custom-resources/<service>/SecretStore.yaml` created *(Mode 1 only)*
  - [ ] `custom-resources/<service>/ExternalSecret.yaml` created *(Mode 1 only)*
  - [ ] `values/dev/<service>.yaml` has IRSA role ARN + `automountServiceAccountToken: true` *(Mode 1 only)*
  - [ ] `values/staging/<service>.yaml` has IRSA role ARN + `automountServiceAccountToken: true` *(Mode 1 only)*
  - [ ] `values/prod/<service>.yaml` has IRSA role ARN + `automountServiceAccountToken: true` *(Mode 1 only)*
  - [ ] `values/global/<service>.yaml` has `environment` block with `secretKeyRef` entries for all secrets
  - [ ] **lfx-self-serve only**: `lfx-self-serve-branch` updated alongside any `lfx-self-serve` values file change

**Configuration checks:**

- [ ] IRSA role ARN format is correct: `arn:aws:iam::<account-id>:role/<service>`
- [ ] All account IDs are correct (dev=`788942260905`, staging=`844790888233`, prod=`372256339901`)
- [ ] AWS SM secret config tags (`tags:` field) are specific enough to scope the deploy workflow run
- [ ] AWS SM resource tag on each secret matches `eso_service_tag`: `service-<eso_service_tag>: enabled`
- [ ] All secrets are stored as JSON (list form fields or `store_as_json: true`)
- [ ] `ExternalSecret` target name is `<service>-secrets` and `secretKeyRef` names match

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
| Committee Service | Auth0 JWT client secret (`auth0_jwt`, auto-rotate, renamed fields) | `secrets/lfx/auth0_clients.yml` in lfx-secrets-management |

Check these repos for the exact file structure and conventions used in production.

---

## Common Workflows

### Adding a JWT secret to a new service

1. User asks: "Set up JWT secret for invite-service"
2. Collect: service name, 1Password item name, field names, environments
3. Follow Mode 1 steps in order
4. Verify using the checklist above
5. Open PRs for `lfx-v2-opentofu`, `lfx-secrets-management`, service Helm chart, and `lfx-v2-argocd`
6. Merge `lfx-secrets-management` PR, trigger Deploy workflow, then merge remaining PRs

### Adding SMTP credentials to an existing service

1. User asks: "Add SMTP secret to email-service"
2. Follow Mode 2 steps
3. Verify using the checklist above
4. Open PRs for `lfx-secrets-management` and `lfx-v2-argocd`
5. Merge `lfx-secrets-management` PR, trigger Deploy workflow, then merge `lfx-v2-argocd` PR

### Adding an Auth0 client key pair to an existing service

1. User asks: "Add the LFX V2 Persona Service auth0 client to lfx-v2-persona-service"
2. Add sync entry in lfx-secrets-management
3. Verify using the checklist above
4. Submit secrets PR
5. Coordinate with the Platform Engineering team to deploy the auto-rotated secret
6. Wire into deployment in values charts
7. Verify using the checklist above
8. Submit argocd PR

### Debugging: "Pods can't read the secret"

Check in order:

1. **Pod events** — `kubectl describe pod <pod>` to see if the SecretStore mounted
2. **ESO logs** — `kubectl logs -n external-secrets-system deployment/external-secrets`
3. **AWS SM permissions** — verify IRSA role has `SecretsManager:GetSecretValue` on the path
4. **Secret exists in AWS SM** — lfx-secrets-management automation has synced the secret
5. **ExternalSecret status** — `kubectl describe externalsecret <name>` shows sync status
6. **Topology/firewalling** — pod can reach AWS API endpoint (check SecurityGroup, NACL, DNS)

---

## Communication Style

This skill serves both platform engineers and application developers:

- **For experienced infrastructure engineers**: Use technical terms freely (IRSA, JWT auth, ESO operator).
- **For application developers touching secrets for the first time**: Explain what ESO is
  (*"it automatically copies secrets from AWS into Kubernetes"*) and IRSA (*"it proves
  your pod is who it claims to be when talking to AWS"*).
- **For non-technical users**: Avoid "Kubernetes", "IRSA", "operator", "manifest". Instead say
  "cloud setup", "permissions", "secure secret storage", "automated sync".

Always finish with the verification checklist so the user can confirm everything is wired correctly.
