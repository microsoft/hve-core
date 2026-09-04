#!/usr/bin/env bash
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#
# install-runtime.sh
# Provision the portable ontology-authoring runtime from its canonical lock.

set -euo pipefail

err() {
  printf "ERROR: %s\n" "$1" >&2
  exit 2
}

find_python() {
  local candidate
  for candidate in python3.11 python3 python; do
    if command -v "${candidate}" &>/dev/null; then
      command -v "${candidate}"
      return 0
    fi
  done
  return 1
}

main() {
  local script_root skill_root python_command
  script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  skill_root="$(cd "${script_root}/.." && pwd)"
  python_command="$(find_python)" || err \
    "Python 3.11 is required. Install Python 3.11 and rerun this command."

  "${python_command}" \
    "${script_root}/ontology_authoring/runtime_provisioning.py" \
    --project-root "${skill_root}" \
    "$@"
}

main "$@"