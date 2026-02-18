#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
#
# Detects whether an existing HVE-Core agent installation requires an upgrade
# by comparing manifest version against the source version.
# Usage: detect-upgrade.sh <hve_core_base_path>
#   hve_core_base_path: Path to the HVE-Core clone root

set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <hve_core_base_path>" >&2
    exit 1
fi

hve_core_base_path="$1"
manifest_path=".hve-tracking.json"

if [ -f "$manifest_path" ]; then
    if command -v jq >/dev/null 2>&1; then
        installed_version=$(jq -r '.version' "$manifest_path")
        installed_collection=$(jq -r '.collection // "rpi-core"' "$manifest_path")
        source_version=$(jq -r '.version' "$hve_core_base_path/package.json")
    else
        installed_version=$(grep '"version"' "$manifest_path" | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
        installed_collection="rpi-core"
        source_version=$(grep '"version"' "$hve_core_base_path/package.json" | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
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
