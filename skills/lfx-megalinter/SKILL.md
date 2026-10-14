---
name: lfx-megalinter
description: >
  MegaLinter and CI-standardization playbook for LFX repos: rolling out or
  upgrading MegaLinter, pinning its version in the workflow and Makefile,
  fixing MegaLinter failures (zizmor, trivy, grype, osv-scanner, golangci-lint,
  revive, cspell, yamllint, eslint, gitleaks/betterleaks, checkov), choosing
  the go.mod Go toolchain version relative to MegaLinter's bundled Go, the
  GOTOOLCHAIN=auto fix, and cleaning up stale scanner suppressions
  (.trivyignore, .grype.yaml, osv-scanner.toml). Use when the user mentions
  MegaLinter, mega-linter.yml, .mega-linter.yml, a failing lint/security CI
  job, "bump MegaLinter", "go.mod requires go >=", "GOTOOLCHAIN", a CVE
  suppression, zizmor findings, or asks to standardize CI across repos, even
  without naming the skill. Do not fire for application security review of
  code changes (use `/lfx-skills:lfx-security-engineer`) or for addressing PR
  review comments (use `/lfx-skills:lfx-pr-resolve`).
allowed-tools: Bash, Read, Edit, Glob, Grep, WebFetch, AskUserQuestion
---

<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->
<!-- Tool names in this file use Claude Code vocabulary. See docs/tool-mapping.md for other platforms. -->

# LFX MegaLinter

LFX repos lint and scan with [MegaLinter](https://megalinter.io/) in GitHub
Actions. The same failures recur across repos, and each has a known fix. This
skill gives the fleet-wide conventions so every repo resolves them the same
way instead of rediscovering them PR by PR.

Read the repo's own `CLAUDE.md`/`AGENTS.md` first; it wins for anything it
states explicitly (e.g. a deliberately disabled linter), except its Go
version rules, which this skill's policy replaces unless the repo file says
it supersedes this skill (see [Go toolchain version](#go-toolchain-version)).

## Where configuration lives

| File                                                         | Holds                                                                                          |
|--------------------------------------------------------------|------------------------------------------------------------------------------------------------|
| `.mega-linter.yml`                                           | Generic MegaLinter config: `DISABLE_LINTERS`, `DISABLE_ERRORS_LINTERS`, `<LINTER>_*` settings. |
| `.github/workflows/mega-linter.yml`                          | The SHA-pinned `uses:` line and Actions-only `env:` values (secrets, runner behavior).         |
| `Makefile` `megalinter` target                               | Local Docker run, pinned to the same release by image digest.                                  |
| `.trivyignore`, `.grype.yaml`, `osv-scanner.toml`            | ID-scoped vulnerability exceptions.                                                            |
| `.cspell.json`, `revive.toml`, `.yamllint*`, `.golangci.yml` | Per-linter config.                                                                             |

Keep generic settings in `.mega-linter.yml` so local runs and CI behave the
same; only put values in the workflow `env:` that exist only in Actions.

## Core principles

- **Fix the finding, not the linter.** Prefer a code/config fix, then an
  inline ID-scoped suppression, then an ID-scoped ignore-file entry. Never
  disable a whole scanner category (e.g. `REPOSITORY_GRYPE`) or move it to
  `DISABLE_ERRORS_LINTERS` to silence one finding — that hides every future
  finding too.
- **Patch the vulnerable dependency directly**, not unrelated top-level
  dependencies. `go get <module>@<fixed-version> && go mod tidy`.
- **Every suppression carries a rationale and a removal condition** that can
  actually be checked (see [Stale suppression cleanup](#stale-suppression-cleanup)).
- **Reuse established comment wording.** Before writing a new rationale
  comment, grep sibling repos for the same scenario and copy the existing
  phrasing. Comments are sentence case, end with a period, and describe
  current behavior only — never "this PR", "this rollout", or past states.

## MegaLinter version

The fleet standard is **MegaLinter v10.1.0**. Pin exactly this release, not
whatever is newest upstream: the fixes in this skill were tested against it,
and a newer release can bundle different linter and Go versions that
invalidate them. Moving the fleet to a newer release is done by updating and
re-testing this skill first, then rolling the new pin out to repos.

Three places must agree — half-upgrades are easy to miss:

1. **Workflow** — SHA-pinned with the tag as a trailing comment. The commit
   SHA is the same for every flavor:

   ```yaml
   uses: oxsecurity/megalinter/flavors/go@9949bad031045f366be2467e00e8371a7328a2e2  # v10.1.0
   ```

2. **Makefile** — pin the image **digest**, not just the tag. Example for
   the Go flavor:

   <!-- markdownlint-disable MD010 -->

   ```makefile
   # Run MegaLinter locally via Docker (matches CI Go flavor at v10.1.0).
   # Keep this digest in sync with .github/workflows/mega-linter.yml.
   MEGALINTER_IMAGE := ghcr.io/oxsecurity/megalinter-go@sha256:42e091a4bcbe9141fe420c2520ed7addf75ae60a0c9d42e3df1278eef1c90a88  # v10.1.0
   megalinter:
   	docker pull $(MEGALINTER_IMAGE)
   	docker run --rm --platform linux/amd64 -e GOTOOLCHAIN=auto -v '$(CURDIR):/tmp/lint:rw' $(MEGALINTER_IMAGE)
   ```

   <!-- markdownlint-enable MD010 -->

   v10.1.0 digests by flavor (use the flavor matching the workflow's
   `flavors/<flavor>` path):

   | Flavor       | `MEGALINTER_IMAGE`                                                                                                 |
   |--------------|--------------------------------------------------------------------------------------------------------------------|
   | `go`         | `ghcr.io/oxsecurity/megalinter-go@sha256:42e091a4bcbe9141fe420c2520ed7addf75ae60a0c9d42e3df1278eef1c90a88`         |
   | `python`     | `ghcr.io/oxsecurity/megalinter-python@sha256:f12a40b0dd5ad2c9aa029dcf7d3a0a92182d05cacc32d37756e67c3446484acb`     |
   | `javascript` | `ghcr.io/oxsecurity/megalinter-javascript@sha256:185a0eada2c8082910fc62a8ab29133521f9341d996e58a8de36a07f0a740a26` |
   | `cupcake`    | `ghcr.io/oxsecurity/megalinter-cupcake@sha256:7cce5b9d46564149d451a9752c5c266982f10c231be7df79996f46e3e171d2fc`    |

   For any other flavor,
   `docker buildx imagetools inspect ghcr.io/oxsecurity/megalinter-<flavor>:v10.1.0`
   prints the digest to copy.

3. **`.mega-linter.yml`** — any version-coupled settings.

The Docker target is always named `megalinter`. If a repo's `lint` target
runs the MegaLinter container, rename it to `megalinter` (and update README,
CI, or other targets that call it). `lint` is reserved for linting with the
local toolchain (e.g. `golangci-lint run`, `revive`), which is fast and
needs no Docker — keeping the names distinct means `make lint` stays cheap
and predictable across repos.

### Updating this skill to a new release

When a newer MegaLinter release is needed, update this skill rather than
bumping one repo ad hoc:

1. Resolve the new SHA
   (`gh api repos/oxsecurity/megalinter/commits/vX.Y.Z --jq .sha`) and
   image digest, and update the pins above.
2. Check the release's bundled Go version (see
   [references/go-toolchain.md](references/go-toolchain.md)) and its
   removed linters (below).
3. Run it against at least one representative repo (`make megalinter`) and
   re-verify the fixes in `references/` still hold, editing any that changed
   (e.g. version-specific false positives that are now fixed upstream).
4. Then roll the new pin out to repos, running the removed-linters sweep in
   each.

### Removed-linters sweep

Every major release drops linters (listed at
<https://megalinter.io/latest/removed-linters/>). Their config keys remain
schema-valid but are silently ignored, so stale config rots without failing
the build. When moving a repo to the pinned release, grep for every removed
linter name across:

- `.mega-linter.yml` (`DISABLE_LINTERS`, `DISABLE_ERRORS_LINTERS`, `<LINTER>_*` keys);
- the workflow's `env:` block;
- the removed linter's dotfiles;
- inline annotations in source referencing the old linter name.

Remove matches along with their rationale comments, unless the removed
linter has a named replacement that reads them: then migrate them to the
replacement's names instead (e.g. gitleaks → betterleaks, see
[references/linter-fixes.md](references/linter-fixes.md)). Example: v10 removed
`REPOSITORY_KICS` (Checkov, enabled by default, covers it), so a
`REPOSITORY_KICS` entry in `DISABLE_ERRORS_LINTERS` is dead config.

Then re-check the repo's Go pin against v10.1.0's bundled Go (next section).

## Go toolchain version

Read [references/go-toolchain.md](references/go-toolchain.md) whenever you
change `go.mod`'s `go` directive, see a `go.mod requires go >=` error, or see
golangci-lint/govulncheck fail on Go version. Summary:

- Set `go.mod` to the **latest patch of the previous minor** Go release
  (latest stable minor − 1), upgrading or downgrading as needed, with no
  user input. Never exceed the minor bundled by the pinned MegaLinter.
- If a dependency CVE fix would raise the `go` directive past that minor,
  revert it and record an ID-scoped CVE exception instead.
- This replaces Go version rules in the repo's `CLAUDE.md`/`AGENTS.md`
  unless they explicitly supersede this skill; ask before rewriting them.
- **Always set `GOTOOLCHAIN=auto`** for MegaLinter in Go repos (workflow
  step `env:` and the Makefile `docker run -e`), so a `go.mod` patch ahead of
  MegaLinter's bundled Go just works. No `*_UNSECURED_ENV_VARIABLES`
  allowlisting is needed.
- A **minor-level** gap (go.mod `1.N+1.x`, MegaLinter bundles `1.N.x`) has no
  workaround; the policy above keeps repos out of it.

## Stale suppression cleanup

Whenever the Go pin, a dependency, or the MegaLinter version changes, grep
the ignore files for entries whose rationale cites a Go version, a MegaLinter
bundled-toolchain version, or phrasing like "cannot upgrade until",
"requires Go 1.X", or "capped at":

```bash
grep -nEi 'go ?1\.[0-9]+|megalinter|cannot upgrade|requires go|capped at' \
  .trivyignore .grype.yaml osv-scanner.toml 2>/dev/null
```

For each hit:

1. Check whether the cited fix is already satisfied by the current `go.mod`
   or dependency version. If so, the suppression is just stale — remove it.
2. If the blocker is a patch-level Go gap within MegaLinter's bundled minor,
   bump `go.mod` to the latest patch (with `GOTOOLCHAIN=auto` set, as
   always) instead of keeping the suppression.
3. If the blocker is a claim about MegaLinter's bundled Go, verify it against
   the current release (see the reference) — these claims go stale quickly.
4. Remove the entry from **every** ignore file carrying it (the same CVE is
   often listed in all three), then confirm the scanner is clean.

Don't leave a suppression whose removal condition has been disproven "for
later"; these accumulate silently.

When a suppression is genuinely needed (e.g. the fix requires a Go minor
newer than the policy's target), add it ID-scoped to each scanner that
reports it:

```yaml
# .grype.yaml
ignore:
  # CVE-YYYY-NNNNN is fixed in example.com/mod vA.B.C, which requires Go 1.N+1.
  - vulnerability: CVE-YYYY-NNNNN
```

```toml
# osv-scanner.toml
[[IgnoredVulns]]
id = "GO-YYYY-NNNN"
reason = "Fixed in example.com/mod vA.B.C, which requires Go 1.N+1."
```

```text
# .trivyignore
# CVE-YYYY-NNNNN is fixed in example.com/mod vA.B.C, which requires Go 1.N+1.
CVE-YYYY-NNNNN
```

## Fixing specific linter failures

Read [references/linter-fixes.md](references/linter-fixes.md) when a specific
linter fails, or when `GO_GOLANGCI_LINT` is disabled or non-blocking (the
standard is to re-enable it). It covers: Trivy rate limits, golangci-lint
and revive, cspell (including the shared `flagWords` setup every cspell repo
needs), gitleaks (resolved by upgrading) and betterleaks, zizmor
online/offline mode and the `github-app` false positive, ESLint flat config,
and yamllint.

Read [references/adjacent-ci-fixes.md](references/adjacent-ci-fixes.md) when
the repo also has Goa code generation, a `ko-build-tag` workflow, or a
`license-header-check` workflow — recurring bugs found alongside MegaLinter
rollouts.

## Local validation before pushing

Run what applies to the repo:

```bash
go build ./... && go vet ./... && go test ./...
zizmor .github/workflows/      # native binary preferred over Docker
actionlint
```

Only run MegaLinter locally (`make megalinter`) if Docker is confirmed
running (`docker info`); otherwise rely on the CI MegaLinter run. Local runs
are slow and pull a multi-GB image, so they're worth it mainly when testing a
version bump or a Go toolchain change.
