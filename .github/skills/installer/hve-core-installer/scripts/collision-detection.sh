#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
# Detects file collisions before copying HVE-Core agents.
# Usage: collision-detection.sh <hve_core_base_path> <selection> [collection_agents...]
#   selection: 'hve-core' for RPI core bundle, or collection id
#   collection_agents: space-separated relative paths (when selection is a collection)
set -euo pipefail

hve_core_base_path="${1:?Usage: $0 <hve_core_base_path> <selection> [collection_agents...]}"
selection="${2:?Usage: $0 <hve_core_base_path> <selection> [collection_agents...]}"
shift 2

target_dir=".github/agents"

# Build file list based on selection
case "$selection" in
    hve-core)
        files_to_copy=(
            "hve-core/task-researcher.agent.md"
            "hve-core/task-planner.agent.md"
            "hve-core/task-implementor.agent.md"
            "hve-core/task-reviewer.agent.md"
            "hve-core/rpi-agent.agent.md"
        )
        ;;
    *)
        files_to_copy=("$@")
        ;;
esac

# Check for collisions (target uses filename only)
collisions=()
for file in "${files_to_copy[@]}"; do
    filename=$(basename "$file")
    target_path="$target_dir/$filename"
    if [ -f "$target_path" ]; then
        collisions+=("$target_path")
    fi
done

if [ ${#collisions[@]} -gt 0 ]; then
    echo "COLLISIONS_DETECTED=true"
    IFS=','; echo "COLLISION_FILES=${collisions[*]}"
else
    echo "COLLISIONS_DETECTED=false"
fi
