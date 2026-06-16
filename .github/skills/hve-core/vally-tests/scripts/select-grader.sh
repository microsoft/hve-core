#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#
# Emits the canonical Vally grader block for a (kind, check) pair.
# Mirror of Select-Grader.ps1.
#
# Usage:
#   select-grader.sh --kind KIND --check NAME [--grader-type TYPE]

set -euo pipefail

usage() {
    sed -n '5,11p' "$0" >&2
    exit "${1:-2}"
}

kind=""
check=""
grader_type=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --kind)         kind="$2"; shift 2 ;;
        --check)        check="$2"; shift 2 ;;
        --grader-type)  grader_type="$2"; shift 2 ;;
        -h|--help)      usage 0 ;;
        *) printf 'unknown argument: %s\n' "$1" >&2; usage 2 ;;
    esac
done

[[ -n "$kind" && -n "$check" ]] || usage 2

case "$kind" in
    prompt|instructions|agent|skill) ;;
    *) printf 'invalid kind: %s\n' "$kind" >&2; usage 2 ;;
esac

case "${grader_type:-output-matches}" in
    prompt|output-contains|output-matches) ;;
    *) printf 'invalid grader type: %s\n' "$grader_type" >&2; usage 2 ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_root="$(dirname "$script_dir")"
references_dir="$skill_root/references"
case "$kind" in
    instructions) kind_reference="$references_dir/instructions.md" ;;
    *)            kind_reference="$references_dir/${kind}s.md" ;;
esac

if [[ ! -f "$kind_reference" ]]; then
    printf 'Per-kind reference not found: %s\n' "$kind_reference" >&2
    exit 1
fi

if [[ -z "$grader_type" ]]; then
    if ! grep -qiE "^#{2,6}[[:space:]]+.*${check}.*$" "$kind_reference"; then
        printf "Check '%s' not found in %s.\n" "$check" "$kind_reference" >&2
        exit 1
    fi
    token="$(awk -v ck="$check" '
        BEGIN { found=0 }
        tolower($0) ~ "^#{2,6}[[:space:]]+.*" tolower(ck) ".*$" { found=1; next }
        found && match($0, /(prompt|output-contains|output-matches|semantic_similarity|contains|regex)/) {
            print substr($0, RSTART, RLENGTH); exit
        }
    ' "$kind_reference")"
    case "$token" in
        semantic_similarity) grader_type="prompt" ;;
        contains)            grader_type="output-contains" ;;
        regex)               grader_type="output-matches" ;;
        prompt|output-contains|output-matches) grader_type="$token" ;;
        *) grader_type="output-matches" ;;
    esac
fi

case "$grader_type" in
    prompt)
        cat <<EOF
  - type: prompt
    name: $check
    config:
      prompt: |
        Score 1 if the response satisfies the $check contract. Score 0 otherwise.
      scoring: scale_1_5
      threshold: 0.85
EOF
        ;;
    output-contains)
        cat <<EOF
  - type: output-contains
    name: $check
    config:
      substring: "<literal phrase>"
EOF
        ;;
    output-matches)
        cat <<EOF
  - type: output-matches
    name: $check
    config:
      pattern: "(?i)<regex-source-of-truth>"
EOF
        ;;
esac
