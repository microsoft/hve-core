#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

# list-changed-files.sh
# Extracts and lists all changed files from a PR reference XML.
# Outputs one file path per line, sorted alphabetically.

set -euo pipefail

show_usage() {
  echo "Usage: ${0##*/} [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --input, -i         Path to pr-reference.xml (default: .copilot-tracking/pr/pr-reference.xml)"
  echo "  --type, -t          Filter by change type: added, deleted, modified, renamed, or all (default: all)"
  echo "                      Supports comma-separated values (e.g., added,modified,renamed)"
  echo "  --exclude-type      Exclude specific change types (comma-separated, e.g., deleted,renamed)"
  echo "  --format, -f        Output format: plain, json, or markdown (default: plain)"
  echo "  --help, -h          Show this help message"
  exit 1
}

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
INPUT_FILE="${REPO_ROOT}/.copilot-tracking/pr/pr-reference.xml"
FILTER_TYPE="all"
EXCLUDE_TYPE=""
OUTPUT_FORMAT="plain"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input|-i)
      if [[ -z "${2:-}" || "$2" == --* ]]; then
        echo "Error: --input requires an argument" >&2
        show_usage
      fi
      INPUT_FILE="$2"
      shift 2
      ;;
    --type|-t)
      if [[ -z "${2:-}" || "$2" == --* ]]; then
        echo "Error: --type requires an argument" >&2
        show_usage
      fi
      FILTER_TYPE="$2"
      shift 2
      ;;
    --exclude-type)
      if [[ -z "${2:-}" || "$2" == --* ]]; then
        echo "Error: --exclude-type requires an argument" >&2
        show_usage
      fi
      EXCLUDE_TYPE="$2"
      shift 2
      ;;
    --format|-f)
      if [[ -z "${2:-}" || "$2" == --* ]]; then
        echo "Error: --format requires an argument" >&2
        show_usage
      fi
      OUTPUT_FORMAT="$2"
      shift 2
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

# Validate mutual exclusion
if [[ "${FILTER_TYPE}" != "all" && -n "${EXCLUDE_TYPE}" ]]; then
  echo "Error: --type and --exclude-type are mutually exclusive when --type is not 'all'" >&2
  exit 1
fi

if [[ ! -f "${INPUT_FILE}" ]]; then
  echo "Error: PR reference file not found: ${INPUT_FILE}" >&2
  echo "Run generate.sh first to create the PR reference." >&2
  exit 1
fi

# Extract file information from diff headers
# Format: diff --git a/path/to/file b/path/to/file
# Check if a change type matches the filter criteria
matches_filter() {
  local change_type="$1"
  local filter="$2"
  local exclude="$3"

  # Exclusion mode: exclude specified types, keep everything else
  if [[ -n "${exclude}" ]]; then
    IFS=',' read -ra excluded_types <<< "${exclude}"
    for et in "${excluded_types[@]}"; do
      if [[ "${et}" == "${change_type}" ]]; then
        return 1
      fi
    done
    return 0
  fi

  # Inclusion mode: match any listed type
  if [[ "${filter}" == "all" ]]; then
    return 0
  fi

  IFS=',' read -ra filter_types <<< "${filter}"
  for ft in "${filter_types[@]}"; do
    if [[ "${ft}" == "${change_type}" ]]; then
      return 0
    fi
  done
  return 1
}

extract_files() {
  local filter="$1"
  local exclude="$2"
  local results=()

  while IFS= read -r line; do
    # Extract file path from diff header
    if [[ "$line" =~ ^diff\ --git\ a/(.+)\ b/(.+)$ ]]; then
      local old_path="${BASH_REMATCH[1]}"
      local new_path="${BASH_REMATCH[2]}"
      local change_type="modified"

      # Read next lines to determine change type
      read -r next_line || true
      if [[ "$next_line" =~ ^new\ file ]]; then
        change_type="added"
      elif [[ "$next_line" =~ ^deleted\ file ]]; then
        change_type="deleted"
      elif [[ "$next_line" =~ ^rename\ from || "$old_path" != "$new_path" ]]; then
        change_type="renamed"
      fi

      # Apply filter
      if matches_filter "${change_type}" "${filter}" "${exclude}"; then
        if [[ "$change_type" == "renamed" ]]; then
          results+=("${old_path} -> ${new_path}|${change_type}")
        else
          results+=("${new_path}|${change_type}")
        fi
      fi
    fi
  done < <(grep -E '^(diff --git|new file|deleted file|rename from)' "${INPUT_FILE}" 2>/dev/null || true)

  printf '%s\n' "${results[@]}" | sort -t'|' -k1
}

format_output() {
  local format="$1"

  case "$format" in
    plain)
      cut -d'|' -f1
      ;;
    json)
      echo "["
      local first=true
      while IFS='|' read -r path type; do
        if [[ -n "$path" ]]; then
          if [[ "$first" == "true" ]]; then
            first=false
          else
            echo ","
          fi
          printf '  {"path": "%s", "type": "%s"}' "$path" "$type"
        fi
      done
      echo ""
      echo "]"
      ;;
    markdown)
      echo "| File | Change Type |"
      echo "|------|-------------|"
      while IFS='|' read -r path type; do
        if [[ -n "$path" ]]; then
          echo "| \`${path}\` | ${type} |"
        fi
      done
      ;;
    *)
      echo "Error: Unknown format: $format" >&2
      exit 1
      ;;
  esac
}

# Main execution
extract_files "${FILTER_TYPE}" "${EXCLUDE_TYPE}" | format_output "${OUTPUT_FORMAT}"
