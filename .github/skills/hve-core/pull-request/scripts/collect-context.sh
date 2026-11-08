#!/usr/bin/env bash
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

set -euo pipefail

usage() {
  echo "Usage: ${0##*/} [--base REF] [--head BRANCH]"
  echo ""
  echo "Collects pull request context for a local branch without changing git state."
  echo ""
  echo "Options:"
  echo "  --base REF       Base branch or ref (default: the remote default branch)."
  echo "                   A plain name resolves to origin/NAME before NAME."
  echo "                   Use refs/heads/NAME for a local branch."
  echo "  --head BRANCH    Local branch to describe (default: the checked-out"
  echo "                   branch). [worktree] always reports the current checkout."
  echo "  --help, -h       Show this help message."
  exit "${1:-1}"
}

fail() {
  echo "Error: $1" >&2
  exit 1
}

resolve_default_base() {
  local symbolic_ref
  symbolic_ref=$(git symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null || true)
  if [[ -n "${symbolic_ref}" ]]; then
    printf '%s\n' "${symbolic_ref#refs/remotes/}"
  elif git rev-parse --verify origin/main &>/dev/null; then
    printf '%s\n' "origin/main"
  elif git rev-parse --verify main &>/dev/null; then
    printf '%s\n' "main"
  else
    fail "Unable to resolve the remote default branch. Pass --base REF."
  fi
}

resolve_base_ref() {
  local requested_ref="$1"
  local candidate
  local candidates=("${requested_ref}")

  if [[ "${requested_ref}" != */* && "${requested_ref}" != refs/* ]]; then
    candidates=("origin/${requested_ref}" "${requested_ref}")
  fi

  for candidate in "${candidates[@]}"; do
    if git rev-parse --verify "${candidate}^{commit}" &>/dev/null; then
      printf '%s\n' "${candidate}"
      return
    fi
  done

  fail "Base ref '${requested_ref}' is unavailable locally. Fetch it or pass another ref."
}

pull_request_base_name() {
  local base_ref="$1"
  if [[ "${base_ref}" == refs/heads/* ]]; then
    printf '%s\n' "${base_ref#refs/heads/}"
    return
  fi
  base_ref="${base_ref#refs/remotes/}"
  base_ref="${base_ref#origin/}"
  printf '%s\n' "${base_ref}"
}

# Lists templates in .github/, the repository root, and docs/, in that order.
# Each location reports its pull_request_template.md file before the Markdown
# files in its PULL_REQUEST_TEMPLATE/ folder. Names match without regard to
# case, so a case-insensitive file system still lists each template once.
list_templates() {
  local repo_root="$1"
  local location
  local directory
  local prefix
  local entry
  local template

  shopt -s nocasematch
  for location in ".github" "" "docs"; do
    directory="${repo_root}${location:+/${location}}"
    prefix="${location:+${location}/}"
    [[ -d "${directory}" ]] || continue

    for entry in "${directory}"/*; do
      if [[ -f "${entry}" && "${entry##*/}" == "pull_request_template.md" ]]; then
        printf '%s\n' "${prefix}${entry##*/}"
      fi
    done

    for entry in "${directory}"/*; do
      if [[ -d "${entry}" && "${entry##*/}" == "pull_request_template" ]]; then
        for template in "${entry}"/*; do
          if [[ -f "${template}" && "${template}" == *.md ]]; then
            printf '%s\n' "${prefix}${entry##*/}/${template##*/}"
          fi
        done
      fi
    done
  done
  shopt -u nocasematch
}

main() {
  local requested_base="auto"
  local requested_head=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --base)
        if [[ -z "${2:-}" || "$2" == --* ]]; then
          fail "--base requires a ref."
        fi
        requested_base="$2"
        shift 2
        ;;
      --head)
        if [[ -z "${2:-}" || "$2" == --* ]]; then
          fail "--head requires a branch name."
        fi
        requested_head="$2"
        shift 2
        ;;
      --help|-h)
        usage 0
        ;;
      *)
        fail "Unknown option: $1"
        ;;
    esac
  done

  command -v git &>/dev/null || fail "Git is required but was not found on PATH."

  local repo_root
  local head_branch
  local head_ref
  local base_ref
  local merge_base
  local divergence
  local behind_count
  local ahead_count
  local upstream_ref
  local upstream_ahead_count
  local upstream_behind_count
  local push_state
  local branch_needs_push

  repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || \
    fail "Run this script inside a git repository."
  if [[ -n "${requested_head}" ]]; then
    head_branch="${requested_head#refs/heads/}"
  else
    head_branch=$(git branch --show-current)
  fi
  [[ -n "${head_branch}" ]] || \
    fail "A named branch must be checked out, or pass --head BRANCH."
  head_ref="refs/heads/${head_branch}"
  git show-ref --verify --quiet "${head_ref}" || \
    fail "'${head_branch}' is not a local branch."

  if [[ "${requested_base}" == "auto" ]]; then
    requested_base=$(resolve_default_base)
  fi
  base_ref=$(resolve_base_ref "${requested_base}")
  merge_base=$(git merge-base "${head_ref}" "${base_ref}") || \
    fail "No merge base exists between '${head_branch}' and '${base_ref}'."
  divergence=$(git rev-list --left-right --count "${base_ref}...${head_ref}")
  read -r behind_count ahead_count <<< "${divergence}"

  upstream_ref=$(git rev-parse --abbrev-ref --symbolic-full-name \
    "${head_branch}@{upstream}" 2>/dev/null || true)
  if [[ -n "${upstream_ref}" ]]; then
    divergence=$(git rev-list --left-right --count \
      "${upstream_ref}...${head_ref}")
    read -r upstream_behind_count upstream_ahead_count <<< "${divergence}"
    if (( upstream_behind_count > 0 && upstream_ahead_count > 0 )); then
      push_state="diverged"
    elif (( upstream_behind_count > 0 )); then
      push_state="behind"
    elif (( upstream_ahead_count > 0 )); then
      push_state="ahead"
    else
      push_state="current"
    fi
  else
    upstream_behind_count="unknown"
    upstream_ahead_count="unknown"
    push_state="missing"
  fi
  if [[ "${push_state}" == "ahead" || "${push_state}" == "missing" ]]; then
    branch_needs_push="true"
  else
    branch_needs_push="false"
  fi

  printf '%s\n' \
    "PR_CONTEXT_V1" \
    "repository_root: ${repo_root}" \
    "head_branch: ${head_branch}" \
    "base_ref: ${base_ref}" \
    "base_branch: $(pull_request_base_name "${base_ref}")" \
    "merge_base: ${merge_base}" \
    "ahead_count: ${ahead_count}" \
    "behind_count: ${behind_count}" \
    "upstream_ref: ${upstream_ref:-none}" \
    "upstream_ahead_count: ${upstream_ahead_count}" \
    "upstream_behind_count: ${upstream_behind_count}" \
    "push_state: ${push_state}" \
    "branch_needs_push: ${branch_needs_push}" \
    "" \
    "[commits]"
  git --no-pager log --format='%h%x09%s' "${merge_base}..${head_ref}"
  printf '%s\n' "" "[changed_files]"
  git --no-pager diff --name-status -M "${merge_base}..${head_ref}"
  printf '%s\n' "" "[diff_stat]"
  git --no-pager diff --stat "${merge_base}..${head_ref}"
  printf '%s\n' "" "[worktree]"
  git status --short
  printf '%s\n' "" "[templates]"
  list_templates "${repo_root}"
}

main "$@"
