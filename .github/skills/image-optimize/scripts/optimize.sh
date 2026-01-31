#!/usr/bin/env bash
#
# optimize.sh
# Optimize images for web and documentation using ImageMagick
# Features: compression, format conversion, resizing, batch processing

set -euo pipefail

# Default values
DEFAULT_QUALITY=85
DEFAULT_OUTPUT_DIR="optimized"
STRIP_METADATA=true
RECURSIVE=false

usage() {
  echo "Usage: ${0##*/} [OPTIONS] [INPUT]"
  echo ""
  echo "Optimize images for web and documentation."
  echo ""
  echo "Options:"
  echo "  --input PATH      Input image or directory (required if not positional)"
  echo "  --output PATH     Output path (default: ${DEFAULT_OUTPUT_DIR}/)"
  echo "  --quality N       JPEG/WebP quality 1-100 (default: ${DEFAULT_QUALITY})"
  echo "  --format FMT      Output format: png, jpg, webp (default: preserve)"
  echo "  --width N         Maximum width in pixels (preserves aspect ratio)"
  echo "  --height N        Maximum height in pixels (preserves aspect ratio)"
  echo "  --recursive       Process subdirectories"
  echo "  --no-strip        Keep metadata (EXIF, etc.)"
  echo "  --help, -h        Show this help message"
  echo ""
  echo "Examples:"
  echo "  ${0##*/} image.png"
  echo "  ${0##*/} --input ./images --recursive --quality 80"
  echo "  ${0##*/} --input photo.jpg --format webp --width 1200"
  exit 1
}

err() {
  printf "ERROR: %s\n" "$1" >&2
  exit 1
}

check_dependencies() {
  if ! command -v magick &>/dev/null && ! command -v convert &>/dev/null; then
    err "ImageMagick is required. Install via: brew install imagemagick (macOS) or apt install imagemagick (Linux)"
  fi
}

get_magick_cmd() {
  if command -v magick &>/dev/null; then
    echo "magick"
  else
    echo "convert"
  fi
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

optimize_image() {
  local input="$1"
  local output="$2"
  local quality="$3"
  local format="$4"
  local width="$5"
  local height="$6"
  local strip="$7"

  local magick_cmd
  magick_cmd=$(get_magick_cmd)

  local args=()
  args+=("${input}")

  # Resize if dimensions specified
  if [[ -n "${width}" ]] && [[ -n "${height}" ]]; then
    args+=("-resize" "${width}x${height}>")
  elif [[ -n "${width}" ]]; then
    args+=("-resize" "${width}x>")
  elif [[ -n "${height}" ]]; then
    args+=("-resize" "x${height}>")
  fi

  # Strip metadata
  if [[ "${strip}" == "true" ]]; then
    args+=("-strip")
  fi

  # Quality setting (for JPEG/WebP)
  args+=("-quality" "${quality}")

  # Determine output filename
  local output_file="${output}"
  if [[ -n "${format}" ]]; then
    local basename="${output%.*}"
    output_file="${basename}.${format}"
  fi

  args+=("${output_file}")

  # Run ImageMagick
  "${magick_cmd}" "${args[@]}"

  echo "${output_file}"
}

process_file() {
  local input="$1"
  local output_dir="$2"
  local quality="$3"
  local format="$4"
  local width="$5"
  local height="$6"
  local strip="$7"
  local base_input_dir="$8"

  # Determine relative path for output structure
  local rel_path=""
  if [[ -n "${base_input_dir}" ]]; then
    rel_path="${input#${base_input_dir}/}"
    rel_path="$(dirname "${rel_path}")"
    if [[ "${rel_path}" == "." ]]; then
      rel_path=""
    fi
  fi

  local filename
  filename="$(basename "${input}")"

  local output_subdir="${output_dir}"
  if [[ -n "${rel_path}" ]]; then
    output_subdir="${output_dir}/${rel_path}"
  fi

  mkdir -p "${output_subdir}"

  local output_file="${output_subdir}/${filename}"
  local original_size
  original_size=$(get_file_size "${input}")

  local result
  result=$(optimize_image "${input}" "${output_file}" "${quality}" "${format}" "${width}" "${height}" "${strip}")

  local new_size
  new_size=$(get_file_size "${result}")

  local reduction=0
  if (( original_size > 0 )); then
    reduction=$(( (original_size - new_size) * 100 / original_size ))
  fi

  printf "  %s: %s → %s (%d%% reduction)\n" \
    "${filename}" \
    "$(format_size ${original_size})" \
    "$(format_size ${new_size})" \
    "${reduction}"
}

# Parse arguments
INPUT=""
OUTPUT="${DEFAULT_OUTPUT_DIR}"
QUALITY="${DEFAULT_QUALITY}"
FORMAT=""
WIDTH=""
HEIGHT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input)
      INPUT="$2"
      shift 2
      ;;
    --output)
      OUTPUT="$2"
      shift 2
      ;;
    --quality)
      QUALITY="$2"
      shift 2
      ;;
    --format)
      FORMAT="$2"
      shift 2
      ;;
    --width)
      WIDTH="$2"
      shift 2
      ;;
    --height)
      HEIGHT="$2"
      shift 2
      ;;
    --recursive)
      RECURSIVE=true
      shift
      ;;
    --no-strip)
      STRIP_METADATA=false
      shift
      ;;
    -h|--help)
      usage
      ;;
    -*)
      err "Unknown option: $1"
      ;;
    *)
      if [[ -z "${INPUT}" ]]; then
        INPUT="$1"
      else
        err "Unexpected argument: $1"
      fi
      shift
      ;;
  esac
done

# Validate input
if [[ -z "${INPUT}" ]]; then
  usage
fi

if [[ ! -e "${INPUT}" ]]; then
  err "Input not found: ${INPUT}"
fi

# Check dependencies
check_dependencies

echo "🖼️  Optimizing images..."
echo "   Quality: ${QUALITY}"
[[ -n "${FORMAT}" ]] && echo "   Format: ${FORMAT}"
[[ -n "${WIDTH}" ]] && echo "   Max width: ${WIDTH}px"
[[ -n "${HEIGHT}" ]] && echo "   Max height: ${HEIGHT}px"
echo ""

# Process input
count=0
if [[ -d "${INPUT}" ]]; then
  # Directory processing
  find_args=("${INPUT}")
  if [[ "${RECURSIVE}" != "true" ]]; then
    find_args+=("-maxdepth" "1")
  fi
  find_args+=("-type" "f" \( "-iname" "*.png" "-o" "-iname" "*.jpg" "-o" "-iname" "*.jpeg" "-o" "-iname" "*.webp" "-o" "-iname" "*.gif" \))

  while IFS= read -r -d '' file; do
    process_file "${file}" "${OUTPUT}" "${QUALITY}" "${FORMAT}" "${WIDTH}" "${HEIGHT}" "${STRIP_METADATA}" "${INPUT}"
    ((count++))
  done < <(find "${find_args[@]}" -print0 2>/dev/null)
else
  # Single file processing
  process_file "${INPUT}" "${OUTPUT}" "${QUALITY}" "${FORMAT}" "${WIDTH}" "${HEIGHT}" "${STRIP_METADATA}" ""
  count=1
fi

echo ""
echo "✅ Optimized ${count} image(s)"
echo "   Output: $(cd "${OUTPUT}" && pwd)"
