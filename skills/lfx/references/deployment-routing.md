<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Deployment Routing

Use this decision tree for deployment-related work. Deployment ownership is split across three layers: service/app chart defaults, shared platform chart behavior, and GitOps environment state.

Most deployed app and service repos in this checkout carry their own Helm chart under `charts/<repo-name>/`. Examples include `lfx-self-serve/charts/lfx-self-serve`, `lfx-v2-project-service/charts/lfx-v2-project-service`, `lfx-v2-query-service/charts/lfx-v2-query-service`, and `lfx-v2-fga-sync/charts/lfx-v2-fga-sync`. Support repos such as `lfx-v2-mockdata` may not. `lfx-v2-helm` is the platform exception: it owns `charts/lfx-platform`, not `charts/lfx-v2-helm`.

The owning app/service chart is where service-local templates, chart defaults, probes, env vars, routes, middleware, buckets, streams, and Secret/ExternalSecret template shape belong. `lfx-v2-helm` owns the shared/local platform chart, umbrella dependency composition, and shared topology. `lfx-v2-argocd` owns deployed Application/ApplicationSet membership, chart source and revision selection, values layering, image tags, custom resources, previews, and promotion.

Deployed Secret refs route to `lfx-v2-argocd`. Source secret values, AWS Secrets Manager paths/tags, and rotation are a DevOps/CloudOps handoff through `lfx-secrets-management`. Do not ask for, print, infer, or edit secret values.

Auth0 tenant resources are a separate control-plane layer. Auth0 clients, API audiences/resource servers, grants, scopes, Actions, token-exchange configuration, connections, and Auth0 OpenTofu plan/apply/import work route to `auth0-terraform`. Runtime auth/profile behavior routes to `lfx-v2-auth-service`; deployed `AUTH0_*` environment values route to `lfx-v2-argocd`.

## When to read this

Read this when the task mentions charts, Helm, ArgoCD, ApplicationSets, image tags, chart pins, source revisions, value overlays, ExternalSecrets, SecretStores, HTTPRoute, Heimdall, Gateway, OpenFGA model, local platform install, preview deployments, promotion, Auth0 tenant resources, or OpenTofu for Auth0.

If the task is not deployment-related, use `routing-playbook.md` first.

## Decision tree

```text
Is the change about apps/<env>/ membership, namespaces, dev/staging/prod values, image tags, chart pins, chart source type, targetRevision, custom-resources/<app>, ExternalSecrets/SecretStores, previews, or promotion?
  -> primary_repo: lfx-v2-argocd

Is the change about charts/lfx-platform, local platform install, platform dependencies, umbrella subcharts, Gateway, Traefik, Heimdall platform wiring, NATS/OpenSearch/OpenFGA topology, External Secrets Operator as a platform dependency, or the OpenFGA authorization model?
  -> primary_repo: lfx-v2-helm

Is the change about Auth0 clients/applications, Auth0 resource servers/API audiences, grants, scopes, Actions, custom token exchange, connections, tenant settings, or OpenTofu plan/apply/import for Auth0 resources?
  -> primary_repo: auth0-terraform

Is the change about one app/service chart's templates, defaults, routes,
middleware, probes, service-local secrets, env vars, buckets, streams, or
HTTPRoute behavior?
  -> primary_repo: owning service/app repo

If more than one answer is yes, pick the layer where the edit happens first and
add the other layer as a peer.
```

## Owning service or app repo

Choose the owning service or app repo when the task changes:

- Service-local chart templates.
- The app/service chart under `charts/<repo-name>/` when present.
- Service defaults.
- Service-specific probes, env defaults, Secret/ExternalSecret template shape, routes, middleware, buckets, streams, or HTTPRoute behavior.
- Self Serve app chart behavior under `lfx-self-serve/charts/lfx-self-serve`.

Handoff:

- Start in the owning service/app repo and let its local setup own service chart
  details.
- Add `lfx-v2-argocd` only when deployed overrides are in scope.
- Add `lfx-v2-helm` only when the service change needs shared platform dependency behavior, OpenFGA model topology, or shared Gateway/Heimdall/NATS/OpenSearch/OpenFGA behavior.

## `lfx-v2-helm`

Choose `lfx-v2-helm` when the task changes:

- `charts/lfx-platform`.
- Shared local platform install behavior.
- Umbrella chart dependency composition and selected platform/service subchart wiring.
- Gateway, Traefik, Heimdall, NATS, OpenSearch, OpenFGA, External Secrets Operator, cert-manager, or platform chart composition.
- OpenFGA model deployment.
- Platform chart dependency or release workflow.
- Local development values for the platform chart, including `values.local.example.yaml` and local-only secret assumptions.

Handoff:

- Start in `lfx-v2-helm`; its local setup owns shared platform chart details.
- Add affected service repos if the OpenFGA model or platform behavior changes
  their emitted/consumed contracts.
- Do not route service-local chart templates to `lfx-v2-helm` just because they are consumed as dependencies by `charts/lfx-platform`.

## `lfx-v2-argocd`

Choose `lfx-v2-argocd` when the task changes:

- `apps/<env>/` Application or ApplicationSet membership.
- Namespaces, app labels, sync policy, ignore-differences, and ArgoCD-specific app behavior.
- Chart source type: dev often uses source repo `path: charts/...` plus `targetRevision: HEAD`, while staging/prod generally use GHCR OCI chart entries plus pinned `targetRevision` versions.
- Values layering through `values/global/<service>.yaml` and `values/<env>/<service>.yaml`.
- Image tags, image pull policies, replica/resource overrides, and environment-specific feature flags.
- Custom Kubernetes resources deployed alongside Helm charts, including ExternalSecret and SecretStore manifests.
- Branch preview ApplicationSets, per-PR hostnames, deploy-preview labels, and promotion workflows.
- References to DevOps/CloudOps-managed secret sources.

Handoff:

- Start in `lfx-v2-argocd`; its local setup owns GitOps environment details.
- Add the owning service/app repo only when you need to verify value schema or
  service-local chart defaults.
- Do not route to the secrets manager as an implementation repo by default. If the task requires changing the underlying secret source definition, AWS Secrets Manager path/tag, service tag, or value, call out the DevOps/CloudOps access boundary and handoff.

## `auth0-terraform`

Choose `auth0-terraform` when the task changes:

- Auth0 clients/applications, callback URLs, allowed logout URLs, allowed origins, or app metadata.
- Auth0 resource servers/API audiences and scopes, including LFX V2 API audience changes.
- Client grants, machine-to-machine permissions, and Management API grants.
- Auth0 Actions, post-login flow ordering, custom claims, custom token exchange, or impersonation token-exchange config.
- Auth0 connections such as passwordless email, username/password, social, or enterprise connections.
- Tenant settings, log streams, provider configuration, or OpenTofu plan/apply/import workflow for Auth0 resources.

Handoff:

- Start in `auth0-terraform` when the implementation truth is an Auth0 resource.
- Add `lfx-v2-auth-service` for runtime auth/profile API behavior, token usage, repository/provider selection, or service-side impersonation behavior.
- Add `lfx-v2-argocd` for deployed `AUTH0_*` environment values, chart pins, values overlays, ExternalSecret references, or application membership.
- Treat Auth0 client secrets, private keys, source secret definitions, AWS Secrets Manager paths, and rotation as a DevOps/CloudOps handoff through the secrets flow. Do not ask for or print secret values.

## Common ambiguities

| Request says | Route to | Why |
| --- | --- | --- |
| "Change this service's chart" | Owning service/app repo | Deployed app/service repos generally own their chart under `charts/<repo-name>/`. |
| "Change a service default" | Owning service/app repo | Defaults and templates are service-local implementation truth. |
| "Change staging/prod/dev config" | `lfx-v2-argocd` | Environment overrides and pins are GitOps implementation truth. |
| "Add this service to dev/staging/prod" | `lfx-v2-argocd` plus owning service repo as peer | ArgoCD owns ApplicationSet membership and deployed namespace/value wiring; the service owns its chart. |
| "Change local full-stack platform install" | `lfx-v2-helm` | Local platform composition lives in the umbrella chart. |
| "Add OpenFGA type/relation" | `lfx-v2-helm` plus affected service repo | The model lives in Helm; the service owns emitted access data. |
| "HTTPRoute changed Heimdall behavior" | Owning service/app repo, with `lfx-v2-helm` as peer if shared middleware is involved | Service routes are local; shared auth/routing topology is platform-owned. |
| "Bump deployed image tag" | `lfx-v2-argocd` | Deployed image tags are environment state. |
| "Bump deployed chart version" | `lfx-v2-argocd` | Deployed chart pins live in `apps/<env>/`; verify changed chart values against the owning chart repo. |
| "Change ExternalSecret manifest" | `lfx-v2-argocd` | Deployed Secret refs route to `lfx-v2-argocd`. |
| "Change secret value/source/tag/path" | DevOps/CloudOps handoff | Source secret definitions and values are outside normal implementation routing. |
| "Change Auth0 client, callback URL, audience, grant, scope, Action, or connection" | `auth0-terraform` | Auth0 control-plane resources are managed in Terraform/OpenTofu, not in app runtime repos. |
| "Change runtime profile/auth behavior" | `lfx-v2-auth-service` | Auth-service owns service behavior over Auth0/Authelia; it does not own Auth0 tenant resources. |
| "Change deployed AUTH0_* env wiring" | `lfx-v2-argocd` | Deployed values and secret references are GitOps environment state. |

## Legacy `lfx-v2-ui` names

Old chart and deployment names may still use `lfx-v2-ui`. Implementation
knowledge for Self Serve routes to `lfx-self-serve`; legacy names are deployment
artifact names, not a separate skills target.

When a task mentions `lfx-v2-ui` in a chart or Argo context, say both:

- `lfx-v2-ui` is legacy deployment/chart naming for the Self Serve surface.
- App implementation and app-chart ownership route to `lfx-self-serve`;
  deployed environment values, image tags, chart pins, and ApplicationSets route
  to `lfx-v2-argocd`.
