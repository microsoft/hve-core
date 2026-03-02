#!/usr/bin/env bash
# Detects whether the current installation is eligible for upgrade.
# Checks for .hve-tracking.json and compares installed version against source.
# Usage: upgrade-detection.sh <hve_core_base_path>
set -euo pipefail

hve_core_base_path="${1:?Usage: $0 <hve_core_base_path>}"
manifest_path=".hve-tracking.json"

if [ -f "$manifest_path" ]; then
    if command -v jq >/dev/null 2>&1; then
        installed_version=$(jq -r '.version' "$manifest_path")
        installed_collection=$(jq -r '.collection // "hve-core"' "$manifest_path")
        source_version=$(jq -r '.version' "$hve_core_base_path/package.json")
    else
        installed_version=$(grep -o '"version": *"[^"]*"' "$manifest_path" | head -1 | sed 's/.*"\([^"]*\)"/\1/')
        installed_collection="hve-core"
        source_version=$(grep -o '"version": *"[^"]*"' "$hve_core_base_path/package.json" | head -1 | sed 's/.*"\([^"]*\)"/\1/')
    fi

    version_changed=false
    [ "$source_version" != "$installed_version" ] && version_changed=true

    echo "UPGRADE_MODE=true"
    echo "INSTALLED_VERSION=$installed_version"
    echo "SOURCE_VERSION=$source_version"
    echo "VERSION_CHANGED=$version_changed"
    echo "INSTALLED_COLLECTION=$installed_collection"
else
    echo "UPGRADE_MODE=false"
fi
