#!/usr/bin/env bash
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
#
# Detect repository type and infrastructure signals.
# Outputs KEY=VALUE pairs on stdout. Source or eval the output.
#
# Usage:
#   eval "$(./lib/detect-repo-type.sh)"
#   echo "$REPO_TYPE"       # angular | vue | go | rust | typescript-bff
#   echo "$HAS_TERRAFORM"   # true | (unset)
#   echo "$HAS_MIGRATIONS"  # true | (unset)
#
# Reusable across: lfx-security-engineer, lfx-preflight, lfx-coordinator

set -euo pipefail

# --- Primary application type detection ---
# Angular: check LFX monorepo structure first (matches lfx-preflight detection),
# then fall back to a root package.json check for non-LFX Angular repos.
if [ -f apps/lfx-one/angular.json ] || [ -f turbo.json ]; then
  echo "REPO_TYPE=angular"
elif [ -f package.json ] && grep -q '"@angular/core"' package.json; then
  echo "REPO_TYPE=angular"
elif [ -f package.json ] && grep -q '"vue"' package.json; then
  echo "REPO_TYPE=vue"
elif [ -f go.mod ]; then
  echo "REPO_TYPE=go"
elif [ -f Cargo.toml ]; then
  echo "REPO_TYPE=rust"
elif [ -f package.json ] && grep -qE '"(express|fastify|@nestjs/core|koa|@hapi/hapi)"' package.json; then
  echo "REPO_TYPE=typescript-bff"
else
  echo "REPO_TYPE=unknown"
fi

# --- Infrastructure signals (run independently of app type) ---
if find . -maxdepth 3 -name "*.tf" 2>/dev/null | grep -q .; then
  echo "HAS_TERRAFORM=true"
fi

if find . -maxdepth 4 \( -path "*/migrations/*.sql" -o -name "*.up.sql" -o -name "*.down.sql" \) 2>/dev/null | grep -q .; then
  echo "HAS_MIGRATIONS=true"
fi
