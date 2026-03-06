#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_DIR"

echo "Running repository security scan..."

# Patterns tuned for common secret leaks and sensitive local machine info.
secret_pattern='BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]+|xox[baprs]-|AIza[0-9A-Za-z_-]{35}'
path_pattern='/Users/[A-Za-z0-9._-]+|/private/|/var/folders/'
local_network_pattern='(?i)\b(ssid|wifi|wi-fi)\b\s*[:=]\s*["'"'"'][^"'"'"']{1,}'
credential_assignment_pattern='(?i)(api[_-]?key|secret|token|password)\s*[:=]\s*["'"'"'][^"'"'"']{8,}'

scan_failed=0

run_scan() {
  local label="$1"
  local pattern="$2"

  echo
  echo "Checking: $label"
  if rg -n \
    --hidden \
    --glob '!.git' \
    --glob '!Dual N-Back.app/**' \
    --glob '!docs/screenshots/**' \
    --glob '!scripts/security_scan.sh' \
    -e "$pattern" \
    .; then
    echo "FAIL: $label"
    scan_failed=1
  else
    echo "PASS: $label"
  fi
}

run_scan "Secret/token patterns" "$secret_pattern"
run_scan "Hardcoded local machine paths" "$path_pattern"
run_scan "Wi-Fi/SSID references" "$local_network_pattern"
run_scan "Potential credential assignments" "$credential_assignment_pattern"

if [[ "$scan_failed" -ne 0 ]]; then
  echo
  echo "Security scan failed. Review findings before committing or publishing."
  exit 1
fi

echo
echo "Security scan passed."
