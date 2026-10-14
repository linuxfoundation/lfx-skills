<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Adjacent CI fixes

Recurring bugs found in sibling CI/build files while rolling out MegaLinter.
Check for each when the repo has the matching file.

## Goa code generation (Makefile)

### Keep the Goa CLI in sync with `go.mod`

If the Makefile installs a pinned `goa.design/goa/v3/cmd/goa@vX.Y.Z` that
differs from `go.mod`'s `goa.design/goa/v3`, `make apigen` regenerates
`gen/` with a stale generator against a newer runtime. Derive it from
`go.mod` via `go list` (which handles both single-line and block `require`
forms) and always (re)install it in the deps target:

<!-- markdownlint-disable MD010 -->

```makefile
GOA_VERSION := $(shell go list -m -f '{{.Version}}' goa.design/goa/v3)

deps:
	go install goa.design/goa/v3/cmd/goa@$(GOA_VERSION)
```

<!-- markdownlint-enable MD010 -->

### Swagger2 `"security": null` jq fix

Goa v3.30.0 emits `"security": null` in Swagger2 output, which repos strip
with jq. Two pitfalls:

- Write the jq filter as **one unbroken single-quoted line**. A Make `\` +
  newline inside single quotes is passed to the shell literally, causing
  `syntax error, unexpected INVALID_CHARACTER`. Use `\` continuations only
  outside the quotes.
- Use a `mktemp` file held in a shell variable, not a fixed path like
  `/tmp/openapi.json.fixed`, so concurrent runs don't collide.

<!-- markdownlint-disable MD010 -->

```makefile
	tmp=$$(mktemp) && \
	jq '<filter on one line>' gen/http/openapi.json > "$$tmp" && \
	mv "$$tmp" gen/http/openapi.json
```

<!-- markdownlint-enable MD010 -->

### Require `jq`

If `apigen` uses jq, have `deps` fail early with an install hint, and list
`jq` as a prerequisite in `README.md`:

<!-- markdownlint-disable MD010 -->

```makefile
	@command -v jq >/dev/null || { echo "jq is required; install it (e.g. brew install jq)"; exit 1; }
```

<!-- markdownlint-enable MD010 -->

## `ko-build-tag.yaml`: version tag stripping

`${REF_NAME//v/}` removes every `v` in the string, not only the leading one.
Use `${REF_NAME#v}`.

## `license-header-check.yaml`: generated-code exclusion

`exclude_pattern: "gen/*"` doesn't match files under `gen/`. Use
`exclude_pattern: "gen"`.
