#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

# read-diff.sh
# Reads diff content from a PR reference XML with chunking and file filtering.
# Supports reading by line range, chunk number, or specific file path.

set -euo pipefail

show_usage() {
  echo "Usage: ${0##*/} [OPTIONS]"
  echo ""
  echo "Read diff content from pr-reference.xml with chunking support."
  echo ""
  echo "Options:"
  echo "  --input, -i      Path to pr-reference.xml (default: .copilot-tracking/pr/pr-reference.xml)"
  echo "  --chunk, -c      Chunk number to read (1-based, default chunk size: 500 lines)"
  echo "  --chunk-size, -s Lines per chunk (default: 500)"
  echo "  --lines, -l      Line range to read (format: START,END or START-END)"
  echo "  --file, -f       Extract diff for a specific file path"
  echo "  --summary        Show diff summary only (file list with stats)"
  echo "  --info           Show chunk information without content"
  echo "  --help, -h       Show this help message"
  echo ""
  echo "Examples:"
  echo "  ${0##*/} --chunk 1                     # Read first 500 lines of diff"
  echo "  ${0##*/} --chunk 2 --chunk-size 300    # Read lines 301-600"
  echo "  ${0##*/} --lines 100,500               # Read lines 100-500"
  echo "  ${0##*/} --file src/main.ts            # Extract diff for specific file"
  echo "  ${0##*/} --info                        # Show chunk breakdown"
  exit 1
}

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
INPUT_FILE="${REPO_ROOT}/.copilot-tracking/pr/pr-reference.xml"
CHUNK_NUM=""
CHUNK_SIZE=500
LINE_RANGE=""
FILE_PATH=""
SHOW_SUMMARY=false
SHOW_INFO=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input|-i)
      INPUT_FILE="$2"
      shift 2
      ;;
    --chunk|-c)
      CHUNK_NUM="$2"
      shift 2
      ;;
    --chunk-size|-s)
      CHUNK_SIZE="$2"
      shift 2
      ;;
    --lines|-l)
      LINE_RANGE="$2"
      shift 2
      ;;
    --file|-f)
      FILE_PATH="$2"
      shift 2
      ;;
    --summary)
      SHOW_SUMMARY=true
      shift
      ;;
    --info)
      SHOW_INFO=true
      shift
      ;;
    --help|-h)
      show_usage
      ;;
    *)
      echo "Unknown option: $1" >&2
      show_usage
      ;;
  esac
done

if [[ ! -f "${INPUT_FILE}" ]]; then
  echo "Error: PR reference file not found: ${INPUT_FILE}" >&2
  echo "Run generate.sh first to create the PR reference." >&2
  exit 1
fi

# Get total line count
TOTAL_LINES=$(wc -l < "${INPUT_FILE}" | awk '{print $1}')
TOTAL_CHUNKS=$(( (TOTAL_LINES + CHUNK_SIZE - 1) / CHUNK_SIZE ))

# Show info mode
if [[ "${SHOW_INFO}" == "true" ]]; then
  echo "File: ${INPUT_FILE}"
  echo "Total lines: ${TOTAL_LINES}"
  echo "Chunk size: ${CHUNK_SIZE}"
  echo "Total chunks: ${TOTAL_CHUNKS}"
  echo ""
  echo "Chunk breakdown:"
  for ((i=1; i<=TOTAL_CHUNKS; i++)); do
    start=$(( (i - 1) * CHUNK_SIZE + 1 ))
    end=$(( i * CHUNK_SIZE ))
    if [[ $end -gt $TOTAL_LINES ]]; then
      end=$TOTAL_LINES
    fi
    echo "  Chunk ${i}: lines ${start}-${end}"
  done
  exit 0
fi

# Show summary mode
if [[ "${SHOW_SUMMARY}" == "true" ]]; then
  echo "Changed files:"
  grep -E '^diff --git' "${INPUT_FILE}" | sed 's|diff --git a/||;s| b/.*||' | sort -u | while read -r file; do
    # Count lines changed for this file
    added=$(grep -A 1000 "diff --git a/${file} b/" "${INPUT_FILE}" | grep -m 1 -B 1000 "^diff --git" | grep -c "^+" 2>/dev/null || echo "0")
    removed=$(grep -A 1000 "diff --git a/${file} b/" "${INPUT_FILE}" | grep -m 1 -B 1000 "^diff --git" | grep -c "^-" 2>/dev/null || echo "0")
    echo "  ${file} (+${added}/-${removed})"
  done
  exit 0
fi

# Extract diff for specific file
if [[ -n "${FILE_PATH}" ]]; then
  # Find the diff block for this file
  awk -v file="${FILE_PATH}" '
    /^diff --git/ {
      if (printing) { printing = 0 }
      if ($0 ~ "a/" file " b/") { printing = 1 }
    }
    printing { print }
  ' "${INPUT_FILE}"
  exit 0
fi

# Read by chunk number
if [[ -n "${CHUNK_NUM}" ]]; then
  if [[ ! "${CHUNK_NUM}" =~ ^[0-9]+$ ]] || [[ "${CHUNK_NUM}" -lt 1 ]]; then
    echo "Error: Invalid chunk number: ${CHUNK_NUM}" >&2
    exit 1
  fi

  start=$(( (CHUNK_NUM - 1) * CHUNK_SIZE + 1 ))
  end=$(( CHUNK_NUM * CHUNK_SIZE ))

  if [[ $start -gt $TOTAL_LINES ]]; then
    echo "Error: Chunk ${CHUNK_NUM} exceeds file (only ${TOTAL_CHUNKS} chunks available)" >&2
    exit 1
  fi

  if [[ $end -gt $TOTAL_LINES ]]; then
    end=$TOTAL_LINES
  fi

  echo "# Chunk ${CHUNK_NUM}/${TOTAL_CHUNKS} (lines ${start}-${end} of ${TOTAL_LINES})"
  echo ""
  sed -n "${start},${end}p" "${INPUT_FILE}"
  exit 0
fi

# Read by line range
if [[ -n "${LINE_RANGE}" ]]; then
  # Support both comma and dash separators
  LINE_RANGE="${LINE_RANGE//,/-}"
  if [[ ! "${LINE_RANGE}" =~ ^[0-9]+-[0-9]+$ ]]; then
    echo "Error: Invalid line range format. Use START,END or START-END" >&2
    exit 1
  fi

  start="${LINE_RANGE%%-*}"
  end="${LINE_RANGE##*-}"

  if [[ $start -gt $TOTAL_LINES ]]; then
    echo "Error: Start line ${start} exceeds file length (${TOTAL_LINES} lines)" >&2
    exit 1
  fi

  if [[ $end -gt $TOTAL_LINES ]]; then
    end=$TOTAL_LINES
  fi

  echo "# Lines ${start}-${end} of ${TOTAL_LINES}"
  echo ""
  sed -n "${start},${end}p" "${INPUT_FILE}"
  exit 0
fi

# Default: show chunk info and first chunk preview
echo "File: ${INPUT_FILE}"
echo "Total lines: ${TOTAL_LINES}"
echo "Total chunks: ${TOTAL_CHUNKS} (at ${CHUNK_SIZE} lines/chunk)"
echo ""
echo "Use --chunk N to read a specific chunk, --lines START,END for a range,"
echo "or --file PATH to extract a specific file's diff."
