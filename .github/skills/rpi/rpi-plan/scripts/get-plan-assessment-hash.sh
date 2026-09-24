#!/usr/bin/env bash
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#
# Forward the same PowerShell arguments to the canonical projection helper.

set -euo pipefail

main() {
  local script_dir
  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  exec pwsh -NoProfile -File "${script_dir}/Get-PlanAssessmentHash.ps1" "$@"
}

main "$@"
