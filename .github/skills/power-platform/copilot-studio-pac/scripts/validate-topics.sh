#!/usr/bin/env bash
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#
# validate-topics.sh
# Cross-platform bash launcher for the topic-integrity gate. The real logic
# lives in the PowerShell implementation (validate-topics.ps1); this wrapper
# forwards all arguments to pwsh and propagates its exit code
# (0 = all topics pass, 1 = fail-closed FAIL, 2 = usage/parse/dependency error).

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v pwsh &>/dev/null; then
  printf 'ERROR: PowerShell 7 (pwsh) is required to run validate-topics.ps1 but was not found on PATH.\n' >&2
  exit 2
fi

exec pwsh -NoProfile -File "${script_dir}/validate-topics.ps1" "$@"
