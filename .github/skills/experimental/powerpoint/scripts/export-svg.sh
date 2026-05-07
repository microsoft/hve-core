#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#
# export-svg.sh
# Export PowerPoint slides to SVG images.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(dirname "${SCRIPT_DIR}")"
VENV_DIR="${SKILL_ROOT}/.venv"

SKIP_VENV_SETUP=false

err() {
  printf "ERROR: %s\n" "$1" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --input <path>          Input PPTX file path (required)
  --output-dir <path>     Output directory for SVG files (required)
  --slides <list>         Comma-separated slide numbers (optional)
  --skip-venv-setup       Skip virtual environment setup
  -v, --verbose           Enable verbose output
  -h, --help              Show this help message
EOF
  exit 0
}

get_venv_python_path() {
  if [[ -f "${VENV_DIR}/Scripts/python.exe" ]]; then
    echo "${VENV_DIR}/Scripts/python.exe"
  elif [[ -f "${VENV_DIR}/bin/python" ]]; then
    echo "${VENV_DIR}/bin/python"
  else
    err "Python interpreter not found in venv. Run: uv sync --directory \"${SKILL_ROOT}\""
  fi
}

main() {
  local -a pass_through=()

  while (( $# > 0 )); do
    case "$1" in
      --skip-venv-setup) SKIP_VENV_SETUP=true; shift ;;
      -h|--help) usage ;;
      *) pass_through+=("$1"); shift ;;
    esac
  done

  if [[ "${SKIP_VENV_SETUP}" == "false" ]]; then
    if ! command -v uv &>/dev/null; then
      err "uv is required but was not found on PATH."
    fi
    uv sync --directory "${SKILL_ROOT}"
  fi

  local python
  python="$(get_venv_python_path)"

  [[ "${VERBOSE:-false}" == "true" ]] && pass_through+=("-v")

  "${python}" "${SCRIPT_DIR}/export_svg.py" "${pass_through[@]}"
}

main "$@"
