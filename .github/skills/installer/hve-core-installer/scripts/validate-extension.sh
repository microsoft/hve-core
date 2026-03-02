#!/usr/bin/env bash
# Validates that the HVE Core VS Code extension is installed.
# Set code_cli to 'code' or 'code-insiders' before running.
# Outputs EXTENSION_INSTALLED=true/false and version details.
set -euo pipefail

# Set based on user's earlier choice: 'code' or 'code-insiders'
code_cli="${code_cli:-code}"

# Check if extension is installed
if "$code_cli" --list-extensions 2>/dev/null | grep -q "ise-hve-essentials.hve-core"; then
    echo "✅ HVE Core extension installed successfully"
    installed=true
else
    echo "❌ Extension not found in installed extensions"
    installed=false
fi

# Verify version (optional)
version=$("$code_cli" --list-extensions --show-versions 2>/dev/null | grep "ise-hve-essentials.hve-core" | sed 's/.*@//' || true)
[ -n "$version" ] && echo "📌 Version: $version"

echo "EXTENSION_INSTALLED=$installed"
