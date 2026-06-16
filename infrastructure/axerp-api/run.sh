#!/usr/bin/env bash
# run.sh — Execute the Axina Group Inc. company provisioner against ERPNext.
#
# Usage:
#   bash run.sh                   # create/update company (production)
#   bash run.sh --dry-run         # validate only, no writes
#   bash run.sh --delete AGI      # remove company (dev/test only)
#
# Required environment variables (export before running, or edit .env below):
#   AXERP_URL         https://erp.axinagroup.com
#   AXERP_API_KEY     your frappe token key
#   AXERP_API_SECRET  your frappe token secret
#
# Alternatively create a .env file in this directory:
#   AXERP_URL=https://erp.axinagroup.com
#   AXERP_API_KEY=<key>
#   AXERP_API_SECRET=<secret>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Load .env if it exists (never commit this file) ────────────────────────
ENV_FILE="$SCRIPT_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
  echo "[info] Loading credentials from $ENV_FILE"
  # shellcheck disable=SC1090
  set -a && source "$ENV_FILE" && set +a
fi

# ── Validate required variables ────────────────────────────────────────────
MISSING=()
[[ -z "${AXERP_URL:-}"        ]] && MISSING+=("AXERP_URL")
[[ -z "${AXERP_API_KEY:-}"    ]] && MISSING+=("AXERP_API_KEY")
[[ -z "${AXERP_API_SECRET:-}" ]] && MISSING+=("AXERP_API_SECRET")

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "[error] Missing required variables: ${MISSING[*]}"
  echo "        Set them in your environment or create $ENV_FILE"
  exit 1
fi

# ── Dependency check ───────────────────────────────────────────────────────
if ! command -v python3 &>/dev/null; then
  echo "[error] python3 not found. Install Python 3.9+ to continue."
  exit 1
fi

if ! python3 -c "import requests" &>/dev/null; then
  echo "[info] Installing requests..."
  pip3 install --quiet requests
fi

# ── Run ────────────────────────────────────────────────────────────────────
echo "────────────────────────────────────────────"
echo " AXERP Company Provisioner"
echo " Target : $AXERP_URL"
echo "────────────────────────────────────────────"

python3 "$SCRIPT_DIR/create_company.py" "$@"
