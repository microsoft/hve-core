#!/usr/bin/env bash
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#
# file-status-check.sh
# Compares installed HVE-Core files against the schema version 2
# .hve-tracking.json manifest and reports per-file status.
#
# Usage: file-status-check.sh [target_root]

set -euo pipefail

fail() {
  echo "❌ $1" >&2
  exit 1
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

main() {
  command -v jq >/dev/null 2>&1 || fail "jq is required by the Bash installer scripts. Install jq or use the PowerShell scripts."

  local target_root="${1:-.}"
  [[ -d "$target_root" ]] || fail "Target root not found: $target_root"

  local target_base manifest_path
  target_base=$(cd "$target_root" && pwd)
  manifest_path="$target_base/.hve-tracking.json"
  [[ -f "$manifest_path" ]] || fail "No .hve-tracking.json found."

  local schema_version
  schema_version=$(jq -r '.schemaVersion // "missing"' "$manifest_path")
  if [[ "$schema_version" != "2" ]]; then
    fail "Unsupported .hve-tracking.json schemaVersion '$schema_version' (expected 2). Delete .hve-tracking.json and re-run the installer for a clean reinstall."
  fi

  local file component kind maturity status stored_hash prefix current_hash
  while IFS=$'\t' read -r file component kind maturity status stored_hash; do
    [[ -n "$file" ]] || continue
    prefix="FILE=$file|COMPONENT=$component|KIND=$kind|MATURITY=$maturity"

    if [[ "$status" == "ejected" ]]; then
      echo "$prefix|STATUS=ejected|ACTION=Skip (user owns this file)"
      continue
    fi

    if [[ ! -f "$target_base/$file" ]]; then
      echo "$prefix|STATUS=missing|ACTION=Will restore"
      continue
    fi

    current_hash=$(sha256_of "$target_base/$file")
    if [[ "$current_hash" != "$stored_hash" ]]; then
      echo "$prefix|STATUS=modified|ACTION=Requires decision"
    else
      echo "$prefix|STATUS=managed|ACTION=Will update"
    fi
  done < <(jq -r '.files // {} | to_entries | sort_by(.key)[]
    | [.key, .value.component, .value.kind, .value.maturity, .value.status, .value.sha256] | @tsv' "$manifest_path")
}

main "$@"
