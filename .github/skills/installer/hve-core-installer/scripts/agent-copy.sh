#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
# Copies selected HVE-Core agents to the target repository.
# Creates .github/agents/, copies agent files, computes SHA256 hashes,
# and writes .hve-tracking.json manifest for upgrade tracking.
# Usage: agent-copy.sh <hve_core_base_path> <collection_id> <file1> [file2...]
#   Files are paths relative to the agents/ directory.
set -euo pipefail

hve_core_base_path="${1:?Usage: $0 <hve_core_base_path> <collection_id> <file1> [file2...]}"
collection_id="${2:?Usage: $0 <hve_core_base_path> <collection_id> <file1> [file2...]}"
shift 2

source_base="$hve_core_base_path/.github/agents"
target_dir=".github/agents"
manifest_path=".hve-tracking.json"
keep_existing="${KEEP_EXISTING:-false}"
collisions_file="${COLLISIONS_FILE:-}"
has_jq=false
command -v jq >/dev/null 2>&1 && has_jq=true

# Load collision list when keep_existing is enabled
declare -A collision_set
if [ "$keep_existing" = "true" ] && [ -n "$collisions_file" ] && [ -f "$collisions_file" ]; then
    while IFS= read -r line; do
        [ -n "$line" ] && collision_set["$line"]=1
    done < "$collisions_file"
fi

# Create target directory
mkdir -p "$target_dir"

# Get version from package.json
if [ "$has_jq" = true ]; then
    version=$(jq -r '.version' "$hve_core_base_path/package.json")
else
    version=$(grep -o '"version": *"[^"]*"' "$hve_core_base_path/package.json" | head -1 | sed 's/.*"\([^"]*\)"/\1/')
fi

# Initialize manifest JSON
installed=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
files_json="{}"

# Copy files (source paths are relative to agents/, target is flat)
for file in "$@"; do
    filename=$(basename "$file")
    source_path="$source_base/$file"
    target_path="$target_dir/$filename"
    rel_path=".github/agents/$filename"

    # Skip files the user chose to keep during collision resolution
    if [ "$keep_existing" = "true" ] && [ -n "${collision_set[$target_path]+x}" ]; then
        echo "⏭️ Kept existing: $filename"
        continue
    fi

    cp "$source_path" "$target_path"
    hash=$(sha256sum "$target_path" | cut -d' ' -f1)
    if [ "$has_jq" = true ]; then
        files_json=$(echo "$files_json" | jq --arg path "$rel_path" --arg ver "$version" --arg sha "$hash" \
            '. + {($path): {"version": $ver, "sha256": $sha, "status": "managed"}}')
    else
        # Build JSON entries without jq
        if [ "$files_json" = "{}" ]; then
            files_json="{\"$rel_path\": {\"version\": \"$version\", \"sha256\": \"$hash\", \"status\": \"managed\"}}"
        else
            files_json="${files_json%\}}, \"$rel_path\": {\"version\": \"$version\", \"sha256\": \"$hash\", \"status\": \"managed\"}}"
        fi
    fi
    echo "✅ Copied $filename"
done

# Write manifest
if [ "$has_jq" = true ]; then
    jq -n --arg src "microsoft/hve-core" --arg ver "$version" --arg inst "$installed" \
        --arg col "$collection_id" --argjson files "$files_json" \
        '{source: $src, version: $ver, installed: $inst, collection: $col, files: $files}' \
        > "$manifest_path"
else
    cat > "$manifest_path" <<EOF
{"source": "microsoft/hve-core", "version": "$version", "installed": "$installed", "collection": "$collection_id", "files": $files_json}
EOF
fi
echo "✅ Created $manifest_path"
