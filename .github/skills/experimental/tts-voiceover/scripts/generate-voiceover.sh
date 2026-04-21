#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#
# generate-voiceover.sh
# Wrapper for generate_voiceover.py — generates per-slide TTS voice-over
# from YAML speaker notes via Azure Speech SDK.

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

Generates per-slide WAV voice-over files from YAML speaker notes.

Options:
  --dry-run                  Print SSML templates without generating audio
  --voice <name>             Azure TTS voice name (default: en-US-Andrew:DragonHDLatestNeural)
  --rate <rate>              Speech prosody rate (default: +10%)
  --content-dir <path>       Path to slide content directory (default: content)
  --output-dir <path>        Path to WAV output directory (default: voice-over)
  --lexicon <path>           Path to custom acronyms.yaml lexicon file
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

  "${python}" "${SCRIPT_DIR}/generate_voiceover.py" "${passthrough_args[@]}"
}

main "$@"
