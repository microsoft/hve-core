#!/usr/bin/env bash
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#
# finalize-accessible-video.sh
# Generate captions, burn them into a rendered demo, retain a selectable
# subtitle track, and write the transcript page.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
SKILL_ROOT="$(dirname "${SCRIPT_DIR}")"
readonly SKILL_ROOT

LEVEL=""
LEVEL_DIR=""
CHECK_PREREQUISITES="false"
TEMP_DIR=""
CAPTIONED=""
CONTROL=""
FFMPEG=""
FFPROBE=""

usage() {
  cat <<EOF
Usage: $(basename "$0") --level <L100|L200|L300|L400> --level-dir <dir>

Options:
  --level <level>      Level label from the curriculum
  --level-dir <dir>    Authored level directory containing content/ and output/
  --check-prerequisites
                       Resolve and print compatible FFmpeg executables, then exit
  -h, --help           Show this help message
EOF
  exit 0
}

err() {
  printf "ERROR: %s\n" "$1" >&2
  exit 1
}

cleanup() {
  [[ -z "${TEMP_DIR}" ]] || rm -rf "${TEMP_DIR}"
  [[ -z "${CAPTIONED}" ]] || rm -f "${CAPTIONED}"
  [[ -z "${CONTROL}" ]] || rm -f "${CONTROL}"
}

parse_args() {
  while (( $# > 0 )); do
    case "$1" in
      --level) LEVEL="$2"; shift 2 ;;
      --level-dir) LEVEL_DIR="$2"; shift 2 ;;
      --check-prerequisites) CHECK_PREREQUISITES="true"; shift ;;
      -h|--help) usage ;;
      *) err "Unknown option: $1" ;;
    esac
  done
}

ffmpeg_is_compatible() {
  local candidate="$1"
  if ! "${candidate}" -hide_banner -filters 2>&1 \
    | grep -E '(^|[[:space:]])subtitles[[:space:]]' >/dev/null; then
    return 1
  fi
  if ! "${candidate}" -hide_banner -encoders 2>&1 \
    | grep -E '(^|[[:space:]])libx264[[:space:]]' >/dev/null; then
    return 1
  fi
}

print_install_guidance() {
  case "$(uname -s)" in
    Darwin)
      printf '%s\n' \
        "Install a compatible FFmpeg after approval:" \
        "  brew install ffmpeg-full" \
        "The skill auto-discovers Homebrew's keg-only ffmpeg-full installation."
      ;;
    Linux)
      if command -v apt-get >/dev/null; then
        printf '%s\n' \
          "Install a compatible FFmpeg after approval:" \
          "  sudo apt-get update && sudo apt-get install ffmpeg"
      elif command -v dnf >/dev/null; then
        printf '%s\n' \
          "Enable RPM Fusion, then install a compatible FFmpeg after approval:" \
          "  sudo dnf install ffmpeg"
      elif command -v apk >/dev/null; then
        printf '%s\n' \
          "Install a compatible FFmpeg after approval:" \
          "  sudo apk add ffmpeg"
      elif command -v pacman >/dev/null; then
        printf '%s\n' \
          "Install a compatible FFmpeg after approval:" \
          "  sudo pacman -S ffmpeg"
      else
        printf '%s\n' \
          "Install FFmpeg with your distribution's package manager after approval."
      fi
      printf '%s\n' \
        "The selected build must include libass subtitles and libx264."
      ;;
    MINGW*|MSYS*|CYGWIN*)
      printf '%s\n' \
        "Install a compatible FFmpeg after approval, for example:" \
        "  winget install Gyan.FFmpeg" \
        "The selected build must include libass subtitles and libx264."
      ;;
    *)
      printf '%s\n' \
        "Install FFmpeg with libass subtitles and libx264 after approval."
      ;;
  esac
  printf '%s\n' \
    "Set FFMPEG_COMMAND and FFPROBE_COMMAND to override executable discovery."
}

ffprobe_is_usable() {
  local candidate="$1"
  "${candidate}" -v error -version >/dev/null 2>&1
}

resolve_probe() {
  local candidate="$1"
  local sibling
  sibling="$(dirname "${candidate}")/ffprobe"
  if [[ -n "${FFPROBE_COMMAND:-}" ]]; then
    command -v "${FFPROBE_COMMAND}" 2>/dev/null || return 1
  elif [[ -x "${sibling}" ]]; then
    printf '%s\n' "${sibling}"
  else
    command -v ffprobe 2>/dev/null || return 1
  fi
}

resolve_ffmpeg() {
  local candidate=""
  local probe=""
  local probe_override=""
  local -a candidates=()
  if [[ -n "${FFPROBE_COMMAND:-}" ]]; then
    probe_override="$(command -v "${FFPROBE_COMMAND}" 2>/dev/null || true)"
    [[ -n "${probe_override}" ]] \
      || err "FFPROBE_COMMAND does not resolve to an executable."
    ffprobe_is_usable "${probe_override}" \
      || err "FFPROBE_COMMAND is not a usable FFprobe executable."
  fi
  if [[ -n "${FFMPEG_COMMAND:-}" ]]; then
    candidate="$(command -v "${FFMPEG_COMMAND}" 2>/dev/null || true)"
    [[ -n "${candidate}" ]] \
      || err "FFMPEG_COMMAND does not resolve to an executable."
    ffmpeg_is_compatible "${candidate}" \
      || err "FFMPEG_COMMAND lacks libass subtitles or libx264."
    probe="$(resolve_probe "${candidate}" || true)"
    [[ -n "${probe}" ]] \
      || err "FFPROBE_COMMAND does not resolve to an executable."
    ffprobe_is_usable "${probe}" \
      || err "FFPROBE_COMMAND is not a usable FFprobe executable."
    FFMPEG="${candidate}"
    FFPROBE="${probe}"
    return
  fi

  candidates+=("$(command -v ffmpeg 2>/dev/null || true)")
  candidates+=(
    "/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg"
    "/usr/local/opt/ffmpeg-full/bin/ffmpeg"
  )
  for candidate in "${candidates[@]}"; do
    [[ -n "${candidate}" && -x "${candidate}" ]] || continue
    ffmpeg_is_compatible "${candidate}" || continue
    probe="$(resolve_probe "${candidate}" || true)"
    [[ -n "${probe}" ]] || continue
    ffprobe_is_usable "${probe}" || continue
    FFMPEG="${candidate}"
    FFPROBE="${probe}"
    return
  done

  print_install_guidance >&2
  err "No compatible FFmpeg and FFprobe pair was found."
}

validate_tools() {
  command -v uv >/dev/null || err "uv is required."
  resolve_ffmpeg
  export FFMPEG_COMMAND="${FFMPEG}"
  export FFPROBE_COMMAND="${FFPROBE}"
}

validate_args() {
  [[ "${LEVEL}" =~ ^L[1-4]00$ ]] || err "--level must be L100 to L400."
  [[ -d "${LEVEL_DIR}/content" ]] || err "No content/ under ${LEVEL_DIR}."
  [[ -d "${LEVEL_DIR}/output" ]] || err "No output/ under ${LEVEL_DIR}."
  LEVEL_DIR="$(cd "${LEVEL_DIR}" && pwd)"
  [[ -f "${LEVEL_DIR}/output/hve-demo-${LEVEL}.raw.mp4" ]] \
    || err "Clean raw assembly missing; reassemble hve-demo-${LEVEL}.raw.mp4 before finalizing."
}

finalize_video() {
  local video="${LEVEL_DIR}/output/hve-demo-${LEVEL}.mp4"
  local raw="${LEVEL_DIR}/output/hve-demo-${LEVEL}.raw.mp4"
  local evidence="${LEVEL_DIR}/output/open-captions.json"
  TEMP_DIR="$(mktemp -d "${LEVEL_DIR}/output/.captions.XXXXXX")"
  local captions="${TEMP_DIR}/hve-demo-${LEVEL}.vtt"
  CAPTIONED="${TEMP_DIR}/hve-demo-${LEVEL}.mp4"
  CONTROL="${TEMP_DIR}/control.mp4"
  trap cleanup EXIT

  uv run --directory "${SKILL_ROOT}" python scripts/render_checks.py captions \
    --level-dir "${LEVEL_DIR}" \
    --output "${captions}"

  if uv run --directory "${SKILL_ROOT}" python scripts/render_checks.py \
    check-open-caption-evidence \
    --video "${video}" \
    --captions "${captions}" \
    --source "${raw}" \
    --evidence "${evidence}" >/dev/null 2>&1; then
    cp "${video}" "${CAPTIONED}"
    cp "${evidence}" "${TEMP_DIR}/open-captions.json"
  else
  cp "${captions}" "${TEMP_DIR}/captions.vtt"
  "${FFMPEG}" -y -v error \
    -i "${raw}" \
    -map 0:v:0 -map '0:a?' \
    -c:v libx264 -preset medium -crf 18 \
    -c:a copy \
    -movflags +faststart \
    "${CONTROL}"

  "${FFMPEG}" -y -v error \
    -i "${raw}" \
    -i "${TEMP_DIR}/captions.vtt" \
    -vf "subtitles=filename='${TEMP_DIR}/captions.vtt'" \
    -map 0:v:0 -map '0:a?' -map 1:0 \
    -c:v libx264 -preset medium -crf 18 \
    -c:a copy -c:s mov_text \
    -metadata:s:a:0 language=eng \
    -metadata:s:s:0 language=eng \
    -disposition:s:0 0 \
    -movflags +faststart \
    "${CAPTIONED}"
  uv run --directory "${SKILL_ROOT}" python scripts/render_checks.py \
    verify-open-captions \
    --control "${CONTROL}" \
    --finalized "${CAPTIONED}" \
    --source "${raw}" \
    --level-dir "${LEVEL_DIR}" \
    --captions "${captions}" \
    --output "${TEMP_DIR}/open-captions.json"
  rm -f "${CONTROL}"
  CONTROL=""
  fi

  uv run --directory "${SKILL_ROOT}" python scripts/render_checks.py transcript \
    --level "${LEVEL}" \
    --level-dir "${LEVEL_DIR}" --output-dir "${TEMP_DIR}"
  uv run --directory "${SKILL_ROOT}" python scripts/render_checks.py publish-generation \
    --level "${LEVEL}" --stage "${TEMP_DIR}" --output-dir "${LEVEL_DIR}/output"
  CAPTIONED=""
}

main() {
  parse_args "$@"
  validate_tools
  if [[ "${CHECK_PREREQUISITES}" == "true" ]]; then
    printf 'ffmpeg=%s\nffprobe=%s\n' "${FFMPEG}" "${FFPROBE}"
    return
  fi
  validate_args
  finalize_video
}

main "$@"