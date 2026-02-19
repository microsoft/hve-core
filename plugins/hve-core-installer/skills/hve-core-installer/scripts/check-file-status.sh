#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
#
# Compares current agent files against the tracking manifest to determine
# file status for upgrade operations (managed, modified, ejected, missing).
# Usage: check-file-status.sh

set -euo pipefail

manifest_path=".hve-tracking.json"

if [ ! -f "$manifest_path" ]; then
    echo "No manifest found at $manifest_path" >&2
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required for file status checking" >&2
    echo "Install: apt-get install -y jq  |  brew install jq  |  choco install jq" >&2
    exit 1
fi

# Iterate over manifest files
jq -r '.files | to_entries[] | "\(.key)|\(.value.sha256)|\(.value.status)"' "$manifest_path" | while IFS='|' read -r file stored_hash status; do
    if [ "$status" = "ejected" ]; then
        echo "FILE=$file|STATUS=ejected|ACTION=Skip (user owns this file)"
        continue
    fi

    if [ ! -f "$file" ]; then
        echo "FILE=$file|STATUS=missing|ACTION=Will restore"
        continue
    fi

    current_hash=$(sha256sum "$file" | cut -d' ' -f1)
    if [ "$current_hash" != "$stored_hash" ]; then
        echo "FILE=$file|STATUS=modified|ACTION=Requires decision"
    else
        echo "FILE=$file|STATUS=managed|ACTION=Will update"
    fi
done
