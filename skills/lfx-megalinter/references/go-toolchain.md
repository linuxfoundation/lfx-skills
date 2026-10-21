<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Go toolchain version and MegaLinter

MegaLinter's linters run against the Go toolchain bundled in its image, and
its precompiled Go tools (`golangci-lint`, `osv-scanner`'s govulncheck) are
built with a specific Go release. Both constrain what `go.mod` can declare.

## Version policy

Set `go.mod`'s `go` directive to the **latest patch of the previous minor
version** (latest stable minor − 1) — e.g. if `go1.27.x` is the current
stable minor, use the newest `go1.26.x`. Apply this directly in whichever
direction it requires (upgrade or downgrade); it needs no user input.

Why: this is a self-updating, objective rule. MegaLinter's bundled Go lags
upstream by months; staying one minor behind latest stable keeps the
toolchain mainstream-supported, avoids incompatibilities with tools pinned to
an older Go, and still picks up every security patch.

- **Patch updates** within the target minor are always taken — they are the
  fix for Go stdlib CVEs.
- **Dependency fixes don't move the minor.** If upgrading a dependency to
  fix a CVE would raise the `go` directive past the target minor (Go's
  module tooling does this automatically), revert that upgrade, keep the
  newest dependency version compatible with the target minor, and record
  the CVE as an ID-scoped exception (see the main skill's suppression
  examples). The exception is removed once the policy's target minor
  reaches the version the fix requires.
- **The target minor must not exceed the minor bundled by the skill's
  pinned MegaLinter release** (see the minor-level gap below). If latest
  stable − 1 is newer than that, use the bundled minor and tell the user the
  skill's MegaLinter pin needs updating.

### Repo-level Go version rules

This policy replaces Go version rules in a repo's `CLAUDE.md`/`AGENTS.md`
(e.g. "don't bump the minor without approval", "stay one minor behind
MegaLinter's bundled Go"). When a repo carries such a rule:

- If the repo file explicitly says it supersedes this skill, follow the repo.
- Otherwise, ask the user before replacing it; with approval, edit the repo
  file to defer to this skill's policy, then apply the policy.

### Finding the latest patch for a minor

```bash
MINOR=$(awk '/^go /{print $2}' go.mod | cut -d. -f1,2)
curl -s "https://go.dev/dl/?mode=json&include=all" \
  | jq -r --arg m "go${MINOR}." '.[].version | select(startswith($m))' \
  | sort -V | tail -1
```

Latest stable minor: `curl -s "https://go.dev/dl/?mode=json" | jq -r '.[0].version'`.

### Finding MegaLinter's bundled Go

```bash
# 1. Flavor and tag pinned in CI.
grep -A1 'oxsecurity/megalinter' .github/workflows/*.yml
# 2. That flavor's Dockerfile build args.
curl -s "https://raw.githubusercontent.com/oxsecurity/megalinter/<tag>/flavors/<flavor>/Dockerfile" \
  | grep -iE 'GO_ALPINE_VERSION|GO_IMAGE_VERSION'
```

Or empirically:
`docker run --rm --entrypoint go ghcr.io/oxsecurity/megalinter-<flavor>:<tag> version`.
MegaLinter v10.1.0 (the skill's pinned release) bundles Go **1.26.3** in
its runtime (`GO_ALPINE_VERSION`), with some tools built from Go 1.26.7
(`GO_IMAGE_VERSION`). The minor version (1.26) is what matters for the gap
regimes below.

## Always set `GOTOOLCHAIN=auto`

Every Go repo sets `GOTOOLCHAIN=auto` for MegaLinter, whether or not
`go.mod` is currently ahead of the bundled Go. The policy above takes the
latest patch, which routinely moves past MegaLinter's bundled patch, so
setting it up front avoids a CI break on every patch update. When the
versions already match, it's a no-op.

Set it in both places MegaLinter runs, which are the tested paths:

```yaml
# .github/workflows/mega-linter.yml, in the MegaLinter step's env: block.
# Lets Go-based linters download the go.mod toolchain when it is newer
# than the Go bundled in the MegaLinter image.
GOTOOLCHAIN: auto
```

<!-- markdownlint-disable MD010 -->

```makefile
	docker run --rm --platform linux/amd64 -e GOTOOLCHAIN=auto -v '$(CURDIR):/tmp/lint:rw' $(MEGALINTER_IMAGE)
```

<!-- markdownlint-enable MD010 -->

No `GO_GOLANGCI_LINT_UNSECURED_ENV_VARIABLES` or
`REPOSITORY_OSV_SCANNER_UNSECURED_ENV_VARIABLES` entry is needed —
MegaLinter only strips a fixed list of sensitive variables, and
`GOTOOLCHAIN` is not on it. One setting covers every Go-toolchain-invoking
linter.

Tradeoff: needs outbound access to the Go module proxy (MegaLinter already
needs this for module downloads) and adds a one-time toolchain download when
versions differ.

## Gap regimes

These explain the errors you see when `GOTOOLCHAIN=auto` is missing or the
Go minor is too new.

### Patch-level gap: fixed by `GOTOOLCHAIN=auto`

Example: `go.mod` says `go 1.26.9`, MegaLinter bundles `1.26.3`. The image
defaults to `GOTOOLCHAIN=local`, so without the setting above anything that
loads packages fails.

Signature:

```text
go: go.mod requires go >= 1.26.9 (running go 1.26.3; GOTOOLCHAIN=local)
```

Effects under `GOTOOLCHAIN=local`:

- `golangci-lint` fails outright.
- `osv-scanner` logs `Failed to run code analysis (govulncheck) ...` and
  falls back to reporting every version-matched CVE regardless of
  reachability — noisier, not safer.
- Plain `osv-scanner scan source` (without call analysis) only parses
  `go.mod`/`go.sum` and is unaffected.

Fix: add the `GOTOOLCHAIN=auto` setting from the section above; `go` then
downloads the matching toolchain from the module proxy.

### Minor-level gap: no workaround

Example: `go.mod` says `go 1.27.0`, MegaLinter bundles `1.26.x`.
`GOTOOLCHAIN=auto` downloads go1.27 successfully, but the precompiled tools
were built with go1.26 and can't read go1.27 export data, syntax, or stdlib.

golangci-lint signature:

```text
Error: can't load config: the Go language version (go1.26) used to build golangci-lint is lower than the targeted Go version (1.27.0)
```

or `export data version 5 is greater than maximum supported version 4`.

govulncheck (via osv-scanner) signature — note the downloaded
`golang.org/toolchain@v0.0.1-go1.27.0...` paths, proving the download
worked:

```text
Failed to run code analysis (govulncheck) ... loading packages:
.../golang.org/toolchain@v0.0.1-go1.27.0.linux-amd64/src/internal/poll/splice_linux.go:237:21: unknown field rfd in struct literal of type splicePipe
.../math/rand/v2/rand.go:213:17: method must have no type parameters
.../client.go:9:1: package requires newer Go version go1.27 (application built with go1.26)
```

Fix: revert `go.mod` to the latest patch of MegaLinter's bundled minor. The
version policy above exists to keep repos out of this regime.
