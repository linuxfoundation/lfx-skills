<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# LFX Glossary

A plain-language reference for common LFX terms. This glossary is for routing and orientation only. Exact commands, file paths, validation steps, and implementation rules belong to the owning repo's `CLAUDE.md`, `AGENTS.md`, local skills, rules, and docs.

## Platform Terms

| Term | What It Is | Where Details Live |
| --- | --- | --- |
| **Goa** | A Go API design and code-generation framework used by several LFX v2 services. | The owning service repo's design files, generated-code rules, and Makefile. |
| **NATS** | The platform messaging and key-value system used for request/reply calls, events, and some storage/caching paths. | The owning service repo for emitted/consumed subjects; platform infrastructure in `lfx-v2-helm`; deployed values in `lfx-v2-argocd`. |
| **OpenFGA (FGA)** | The relationship-based authorization system used for resource permissions. | Model ownership in `lfx-v2-helm`; tuple sync/check mechanics in `lfx-v2-fga-sync`; resource contracts in the owning service repo. |
| **Heimdall** | The gateway authorization layer in front of platform APIs. | Shared platform wiring in `lfx-v2-helm`; service-specific route/rule templates in the owning service repo; deployed values in `lfx-v2-argocd`. |
| **OpenSearch** | The search/index backend used by query and indexer flows. | Indexing mechanics in `lfx-v2-indexer-service`; query behavior in `lfx-v2-query-service`; emitted schemas in each owning service repo. |
| **KV (Key-Value store)** | NATS JetStream key-value storage used by some services and platform helpers. | The repo that creates or reads the bucket. |
| **PrimeNG** | Angular UI component library used by some LFX frontends. | App-specific UI rules in the frontend repo; shared UI package rules in `lfx-ui`. |
| **Express proxy** | Node/Express backend layer used by Self Serve to proxy application requests. | `lfx-self-serve` backend architecture docs and local skills. |

## Architecture Terms

| Term | What It Means | Where Details Live |
| --- | --- | --- |
| **Resource service** | A service that owns a domain resource such as projects, committees, meetings, votes, surveys, mailing lists, or members. | The owning `lfx-v2-*` service repo. |
| **Wrapper service** | A service that exposes LFX v2 APIs while delegating source-of-truth behavior to an external system. | The wrapper service repo and its external-system docs. |
| **Platform service** | Shared infrastructure service such as query, indexer, FGA sync, or access check. | The platform service repo. |
| **Shared types** | Reusable type definitions shared inside a repo or app workspace. | The repo that publishes and consumes those types. |
| **Domain model** | The service-owned model for a resource or operation. | The owning service repo. |
| **Goa design** | API blueprint files used by Goa-based services. | The owning service repo. |
| **Signal** | Angular reactive state primitive. | The frontend repo's Angular rules and examples. |

## Workflow Terms

| Term | What It Means |
| --- | --- |
| **Preflight** | Repo-local checks run before a PR or review handoff. Exact checks are repo-specific. |
| **Protected file** | A file that needs special care or code-owner review in that repo. |
| **Code owner** | A reviewer or team responsible for a path or behavior. |
| **Feature branch** | A branch used for isolated work before review. |
| **Signoff** | A `Signed-off-by:` commit trailer required by Linux Foundation DCO policy. |
