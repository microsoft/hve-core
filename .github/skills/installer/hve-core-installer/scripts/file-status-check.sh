#!/usr/bin/env bash
# Compares current agent files against the .hve-tracking.json manifest.
# Requires jq. Outputs per-file status lines.
set -euo pipefail

manifest_path=".hve-tracking.json"
if [ ! -f "$manifest_path" ]; then
    echo "❌ No .hve-tracking.json found" >&2
    exit 1
fi

jq -r '.files | to_entries[] | "\(.key)|\(.value.status)|\(.value.sha256)"' "$manifest_path" | while IFS='|' read -r file status stored_hash; do
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
