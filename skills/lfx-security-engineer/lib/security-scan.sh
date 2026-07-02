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

while [[ $# -gt 0 ]]; do
  case $1 in
    --full-scan) SCAN_MODE="full"; shift ;;
    --file)
      if [[ -z "${2:-}" ]]; then
        echo "ERROR: --file requires a path argument" >&2
        exit 1
      fi
      SCAN_MODE="file"; TARGET_PATH="$2"; shift 2 ;;
    *) shift ;;
  esac
done

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
    git diff --name-only "${base_ref}...HEAD" 2>/dev/null || git diff --name-only HEAD~1 2>/dev/null || true
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
  filter_files "$ext_filter" | xargs grep -HnE "$grep_pattern" 2>/dev/null || true
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

# Emit a finding, downgrading severity for test files
# location is the full grep -Hn output: file:line:matched_source
# We split into file:line for field 4 and fold matched source into description
emit_finding() {
  local severity="$1" check="$2" location="$3" description="$4"
  local file line_num file_line
  file=$(echo "$location" | cut -d: -f1)
  line_num=$(echo "$location" | cut -d: -f2)
  file_line="$file:$line_num"
  if is_test_file "$file"; then
    # Downgrade: CRITICAL→HIGH, HIGH→MEDIUM in test files
    case "$severity" in
      CRITICAL) severity="HIGH" ;;
      HIGH) severity="MEDIUM" ;;
    esac
    description="$description [test file]"
  fi
  echo "FINDING|$severity|$check|$file_line|$description"
}

# ============================================================
# CHECK 1: Secrets and Credentials
# ============================================================
check_secrets() {
  local findings
  findings=$(scan_files '\.(ts|js|go|rs|py|json|yaml|yml|env|tf|tfvars)$' \
    '(api[_-]?key|secret[_-]?key|access[_-]?token|private[_-]?key|password|passwd|bearer)\s*[:=]\s*["'"'"'][A-Za-z0-9+/=_\-]{8,}')

  if [ -z "$findings" ]; then
    echo "PASSED|secrets|No hardcoded secrets or credentials detected"
    return
  fi

  # Filter out safe patterns
  while IFS= read -r line; do
    # Skip env var references, placeholders, and test fixtures
    if echo "$line" | grep -qE 'process\.env\.|os\.Getenv|your-.*-here|<YOUR_|test-secret|fake-|example-'; then
      continue
    fi
    # Check for live key patterns (high confidence)
    if echo "$line" | grep -qE 'AKIA[0-9A-Z]{16}|sk_live_|ghp_[0-9a-zA-Z]{36}|AIza[0-9A-Za-z_-]{35}'; then
      emit_finding CRITICAL secrets "$line" "Live service credential detected"
    else
      emit_finding CRITICAL secrets "$line" "Potential hardcoded secret"
    fi
  done <<< "$findings"
}

# ============================================================
# CHECK 2: OWASP A01 — Broken Access Control
# ============================================================
check_access_control() {
  local findings=""

  case "$REPO_TYPE" in
    angular|typescript-bff)
      findings=$(scan_files '\.(ts|js)$' 'router\.(get|post|put|delete|patch)\(' 2>/dev/null)
      # Also check for IDOR patterns
      local idor
      idor=$(scan_files '\.(ts|js)$' 'req\.params\.(id|userId|orgId)' 2>/dev/null)
      findings="$findings"$'\n'"$idor"
      ;;
    go)
      findings=$(scan_files '\.go$' 'func.*Handler|func.*http\.Handler' 2>/dev/null)
      ;;
    rust)
      findings=$(scan_files '\.rs$' '#\[(get|post|put|delete)\(' 2>/dev/null)
      ;;
  esac

  findings=$(echo "$findings" | sed '/^$/d')
  if [ -z "$findings" ]; then
    echo "PASSED|access-control|No broken access control patterns detected"
    return
  fi

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    emit_finding HIGH access-control "$line" "Route/handler may lack auth middleware — verify manually"
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
      emit_finding CRITICAL crypto "$line" "Weak hash algorithm — use bcrypt/argon2 for passwords"
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

  # SQL injection — string concatenation in queries
  local sql_inj
  sql_inj=$(scan_files '\.(ts|js|go|rs)$' 'SELECT .+\+|INSERT .+\+|format!\("SELECT|format!\("INSERT|fmt\.Sprintf\("SELECT|fmt\.Sprintf\("DELETE')
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
    rust_unsafe=$(scan_files '\.rs$' 'unsafe\s*\{')
    findings="$findings"$'\n'"$rust_unsafe"
  fi

  findings=$(echo "$findings" | sed '/^$/d')
  if [ -z "$findings" ]; then
    echo "PASSED|injection|No injection patterns detected"
    return
  fi

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if echo "$line" | grep -qE 'unsafe\s*\{'; then
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

  # Silent catch blocks in auth code
  local silent_catch
  silent_catch=$(scan_files '\.(ts|js)$' 'catch\s*(\(.*\))?\s*\{[^}]*return\s*(null|undefined|false)')
  findings="$findings"$'\n'"$silent_catch"

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
      emit_finding CRITICAL terraform "$f" ".tfvars file in source control — may contain secrets"
      has_findings=true
    done <<< "$tfvars"
  fi

  # Wildcard IAM
  local wildcard_iam
  wildcard_iam=$(scan_files '\.tf$' 'actions\s*=\s*\["\*"\]|resources\s*=\s*\["\*"\]')
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
  unencrypted=$(scan_files '\.tf$' 'storage_encrypted\s*=\s*false|acl\s*=\s*"public-read"')
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
  sensitive_cols=$(scan_files '\.(sql|up\.sql)$' '(password|passwd|ssn|tax_id|national_id|credit_card|card_number|cvv)\s+(VARCHAR|TEXT|CHAR)')
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
