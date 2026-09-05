#!/usr/bin/env bash
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

set -euo pipefail

usage() {
  echo "Usage: ${0##*/} [--base REF]"
  echo ""
  echo "Collects local branch context for a pull request without changing git state."
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
  base_ref="${base_ref#refs/remotes/}"
  base_ref="${base_ref#origin/}"
  printf '%s\n' "${base_ref}"
}

list_templates() {
  local repo_root="$1"
  local candidate
  local candidates=(
    ".github/PULL_REQUEST_TEMPLATE.md"
    ".github/pull_request_template.md"
    "docs/PULL_REQUEST_TEMPLATE.md"
    "docs/pull_request_template.md"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -f "${repo_root}/${candidate}" ]]; then
      printf '%s\n' "${candidate}"
    fi
  done

  for candidate in \
    "${repo_root}/.github/PULL_REQUEST_TEMPLATE"/*.md \
    "${repo_root}/.github/pull_request_template"/*.md; do
    if [[ -f "${candidate}" ]]; then
      printf '%s\n' "${candidate#"${repo_root}/"}"
    fi
  done
}

main() {
  local requested_base="auto"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --base)
        if [[ -z "${2:-}" || "$2" == --* ]]; then
          fail "--base requires a ref."
        fi
        requested_base="$2"
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
  head_branch=$(git branch --show-current)
  [[ -n "${head_branch}" ]] || fail "A named branch must be checked out."

  if [[ "${requested_base}" == "auto" ]]; then
    requested_base=$(resolve_default_base)
  fi
  base_ref=$(resolve_base_ref "${requested_base}")
  merge_base=$(git merge-base HEAD "${base_ref}") || \
    fail "No merge base exists between HEAD and '${base_ref}'."
  divergence=$(git rev-list --left-right --count "${base_ref}...HEAD")
  read -r behind_count ahead_count <<< "${divergence}"

  upstream_ref=$(git rev-parse --abbrev-ref --symbolic-full-name \
    '@{upstream}' 2>/dev/null || true)
  if [[ -n "${upstream_ref}" ]]; then
    divergence=$(git rev-list --left-right --count "${upstream_ref}...HEAD")
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
  git --no-pager log --format='%h%x09%s' "${merge_base}..HEAD"
  printf '%s\n' "" "[changed_files]"
  git --no-pager diff --name-status -M "${merge_base}..HEAD"
  printf '%s\n' "" "[diff_stat]"
  git --no-pager diff --stat "${merge_base}..HEAD"
  printf '%s\n' "" "[worktree]"
  git status --short
  printf '%s\n' "" "[templates]"
  list_templates "${repo_root}"
}

main "$@"
