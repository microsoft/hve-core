#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
#
# Ejects a file from HVE-Core upgrade tracking. Ejected files are permanently
# excluded from future upgrades, giving the user full ownership.
# Usage: eject-file.sh <file_path>
#   file_path: Relative path to the file to eject (e.g., .github/agents/task-planner.agent.md)

set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <file_path>" >&2
    exit 1
fi

file_path="$1"
manifest_path=".hve-tracking.json"

if [ ! -f "$manifest_path" ]; then
    echo "No manifest found at $manifest_path" >&2
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required for eject operations" >&2
    echo "Install: apt-get install -y jq  |  brew install jq  |  choco install jq" >&2
    exit 1
fi

# Check if file exists in manifest
if ! jq -e ".files[\"$file_path\"]" "$manifest_path" >/dev/null 2>&1; then
    echo "File not found in manifest: $file_path" >&2
    exit 1
fi

ejected_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Update manifest
jq --arg fp "$file_path" --arg ea "$ejected_at" \
    '.files[$fp].status = "ejected" | .files[$fp].ejectedAt = $ea' \
    "$manifest_path" > "${manifest_path}.tmp" && mv "${manifest_path}.tmp" "$manifest_path"

echo "✅ Ejected: $file_path"
echo "   This file will never be updated by HVE-Core."
