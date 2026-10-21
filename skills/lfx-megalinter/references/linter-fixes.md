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

### Shared `flagWords`

LFX repos don't maintain their own `flagWords` (terms cspell rejects, mostly
non-inclusive language). They pull the org-wide list from
`lfx-public-workflows` at MegaLinter run time and keep only repo-specific
`words`, `dictionaries`, and `ignorePaths` locally. The source of truth for
this setup is
[lfx-public-workflows/cspell/README.md](https://github.com/linuxfoundation/lfx-public-workflows/blob/main/cspell/README.md);
read it when the setup below doesn't match what you find.

Every repo with cspell enabled needs both parts:

1. A placeholder in `.cspell.json`, on its own line, exactly
   `"flagWords": [],`:

   ```json
   {
     "language": "en",
     "dictionaries": ["companies", "filetypes", "fullstack", "softwareTerms"],
     "words": ["lfx", "lfxv", "linuxfoundation"],
     "flagWords": [],
     "ignorePaths": [".cspell.json", "CODEOWNERS", "LICENSE", "LICENSE-docs", "megalinter-reports"]
   }
   ```

2. Pre/post commands in `.mega-linter.yml` that back up `.cspell.json`,
   fetch the snippet, substitute it for the placeholder, and restore the
   original after cspell runs:

   ```yaml
   SPELL_CSPELL_PRE_COMMANDS:
     - command: >-
         cp .cspell.json /tmp/cspell.json.orig &&
         curl -sSf --connect-timeout 5 --max-time 15
         https://raw.githubusercontent.com/linuxfoundation/lfx-public-workflows/737873e045a02df2f66b09d8061b98997cdf1880/cspell/flagwords.json.snippet
         -o /tmp/flagwords.json.snippet &&
         test "$(grep -c '^[[:space:]]*"flagWords"[[:space:]]*:[[:space:]]*\[\],[[:space:]]*$' .cspell.json)" -eq 1 &&
         sed -i -e '/^[[:space:]]*"flagWords"[[:space:]]*:[[:space:]]*\[\],[[:space:]]*$/{r /tmp/flagwords.json.snippet' -e 'd}' .cspell.json
       cwd: workspace
       continue_if_failed: false
   SPELL_CSPELL_POST_COMMANDS:
     - command: cp /tmp/cspell.json.orig .cspell.json
       cwd: workspace
   ```

Why each piece matters (keep them all when copying):

- **Pinned SHA, not `main`**: a mutable ref would let an upstream change
  silently alter every repo's cspell policy with no reviewable diff. To pick
  up list changes, bump the SHA in a PR.
- **`continue_if_failed: false` and `curl -sSf`**: pre-commands default to
  continuing on failure, which would leave `flagWords: []` and silently
  disable the shared policy; `-S` keeps curl's error visible in the logs.
- **`grep -c ... -eq 1` guard**: `sed` succeeds even when the placeholder
  matches zero or several lines, so without it a missing or reformatted
  placeholder would also silently disable the policy.
- **Timeouts**: pre-commands have no built-in timeout, so a stalled fetch
  would otherwise hang until the CI job times out.
- **Backup/restore**: `make megalinter` bind-mounts the working tree, so
  without `SPELL_CSPELL_POST_COMMANDS` a local run leaves the substituted
  `.cspell.json` on disk, ready to be committed by accident.
- **`sed`, not `gsed`**: these commands run inside MegaLinter's Linux image,
  which ships GNU `sed` (plus `curl`), not on the macOS host.

## gitleaks / betterleaks

MegaLinter v10 replaced `REPOSITORY_GITLEAKS` with `REPOSITORY_BETTERLEAKS`,
so a gitleaks finding means the repo is on an older MegaLinter. Resolve
every gitleaks issue by moving the repo to the skill's pinned release
(v10.1.0) — don't tune or suppress gitleaks.

Then explicitly migrate gitleaks configuration to betterleaks names.
betterleaks still reads the gitleaks names for backward compatibility, but
keeping them leaves the repo's config pointing at a removed tool. Carry the
contents over unchanged (the formats are the same); don't delete them, since
they hold active rules and allowlists:

| gitleaks                         | betterleaks                              |
|----------------------------------|------------------------------------------|
| `.gitleaks.toml`                 | `.betterleaks.toml`                      |
| `.gitleaksignore`                | `.betterleaksignore`                     |
| `gitleaks:allow` inline comments | `betterleaks:allow`                      |
| `REPOSITORY_GITLEAKS_*` settings | `REPOSITORY_BETTERLEAKS_*` (same suffix) |

```bash
git mv .gitleaks.toml .betterleaks.toml
git mv .gitleaksignore .betterleaksignore
files=$(git grep -l 'gitleaks:allow') && gsed -i 's/gitleaks:allow/betterleaks:allow/g' $files
```

Check each `REPOSITORY_GITLEAKS_*` key against the betterleaks variable list
in MegaLinter's
[betterleaks docs](https://megalinter.io/10.1.0/descriptors/repository_betterleaks/)
before renaming it.

For a small, localized betterleaks false positive, add a trailing
`betterleaks:allow` comment on the flagged line:

```go
const exampleToken = "not-a-real-secret-value" // betterleaks:allow
```

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

- **Any target is a private repo other than the workflow's own** (a private
  shared workflow or action, in this org or another): the workflow token can
  only read its own repository, so zizmor reports impostor-commit/unreachable
  findings. Use `ACTION_ZIZMOR_ARGUMENTS: "--offline"` and remove
  `ACTION_ZIZMOR_UNSECURED_ENV_VARIABLES`.

Don't blanket-copy `--offline` from another repo without checking its
`uses:` targets.

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
  # The JavaScript image sets NODE_ENV=production, which skips
  # devDependencies (where ESLint and its plugins live) unless included.
  - command: npm ci --include=dev  # Or the package manager's equivalent.
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
