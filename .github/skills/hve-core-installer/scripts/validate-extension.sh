#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
#
# Validates the HVE Core VS Code extension installation.
# Usage: validate-extension.sh <code_cli>
#   code_cli: 'code' or 'code-insiders'

set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <code_cli>" >&2
    echo "  code_cli: 'code' or 'code-insiders'" >&2
    exit 1
fi

code_cli="$1"

# Check if extension is installed
if "$code_cli" --list-extensions 2>/dev/null | grep -q "ise-hve-essentials.hve-core"; then
    echo "✅ HVE Core extension installed successfully"
    installed=true
else
    echo "❌ Extension not found in installed extensions"
    installed=false
fi

# Verify version (optional)
version=$("$code_cli" --list-extensions --show-versions 2>/dev/null | grep "ise-hve-essentials.hve-core" | sed 's/.*@//')
[ -n "$version" ] && echo "📌 Version: $version"

echo "EXTENSION_INSTALLED=$installed"
