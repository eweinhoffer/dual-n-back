#!/usr/bin/env bash
set -euo pipefail

TAG_NAME="${1:?usage: render_release_notes.sh <tag> <signed:true|false> [template] [output]}"
SIGNED_RELEASE="${2:-false}"
TEMPLATE_PATH="${3:-.github/release-notes-template.md}"
OUTPUT_PATH="${4:-dist/release-notes.md}"

if [[ ! -f "$TEMPLATE_PATH" ]]; then
  echo "Template not found: $TEMPLATE_PATH"
  exit 1
fi

if [[ "$SIGNED_RELEASE" == "true" ]]; then
  SIGNATURE_ASSETS_LINE='- `SHA256SUMS.txt.sig` and `release-signing-public.pem` (artifact signature + verification key)'
  SIGNATURE_VERIFY_LINE='3. Run: `openssl dgst -sha256 -verify release-signing-public.pem -signature SHA256SUMS.txt.sig SHA256SUMS.txt`'
else
  SIGNATURE_ASSETS_LINE="- Signature assets are not included in this release."
  SIGNATURE_VERIFY_LINE="3. Optional artifact signatures are not enabled for this release."
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"

sed \
  -e "s/{{TAG}}/${TAG_NAME}/g" \
  -e "s|{{SIGNATURE_ASSETS_LINE}}|${SIGNATURE_ASSETS_LINE}|g" \
  -e "s|{{SIGNATURE_VERIFY_LINE}}|${SIGNATURE_VERIFY_LINE}|g" \
  "$TEMPLATE_PATH" > "$OUTPUT_PATH"
