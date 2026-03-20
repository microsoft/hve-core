#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

# generate.sh
# Generates a PR reference file with commit history and full diff.
# The output XML is consumed by GitHub Copilot to produce accurate PR descriptions.
#
# Compares the current branch with a specified base branch (default: main)
# and writes an XML document containing commit history and diff information.

set -euo pipefail

# Display usage information
show_usage() {
  echo "Usage: ${0##*/} [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --no-md-diff       Exclude markdown files (*.md) from the diff output"
  echo "  --base-branch      Specify the base branch to compare against (default: main)"
  echo "                     Use 'auto' to detect the remote default branch"
  echo "  --merge-base       Use git merge-base for three-way comparison"
  echo "  --exclude-ext      Comma-separated extensions to exclude (e.g., yml,yaml,json)"
  echo "  --exclude-path     Comma-separated path prefixes to exclude (e.g., docs/,.github/)"
  echo "  --output           Specify output file path (default: .copilot-tracking/pr/pr-reference.xml)"
  echo "  --help, -h         Show this help message"
  exit 1
}

# Get the repository root directory
REPO_ROOT=$(git rev-parse --show-toplevel)

# Resolve the remote default branch via symbolic-ref
resolve_default_branch() {
  local sym_ref
  sym_ref=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null || true)
  if [[ -n "${sym_ref}" ]]; then
    # Strip refs/remotes/ prefix to get origin/<branch>
    echo "${sym_ref#refs/remotes/}"
  else
    echo "origin/main"
  fi
}

# Process command line arguments
NO_MD_DIFF=false
USE_MERGE_BASE=false
BASE_BRANCH="origin/main"
EXCLUDE_EXT=""
EXCLUDE_PATH=""
OUTPUT_FILE="${REPO_ROOT}/.copilot-tracking/pr/pr-reference.xml"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-md-diff)
      NO_MD_DIFF=true
      shift
      ;;
    --merge-base)
      USE_MERGE_BASE=true
      shift
      ;;
    --base-branch)
      if [[ -z "${2:-}" || "$2" == --* ]]; then
        echo "Error: --base-branch requires an argument" >&2
        show_usage
      fi
      BASE_BRANCH="$2"
      shift 2
      ;;
    --exclude-ext)
      if [[ -z "${2:-}" || "$2" == --* ]]; then
        echo "Error: --exclude-ext requires an argument" >&2
        show_usage
      fi
      EXCLUDE_EXT="$2"
      shift 2
      ;;
    --exclude-path)
      if [[ -z "${2:-}" || "$2" == --* ]]; then
        echo "Error: --exclude-path requires an argument" >&2
        show_usage
      fi
      EXCLUDE_PATH="$2"
      shift 2
      ;;
    --output)
      if [[ -z "${2:-}" || "$2" == --* ]]; then
        echo "Error: --output requires an argument" >&2
        show_usage
      fi
      OUTPUT_FILE="$2"
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

# Resolve auto base branch
if [[ "${BASE_BRANCH}" == "auto" ]]; then
  BASE_BRANCH=$(resolve_default_branch)
fi

# Verify the base branch exists
if ! git rev-parse --verify "${BASE_BRANCH}" &>/dev/null; then
  echo "Error: Branch '${BASE_BRANCH}' does not exist or is not accessible" >&2
  exit 1
fi

# Resolve comparison ref via merge-base when requested
COMPARISON_REF="${BASE_BRANCH}"
if [[ "${USE_MERGE_BASE}" == "true" ]]; then
  MERGE_BASE_REF=$(git merge-base HEAD "${BASE_BRANCH}" 2>/dev/null || true)
  if [[ -n "${MERGE_BASE_REF}" ]]; then
    COMPARISON_REF="${MERGE_BASE_REF}"
  else
    echo "Warning: merge-base resolution failed, using direct comparison" >&2
  fi
fi

# Build pathspec exclusion arguments
build_pathspec_args() {
  local specs=()
  if [[ "${NO_MD_DIFF}" == "true" ]]; then
    specs+=(':!*.md')
  fi
  if [[ -n "${EXCLUDE_EXT}" ]]; then
    IFS=',' read -ra exts <<< "${EXCLUDE_EXT}"
    for ext in "${exts[@]}"; do
      ext="${ext#.}"
      if [[ -n "${ext}" ]]; then
        specs+=(":!*.${ext}")
      fi
    done
  fi
  if [[ -n "${EXCLUDE_PATH}" ]]; then
    IFS=',' read -ra paths <<< "${EXCLUDE_PATH}"
    for p in "${paths[@]}"; do
      p="${p%/}"
      if [[ -n "${p}" ]]; then
        specs+=(":!${p}/**")
      fi
    done
  fi
  if [[ ${#specs[@]} -gt 0 ]]; then
    printf '%s\n' "${specs[@]}"
  fi
}

mapfile -t PATHSPEC_ARGS < <(build_pathspec_args)

# Set output file path and ensure parent directory exists
PR_REF_FILE="${OUTPUT_FILE}"
mkdir -p "$(dirname "${PR_REF_FILE}")"

# Create the reference file with commit history using XML tags
{
  echo "<commit_history>"
  echo "  <current_branch>"
  git --no-pager branch --show-current
  echo "  </current_branch>"
  echo ""

  echo "  <base_branch>"
  echo "    ${BASE_BRANCH}"
  echo "  </base_branch>"
  echo ""

  echo "  <commits>"
  # Output commit information including subject and body
  git --no-pager log --pretty=format:"<commit hash=\"%h\" date=\"%cd\"><message><subject><\![CDATA[%s]]></subject><body><\![CDATA[%b]]></body></message></commit>" --date=short "${COMPARISON_REF}"..HEAD
  echo "  </commits>"
  echo ""

  # Add the full diff, excluding specified files
  echo "  <full_diff>"
  if [[ ${#PATHSPEC_ARGS[@]} -gt 0 ]]; then
    git --no-pager diff "${COMPARISON_REF}" -- "${PATHSPEC_ARGS[@]}"
  else
    git --no-pager diff "${COMPARISON_REF}"
  fi
  echo "  </full_diff>"
  echo "</commit_history>"
} >"${PR_REF_FILE}"

LINE_COUNT=$(wc -l <"${PR_REF_FILE}" | awk '{print $1}')

echo "Created ${PR_REF_FILE}"
if [[ "${NO_MD_DIFF}" == "true" ]]; then
  echo "Note: Markdown files were excluded from diff output"
fi
if [[ -n "${EXCLUDE_EXT}" ]]; then
  echo "Note: Extensions excluded from diff: ${EXCLUDE_EXT}"
fi
if [[ -n "${EXCLUDE_PATH}" ]]; then
  echo "Note: Paths excluded from diff: ${EXCLUDE_PATH}"
fi
if [[ "${USE_MERGE_BASE}" == "true" ]]; then
  echo "Comparison mode: merge-base"
fi
echo "Lines: ${LINE_COUNT}"
echo "Base branch: ${BASE_BRANCH}"
echo "File name: ${PR_REF_FILE}"
