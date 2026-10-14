<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Linter-specific fixes

Known MegaLinter failure patterns and their fleet-standard fixes. Settings
shown belong in `.mega-linter.yml` unless noted.

## Trivy: rate-limited DB downloads

Wherever Trivy is enabled and the entry is missing, add (works around
[aquasecurity/trivy#7668](https://github.com/aquasecurity/trivy/discussions/7668)):

```yaml
REPOSITORY_TRIVY_UNSECURED_ENV_VARIABLES:
  - GITHUB_TOKEN
```

## golangci-lint and revive

Go repos run both `GO_GOLANGCI_LINT` and `GO_REVIVE` as blocking linters.
When `GO_GOLANGCI_LINT` is in `DISABLE_LINTERS` or `DISABLE_ERRORS_LINTERS`
(often with a `# Prefer Revive.` rationale), re-enable it: remove the entry
and its comment, then fix the findings it reports. golangci-lint catches
bugs (e.g. `errcheck`, `staticcheck`, `govet`) that revive's style checks
don't, so running only revive leaves those undetected.

Verify locally before pushing:

```bash
golangci-lint run ./...
revive -config revive.toml ./...
```

Fix findings in code. Where one is a genuine false positive, suppress it
inline with a scoped `//nolint:<linter> // <reason>` rather than disabling
the linter or the rule repo-wide.

## cspell

There's no easy local feedback loop for spelling, so keep `SPELL_CSPELL` in
`DISABLE_ERRORS_LINTERS` (non-blocking) rather than in `DISABLE_LINTERS`.
Add missing words to `.cspell.json` in **lowercase**.

When a script rewrites the `flagWords` placeholder in `.cspell.json`, guard
the `sed` with an anchored exact-count check so it can't silently corrupt the
file if the placeholder is missing or duplicated:

```bash
test "$(grep -c '^[[:space:]]*"flagWords"[[:space:]]*:[[:space:]]*\[\],[[:space:]]*$' .cspell.json)" -eq 1 && \
  gsed -i '...' .cspell.json
```

## gitleaks / betterleaks false positives

For small, localized false positives, use inline annotations
(`gitleaks:allow` or `betterleaks:allow`, matching the release's secret
scanner) on the flagged line. If the finding comes from a repo still on an
older MegaLinter, moving it to the skill's pinned release (v10.1.0, which
uses betterleaks) is the fix; don't bump one repo past that pin.

## zizmor

### Online vs offline

zizmor's online audits (e.g. impostor-commit, verifying SHA-pinned tags)
need the GitHub API. Choose the mode by checking every `uses:` target repo:

```bash
gh api repos/<owner>/<repo> --jq '.visibility'
```

- **All targets public** (the default): run online. Remove any
  `ACTION_ZIZMOR_ARGUMENTS: "--offline"` and add:

  ```yaml
  # zizmor's "artipacked" audit needs the GitHub API (to verify
  # SHA-pinned action tags), which requires GITHUB_TOKEN.
  ACTION_ZIZMOR_UNSECURED_ENV_VARIABLES: GITHUB_TOKEN
  ```

- **A target is a private cross-org repo**: the workflow token can't read it,
  so zizmor reports impostor-commit/unreachable findings. Use
  `ACTION_ZIZMOR_ARGUMENTS: "--offline"` and remove
  `ACTION_ZIZMOR_UNSECURED_ENV_VARIABLES`.

- **Exception**: if the MegaLinter workflow runs on `pull_request` including
  Dependabot PRs, those runs get a restricted `GITHUB_TOKEN` (401 on API
  calls) regardless of visibility, which can also justify `--offline`.

Don't blanket-copy `--offline` from another repo without checking which case
applies.

### `github-app` false positive

`actions/create-github-app-token` with both `owner:` and `repositories:` set
is flagged as "token granted access to all repositories" by zizmor v1.25.0,
which MegaLinter v10.1.0 bundles (fixed upstream in zizmor v1.25.1).
Suppress inline on the `owner:` line, splitting the rationale across preceding
lines to stay under
yamllint's 120-character limit:

```yaml
        with:
          # zizmor flags owner plus repositories as all-repository access;
          # repositories scopes the token, so this is a false positive.
          owner: example-org  # zizmor: ignore[github-app]
          repositories: example-repo
```

The comment may sit anywhere within the finding's span.

## ESLint flat config: `ERR_MODULE_NOT_FOUND`

MegaLinter's bundled ESLint can't resolve the repo's flat-config plugins.
Install the repo's dependencies and use its own ESLint:

```yaml
JAVASCRIPT_ES_PRE_COMMANDS:
  - command: npm ci  # Or the repo's package manager equivalent.
    cwd: workspace
JAVASCRIPT_ES_CLI_EXECUTABLE: node_modules/.bin/eslint
```

## yamllint

Mechanical fixes:

- Quote the workflow trigger key: `on:` → `"on":`.
- Add `---` document start.
- Fix comment spacing (two spaces before an inline `#`, one after).
- Long SHA-pinned `uses:` lines: add a rationale comment and a line-length
  disable on the line before (yamllint applies `disable-line` to the next
  line when it stands alone):

  ```yaml
  # SHA-pinned for supply-chain safety; the pin exceeds the line length.
  # yamllint disable-line rule:line-length
  uses: example-org/example-action/path@<40-char-sha>  # vX.Y.Z
  ```
