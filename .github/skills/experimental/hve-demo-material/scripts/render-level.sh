#!/usr/bin/env bash
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#
# render-level.sh
# Render one authored demo-material level into a deck, frames, narration, a
# captioned MP4, and a transcript page, then score the machine-verifiable
# criteria.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
SKILL_ROOT="$(dirname "${SCRIPT_DIR}")"
readonly SKILL_ROOT
SKILLS_ROOT="$(dirname "${SKILL_ROOT}")"
readonly SKILLS_ROOT

readonly PPTX_PIPELINE="${SKILLS_ROOT}/powerpoint/scripts/invoke-pptx-pipeline.sh"
readonly VOICEOVER="${SKILLS_ROOT}/tts-voiceover/scripts/generate-voiceover.sh"
readonly ASSEMBLE="${SKILLS_ROOT}/demo-video/scripts/assemble-video.sh"
readonly CAPTURE_SKILL="${SKILLS_ROOT}/vscode-playwright"

LEVEL=""
LEVEL_DIR=""
WORKSPACE=""
NARRATION="piper"
CAPTURE=""
VISION_PROMPT_FILE=""
declare -a SKIP_VENV=()

usage() {
  cat <<EOF
Usage: $(basename "$0") --level <L100|L200|L300|L400> --level-dir <dir> \\
  --workspace <repo> [OPTIONS]

Options:
  --level <level>               Level label from the curriculum
  --level-dir <dir>             Authored level directory containing content/
  --workspace <repo>            Repository folder opened for live captures
  --narration <azure|piper>     Narration engine (default: piper)
  --capture <live|deck-export>  Capture profile (default: the level default)
  --vision-prompt-file <path>   Run the vision slide check with this prompt
  --skip-venv-setup             Skip uv sync in each skill wrapper
  -h, --help                    Show this help message
EOF
  exit 0
}

err() {
  printf "ERROR: %s\n" "$1" >&2
  exit 1
}

log() {
  printf "==> %s\n" "$1"
}

parse_args() {
  while (( $# > 0 )); do
    case "$1" in
      --level) LEVEL="$2"; shift 2 ;;
      --level-dir) LEVEL_DIR="$2"; shift 2 ;;
      --workspace) WORKSPACE="$2"; shift 2 ;;
      --narration) NARRATION="$2"; shift 2 ;;
      --capture) CAPTURE="$2"; shift 2 ;;
      --vision-prompt-file) VISION_PROMPT_FILE="$2"; shift 2 ;;
      --skip-venv-setup) SKIP_VENV=("--skip-venv-setup"); shift ;;
      -h|--help) usage ;;
      *) err "Unknown option: $1" ;;
    esac
  done
}

validate_args() {
  [[ "${LEVEL}" =~ ^L[1-4]00$ ]] || err "--level must be L100 to L400."
  [[ -d "${LEVEL_DIR}/content" ]] || err "No content/ under ${LEVEL_DIR}."
  [[ -d "${WORKSPACE}" ]] || err "--workspace must be a directory."
  [[ "${NARRATION}" =~ ^(azure|piper)$ ]] || err "--narration must be azure or piper."
  if [[ -z "${CAPTURE}" ]]; then
    case "${LEVEL}" in
      L300|L400) CAPTURE="live" ;;
      *) CAPTURE="deck-export" ;;
    esac
  fi
  [[ "${CAPTURE}" =~ ^(live|deck-export)$ ]] || err "--capture must be live or deck-export."
  LEVEL_DIR="$(cd "${LEVEL_DIR}" && pwd)"
  WORKSPACE="$(cd "${WORKSPACE}" && pwd)"
}

run_captures() {
  local plan="${LEVEL_DIR}/capture-plan.yml"
  [[ -f "${plan}" ]] || err "capture: live requires ${plan}."
  log "Capturing live VS Code frames"
  local summary exit_code=0
  summary="$(uv run --directory "${CAPTURE_SKILL}" python scripts/capture_vscode.py \
    --plan "${plan}" \
    --workspace "${WORKSPACE}" \
    --output-root "${LEVEL_DIR}")" || exit_code=$?
  printf '%s\n' "${summary##*$'\n'}" > "${LEVEL_DIR}/output/captures.json"
  (( exit_code == 0 )) || err "Live capture failed; see output/captures.json."
}

build_and_validate_deck() {
  local deck="$1"
  log "Building deck"
  bash "${PPTX_PIPELINE}" --action build "${SKIP_VENV[@]}" \
    --content-dir "${LEVEL_DIR}/content" \
    --style "${LEVEL_DIR}/content/global/style.yaml" \
    --output "${deck}"

  log "Validating deck"
  local -a vision=()
  [[ -n "${VISION_PROMPT_FILE}" ]] && vision=(--validation-prompt-file "${VISION_PROMPT_FILE}")
  bash "${PPTX_PIPELINE}" --action validate "${SKIP_VENV[@]}" \
    --input "${deck}" \
    --content-dir "${LEVEL_DIR}/content" \
    --image-output-dir "${LEVEL_DIR}/output/validation" \
    "${vision[@]}"

  log "Exporting deck frames"
  bash "${PPTX_PIPELINE}" --action export "${SKIP_VENV[@]}" \
    --input "${deck}" \
    --image-output-dir "${LEVEL_DIR}/frames/deck"
}

narrate_and_assemble() {
  local video_name="$1"
  log "Synthesizing narration with ${NARRATION}"
  bash "${VOICEOVER}" "${SKIP_VENV[@]}" \
    --engine "${NARRATION}" \
    --collapse-newlines \
    --content-dir "${LEVEL_DIR}/content" \
    --output-dir "${LEVEL_DIR}/audio"

  log "Assembling narrated MP4"
  uv run --directory "${SKILL_ROOT}" python scripts/render_checks.py segments \
    --level-dir "${LEVEL_DIR}" \
    --output-name "${video_name}"
  bash "${ASSEMBLE}" \
    --manifest "${LEVEL_DIR}/output/segments.yml" \
    --output "${LEVEL_DIR}/output/${video_name}"
}

write_accessible_media() {
  local video="${LEVEL_DIR}/output/$1"
  local captions="${video%.mp4}.vtt"
  local captioned="${video%.mp4}.captioned.mp4"
  log "Writing captions and transcript"
  uv run --directory "${SKILL_ROOT}" python scripts/render_checks.py captions \
    --level-dir "${LEVEL_DIR}" \
    --output "${captions}"
  ffmpeg -y -v error -i "${video}" -i "${captions}" \
    -map 0 -map 1 -c copy -c:s mov_text \
    -metadata:s:a:0 language=eng -metadata:s:s:0 language=eng \
    "${captioned}"
  mv "${captioned}" "${video}"
  uv run --directory "${SKILL_ROOT}" python scripts/render_checks.py transcript \
    --level "${LEVEL}" \
    --level-dir "${LEVEL_DIR}"
}

main() {
  parse_args "$@"
  validate_args
  mkdir -p "${LEVEL_DIR}/output" "${LEVEL_DIR}/frames/deck" "${LEVEL_DIR}/audio"

  local deck="${LEVEL_DIR}/output/hve-demo-${LEVEL}.pptx"
  local video_name="hve-demo-${LEVEL}.mp4"

  if [[ "${CAPTURE}" == "live" ]]; then
    run_captures
  fi
  build_and_validate_deck "${deck}"
  narrate_and_assemble "${video_name}"
  write_accessible_media "${video_name}"

  log "Scoring machine-verifiable criteria"
  local exit_code=0
  uv run --directory "${SKILL_ROOT}" python scripts/render_checks.py evaluate \
    --level "${LEVEL}" \
    --level-dir "${LEVEL_DIR}" \
    --capture "${CAPTURE}" \
    --narration "${NARRATION}" \
    > "${LEVEL_DIR}/output/render-result.json" || exit_code=$?
  cat "${LEVEL_DIR}/output/render-result.json"
  return "${exit_code}"
}

main "$@"
