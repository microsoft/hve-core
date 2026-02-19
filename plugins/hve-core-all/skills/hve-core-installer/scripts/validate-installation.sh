#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
#
# Validates an HVE-Core clone-based installation by checking required directories
# and method-specific configuration.
# Usage: validate-installation.sh <method> <base_path>
#   method:    Installation method number (1-6)
#   base_path: Path to hve-core root directory

set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <method> <base_path>" >&2
    echo "  method:    Installation method number (1-6)" >&2
    echo "  base_path: Path to hve-core root directory" >&2
    exit 1
fi
method="$1"
base_path="$2"

valid=true
for path in "$base_path/.github/agents" "$base_path/.github/prompts" "$base_path/.github/instructions"; do
    if [ -d "$path" ]; then echo "✅ Found: $path"; else echo "❌ Missing: $path"; valid=false; fi
done

# Method 5: workspace file check (requires jq)
if [ "$method" = "5" ]; then
    if ! command -v jq >/dev/null 2>&1; then
        echo "⚠️  jq not installed - skipping workspace JSON validation"
        echo "   Install jq for full validation, or manually verify hve-core.code-workspace has 2+ folders"
    elif [ -f "hve-core.code-workspace" ] && jq -e '.folders | length >= 2' hve-core.code-workspace >/dev/null 2>&1; then
        echo "✅ Multi-root configured"
    else
        echo "❌ Multi-root not configured"; valid=false
    fi
fi

# Method 6: submodule check
[ "$method" = "6" ] && { grep -q "lib/hve-core" .gitmodules 2>/dev/null && echo "✅ Submodule configured" || { echo "❌ Submodule not in .gitmodules"; valid=false; }; }

[ "$valid" = true ] && echo "✅ Installation validated successfully"
