#!/usr/bin/env bash
#
# convert.sh
# Convert video files to optimized GIF animations using FFmpeg two-pass palette optimization
# Features: HDR auto-detection with tonemapping, workspace-first file search, time range selection

set -euo pipefail

# Default values
DEFAULT_FPS=10
DEFAULT_WIDTH=1280
DEFAULT_DITHER="sierra2_4a"
DEFAULT_TONEMAP="hable"
DEFAULT_LOOP=0

usage() {
  echo "Usage: ${0##*/} [OPTIONS] [INPUT_FILE]"
  echo ""
  echo "Convert video files to optimized GIF animations."
  echo ""
  echo "Options:"
  echo "  --input FILE      Input video file (required if not positional)"
  echo "  --output FILE     Output GIF file (defaults to input with .gif extension)"
  echo "  --fps N           Frame rate (default: ${DEFAULT_FPS})"
  echo "  --width N         Output width in pixels (default: ${DEFAULT_WIDTH})"
  echo "  --dither ALG      Dithering algorithm (default: ${DEFAULT_DITHER})"
  echo "                    Options: sierra2_4a, floyd_steinberg, bayer, none"
  echo "  --tonemap ALG     HDR tonemapping algorithm (default: ${DEFAULT_TONEMAP})"
  echo "                    Options: hable, reinhard, mobius, bt2390"
  echo "  --start N         Start time in seconds (default: 0)"
  echo "  --duration N      Duration to convert in seconds (default: full video)"
  echo "  --loop N          GIF loop count, 0=infinite (default: ${DEFAULT_LOOP})"
  echo "  --skip-palette    Use single-pass mode (faster, lower quality)"
  echo "  --help, -h        Show this help message"
  echo ""
  echo "Examples:"
  echo "  ${0##*/} video.mp4"
  echo "  ${0##*/} --input video.mp4 --output demo.gif --fps 15"
  echo "  ${0##*/} --input video.mp4 --start 5 --duration 10"
  exit 1
}

err() {
  printf "ERROR: %s\n" "$1" >&2
  exit 1
}

get_file_size() {
  local file="$1"
  if [[ "$(uname)" == "Darwin" ]]; then
    stat -f%z "${file}"
  else
    stat -c%s "${file}"
  fi
}

format_size() {
  local bytes="$1"
  if (( bytes >= 1048576 )); then
    printf "%.2f MB" "$(echo "scale=2; ${bytes} / 1048576" | bc)"
  elif (( bytes >= 1024 )); then
    printf "%.2f KB" "$(echo "scale=2; ${bytes} / 1024" | bc)"
  else
    printf "%d bytes" "${bytes}"
  fi
}

# Find file using prefix matching to handle Unicode whitespace mismatches
# macOS screen recordings use non-breaking spaces (U+00A0) that look like ASCII spaces
find_by_prefix() {
  local dir="$1"
  local basename="$2"

  [[ -d "${dir}" ]] || return 1

  local base_no_ext="${basename%.*}"
  local ext="${basename##*.}"
  local prefix="${base_no_ext:0:15}"

  local found_file
  while IFS= read -r -d '' found_file; do
    echo "${found_file}"
    return 0
  done < <(find "${dir}" -maxdepth 1 -type f -name "${prefix}*.${ext}" -print0 2>/dev/null)

  return 1
}

# Search for file in workspace and common directories
find_video_file() {
  local filename="$1"

  # Direct path lookup
  if [[ -f "${filename}" ]]; then
    echo "${filename}"
    return 0
  fi

  # Extract directory and basename for prefix matching
  local dir_part base_part
  if [[ "${filename}" == */* ]]; then
    dir_part="${filename%/*}"
    base_part="${filename##*/}"
  else
    dir_part=""
    base_part="${filename}"
  fi

  # For absolute paths, try prefix matching in the specified directory
  if [[ "${filename}" == /* ]]; then
    if find_by_prefix "${dir_part}" "${base_part}"; then
      return 0
    fi
    return 1
  fi

  # Build search locations for relative paths
  local search_dirs=("." "${PWD}")

  local git_root
  if git_root=$(git rev-parse --show-toplevel 2>/dev/null); then
    search_dirs+=("${git_root}")
  fi

  if [[ "$(uname)" == "Darwin" ]]; then
    search_dirs+=("${HOME}/Movies" "${HOME}/Downloads" "${HOME}/Desktop")
  else
    search_dirs+=("${HOME}/Videos" "${HOME}/Downloads" "${HOME}/Desktop")
  fi

  for dir in "${search_dirs[@]}"; do
    # Try exact match first
    if [[ -f "${dir}/${filename}" ]]; then
      echo "${dir}/${filename}"
      return 0
    fi
    # Fall back to prefix matching for Unicode whitespace issues
    if find_by_prefix "${dir}" "${base_part}"; then
      return 0
    fi
  done

  return 1
}

# Detect if video is HDR using ffprobe
detect_hdr() {
  local file="$1"

  if ! command -v ffprobe &>/dev/null; then
    echo "false"
    return
  fi

  local color_info
  color_info=$(ffprobe -v error -select_streams v:0 \
    -show_entries stream=color_primaries,color_transfer \
    -of csv=p=0 "${file}" 2>/dev/null || echo "")

  # Check for HDR indicators: bt2020 primaries or smpte2084 transfer
  if [[ "${color_info}" == *"bt2020"* ]] || [[ "${color_info}" == *"smpte2084"* ]]; then
    echo "true"
  else
    echo "false"
  fi
}

main() {
  local input_file=""
  local output_file=""
  local fps="${DEFAULT_FPS}"
  local width="${DEFAULT_WIDTH}"
  local dither="${DEFAULT_DITHER}"
  local tonemap="${DEFAULT_TONEMAP}"
  local loop="${DEFAULT_LOOP}"
  local start_time=""
  local duration=""
  local skip_palette=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --input)
        if [[ -z "${2:-}" || "$2" == --* ]]; then
          err "--input requires a file path"
        fi
        input_file="$2"
        shift 2
        ;;
      --output)
        if [[ -z "${2:-}" || "$2" == --* ]]; then
          err "--output requires a file path"
        fi
        output_file="$2"
        shift 2
        ;;
      --fps)
        if [[ -z "${2:-}" || "$2" == --* ]]; then
          err "--fps requires a number"
        fi
        fps="$2"
        shift 2
        ;;
      --width)
        if [[ -z "${2:-}" || "$2" == --* ]]; then
          err "--width requires a number"
        fi
        width="$2"
        shift 2
        ;;
      --dither)
        if [[ -z "${2:-}" || "$2" == --* ]]; then
          err "--dither requires an algorithm name"
        fi
        dither="$2"
        shift 2
        ;;
      --tonemap)
        if [[ -z "${2:-}" || "$2" == --* ]]; then
          err "--tonemap requires an algorithm name"
        fi
        tonemap="$2"
        shift 2
        ;;
      --start)
        if [[ -z "${2:-}" || "$2" == --* ]]; then
          err "--start requires a number"
        fi
        start_time="$2"
        shift 2
        ;;
      --duration)
        if [[ -z "${2:-}" || "$2" == --* ]]; then
          err "--duration requires a number"
        fi
        duration="$2"
        shift 2
        ;;
      --loop)
        if [[ -z "${2:-}" || "$2" == --* ]]; then
          err "--loop requires a number"
        fi
        loop="$2"
        shift 2
        ;;
      --skip-palette)
        skip_palette=true
        shift
        ;;
      --help|-h)
        usage
        ;;
      -*)
        err "Unknown option: $1"
        ;;
      *)
        if [[ -z "${input_file}" ]]; then
          input_file="$1"
        else
          err "Unexpected argument: $1"
        fi
        shift
        ;;
    esac
  done

  # Validate input file
  if [[ -z "${input_file}" ]]; then
    err "Input file is required. Use --input FILE or provide as positional argument."
  fi

  # Search for file if not found at given path
  if [[ ! -f "${input_file}" ]]; then
    local found_file
    if found_file=$(find_video_file "${input_file}") && [[ -n "${found_file}" ]]; then
      echo "Found: ${found_file}"
      input_file="${found_file}"
    else
      err "Input file not found: ${input_file}
Searched: current directory, workspace root, ~/Movies (or ~/Videos), ~/Downloads, ~/Desktop"
    fi
  fi

  # Set default output file if not specified
  if [[ -z "${output_file}" ]]; then
    output_file="${input_file%.*}.gif"
  fi

  # Validate dithering algorithm
  case "${dither}" in
    sierra2_4a|floyd_steinberg|bayer|none) ;;
    *)
      err "Invalid dithering algorithm: ${dither}. Options: sierra2_4a, floyd_steinberg, bayer, none"
      ;;
  esac

  # Validate tonemapping algorithm
  case "${tonemap}" in
    hable|reinhard|mobius|bt2390) ;;
    *)
      err "Invalid tonemapping algorithm: ${tonemap}. Options: hable, reinhard, mobius, bt2390"
      ;;
  esac

  # Check for FFmpeg
  if ! command -v ffmpeg &>/dev/null; then
    echo "ERROR: FFmpeg is required but not installed." >&2
    echo "" >&2
    echo "Install FFmpeg:" >&2
    echo "  macOS:  brew install ffmpeg" >&2
    echo "  Ubuntu: sudo apt install ffmpeg" >&2
    echo "  Windows: choco install ffmpeg" >&2
    exit 1
  fi

  # Detect HDR content
  local is_hdr
  is_hdr=$(detect_hdr "${input_file}")

  # Build time range arguments
  local time_args=()
  if [[ -n "${start_time}" ]]; then
    time_args+=(-ss "${start_time}")
  fi
  if [[ -n "${duration}" ]]; then
    time_args+=(-t "${duration}")
  fi

  echo "Converting: ${input_file}"
  echo "Output:     ${output_file}"
  echo "Settings:   ${fps} FPS, ${width}px width, ${dither} dithering, loop=${loop}"
  if [[ -n "${start_time}" ]] || [[ -n "${duration}" ]]; then
    echo "Time range: start=${start_time:-0}s, duration=${duration:-full}"
  fi
  if [[ "${is_hdr}" == "true" ]]; then
    echo "HDR:        Detected, applying ${tonemap} tonemapping"
  fi

  # Build video filter chain
  local base_filter="fps=${fps},scale=${width}:-1:flags=lanczos"

  # Add HDR tonemapping if detected
  # Convert HDR to SDR using selected tonemapping algorithm, then explicitly convert to sRGB for accurate GIF colors
  if [[ "${is_hdr}" == "true" ]]; then
    base_filter="zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=${tonemap}:desat=0,zscale=t=iec61966-2-1:m=bt709:r=full,format=rgb24,${base_filter}"
  fi

  if [[ "${skip_palette}" == true ]]; then
    echo "Mode:       Single-pass (faster, lower quality)"
    echo ""

    ffmpeg "${time_args[@]}" -i "${input_file}" \
      -vf "${base_filter}" \
      -loop "${loop}" -y "${output_file}"
  else
    echo "Mode:       Two-pass palette optimization"
    echo ""

    local palette_file="/tmp/palette_$$.png"

    # Pass 1: Generate palette
    echo "Pass 1: Generating optimized palette..."
    ffmpeg "${time_args[@]}" -i "${input_file}" \
      -vf "${base_filter},palettegen=stats_mode=diff" \
      -y "${palette_file}"

    # Pass 2: Create GIF
    echo "Pass 2: Creating GIF with palette..."
    ffmpeg "${time_args[@]}" -i "${input_file}" -i "${palette_file}" \
      -filter_complex "${base_filter}[x];[x][1:v]paletteuse=dither=${dither}:diff_mode=rectangle" \
      -loop "${loop}" -y "${output_file}"

    # Cleanup palette file
    rm -f "${palette_file}"
  fi

  if [[ -f "${output_file}" ]]; then
    local file_size
    file_size=$(get_file_size "${output_file}")
    echo ""
    echo "Conversion complete: ${output_file} ($(format_size "${file_size}"))"
  else
    err "Conversion failed. Output file was not created."
  fi
}

main "$@"
