#!/usr/bin/env bash
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#
# upgrade-detection.sh
# Detects whether the current installation is eligible for upgrade by checking
# for a schema version 2 .hve-tracking.json and comparing the installed version
# against the source HVE-Core version.
#
# Usage: upgrade-detection.sh <hve_core_base_path> [target_root]

set -euo pipefail

fail() {
  echo "❌ $1" >&2
  exit 1
}

main() {
  [[ $# -ge 1 ]] || fail "Usage: $0 <hve_core_base_path> [target_root]"
  command -v jq >/dev/null 2>&1 || fail "jq is required by the Bash installer scripts. Install jq or use the PowerShell scripts."

  local hve_core_base_path="$1"
  local target_root="${2:-.}"
  [[ -d "$hve_core_base_path" ]] || fail "HVE-Core base path not found: $hve_core_base_path"
  [[ -d "$target_root" ]] || fail "Target root not found: $target_root"

  local manifest_path
  manifest_path="$(cd "$target_root" && pwd)/.hve-tracking.json"
  if [[ ! -f "$manifest_path" ]]; then
    echo "UPGRADE_MODE=false"
    return 0
  fi

  local schema_version
  schema_version=$(jq -r '.schemaVersion // "missing"' "$manifest_path")
  if [[ "$schema_version" != "2" ]]; then
    fail "Unsupported .hve-tracking.json schemaVersion '$schema_version' (expected 2). Delete .hve-tracking.json and re-run the installer for a clean reinstall."
  fi

  local installed_version installed_package installed_profile installed_components source_version version_changed
  installed_version=$(jq -r '.version' "$manifest_path")
  # Empty when a schema version 2 manifest predates package-explicit selection; no package is inferred.
  installed_package=$(jq -r '.selection.package // ""' "$manifest_path")
  installed_profile=$(jq -r '.selection.profile // "custom"' "$manifest_path")
  installed_components=$(jq -r '(.selection.components // []) | join(",")' "$manifest_path")
  source_version=$(jq -r '.version' "$hve_core_base_path/package.json")

  version_changed=false
  [[ "$source_version" != "$installed_version" ]] && version_changed=true

  echo "UPGRADE_MODE=true"
  echo "INSTALLED_VERSION=$installed_version"
  echo "SOURCE_VERSION=$source_version"
  echo "VERSION_CHANGED=$version_changed"
  echo "INSTALLED_PACKAGE=$installed_package"
  echo "INSTALLED_PROFILE=$installed_profile"
  echo "INSTALLED_COMPONENTS=$installed_components"
}

main "$@"
