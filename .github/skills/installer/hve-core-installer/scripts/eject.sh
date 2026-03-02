#!/usr/bin/env bash
# Ejects a tracked file from HVE-Core upgrade management.
# Marks the file as 'ejected' in .hve-tracking.json so future upgrades skip it.
# Usage: eject.sh <file_path>
set -euo pipefail

file_path="${1:?Usage: $0 <file_path>}"
manifest_path=".hve-tracking.json"

if [ ! -f "$manifest_path" ]; then
    echo "❌ No .hve-tracking.json found" >&2
    exit 1
fi

if jq -e --arg fp "$file_path" '.files[$fp]' "$manifest_path" >/dev/null 2>&1; then
    ejected_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    jq --arg fp "$file_path" --arg ea "$ejected_at" \
        '.files[$fp].status = "ejected" | .files[$fp].ejectedAt = $ea' \
        "$manifest_path" > "${manifest_path}.tmp" && mv "${manifest_path}.tmp" "$manifest_path"
    echo "✅ Ejected: $file_path"
    echo "   This file will never be updated by HVE-Core."
else
    echo "❌ File not found in tracking manifest: $file_path"
fi
