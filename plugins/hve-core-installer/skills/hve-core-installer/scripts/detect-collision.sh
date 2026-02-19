#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
#
# Detects collisions between HVE-Core source agents and existing agents
# in the target directory before copy operations.
# Usage: detect-collision.sh <selection> <hve_core_base_path> [agent_file ...]
#   selection:          'rpi-core' or 'collection'
#   hve_core_base_path: Path to the HVE-Core clone root
#   agent_file:         Additional agent filenames when selection is 'collection'

set -euo pipefail

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <selection> <hve_core_base_path> [agent_file ...]" >&2
    echo "  selection:          'rpi-core' or 'collection'" >&2
    echo "  hve_core_base_path: Path to the HVE-Core clone root" >&2
    echo "  agent_file:         Additional agent filenames when selection is 'collection'" >&2
    exit 1
fi

selection="$1"
hve_core_base_path="$2"
shift 2

target_dir=".github/agents"

# Build file list based on selection
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

# Check for collisions
collisions=()
for file in "${files_to_copy[@]}"; do
    target_path="$target_dir/$file"
    if [ -f "$target_path" ]; then
        collisions+=("$target_path")
    fi
done

if [ "${#collisions[@]}" -gt 0 ]; then
    echo "COLLISIONS_DETECTED=true"
    echo "COLLISION_FILES=$(IFS=','; echo "${collisions[*]}")"
else
    echo "COLLISIONS_DETECTED=false"
fi
