---
name: lfx-snowflake-access
description: >
  Guide users through requesting Snowflake access at the Linux Foundation. Handles two request
  types: (1) individual user access — adding or modifying an entry in users.tf in the
  lfx-snowflake-terraform repo, and (2) service account creation — adding an entry in
  service_accounts.tf. For each, the skill collects the necessary details, generates the exact
  Terraform HCL block to add, explains where to place it, and guides the user through the PR
  process. Use this skill any time someone asks about Snowflake access, permissions, user
  provisioning, service accounts, or making changes to the lfx-snowflake-terraform repo —
  including phrases like "get access to Snowflake", "add me to Snowflake", "need a service account",
  "request Snowflake permissions", "I need to query Snowflake", or "how do I get Snowflake access".
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion, WebFetch
---

<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Snowflake Access Request Guide

Snowflake access at the Linux Foundation is controlled through a configuration file that the
platform engineering team manages. Requesting access means submitting a small change to that file for review
— once approved, access is automatically applied within minutes.

> **For the AI**: The underlying mechanism is Terraform in the
> [lfx-snowflake-terraform](https://github.com/linuxfoundation/lfx-snowflake-terraform) repo,
> provisioned via pull request. Use technical terms freely with engineers. With everyone else,
> say "access configuration", "change request", and "submit for review" — avoid "Terraform",
> "HCL", "PR", "commit", and "branch" unless the user introduces those terms first.

There are two types of access requests:

| Who needs access | What gets updated |
| --- | --- |
| A person logging into the Snowflake web UI or tools | The user access list (`users.tf`) |
| An automated system, script, or integration | The service account list (`service_accounts.tf`) |

**Your job is to:**

1. Determine which type of request the user needs (ask if unclear)
2. Collect the required information through a brief conversation
3. Generate the exact configuration to add, with clear placement instructions
4. Walk them through submitting the change for review

> ⚠️ **Scope of changes**: Users should only ever edit `users.tf` or `service_accounts.tf`.
> Do not assist with changes to warehouses, role definitions, network rules (beyond IP lists for
> service accounts), providers, or any other Terraform files. If someone asks about those, let
> them know that infrastructure changes require a CloudOps engineer and they should open a GitHub
> issue or reach out in the `#lfx-devops` Slack channel.

<!-- -->

> 🤖 **AI attribution**: If an AI tool is used to help draft any part of this PR (HCL blocks,
> commit messages, descriptions), the LF engineering standard requires attribution. See the
> [AI Attribution Guide for Git Commits](https://github.com/linuxfoundation/lfx-engineering/blob/main/ai/git-commits.md)
> for the full standard — the relevant steps are also covered in the PR Submission Guide below.

---

## Type 1: Individual User Access (`users.tf`)

### Information to collect

Ask the user for:

1. **Email address** — must be `@linuxfoundation.org` or `@contractor.linuxfoundation.org`
2. **Full name** — e.g., "Jane Smith"
3. **Team or function** — use this to recommend roles (see Role Guide below)
4. **Web UI only, or also command-line / programmatic access?** — Most people only need the
   Snowflake web dashboard (accessible via single sign-on). Ask this in plain terms:
   *"Will you be using Snowflake through a web browser, or do you also need to connect
   through code or a command-line tool (for example, dbt, SnowSQL, or a script)?"*
   CLI access requires extra setup steps after the PR merges (covered below).

### Role Guide

Use the team/function to recommend an appropriate role set. These map to existing patterns in `users.tf`:

| Team / Function | Recommended roles |
| --- | --- |
| Platform Engineering / Platform Admin | `ACCOUNTADMIN` *(CloudOps approval required)* |
| Datalake Core Team | `DATA_ADMIN`, `DBT_TRANSFORM_DEV`, `CENSUS_ROLE`, `AIRFLOW_ROLE`, `FORMATION_TEAM_ROLE`, `TRAINING_TEAM_ROLE` |
| Core Services / Backend Dev | `DATA_DEV`, `DBT_TRANSFORM_DEV` |
| Community Management Dev | `PRODUCT_DEV`, `DATA_DEV`, `DBT_TRANSFORM_DEV`, `COMMUNITY_MANAGEMENT_USER` |
| Product Dev | `PRODUCT_DEV`, `DBT_TRANSFORM_DEV`, `LF_DEVELOPER_R_ROLE` |
| Product Support | `VIEWER`, `PRODUCT_DEV`, `FORMATION_TEAM_ROLE`, `TRAINING_TEAM_ROLE`, `DBT_TRANSFORM_DEV`, `CENSUS_ROLE`, `AIRFLOW_ROLE` |
| Architecture Team | `DATA_DEV`, `DBT_TRANSFORM_DEV` (+ additional as needed) |
| BizOps | `VIEWER`, `PRODUCT_DEV`, `DBT_TRANSFORM_DEV` |
| Marketing | `VIEWER`, `HUBSPOT_INTEGRATION_ROLE`, `LF_DEVELOPER_R_ROLE`, `DB_HUBSPOT_INGEST_RO` |
| Sales | `VIEWER`, `LF_DEVELOPER_R_ROLE` |
| Finance | `VIEWER`, `LF_DEVELOPER_R_ROLE` |
| Mentorship | `VIEWER`, `LF_DEVELOPER_R_ROLE` |
| Events | `DBT_TRANSFORM_DEV` |
| Formation Team | `VIEWER`, `FORMATION_TEAM_ROLE` |
| Training / Education | `VIEWER`, `TRAINING_TEAM_ROLE` |
| Data Privacy | `DBT_TRANSFORM_DEV` |
| Project / Community Management | `VIEWER`, `PRODUCT_DEV`, `DBT_TRANSFORM_DEV` |
| Read-only / general business | `VIEWER`, `LF_DEVELOPER_R_ROLE` |

**Role descriptions** (for explaining to users what they're getting):

| Role | What it grants |
| --- | --- |
| `VIEWER` | Read-only access to analytics data in Snowflake |
| `DATA_ADMIN` | Full administrative access to data pipelines and schemas |
| `DATA_DEV` | Data development access — read/write to development data schemas |
| `DBT_TRANSFORM_DEV` | Access to run and develop dbt transformations |
| `PRODUCT_DEV` | Product engineering data access |
| `LF_DEVELOPER_R_ROLE` | Read access to LFX developer-facing data |
| `CENSUS_ROLE` | Integration access for the Census reverse ETL tool |
| `AIRFLOW_ROLE` | Access for Airflow-orchestrated pipelines |
| `FORMATION_TEAM_ROLE` | Access for Formation team workflows |
| `TRAINING_TEAM_ROLE` | Access for the training/certification team datasets |
| `COMMUNITY_MANAGEMENT_USER` | Community management platform data access |
| `HUBSPOT_INTEGRATION_ROLE` | HubSpot marketing tool integration access |
| `DB_HUBSPOT_INGEST_RO` | Read-only access to HubSpot ingested raw data |
| `DB_STRIPE_INGEST_RO` | Read-only access to Stripe ingested raw data |
| `DB_RAW_RW` | Read/write access to raw data schemas |
| `ACCOUNTADMIN` | Full Snowflake account administration — CloudOps only |

### HCL block to generate

Generate a block like this and instruct the user to add it inside the `users = { ... }` map in
`users.tf`, under the appropriate team comment section:

```hcl
"user@linuxfoundation.org" = {
  roles     = ["ROLE_ONE", "ROLE_TWO"]
  full_name = "Full Name"
},
```

If CLI access was requested, add `cli = "started"`:

```hcl
"user@linuxfoundation.org" = {
  roles     = ["ROLE_ONE", "ROLE_TWO"]
  cli       = "started"
  full_name = "Full Name"
},
```

### Placement instruction

The `users` map is organized by team sections with `#` comments. Tell the user:
> Add your block under the comment that matches your team (e.g., `# Product Dev`, `# Marketing Team`,
> etc.). If your team doesn't have a section yet, add a new comment and your entry at the end of
> the `users = { ... }` block, before the closing `}`.

---

## Type 2: Service Account (`service_accounts.tf`)

Service accounts are for applications, automation scripts, CI/CD pipelines, or integrations —
not for humans logging in. They are given an IP allowlist and specific role grants.

### Information to collect

Ask the user for:

1. **Service account name** — uppercase, underscore-separated, e.g., `MY_SERVICE`
   (this becomes the Snowflake username)
2. **Purpose** — what system or integration is this for?
3. **Required data access** — what data does it need to read or write? Use this to suggest roles.
4. **IP address(es)** — the outbound IP(s) of the service. Required for network policy enforcement.
   - If this is an internal LF system on the API gateway, they can use `local.ip_list_api_gw`
   - If this is on the shared k8s clusters, they can use `local.ip_list_k8s_clusters`
   - Otherwise, collect the specific IP(s) or CIDR ranges
5. **Default warehouse** — which Snowflake warehouse should it use? (optional; leave out if unsure)
6. **Default role** — should the account default to a specific role?
   (optional; usually the account name itself or leave out)

### Common service account roles

| Access pattern | Roles to include |
| --- | --- |
| Read analytics data | `DB_ANALYTICS_RO` (or `DB_ANALYTICS_PLATINUM_RO`, `DB_ANALYTICS_GOLD_RO` for tiered access) |
| Read all ingested data | `DB_INGEST_ALL_RO` |
| Write ingested data | A specific `DB_*_INGEST_RW` role (coordinate with CloudOps) |
| Use a dedicated warehouse | `WH_<NAME>_USAGE` (CloudOps creates warehouses — see note below) |
| Read raw data | `DB_RAW_RO` or `DB_RAW_RW` |

> **Warehouse note**: If the service needs its own warehouse (e.g., `WH_MY_SERVICE_USAGE`), that
> warehouse must be created separately by CloudOps. Note this in the PR description so reviewers
> know to provision it. For existing shared warehouses, use the appropriate `WH_*_USAGE` role.

### HCL block to generate

Add inside the `legacy_service_accounts = { ... }` map:

```hcl
"MY_SERVICE" = {
  roles             = ["WH_MY_SERVICE_USAGE", "DB_ANALYTICS_RO"],
  default_warehouse = "MY_SERVICE_WH",    # omit if no dedicated warehouse
  default_role      = "MY_SERVICE",       # omit if using default behavior
  ip_list           = ["1.2.3.4"],        # or: local.ip_list_api_gw
},
```

Minimal example (no dedicated warehouse, no default role override):

```hcl
"MY_SERVICE" = {
  roles   = ["DB_ANALYTICS_RO", "DB_INGEST_ALL_RO"],
  ip_list = ["1.2.3.4", "5.6.7.8"],
},
```

A network policy will be **automatically created** from the `ip_list` — no additional changes needed.

### Placement instruction

> Add the block inside the `legacy_service_accounts = { ... }` local in `service_accounts.tf`,
> before the closing `}`. Add a comment above it explaining what the service is.

---

## Submitting the Change Request

After generating the configuration, walk the user through submitting it for review.

> **Not comfortable with git?** That's completely fine. Share the configuration block above
> with a technical teammate (an engineer on your team, or post in the `#lfx-devops` Slack
> channel), and ask them to open a pull request on your behalf. The steps below are for
> people who will submit the change themselves via git.

<!-- -->

> **For the AI**: "PR" and "pull request" are the correct technical terms. When talking to
> non-engineers, say "change request" or "submit the change for review" instead. Explain that
> the review process exists so CloudOps can verify access is appropriate before it takes effect.

1. **Create a working branch**: Start from `main` with a descriptive name, e.g.,
   `add-user-jane-smith` or `add-sa-my-service`
2. **Make the edit**: Add the generated configuration block to `users.tf` or
   `service_accounts.tf` at the location described in the placement instruction above.
3. **Save and sign the change**: The Linux Foundation requires all commits to be
   **DCO-signed** (certifying the change is yours to contribute) and **GPG-signed**
   (a cryptographic identity check). Run:

   ```bash
   git commit -S --signoff -m "Add Snowflake access for Jane Smith (Product Dev team)"
   ```

   - `-S` applies a GPG signature (cryptographic proof the commit came from you)
   - `--signoff` appends a `Signed-off-by:` trailer, satisfying the [Developer Certificate of Origin (DCO)](https://developercertificate.org/)
   - If you haven't set up GPG signing yet, follow GitHub's guide: [Signing commits](https://docs.github.com/en/authentication/managing-commit-signature-verification/signing-commits)

4. **AI attribution** — if an AI tool helped generate the configuration in this commit, add an attribution
   line *above* the `Signed-off-by:` trailer. The full commit message format is:

   ```text
   Add Snowflake access for Jane Smith (Product Dev team)

   Generated with [Claude Code](https://claude.ai/code)
   Signed-off-by: Your Name <your.email@linuxfoundation.org>
   ```

   Use `Generated with [Tool](URL)` for AI-generated content, or `Assisted by [Tool](URL)` for
   partial help. See the full [AI attribution guide](https://github.com/linuxfoundation/lfx-engineering/blob/main/ai/git-commits.md)
   for supported tools and multi-tool examples.

5. **Title your change request** with a clear description, e.g.:
   - `Add Snowflake access for Jane Smith (Product Dev team)`
   - `Add MY_SERVICE service account for [purpose]`
6. **Write a short description** explaining:
   - Who or what needs access and why
   - What level of access is being granted and a brief justification
   - For service accounts: which system it belongs to and its outbound IP addresses
   - If a new compute resource (warehouse) is needed: call this out so CloudOps knows to
     provision it alongside the access change
   - If AI tooling was used to help draft this, note it here too (consistent with the commit)
7. **Submit the change request to**:
   `https://github.com/linuxfoundation/lfx-snowflake-terraform`
8. **Reviewers**: The CloudOps team is automatically notified — no need to manually assign anyone

> Once the change is approved and merged, access is applied automatically within a few minutes.
> New users will receive an activation email from Snowflake. Anyone who also needs command-line
> or programmatic access (dbt, SnowSQL) must complete the key setup described below.

---

## After Your PR Merges: Logging In & CLI Setup

### Logging into the Snowflake console (all users)

Once the PR is merged and Terraform applies (usually within minutes):

1. From the [Okta dashboard](https://okta.linuxfoundation.org/app/UserHome),
   launch the **Snowflake** application for the Linux Foundation.
2. When prompted, choose the **Okta SSO** option and sign in with your LF email
3. After authentication completes, you'll be redirected to the Snowflake landing page — you're in.

> If your account isn't active yet, wait a few minutes for CI/CD to complete and try again.
> If it still doesn't work after 15 minutes, reach out in the `#lfx-devops` Slack channel.

### RSA keypair setup for CLI / dbt users

If the user's `users.tf` entry includes `cli = "started"` (meaning they need `dbt build`,
SnowSQL, or other programmatic access), they must set up RSA keypair authentication.
This replaces password/MFA for CLI connections and is required for `dbt build` to work
without repeated Duo push prompts.

Full instructions: [lf-dbt README — SnowSQL Keypair Authentication Setup](https://github.com/linuxfoundation/lf-dbt/blob/main/README.md#snowsql-keypair-authentication-setup)

**Summary of steps:**

1. **Generate the private key:**

   ```bash
   openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt
   ```

2. **Generate the public key:**

   ```bash
   openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
   ```

3. **Store keys securely:**

   ```bash
   mkdir ~/.sf/ && chmod go-rwx ~/.sf/
   cp rsa_key.p8 rsa_key.pub ~/.sf/
   chmod go-rwx ~/.sf/rsa_key.*
   ```

4. **Copy the public key contents** (`cat ~/.sf/rsa_key.pub`, strip the header/footer lines,
   remove line breaks) and **send it to CloudOps** — they will run:

   ```sql
   ALTER USER DEV_YOUR_USERNAME SET RSA_PUBLIC_KEY='<your public key>';
   ```

   The CLI username format is `DEV_` + your email prefix in uppercase, e.g.,
   `DEV_JSMITH` for `jsmith@linuxfoundation.org`.

5. **Verify the key was registered** by comparing fingerprints — see the full README for the
   verification commands.

6. **Connect via SnowSQL** using your private key:

   ```bash
   snowsql -a <account> -u DEV_YOUR_USERNAME --private-key-path "${HOME}/.sf/rsa_key.p8"
   ```

> For dbt-specific key/pair setup (profiles.yml configuration), see the
> [dbt Snowflake setup guide](https://docs.getdbt.com/docs/core/connect-data-platform/snowflake-setup#key-pair-authentication).

---

## Conversation tips

### Adapting to non-technical users

Many people requesting Snowflake access — in marketing, sales, finance, leadership, and product —
will not be familiar with git, Terraform, or pull requests. Adjust your language to match:

- **Don't say**: "I'll generate an HCL block for your PR" — **Do say**: "I'll put together the
  access configuration and walk you through submitting it for CloudOps review."
- **Don't say**: "Add this to `users.tf` and commit it" — **Do say**: "Open the file, paste
  this entry in, then save and submit the change."
- **Don't say**: "Create a feature branch" — **Do say**: "Start a new working copy of the file
  so your change doesn't affect others until it's reviewed."
- If someone looks confused or asks "what's a pull request?", explain: *"It's a way of proposing
  a change so someone can review it before it takes effect — like a tracked edit waiting for
  approval."*
- If the user is clearly non-technical and not comfortable submitting the change themselves,
  offer the handoff path: *"No problem — I can give you a summary to share with a technical
  teammate or post in `#lfx-devops`, and they can submit it on your behalf."*

### Role and access guidance

- If the user isn't sure which roles they need, ask about their job function and the specific
  data or tools they need to access, then recommend a role set from the table above.
- If they're an existing user who needs **additional roles**, generate just the updated
  `roles = [...]` line with the new roles appended, and tell them to find their existing
  entry and update that line.
- If they're unsure whether they need a service account vs. user access: service accounts are
  for automated processes; if a human is logging in via the Snowflake web UI or SSO, it's a
  user account.

### Escalation

- If the request involves new roles, new warehouses, or infrastructure not covered here, don't
  guess — direct them to open a GitHub issue or reach out in the `#lfx-devops` Slack channel.
