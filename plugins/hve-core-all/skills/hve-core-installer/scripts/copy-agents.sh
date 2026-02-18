#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
#
# Copies selected HVE-Core agent files to the target repository and creates
# a tracking manifest (.hve-tracking.json) for upgrade management.
# Usage: copy-agents.sh <selection> <hve_core_base_path> <collection_id> [--keep-existing] [agent_file ...]
#   selection:          'rpi-core' or 'collection'
#   hve_core_base_path: Path to the HVE-Core clone root
#   collection_id:      Collection identifier for manifest tracking
#   --keep-existing:    Skip files that already exist (collision resolution)
#   agent_file:         Additional agent filenames when selection is 'collection'

set -euo pipefail

if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <selection> <hve_core_base_path> <collection_id> [--keep-existing] [agent_file ...]" >&2
    exit 1
fi

selection="$1"
hve_core_base_path="$2"
collection_id="$3"
shift 3

keep_existing=false
if [ "${1:-}" = "--keep-existing" ]; then
    keep_existing=true
    shift
fi

source_dir="$hve_core_base_path/.github/agents"
target_dir=".github/agents"
manifest_path=".hve-tracking.json"

# Build file list
case "$selection" in
    rpi-core)
        files_to_copy=(
            "task-researcher.agent.md"
            "task-planner.agent.md"
            "task-implementor.agent.md"
            "task-reviewer.agent.md"
            "rpi-agent.agent.md"
        )
        ;;
    collection)
        files_to_copy=("$@")
        ;;
    *)
        echo "Unknown selection: $selection" >&2
        exit 1
        ;;
esac

# Create target directory
mkdir -p "$target_dir"
echo "✅ Created $target_dir"

# Get source version
if command -v jq >/dev/null 2>&1; then
    source_version=$(jq -r '.version' "$hve_core_base_path/package.json")
else
    source_version=$(grep '"version"' "$hve_core_base_path/package.json" | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
fi
installed_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Initialize manifest JSON
manifest_files="{"
first_file=true

# Copy files
for file in "${files_to_copy[@]}"; do
    source_path="$source_dir/$file"
    target_path="$target_dir/$file"
    rel_path=".github/agents/$file"

    if [ "$keep_existing" = true ] && [ -f "$target_path" ]; then
        echo "⏭️ Kept existing: $file"
        continue
    fi

    cp "$source_path" "$target_path"
    hash=$(sha256sum "$target_path" | cut -d' ' -f1)

    if [ "$first_file" = true ]; then
        first_file=false
    else
        manifest_files+=","
    fi
    manifest_files+="\"$rel_path\":{\"version\":\"$source_version\",\"sha256\":\"$hash\",\"status\":\"managed\"}"
    echo "✅ Copied $file"
done

manifest_files+="}"

# Write manifest
if command -v jq >/dev/null 2>&1; then
    echo "{\"source\":\"microsoft/hve-core\",\"version\":\"$source_version\",\"installed\":\"$installed_date\",\"collection\":\"$collection_id\",\"files\":$manifest_files,\"skip\":[]}" | jq '.' > "$manifest_path"
else
    echo "{\"source\":\"microsoft/hve-core\",\"version\":\"$source_version\",\"installed\":\"$installed_date\",\"collection\":\"$collection_id\",\"files\":$manifest_files,\"skip\":[]}" > "$manifest_path"
fi
echo "✅ Created $manifest_path"
