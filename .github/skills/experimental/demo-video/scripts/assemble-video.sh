#!/usr/bin/env bash
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#
# assemble-video.sh
# Wrapper for assemble_video.py that resolves the skill's Python environment
# and delegates FFmpeg video assembly.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(dirname "${SCRIPT_DIR}")"

err() {
  printf "ERROR: %s\n" "$1" >&2
  exit 1
}

test_uv_availability() {
  if ! command -v uv &>/dev/null; then
    err "uv is required but was not found on PATH. Install with: curl -LsSf https://astral.sh/uv/install.sh | sh"
  fi
}

initialize_python_environment() {
  echo "Syncing Python environment via uv..."
  uv sync --directory "${SKILL_ROOT}"
  echo "Environment synchronized."
}

get_venv_python_path() {
  echo "${SKILL_ROOT}/.venv/bin/python"
}

main() {
  local python
  local -a passthrough_args=("$@")

  test_uv_availability
  initialize_python_environment

  python="$(get_venv_python_path)"
  if [[ ! -x "${python}" ]]; then
    err "Python not found at ${python}."
  fi

  "${python}" "${SCRIPT_DIR}/assemble_video.py" "${passthrough_args[@]}"
}

main "$@"
