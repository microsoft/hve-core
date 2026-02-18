#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
#
# Detects the current development environment type for HVE-Core installation.
# Outputs key-value pairs used by the installer to recommend an installation method.

set -euo pipefail

# Detect environment type
env_type="local"
is_codespaces=false
is_devcontainer=false

if [ "${CODESPACES:-}" = "true" ]; then
    env_type="codespaces"
    is_codespaces=true
    is_devcontainer=true
elif [ -f "/.dockerenv" ] || [ "${REMOTE_CONTAINERS:-}" = "true" ]; then
    env_type="devcontainer"
    is_devcontainer=true
fi

has_devcontainer_json=false
[ -f ".devcontainer/devcontainer.json" ] && has_devcontainer_json=true

has_workspace_file=false
[ -n "$(find . -maxdepth 1 -name '*.code-workspace' -print -quit 2>/dev/null)" ] && has_workspace_file=true

is_hve_core_repo=false
repo_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
[ -n "$repo_root" ] && [ "$(basename "$repo_root")" = "hve-core" ] && is_hve_core_repo=true

echo "ENV_TYPE=$env_type"
echo "IS_CODESPACES=$is_codespaces"
echo "IS_DEVCONTAINER=$is_devcontainer"
echo "HAS_DEVCONTAINER_JSON=$has_devcontainer_json"
echo "HAS_WORKSPACE_FILE=$has_workspace_file"
echo "IS_HVE_CORE_REPO=$is_hve_core_repo"
