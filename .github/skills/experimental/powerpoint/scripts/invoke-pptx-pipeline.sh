#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#
# invoke-pptx-pipeline.sh
# Orchestrates PowerPoint slide deck operations via Python scripts.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(dirname "${SCRIPT_DIR}")"
VENV_DIR="${SKILL_ROOT}/.venv"

# Defaults
RESOLUTION=150
VALIDATION_MODEL="claude-haiku-4.5"
SKIP_VENV_SETUP=false

err() {
  printf "ERROR: %s\n" "$1" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: $(basename "$0") --action <Action> [OPTIONS]

Actions:
  build       Build a PowerPoint deck from YAML content
  extract     Extract content from an existing PPTX to YAML
  validate    Validate a PPTX deck (property checks + optional vision)
  export      Export PPTX slides to JPG images

Options:
  --action <action>                 Required. build|extract|validate|export
  --content-dir <path>              Content directory (required for build)
  --style <path>                    Style YAML path (required for build)
  --output <path>                   Output PPTX path (required for build)
  --input <path>                    Input PPTX path (required for extract/validate/export)
  --output-dir <path>               Output directory (required for extract)
  --template <path>                 Template PPTX for themed builds (optional, build)
  --source <path>                   Source PPTX for partial rebuilds (optional, build)
  --slides <list>                   Comma-separated slide numbers (optional)
  --image-output-dir <path>         Image output directory (required for export)
  --resolution <dpi>                DPI for exported images (default: 150)
  --validation-prompt <text>        Vision validation prompt text (optional)
  --validation-prompt-file <path>   Vision validation prompt file (optional)
  --validation-model <model>        Vision model name (default: claude-haiku-4.5)
  --skip-venv-setup                 Skip virtual environment setup
  -h, --help                        Show this help message
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
  echo "${VENV_DIR}/bin/python"
}

assert_build_parameters() {
  [[ -z "${CONTENT_DIR:-}" ]] && err "Build action requires --content-dir."
  [[ -z "${STYLE_PATH:-}" ]] && err "Build action requires --style."
  [[ -z "${OUTPUT_PATH:-}" ]] && err "Build action requires --output."
  if [[ -n "${SLIDES:-}" && -z "${SOURCE_PATH:-}" ]]; then
    err "--slides requires --source for partial rebuilds."
  fi
}

assert_extract_parameters() {
  [[ -z "${INPUT_PATH:-}" ]] && err "Extract action requires --input."
  [[ -z "${OUTPUT_DIR:-}" ]] && err "Extract action requires --output-dir."
}

assert_validate_parameters() {
  [[ -z "${INPUT_PATH:-}" ]] && err "Validate action requires --input."
}

assert_export_parameters() {
  [[ -z "${INPUT_PATH:-}" ]] && err "Export action requires --input."
  [[ -z "${IMAGE_OUTPUT_DIR:-}" ]] && err "Export action requires --image-output-dir."
}

invoke_build_deck() {
  local python
  python="$(get_venv_python_path)"
  local script="${SCRIPT_DIR}/build_deck.py"

  local -a args=(
    "${script}"
    "--content-dir" "${CONTENT_DIR}"
    "--style" "${STYLE_PATH}"
    "--output" "${OUTPUT_PATH}"
  )

  [[ -n "${TEMPLATE_PATH:-}" ]] && args+=("--template" "${TEMPLATE_PATH}")
  [[ -n "${SOURCE_PATH:-}" ]] && args+=("--source" "${SOURCE_PATH}")
  [[ -n "${SLIDES:-}" ]] && args+=("--slides" "${SLIDES}")

  echo "Building deck from ${CONTENT_DIR} -> ${OUTPUT_PATH}"
  "${python}" "${args[@]}"
}

invoke_extract_content() {
  local python
  python="$(get_venv_python_path)"
  local script="${SCRIPT_DIR}/extract_content.py"

  local -a args=(
    "${script}"
    "--input" "${INPUT_PATH}"
    "--output-dir" "${OUTPUT_DIR}"
  )

  [[ -n "${SLIDES:-}" ]] && args+=("--slides" "${SLIDES}")

  echo "Extracting content from ${INPUT_PATH} -> ${OUTPUT_DIR}"
  "${python}" "${args[@]}"
}

invoke_export_slides() {
  local python
  python="$(get_venv_python_path)"
  local export_script="${SCRIPT_DIR}/export_slides.py"

  if ! command -v libreoffice &>/dev/null && ! command -v soffice &>/dev/null; then
    err "LibreOffice is required for PPTX-to-PDF export but was not found on PATH. Install with: brew install --cask libreoffice"
  fi

  mkdir -p "${IMAGE_OUTPUT_DIR}"

  # Clear stale slide images from prior runs
  local stale_count
  stale_count="$(find "${IMAGE_OUTPUT_DIR}" -maxdepth 1 -name 'slide-*.jpg' 2>/dev/null | wc -l | tr -d ' ')"
  if (( stale_count > 0 )); then
    find "${IMAGE_OUTPUT_DIR}" -maxdepth 1 -name 'slide-*.jpg' -delete
    echo "Cleared ${stale_count} stale slide image(s) from ${IMAGE_OUTPUT_DIR}"
  fi

  local pdf_output="${IMAGE_OUTPUT_DIR}/slides.pdf"

  local -a args=(
    "${export_script}"
    "--input" "${INPUT_PATH}"
    "--output" "${pdf_output}"
  )

  [[ -n "${SLIDES:-}" ]] && args+=("--slides" "${SLIDES}")

  echo "Exporting slides from ${INPUT_PATH} to PDF"
  "${python}" "${args[@]}"

  # Convert PDF to JPG images
  convert_to_slide_images "${pdf_output}" "${IMAGE_OUTPUT_DIR}" "${RESOLUTION}" "${SLIDES:-}"

  # Clean up intermediate PDF
  if [[ -f "${pdf_output}" ]]; then
    rm -f "${pdf_output}"
    echo "Cleaned up intermediate PDF."
  fi
}

convert_to_slide_images() {
  local pdf_path="$1"
  local output_dir="$2"
  local dpi="$3"
  local slide_numbers="${4:-}"

  if command -v pdftoppm &>/dev/null; then
    echo "Converting PDF to JPG via pdftoppm (${dpi} DPI)"
    pdftoppm -jpeg -r "${dpi}" "${pdf_path}" "${output_dir}/slide"

    # Rename to zero-padded 3-digit format and optionally remap slide numbers
    if [[ -n "${slide_numbers}" ]]; then
      IFS=',' read -ra target_nums <<< "${slide_numbers}"
      local idx=0
      for file in $(find "${output_dir}" -maxdepth 1 -name 'slide-*.jpg' | sort); do
        if (( idx < ${#target_nums[@]} )); then
          local new_name
          new_name=$(printf "slide-%03d.jpg" "${target_nums[idx]}")
          local base_name
          base_name="$(basename "${file}")"
          if [[ "${base_name}" != "${new_name}" ]]; then
            mv "${file}" "${output_dir}/${new_name}"
          fi
          (( idx++ )) || true
        fi
      done
    else
      for file in $(find "${output_dir}" -maxdepth 1 -name 'slide-*.jpg' | sort); do
        local base_name
        base_name="$(basename "${file}")"
        if [[ "${base_name}" =~ ^slide-([0-9]+)\.jpg$ ]]; then
          local num="${BASH_REMATCH[1]}"
          local new_name
          new_name=$(printf "slide-%03d.jpg" "$((10#${num}))")
          if [[ "${base_name}" != "${new_name}" ]]; then
            mv "${file}" "${output_dir}/${new_name}"
          fi
        fi
      done
    fi
  else
    echo "pdftoppm not found, falling back to PyMuPDF"
    local python
    python="$(get_venv_python_path)"
    local render_script="${SCRIPT_DIR}/render_pdf_images.py"

    local -a render_args=(
      "${render_script}"
      "--input" "${pdf_path}"
      "--output-dir" "${output_dir}"
      "--dpi" "${dpi}"
    )
    [[ -n "${slide_numbers}" ]] && render_args+=("--slide-numbers" "${slide_numbers}")

    "${python}" "${render_args[@]}"
  fi

  local image_count
  image_count="$(find "${output_dir}" -maxdepth 1 -name 'slide-*.jpg' | wc -l | tr -d ' ')"
  echo "Exported ${image_count} slide image(s) to ${output_dir}"
}

invoke_validate_deck() {
  local python
  python="$(get_venv_python_path)"
  local has_vision_prompt=false
  [[ -n "${VALIDATION_PROMPT:-}" || -n "${VALIDATION_PROMPT_FILE:-}" ]] && has_vision_prompt=true

  local total_steps=2
  ${has_vision_prompt} && total_steps=3

  # Default image output directory
  if [[ -z "${IMAGE_OUTPUT_DIR:-}" ]]; then
    IMAGE_OUTPUT_DIR="$(dirname "${INPUT_PATH}")/validation"
  fi

  # Step 1: Export slides to images
  echo "Step 1/${total_steps}: Exporting slides to images..."
  invoke_export_slides

  # Step 2: Run PPTX property checks
  echo "Step 2/${total_steps}: Running PPTX property checks..."
  local pptx_script="${SCRIPT_DIR}/validate_deck.py"
  local -a pptx_args=(
    "${pptx_script}"
    "--input" "${INPUT_PATH}"
  )
  [[ -n "${CONTENT_DIR:-}" ]] && pptx_args+=("--content-dir" "${CONTENT_DIR}")
  [[ -n "${SLIDES:-}" ]] && pptx_args+=("--slides" "${SLIDES}")

  local deck_output="${IMAGE_OUTPUT_DIR}/deck-validation-results.json"
  pptx_args+=("--output" "${deck_output}")
  local deck_report="${IMAGE_OUTPUT_DIR}/deck-validation-report.md"
  pptx_args+=("--report" "${deck_report}")
  pptx_args+=("--per-slide-dir" "${IMAGE_OUTPUT_DIR}")

  local exit_code=0
  "${python}" "${pptx_args[@]}" || exit_code=$?
  if (( exit_code == 2 )); then
    err "validate_deck.py encountered an error (exit code ${exit_code})."
  fi
  if (( exit_code == 1 )); then
    echo "PPTX property checks found warnings — see ${deck_report}"
  fi

  # Step 3: Vision validation (when prompt provided)
  if ${has_vision_prompt}; then
    echo "Step 3/${total_steps}: Running Copilot SDK vision validation..."
    local vision_script="${SCRIPT_DIR}/validate_slides.py"
    local -a vision_args=(
      "${vision_script}"
      "--image-dir" "${IMAGE_OUTPUT_DIR}"
      "--model" "${VALIDATION_MODEL}"
    )
    [[ -n "${VALIDATION_PROMPT:-}" ]] && vision_args+=("--prompt" "${VALIDATION_PROMPT}")
    [[ -n "${VALIDATION_PROMPT_FILE:-}" ]] && vision_args+=("--prompt-file" "${VALIDATION_PROMPT_FILE}")

    local vision_output="${IMAGE_OUTPUT_DIR}/validation-results.json"
    vision_args+=("--output" "${vision_output}")
    [[ -n "${SLIDES:-}" ]] && vision_args+=("--slides" "${SLIDES}")

    "${python}" "${vision_args[@]}"
    echo "Vision validation results: ${vision_output}"
  fi
}

parse_args() {
  while (( $# > 0 )); do
    case "$1" in
      --action) ACTION="$2"; shift 2 ;;
      --content-dir) CONTENT_DIR="$2"; shift 2 ;;
      --style) STYLE_PATH="$2"; shift 2 ;;
      --output) OUTPUT_PATH="$2"; shift 2 ;;
      --input) INPUT_PATH="$2"; shift 2 ;;
      --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
      --template) TEMPLATE_PATH="$2"; shift 2 ;;
      --source) SOURCE_PATH="$2"; shift 2 ;;
      --slides) SLIDES="$2"; shift 2 ;;
      --image-output-dir) IMAGE_OUTPUT_DIR="$2"; shift 2 ;;
      --resolution) RESOLUTION="$2"; shift 2 ;;
      --validation-prompt) VALIDATION_PROMPT="$2"; shift 2 ;;
      --validation-prompt-file) VALIDATION_PROMPT_FILE="$2"; shift 2 ;;
      --validation-model) VALIDATION_MODEL="$2"; shift 2 ;;
      --skip-venv-setup) SKIP_VENV_SETUP=true; shift ;;
      -h|--help) usage ;;
      *) err "Unknown option: $1" ;;
    esac
  done
}

main() {
  parse_args "$@"

  [[ -z "${ACTION:-}" ]] && err "Action is required. Use --action <build|extract|validate|export>."

  if [[ "${SKIP_VENV_SETUP}" == "false" ]]; then
    test_uv_availability
    initialize_python_environment
  fi

  case "${ACTION}" in
    build)
      assert_build_parameters
      invoke_build_deck
      ;;
    extract)
      assert_extract_parameters
      invoke_extract_content
      ;;
    validate)
      assert_validate_parameters
      invoke_validate_deck
      ;;
    export)
      assert_export_parameters
      invoke_export_slides
      ;;
    *) err "Unknown action: ${ACTION}. Use build|extract|validate|export." ;;
  esac
}

main "$@"
