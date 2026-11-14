#!/usr/bin/env bash
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#
# render-level.sh
# Render one authored non-character level into required HTML and matching
# frames, narration, captioned MP4 and transcript, then score the evidence.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
SKILL_ROOT="$(dirname "${SCRIPT_DIR}")"
readonly SKILL_ROOT
SKILLS_ROOT="$(dirname "${SKILL_ROOT}")"
readonly SKILLS_ROOT

readonly VOICEOVER_SKILL="${SKILLS_ROOT}/tts-voiceover"
readonly ASSEMBLE_SKILL="${SKILLS_ROOT}/demo-video"
readonly CAPTURE_SKILL="${SKILLS_ROOT}/vscode-playwright"
readonly FINALIZE_ACCESSIBLE_VIDEO="${SCRIPT_DIR}/finalize-accessible-video.sh"

LEVEL=""
LEVEL_DIR=""
WORKSPACE=""
NARRATION="azure"
CAPTURE=""
ANIMATION="none"
SLIDES_SKILL_ROOT=""
declare -a SYNC_ARGS=()

usage() {
  cat <<EOF
Usage: $(basename "$0") --level <L100|L200|L300|L400> --level-dir <dir> \\
  --workspace <repo> [OPTIONS]

Options:
  --level <level>               Level label from the curriculum
  --level-dir <dir>             Authored level directory containing content/
  --workspace <repo>            Repository folder opened for live captures
  --narration <azure|none>      Narration mode (default: azure; CI requires none)
  --capture <live|deck-export>  Capture profile (default: the level default)
  --animation <none|characters>  Only none is supported; use the builder for characters
  --slides-skill-root <dir>     Required trusted loaded hve-slides skill root
  --skip-venv-setup             Use already-restored caller-owned environments
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

run_skill_python() {
  local skill_root="$1"
  local script="$2"
  local environment_name
  environment_name="$(basename "${skill_root}")"
  local current="${LEVEL_DIR}/.venv/${environment_name}"
  while [[ "${current}" != "/" && "${current}" != "." ]]; do
    [[ ! -L "${current}" ]] || err "Refusing a symlink in the caller environment path."
    current="$(dirname "${current}")"
  done
  shift 2
  UV_PROJECT_ENVIRONMENT="${LEVEL_DIR}/.venv/${environment_name}" \
    uv run --frozen --directory "${skill_root}" "${SYNC_ARGS[@]}" \
    python "${script}" "$@"
}

parse_args() {
  while (( $# > 0 )); do
    case "$1" in
      --level) LEVEL="$2"; shift 2 ;;
      --level-dir) LEVEL_DIR="$2"; shift 2 ;;
      --workspace) WORKSPACE="$2"; shift 2 ;;
      --narration) NARRATION="$2"; shift 2 ;;
      --capture) CAPTURE="$2"; shift 2 ;;
      --animation) ANIMATION="$2"; shift 2 ;;
      --slides-skill-root) SLIDES_SKILL_ROOT="$2"; shift 2 ;;
      --skip-venv-setup) SYNC_ARGS=("--no-sync"); shift ;;
      -h|--help) usage ;;
      *) err "Unknown option: $1" ;;
    esac
  done
}

validate_args() {
  [[ "${LEVEL}" =~ ^L[1-4]00$ ]] || err "--level must be L100 to L400."
  [[ -d "${LEVEL_DIR}/content" ]] || err "No content/ under ${LEVEL_DIR}."
  [[ -d "${WORKSPACE}" ]] || err "--workspace must be a directory."
  [[ "${NARRATION}" =~ ^(azure|none)$ ]] || err "--narration must be azure or none."
  if [[ "${GITHUB_ACTIONS:-false}" == "true" && "${NARRATION}" != "none" ]]; then
    err "CI demo rendering requires --narration none; speech synthesis is disabled."
  fi
  if [[ -z "${CAPTURE}" ]]; then
    case "${LEVEL}" in
      L300|L400) CAPTURE="live" ;;
      *) CAPTURE="deck-export" ;;
    esac
  fi
  [[ "${CAPTURE}" =~ ^(live|deck-export)$ ]] || err "--capture must be live or deck-export."
  LEVEL_DIR="$(cd "${LEVEL_DIR}" && pwd)"
  case "${LEVEL_DIR}/" in
    "${SKILLS_ROOT}/"*) err "Level outputs must not be inside skill installations." ;;
  esac
  if [[ -n "${SLIDES_SKILL_ROOT}" && -d "${SLIDES_SKILL_ROOT}" ]]; then
    SLIDES_SKILL_ROOT="$(cd "${SLIDES_SKILL_ROOT}" && pwd -P)"
    case "${LEVEL_DIR}/" in
      "${SLIDES_SKILL_ROOT}/"*) err "Level outputs must not be inside hve-slides." ;;
    esac
  fi
  command -v uv >/dev/null || err "uv is required."
  run_skill_python "${SKILL_ROOT}" scripts/render_checks.py \
    scripted-preflight --level "${LEVEL}" --level-dir "${LEVEL_DIR}" \
    --capture "${CAPTURE}" --animation "${ANIMATION}"
  [[ -f "${SLIDES_SKILL_ROOT}/scripts/render-deck.mjs" ]] \
    || err "Resolve hve-slides by name and pass its trusted root via --slides-skill-root."
  command -v node >/dev/null || err "Node.js 24+ is required."
  command -v npm >/dev/null || err "npm is required for pinned renderer dependencies."
  node -e 'if (Number(process.versions.node.split(".")[0]) < 24) process.exit(1)' \
    || err "Node.js 24+ is required."
  run_skill_python "${SKILL_ROOT}" scripts/render_checks.py \
    scripted-preflight --level "${LEVEL}" --level-dir "${LEVEL_DIR}" \
    --capture "${CAPTURE}" --animation "${ANIMATION}" \
    --slides-skill-root "${SLIDES_SKILL_ROOT}"
  SLIDES_SKILL_ROOT="$(cd "${SLIDES_SKILL_ROOT}" && pwd -P)"
  local tool_report ffmpeg_path ffprobe_path ffmpeg_dir ffprobe_dir
  tool_report="$(bash "${FINALIZE_ACCESSIBLE_VIDEO}" --check-prerequisites)"
  ffmpeg_path="$(printf '%s\n' "${tool_report}" | sed -n 's/^ffmpeg=//p')"
  ffprobe_path="$(printf '%s\n' "${tool_report}" | sed -n 's/^ffprobe=//p')"
  [[ -n "${ffmpeg_path}" && -n "${ffprobe_path}" ]] \
    || err "Could not resolve compatible FFmpeg tools."
  ffmpeg_dir="$(dirname "${ffmpeg_path}")"
  ffprobe_dir="$(dirname "${ffprobe_path}")"
  export FFMPEG_COMMAND="${ffmpeg_path}"
  export FFPROBE_COMMAND="${ffprobe_path}"
  export PATH="${ffmpeg_dir}:${ffprobe_dir}:${PATH}"
  WORKSPACE="$(cd "${WORKSPACE}" && pwd)"
}

run_captures() {
  local plan="${LEVEL_DIR}/capture-plan.yml"
  [[ -f "${plan}" ]] || err "capture: live requires ${plan}."
  log "Capturing live VS Code frames"
  local summary exit_code=0
  summary="$(run_skill_python "${CAPTURE_SKILL}" scripts/capture_vscode.py \
    --plan "${plan}" \
    --workspace "${WORKSPACE}" \
    --output-root "${LEVEL_DIR}")" || exit_code=$?
  printf '%s\n' "${summary##*$'\n'}" > "${LEVEL_DIR}/output/captures.json"
  (( exit_code == 0 )) || err "Live capture failed; see output/captures.json."
}

narrate_and_assemble() {
  local video_name="$1"
  if [[ "${NARRATION}" == "none" ]]; then
    log "Preparing silent slide timing without speech synthesis"
    run_skill_python "${SKILL_ROOT}" scripts/render_checks.py silent-timing \
      --level-dir "${LEVEL_DIR}"
  else
    log "Synthesizing narration with Azure AI Speech"
    run_skill_python "${VOICEOVER_SKILL}" scripts/generate_voiceover.py \
      --collapse-newlines \
      --content-dir "${LEVEL_DIR}/content" \
      --output-dir "${LEVEL_DIR}/audio"
  fi

  log "Assembling MP4 (${NARRATION})"
  run_skill_python "${SKILL_ROOT}" scripts/render_checks.py segments \
    --level-dir "${LEVEL_DIR}" \
    --output-name "${video_name}"
  run_skill_python "${ASSEMBLE_SKILL}" scripts/assemble_video.py \
    --manifest "${LEVEL_DIR}/output/segments.yml" \
    --output "${LEVEL_DIR}/output/${video_name}"
}

build_html_deck() {
  local name="hve-demo-${LEVEL}"
  local root="${LEVEL_DIR}/html-deck"
  local deck_dir="${root}/slides/${name}"
  log "Building the HTML slide deck"
  run_skill_python "${SKILL_ROOT}" scripts/html_deck.py \
    --level "${LEVEL}" \
    --level-dir "${LEVEL_DIR}" \
    --template "${SLIDES_SKILL_ROOT}/templates/deck" \
    --deck-dir "${deck_dir}" \
    --workspace "${WORKSPACE}"
  npm ci --prefix "${deck_dir}" --ignore-scripts --no-audit --no-fund --silent
  node "${SLIDES_SKILL_ROOT}/scripts/render-deck.mjs" \
    --deck-dir "${deck_dir}" --output "${LEVEL_DIR}/output/${name}.html"
  cp "${deck_dir}/demo-material-build.json" "${LEVEL_DIR}/output/html-deck-build.json"

  log "Checking the HTML slide deck offline"
  run_skill_python "${CAPTURE_SKILL}" "${SCRIPT_DIR}/check_html_deck.py" \
    --deck "${LEVEL_DIR}/output/${name}.html" \
    --output "${LEVEL_DIR}/output/html-deck-check.json" \
    --level-dir "${LEVEL_DIR}" --frames-dir "${LEVEL_DIR}/frames/deck"
}

write_accessible_media() {
  log "Burning captions and writing accessible media"
  bash "${FINALIZE_ACCESSIBLE_VIDEO}" \
    --level "${LEVEL}" \
    --level-dir "${LEVEL_DIR}" \
    --narration "${NARRATION}"
}

main() {
  parse_args "$@"
  validate_args
  mkdir -p "${LEVEL_DIR}/output" "${LEVEL_DIR}/frames/deck" "${LEVEL_DIR}/audio"

  local video_name="hve-demo-${LEVEL}.raw.mp4"

  if [[ "${CAPTURE}" == "live" ]]; then
    run_captures
  fi
  build_html_deck
  narrate_and_assemble "${video_name}"
  write_accessible_media

  log "Scoring machine-verifiable criteria"
  local exit_code=0
  run_skill_python "${SKILL_ROOT}" scripts/render_checks.py evaluate \
    --level "${LEVEL}" \
    --level-dir "${LEVEL_DIR}" \
    --capture "${CAPTURE}" \
    --narration "${NARRATION}" \
    --slides-skill-root "${SLIDES_SKILL_ROOT}" \
    > "${LEVEL_DIR}/output/render-result.json" || exit_code=$?
  cat "${LEVEL_DIR}/output/render-result.json"
  return "${exit_code}"
}

main "$@"
