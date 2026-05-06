#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#
# embed-audio.sh
# Wrapper for embed_audio.py — embeds per-slide WAV voice-over files
# into a PowerPoint deck.
#
# No environment variables required. This script embeds pre-generated
# WAV files and does not call Azure services.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(dirname "${SCRIPT_DIR}")"

err() {
  printf "ERROR: %s\n" "$1" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Embeds per-slide WAV voice-over files into a PPTX deck.

Options:
  --input <path>             Source PPTX file path (required)
  --audio-dir <path>         Directory containing slide-NNN.wav files (default: voice-over)
  --output <path>            Output PPTX file path (default: input stem + '-narrated.pptx')
  -v, --verbose              Enable verbose (DEBUG) logging output
  --skip-venv-setup          Skip virtual environment setup
  -h, --help                 Show this help message
EOF
  exit 0
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
  local -a passthrough_args=()
  local skip_venv_setup=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) usage ;;
      --skip-venv-setup) skip_venv_setup=true; shift ;;
      *) passthrough_args+=("$1"); shift ;;
    esac
  done

  test_uv_availability

  if [[ "${skip_venv_setup}" == "false" ]]; then
    initialize_python_environment
  fi

  local python
  python="$(get_venv_python_path)"

  if [[ ! -x "${python}" ]]; then
    err "Python not found at ${python}. Run without --skip-venv-setup to initialize."
  fi

  "${python}" "${SCRIPT_DIR}/embed_audio.py" "${passthrough_args[@]}"
}

main "$@"
