#!/usr/bin/env bash
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#
# eject.sh
# Ejects a tracked component from HVE-Core upgrade management by marking every
# file belonging to it as 'ejected' in the schema version 2 .hve-tracking.json.
# The files remain on disk and become owned by the user.
#
# Usage: eject.sh <component> [target_root]

set -euo pipefail

fail() {
  echo "❌ $1" >&2
  exit 1
}

main() {
  [[ $# -ge 1 ]] || fail "Usage: $0 <component> [target_root]"
  command -v jq >/dev/null 2>&1 || fail "jq is required by the Bash installer scripts. Install jq or use the PowerShell scripts."

  local component="$1"
  local target_root="${2:-.}"
  [[ -n "$component" ]] || fail "Component must be a non-empty string."
  [[ -d "$target_root" ]] || fail "Target root not found: $target_root"

  local manifest_path
  manifest_path="$(cd "$target_root" && pwd)/.hve-tracking.json"
  [[ -f "$manifest_path" ]] || fail "No .hve-tracking.json found."

  local schema_version
  schema_version=$(jq -r '.schemaVersion // "missing"' "$manifest_path")
  if [[ "$schema_version" != "2" ]]; then
    fail "Unsupported .hve-tracking.json schemaVersion '$schema_version' (expected 2). Delete .hve-tracking.json and re-run the installer for a clean reinstall."
  fi

  local matched
  matched=$(jq -r --arg component "$component" '[.files // {} | to_entries[] | select(.value.component == $component)] | length' "$manifest_path")
  if [[ "$matched" == "0" ]]; then
    echo "❌ Component not found in tracking manifest: $component"
    return 0
  fi

  local ejected_at
  ejected_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  jq --arg component "$component" --arg ejectedAt "$ejected_at" \
    '.files |= with_entries(if .value.component == $component
       then .value += {status: "ejected", ejectedAt: $ejectedAt} else . end)' \
    "$manifest_path" >"${manifest_path}.tmp" && mv "${manifest_path}.tmp" "$manifest_path"
  echo "✅ Ejected: $component"
  echo "   HVE-Core will never update this component."
}

main "$@"
