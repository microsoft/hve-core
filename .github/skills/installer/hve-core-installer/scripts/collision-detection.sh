#!/usr/bin/env bash
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#
# collision-detection.sh
# Reports component maturity and target collisions before copying HVE-Core
# components. Delegates to component-copy.sh in report-only mode so the
# pre-write check resolves components exactly as the copy does. Collisions are
# component-level: a file component collides on its full target path and a
# skill component collides on its target directory.
#
# Usage: collision-detection.sh <hve_core_base_path> <target_root> <component...>

set -euo pipefail

main() {
  if [[ $# -lt 3 ]]; then
    echo "Usage: $0 <hve_core_base_path> <target_root> <component...>" >&2
    exit 1
  fi

  local script_dir
  script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

  local hve_core_base_path="$1"
  local target_root="$2"
  shift 2

  export REPORT_ONLY=true
  exec bash "$script_dir/component-copy.sh" "$hve_core_base_path" "$target_root" custom "$@"
}

main "$@"
