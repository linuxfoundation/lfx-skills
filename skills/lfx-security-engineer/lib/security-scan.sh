#!/usr/bin/env bash
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
#
# Phase 1: Automated Security Scan
# Runs mechanical pattern-matching checks against changed files.
# Outputs structured findings to stdout (pipe-delimited).
#
# Output format per line:
#   FINDING|SEVERITY|CHECK|FILE:LINE|DESCRIPTION
#   PASSED|CHECK|DESCRIPTION
#
# Usage:
#   ./lib/security-scan.sh                    # scan changed files (default)
#   ./lib/security-scan.sh --full-scan        # scan all files
#   ./lib/security-scan.sh --file src/auth/   # scan specific path
#
# Requires: detect-repo-type.sh output (REPO_TYPE, HAS_TERRAFORM, HAS_MIGRATIONS)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Parse arguments ---
SCAN_MODE="changed"  # changed | full | file
TARGET_PATH=""
SHOW_ALL="false"

while [[ $# -gt 0 ]]; do
  case $1 in
    --full-scan) SCAN_MODE="full"; shift ;;
    --all) SHOW_ALL="true"; shift ;;
    --file)
      if [[ -z "${2:-}" ]]; then
        echo "ERROR: --file requires a path argument" >&2
        exit 1
      fi
      SCAN_MODE="file"; TARGET_PATH="$2"; shift 2 ;;
    *)
      echo "ERROR: unrecognized flag: $1" >&2
      exit 1
      ;;
  esac
done

if [[ "$SCAN_MODE" == "file" && ! -e "$TARGET_PATH" ]]; then
  echo "ERROR: --file target does not exist: $TARGET_PATH" >&2
  exit 1
fi

# --- Detect repo type ---
eval "$("$SCRIPT_DIR/detect-repo-type.sh")"

# --- Determine file list ---
get_changed_files() {
  if [[ "$SCAN_MODE" == "full" ]]; then
    find . -type f \( -name "*.ts" -o -name "*.go" -o -name "*.rs" -o -name "*.tf" -o -name "*.sql" -o -name "*.js" -o -name "*.json" \
      -o -name "*.yaml" -o -name "*.yml" -o -name "*.env" -o -name "*.tfvars" -o -name "*.py" \) \
      -not -path "*/node_modules/*" -not -path "*/dist/*" -not -path "*/build/*" -not -path "*/.next/*" -not -path "*/target/*" 2>/dev/null
  elif [[ "$SCAN_MODE" == "file" ]]; then
    if [ -d "$TARGET_PATH" ]; then
      find "$TARGET_PATH" -type f 2>/dev/null
    else
      echo "$TARGET_PATH"
    fi
  else
    local base_ref
    base_ref=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/||' || echo "origin/main")
    {
      git diff -z --name-only "${base_ref}...HEAD" 2>/dev/null || git diff -z --name-only HEAD~1 2>/dev/null || true
      # Include staged + unstaged changes and untracked (non-ignored) files,
      # not just what's already committed on this branch.
      git diff -z --name-only HEAD 2>/dev/null || true
      git ls-files -z --others --exclude-standard 2>/dev/null || true
    } | tr '\0' '\n' | sort -u
  fi
}

# Filter files by extension pattern, excluding .secignore paths
filter_files() {
  local pattern="$1"
  get_changed_files | apply_secignore | grep -E "$pattern" 2>/dev/null || true
}

# Grep changed files matching extension for a pattern
scan_files() {
  local ext_filter="$1"
  local grep_pattern="$2"
  filter_files "$ext_filter" | xargs -r grep -HnE "$grep_pattern" 2>/dev/null || true
}

# Case-insensitive variant of scan_files.
# Deliberately a separate helper rather than adding -i to scan_files: only the
# secrets check needs case-insensitivity (variable names are camelCase as often
# as snake_case), and flipping -i globally would silently change the match
# behaviour of all the other checks.
scan_files_i() {
  local ext_filter="$1"
  local grep_pattern="$2"
  filter_files "$ext_filter" | xargs -r grep -HniE "$grep_pattern" 2>/dev/null || true
}

# Check if a file is a test file (for false positive reduction)
is_test_file() {
  local file="$1"
  echo "$file" | grep -qE '\.(spec|test)\.(ts|js)$|_test\.go$|test_.*\.py$|/tests/|/__tests__/|/spec/|/fixtures/|/mocks/|/__mocks__/'
}

# Respect .secignore if present — build an array of grep exclude patterns
SECIGNORE_PATTERNS=()
if [ -f .secignore ]; then
  while IFS= read -r pattern; do
    [[ "$pattern" =~ ^#.*$ || -z "$pattern" ]] && continue
    SECIGNORE_PATTERNS+=("$pattern")
  done < .secignore
fi

# Filter out paths matching .secignore glob patterns (fnmatch-style)
apply_secignore() {
  if [ ${#SECIGNORE_PATTERNS[@]} -eq 0 ]; then
    cat
    return
  fi
  while IFS= read -r filepath; do
    local excluded=false
    for pattern in "${SECIGNORE_PATTERNS[@]}"; do
      # Use bash extended globbing for fnmatch-style matching
      # shellcheck disable=SC2254
      case "$filepath" in
        $pattern) excluded=true; break ;;
      esac
    done
    if [[ "$excluded" == "false" ]]; then
      echo "$filepath"
    fi
  done
}

# Highest severity seen across the whole scan, for the final exit code
MAX_SEVERITY="NONE"

# Emit a finding, downgrading severity for test files
# location is the full grep -Hn output: file:line:matched_source
# We split into file:line for field 4 and fold matched source into description
# Pass "no-downgrade" as $5 to keep high-confidence findings (e.g. live
# credentials) at full severity even when they appear in a test file.
emit_finding() {
  local severity="$1" check="$2" location="$3" description="$4" downgrade="${5:-downgrade}"
  local file line_num file_line
  file=$(echo "$location" | cut -d: -f1)
  line_num=$(echo "$location" | cut -d: -f2)
  file_line="$file:$line_num"
  if [[ "$downgrade" == "downgrade" ]] && is_test_file "$file"; then
    # Downgrade: CRITICAL→HIGH, HIGH→MEDIUM in test files
    case "$severity" in
      CRITICAL) severity="HIGH" ;;
      HIGH) severity="MEDIUM" ;;
    esac
    description="$description [test file]"
  fi
  # MEDIUM means "a lead for the Phase 2 agent, not a defect" — either a
  # test-file downgrade or a heuristic that needs human judgment to resolve
  # (see check_access_control). It is noise by default; --all surfaces it.
  if [[ "$severity" == "MEDIUM" && "$SHOW_ALL" != "true" ]]; then
    return
  fi
  # MEDIUM deliberately does not touch MAX_SEVERITY. The exit code must describe
  # the repo, not the invocation: if MEDIUM counted, the same clean checkout
  # would exit 0 without --all and 1 with it, which makes the code useless to a
  # caller and surprising to a human.
  case "$severity" in
    CRITICAL) MAX_SEVERITY="CRITICAL" ;;
    HIGH) [[ "$MAX_SEVERITY" != "CRITICAL" ]] && MAX_SEVERITY="WARNING" ;;
  esac
  echo "FINDING|$severity|$check|$file_line|$description"
}

# ============================================================
# CHECK 1: Secrets and Credentials
# ============================================================
check_secrets() {
  local ext='\.(ts|js|go|rs|py|json|yaml|yml|env|tf|tfvars)$'
  # Recognizable credential formats. These identify a secret by its own shape,
  # so they must never be gated behind a variable-name guess.
  local live_key_pattern='AKIA[0-9A-Z]{16}|sk_live_|ghp_[0-9a-zA-Z]{36}|AIza[0-9A-Za-z_-]{35}'
  local placeholder_pattern='process\.env\.|os\.Getenv|your-.*-here|<YOUR_|test-secret|fake-|example-'
  local found_any=false

  # --- Pass 1: format-based detection (high confidence, ungated) ---
  # Runs over every scanned file independently of variable naming: an AWS key
  # assigned to `apiKey`, `ApiKey`, `creds[0]` or nothing at all is still an
  # AWS key. Case-sensitive on purpose — these prefixes are fixed-case, and
  # matching them loosely would turn `aKiA...` typos into findings.
  local live_findings
  live_findings=$(scan_files "$ext" "$live_key_pattern")
  if [ -n "$live_findings" ]; then
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      # Env-var/placeholder filter still applies. Note we deliberately do NOT
      # suppress on the substring "EXAMPLE": it would silence a real key on any
      # line that happens to mention the word, and suppressing a live
      # credential is a far worse failure than one noisy doc finding.
      if echo "$line" | grep -qE "$placeholder_pattern"; then
        continue
      fi
      emit_finding CRITICAL secrets "$line" "Live service credential detected" no-downgrade
      found_any=true
    done <<< "$live_findings"
  fi

  # --- Pass 2: name-based heuristic (lower confidence) ---
  # Case-insensitive so `apiKey`, `API_KEY` and `api_key` all match. Bare
  # `token` is included: it is the most common name for exactly the thing this
  # check exists to catch.
  local name_findings
  name_findings=$(scan_files_i "$ext" \
    '(api[_-]?key|secret[_-]?key|access[_-]?token|private[_-]?key|token|password|passwd|bearer)[[:space:]]*[:=][[:space:]]*["'"'"'][A-Za-z0-9+/=_\-]{8,}')
  if [ -n "$name_findings" ]; then
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      if echo "$line" | grep -qE "$placeholder_pattern"; then
        continue
      fi
      # Already reported at full confidence by pass 1 — don't double-report.
      if echo "$line" | grep -qE "$live_key_pattern"; then
        continue
      fi
      # HIGH, not CRITICAL: this is a name heuristic that pass 1 declined to
      # confirm by format, so it belongs in the exit-1 "confirm against the
      # source" band. Emitting CRITICAL would make `token = "some-long-value"`
      # fail a required check that SKILL.md documents as format-based only.
      emit_finding HIGH secrets "$line" "Potential hardcoded secret"
      found_any=true
    done <<< "$name_findings"
  fi

  if [ "$found_any" = false ]; then
    echo "PASSED|secrets|No hardcoded secrets or credentials detected"
  fi
}

# ============================================================
# CHECK 2: OWASP A01 — Broken Access Control
# ============================================================
# Route enumeration cannot prove or disprove authorization in LFX V2, because
# auth is not applied inside the handler body. Services register routes wrapped
# in middleware — `mux.Handle("POST /...", h.withAuth(http.HandlerFunc(h.Create)))`
# — and the real decision is enforced out of process at Heimdall/OpenFGA. So the
# presence of a handler function carries no authz signal at all: on a clean
# lfx-v2-newsletter-service main, `func.*Handler` matched 30 times with zero true
# positives, flagging the `withAuth` middleware itself, the request logger, and a
# liveness probe. The Go branch is therefore removed rather than tuned: no
# single-file regex can see a wrapper applied at a different call site, and
# emitting it as MEDIUM would only move the noise, still costing the Phase 2
# agent turns to dismiss.
#
# Authorization review belongs to Phase 2 Review 2, which reads the route table
# and the middleware together. That is where the real access-control findings on
# this repo came from.
#
# What stays here is deliberately narrow: patterns that name a specific
# user-controlled identifier reaching a lookup (IDOR shape). Those are emitted as
# MEDIUM — a lead for the agent to chase behind `--all`, never a gate.
check_access_control() {
  local findings=""

  case "$REPO_TYPE" in
    angular|typescript-bff)
      # IDOR shape only: a request-supplied id used directly. This applies to the
      # server-side Express proxy/BFF layer inside the LFX Angular monorepo
      # (e.g. apps/*/server/, server/, bff/), not browser-only components.
      # Route enumeration (`router.get(...)`) is intentionally not scanned — same
      # reasoning as the Go branch above.
      findings=$(scan_files '\.(ts|js)$' 'req\.params\.(id|userId|orgId)' 2>/dev/null)
      ;;
    go)
      # Intentionally empty — see the comment block above this function.
      findings=""
      ;;
    rust)
      # Path-extractor IDOR shape (axum/actix): an id pulled straight from the path.
      findings=$(scan_files '\.rs$' 'Path\(\([[:space:]]*[A-Za-z_]*(id|uid|user)' 2>/dev/null)
      ;;
  esac

  findings=$(echo "$findings" | sed '/^$/d')
  if [ -z "$findings" ]; then
    echo "PASSED|access-control|No broken access control patterns detected"
    return
  fi

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    # MEDIUM, not HIGH: this is a lead, not a defect. A request-supplied id is
    # only an IDOR if the subsequent lookup is unscoped, and that is a Phase 2
    # judgment. MEDIUM keeps it out of the default output and the exit code.
    emit_finding MEDIUM access-control "$line" \
      "Request-supplied identifier used directly — confirm the lookup is scoped to the caller"
  done <<< "$findings"
}

# ============================================================
# CHECK 3: OWASP A04 — Cryptographic Failures
# ============================================================
check_crypto() {
  local findings=""

  # Weak hashing for passwords
  local weak_hash
  weak_hash=$(scan_files '\.(ts|js|go|rs)$' 'createHash\(.md5|createHash\(.sha1|md5\.New|sha1\.New|use md5::|use sha1::')
  findings="$findings"$'\n'"$weak_hash"

  # Insecure random for tokens
  local weak_random
  weak_random=$(scan_files '\.(ts|js)$' 'Math\.random\(\)')
  findings="$findings"$'\n'"$weak_random"

  # Rust-specific weak RNG
  if [[ "$REPO_TYPE" == "rust" ]]; then
    local rust_rng
    rust_rng=$(scan_files '\.rs$' 'thread_rng\(\)|rand::random\(\)')
    findings="$findings"$'\n'"$rust_rng"
  fi

  findings=$(echo "$findings" | sed '/^$/d')
  if [ -z "$findings" ]; then
    echo "PASSED|crypto|No weak cryptography patterns detected"
    return
  fi

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if echo "$line" | grep -qE 'md5|sha1'; then
      # HIGH for the same reason: the pattern sees the algorithm, not what the
      # digest is for. md5 over a cache key or an etag is fine, and only a
      # human can tell that from md5 over a password.
      emit_finding HIGH crypto "$line" "Weak hash algorithm — use bcrypt/argon2 if this hashes a password"
    else
      emit_finding HIGH crypto "$line" "Insecure random — use crypto.randomBytes() or OsRng"
    fi
  done <<< "$findings"
}

# ============================================================
# CHECK 4: OWASP A05 — Injection
# ============================================================
check_injection() {
  local findings=""

  # SQL injection — anchor on string *building*, not on any `+` after a keyword.
  # The previous `SELECT .+\+` form matched the `+` inside a correctly
  # parameterized call's argument list — e.g.
  #   db.NewRaw("SELECT COUNT(*) ... WHERE sg_event_id = ?", group+"-late-ev")
  # where the `?` placeholder is right and the concat is outside the SQL literal.
  # It also missed UPDATE/DELETE concatenation and Sprintf-built UPDATE entirely.
  # Requiring a closing quote immediately followed by `+` ties the match to a
  # query string being glued to an expression, and covers all four verbs.
  local sql_inj
  sql_inj=$(scan_files '\.(ts|js|go|rs)$' '"(SELECT|INSERT|UPDATE|DELETE)[^"]*"[[:space:]]*\+|fmt\.Sprintf\("(SELECT|INSERT|UPDATE|DELETE)|format!\("(SELECT|INSERT|UPDATE|DELETE)')
  findings="$findings"$'\n'"$sql_inj"

  # Command injection
  local cmd_inj
  cmd_inj=$(scan_files '\.(ts|js)$' 'exec\(|spawn\(.*req\.|eval\(')
  findings="$findings"$'\n'"$cmd_inj"

  # Rust command injection
  if [[ "$REPO_TYPE" == "rust" ]]; then
    local rust_cmd
    rust_cmd=$(scan_files '\.rs$' 'Command::new\(|std::process::Command')
    findings="$findings"$'\n'"$rust_cmd"

    # Unsafe blocks
    local rust_unsafe
    rust_unsafe=$(scan_files '\.rs$' 'unsafe[[:space:]]*\{')
    findings="$findings"$'\n'"$rust_unsafe"
  fi

  findings=$(echo "$findings" | sed '/^$/d')
  if [ -z "$findings" ]; then
    echo "PASSED|injection|No injection patterns detected"
    return
  fi

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if echo "$line" | grep -qE 'unsafe[[:space:]]*\{'; then
      emit_finding HIGH injection "$line" "Unsafe block — verify SAFETY comment and no attacker-controlled data"
    else
      emit_finding CRITICAL injection "$line" "Potential injection vulnerability"
    fi
  done <<< "$findings"
}

# ============================================================
# CHECK 5: OWASP A07 — Authentication Failures
# ============================================================
check_auth() {
  local findings=""

  # JWT without algorithm enforcement
  local jwt_issues
  jwt_issues=$(scan_files '\.(ts|js|go|rs)$' 'alg.*none|algorithms.*\[\]|verify.*false')
  findings="$findings"$'\n'"$jwt_issues"

  # Insecure cookie flags
  local cookie_issues
  cookie_issues=$(scan_files '\.(ts|js)$' 'cookie\(|setCookie|set-cookie' 2>/dev/null)
  if [ -n "$cookie_issues" ]; then
    # Check if secure flags are missing
    local missing_secure
    missing_secure=$(echo "$cookie_issues" | grep -v -E 'secure.*true|httpOnly.*true|sameSite' 2>/dev/null || true)
    findings="$findings"$'\n'"$missing_secure"
  fi

  findings=$(echo "$findings" | sed '/^$/d')
  if [ -z "$findings" ]; then
    echo "PASSED|auth|No authentication failure patterns detected"
    return
  fi

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    emit_finding HIGH auth "$line" "Authentication weakness — verify JWT validation and cookie security"
  done <<< "$findings"
}

# ============================================================
# CHECK 6: OWASP A09 — Security Logging Failures
# ============================================================
check_logging() {
  local findings=""

  # Silent catch blocks: grep matches one line at a time, so a plain grep
  # pattern only catches `catch { ... return null }` written on a single
  # line. Use awk to track brace depth so normally-formatted multiline
  # catch blocks are caught too.
  local ts_js_files
  ts_js_files=$(filter_files '\.(ts|js)$')
  if [ -n "$ts_js_files" ]; then
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      [ -f "$f" ] || continue
      local silent_catch
      silent_catch=$(awk '
        /catch[[:space:]]*\(/ && !in_catch {
          in_catch=1; start_line=NR
          idx = index($0, "catch")
          sub_line = substr($0, idx)
          block = sub_line "\n"
          depth = gsub(/\{/, "{", sub_line) - gsub(/\}/, "}", sub_line)
          next
        }
        in_catch {
          block = block $0 "\n"
          depth += gsub(/\{/, "{") - gsub(/\}/, "}")
          if (depth <= 0) {
            if (block ~ /return[[:space:]]*\(?(null|undefined|false)\)?/ \
                && block !~ /log|Logger|console\.(error|warn)|Sentry|captureException/) {
              print FILENAME ":" start_line ":silent-catch"
            }
            in_catch=0
          }
        }
      ' "$f" 2>/dev/null)
      findings="$findings"$'\n'"$silent_catch"
    done <<< "$ts_js_files"
  fi

  findings=$(echo "$findings" | sed '/^$/d')
  if [ -z "$findings" ]; then
    echo "PASSED|logging|No security logging failures detected"
    return
  fi

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    # Only flag if in auth-related files
    if echo "$line" | grep -qiE 'auth|token|jwt|session|login'; then
      emit_finding HIGH logging "$line" "Silent error in auth code — add security event logging"
    fi
  done <<< "$findings"
}

# ============================================================
# CHECK 7: Sensitive Data Exposure
# ============================================================
check_data_exposure() {
  local findings=""

  # Stack traces in responses
  local stack_traces
  stack_traces=$(scan_files '\.(ts|js|go)$' 'err\.stack|error\.stack|stackTrace|panic.*http')
  findings="$findings"$'\n'"$stack_traces"

  # PII in URLs/query strings
  local pii_urls
  pii_urls=$(scan_files '\.(ts|js|go)$' '(email|password|token|ssn|dob)=.*req\.(query|url|originalUrl)')
  findings="$findings"$'\n'"$pii_urls"

  findings=$(echo "$findings" | sed '/^$/d')
  if [ -z "$findings" ]; then
    echo "PASSED|data-exposure|No sensitive data exposure patterns detected"
    return
  fi

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    emit_finding HIGH data-exposure "$line" "Potential sensitive data exposure"
  done <<< "$findings"
}

# ============================================================
# CHECK 8: Terraform/OpenTofu — Infrastructure Security
# ============================================================
check_terraform() {
  if [[ "${HAS_TERRAFORM:-}" != "true" ]]; then
    echo "PASSED|terraform|No Terraform files detected — skipped"
    return
  fi

  local has_findings=false

  # Committed .tfvars
  local tfvars
  tfvars=$(filter_files '\.tfvars$')
  if [ -n "$tfvars" ]; then
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      emit_finding CRITICAL terraform "$f:1:$f" ".tfvars file in source control — may contain secrets"
      has_findings=true
    done <<< "$tfvars"
  fi

  # Wildcard IAM
  local wildcard_iam
  wildcard_iam=$(scan_files '\.tf$' 'actions[[:space:]]*=[[:space:]]*\["\*"\]|resources[[:space:]]*=[[:space:]]*\["\*"\]')
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    emit_finding HIGH terraform "$line" "Overly permissive IAM — scope actions and resources"
    has_findings=true
  done <<< "$wildcard_iam"

  # Open network (0.0.0.0/0 on sensitive ports)
  local open_net
  open_net=$(scan_files '\.tf$' '0\.0\.0\.0/0|::/0')
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    emit_finding HIGH terraform "$line" "Open network rule — restrict CIDR for sensitive ports"
    has_findings=true
  done <<< "$open_net"

  # Unencrypted storage
  local unencrypted
  unencrypted=$(scan_files '\.tf$' 'storage_encrypted[[:space:]]*=[[:space:]]*false|acl[[:space:]]*=[[:space:]]*"public-read"')
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    emit_finding HIGH terraform "$line" "Unencrypted or public storage"
    has_findings=true
  done <<< "$unencrypted"

  # Sensitive outputs without sensitive = true
  # Grep for output blocks with sensitive names, then check context for sensitive = true
  local tf_files
  tf_files=$(filter_files '\.tf$')
  if [ -n "$tf_files" ]; then
    while IFS= read -r tf_file; do
      [ -z "$tf_file" ] && continue
      [ -f "$tf_file" ] || continue
      # Use awk to find output blocks with sensitive names and check for sensitive = true
      local bad_outputs
      bad_outputs=$(awk '
        /^[[:space:]]*output[[:space:]]*"[^"]*((password|secret|token|key)[^"]*)"/{ in_block=1; block_file=FILENAME; block_line=NR; block_text=$0; has_sensitive=0 }
        in_block && /sensitive[[:space:]]*=[[:space:]]*true/ { has_sensitive=1 }
        in_block && /^[[:space:]]*\}/ { if (!has_sensitive) print block_file ":" block_line ":" block_text; in_block=0 }
      ' "$tf_file" 2>/dev/null)
      while IFS= read -r line; do
        [ -z "$line" ] && continue
        emit_finding HIGH terraform "$line" "Sensitive output without sensitive = true"
        has_findings=true
      done <<< "$bad_outputs"
    done <<< "$tf_files"
  fi

  if [[ "$has_findings" != "true" ]]; then
    echo "PASSED|terraform|Terraform checks passed"
  fi
}

# ============================================================
# CHECK 9: Database Migrations — Schema Security
# ============================================================
check_migrations() {
  if [[ "${HAS_MIGRATIONS:-}" != "true" ]]; then
    echo "PASSED|migrations|No migration files detected — skipped"
    return
  fi

  local has_findings=false

  # Sensitive columns as plain text
  local sensitive_cols
  sensitive_cols=$(scan_files '\.(sql|up\.sql)$' '(password|passwd|ssn|tax_id|national_id|credit_card|card_number|cvv)[[:space:]]+(VARCHAR|TEXT|CHAR)')
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    emit_finding CRITICAL migrations "$line" "Sensitive column stored as plain text"
    has_findings=true
  done <<< "$sensitive_cols"

  # Overly broad grants
  local broad_grants
  broad_grants=$(scan_files '\.sql$' 'GRANT ALL PRIVILEGES|GRANT.*TO PUBLIC')
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    emit_finding HIGH migrations "$line" "Overly broad permission grant"
    has_findings=true
  done <<< "$broad_grants"

  # Hardcoded PII in seed data
  local hardcoded_pii
  hardcoded_pii=$(scan_files '\.sql$' "INSERT.*VALUES.*@[a-z]+\.[a-z]|INSERT.*VALUES.*[0-9]{3}-[0-9]{2}-[0-9]{4}")
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    # Skip clearly synthetic data
    if echo "$line" | grep -qE '@example\.(com|invalid|test)|555-0[0-9]{3}|000-00-0000'; then
      continue
    fi
    emit_finding CRITICAL migrations "$line" "Potential real PII in migration seed data"
    has_findings=true
  done <<< "$hardcoded_pii"

  if [[ "$has_findings" != "true" ]]; then
    echo "PASSED|migrations|Migration security checks passed"
  fi
}

# ============================================================
# RUN ALL CHECKS
# ============================================================
echo "# Security Scan Results"
echo "# Repo Type: ${REPO_TYPE}"
echo "# Terraform: ${HAS_TERRAFORM:-false}"
echo "# Migrations: ${HAS_MIGRATIONS:-false}"
echo "# Scan Mode: ${SCAN_MODE}"
echo "# ---"

check_secrets
check_access_control
check_crypto
check_injection
check_auth
check_logging
check_data_exposure
check_terraform
check_migrations

# --- Summary ---
echo "# --- END ---"

# Exit code contract. Only exit 2 is safe to gate a build on.
#
#   2 — CRITICAL: a recognizable credential format or a committed .tfvars.
#       Format-based, low false-positive rate. Gate on this.
#   1 — HIGH: a heuristic pattern match that still needs a human or the Phase 2
#       agent to confirm. Treat as "review needed", not "build broken".
#   0 — nothing above MEDIUM.
#
# Phase 1 is a mechanical starting checklist, not a standalone gate: it reads
# single lines in isolation, so it cannot see a wrapper applied at another call
# site or a value that is safe because of where it came from. Wiring exit 1 into
# a required check will block clean repos. See the Phase 1 framing note in
# SKILL.md.
case "$MAX_SEVERITY" in
  CRITICAL) exit 2 ;;
  WARNING) exit 1 ;;
  *) exit 0 ;;
esac
