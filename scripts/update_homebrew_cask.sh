#!/usr/bin/env bash
set -euo pipefail

TAG_NAME="${1:?usage: update_homebrew_cask.sh <tag> <arm_sha256> <intel_sha256> [cask_path]}"
ARM_SHA="${2:?usage: update_homebrew_cask.sh <tag> <arm_sha256> <intel_sha256> [cask_path]}"
INTEL_SHA="${3:?usage: update_homebrew_cask.sh <tag> <arm_sha256> <intel_sha256> [cask_path]}"
CASK_PATH="${4:-Casks/dual-n-back.rb}"
VERSION_VALUE="${TAG_NAME#v}"

if [[ ! -f "$CASK_PATH" ]]; then
  echo "Cask file not found: $CASK_PATH"
  exit 1
fi

ruby - "$CASK_PATH" "$VERSION_VALUE" "$ARM_SHA" "$INTEL_SHA" <<'RUBY'
cask_path, version, arm_sha, intel_sha = ARGV
content = File.read(cask_path)

version_count = 0
content = content.sub(/version "[^"]+"/) do
  version_count += 1
  %(version "#{version}")
end

sha_count = 0
content = content.sub(/sha256 arm: "[0-9a-f]+",\n\s+intel: "[0-9a-f]+"/) do
  sha_count += 1
  %(sha256 arm: "#{arm_sha}",\n         intel: "#{intel_sha}")
end

abort("Could not update version/sha256 block in cask file") unless version_count == 1 && sha_count == 1

File.write(cask_path, content)
RUBY
