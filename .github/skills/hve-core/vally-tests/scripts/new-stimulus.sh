#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#
# Scaffolds a Vally stimulus YAML block from a target artifact path.
# Mirror of New-Stimulus.ps1. Pure transformation: no Vally invocation,
# no network, no LLM call.
#
# Usage:
#   new-stimulus.sh --artifact-path PATH --kind KIND --prompt-text TEXT \
#       [--output-path PATH] [--grader-type TYPE]
#
# KIND:        prompt | instructions | agent | skill
# GRADER-TYPE: prompt | output-contains | output-matches (default: output-matches)

set -euo pipefail

usage() {
    sed -n '5,16p' "$0" >&2
    exit "${1:-2}"
}

artifact_path=""
kind=""
prompt_text=""
output_path=""
grader_type="output-matches"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --artifact-path) artifact_path="$2"; shift 2 ;;
        --kind)          kind="$2"; shift 2 ;;
        --prompt-text)   prompt_text="$2"; shift 2 ;;
        --output-path)   output_path="$2"; shift 2 ;;
        --grader-type)   grader_type="$2"; shift 2 ;;
        -h|--help)       usage 0 ;;
        *) printf 'unknown argument: %s\n' "$1" >&2; usage 2 ;;
    esac
done

[[ -n "$artifact_path" && -n "$kind" && -n "$prompt_text" ]] || usage 2

case "$kind" in
    prompt|instructions|agent|skill) ;;
    *) printf 'invalid kind: %s\n' "$kind" >&2; usage 2 ;;
esac

case "$grader_type" in
    prompt|output-contains|output-matches) ;;
    *) printf 'invalid grader type: %s\n' "$grader_type" >&2; usage 2 ;;
esac

normalize_and_hash() {
    local text="$1"
    printf '%s' "$text" \
        | tr '[:upper:]' '[:lower:]' \
        | tr -s '[:space:]' ' ' \
        | sed 's/^ //; s/ $//' \
        | sha256sum \
        | awk '{print $1}'
}

leaf_for() {
    local path="$1"
    local leaf
    leaf="${path##*/}"
    leaf="${leaf%.prompt.md}"
    leaf="${leaf%.instructions.md}"
    leaf="${leaf%.agent.md}"
    leaf="$(printf '%s' "$leaf" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]\{1,\}/-/g; s/^-//; s/-$//')"
    printf '%s' "$leaf"
}

category_for() {
    case "$1" in
        agent) printf 'agent-behavior' ;;
        *)     printf 'behavior-conformance' ;;
    esac
}

emit_prompt_block() {
    while IFS= read -r line; do
        printf '      %s\n' "$line"
    done <<< "$1"
}

yaml_dquote() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '"%s"' "$value"
}

grader_block() {
    case "$1" in
        prompt)
            cat <<'EOF'
    graders:
      - type: prompt
        name: rubric-match
        config:
          prompt: |
            Score 1 if the response satisfies the contract. Score 0 otherwise.
          scoring: scale_1_5
          threshold: 0.85
EOF
            ;;
        output-contains)
            cat <<'EOF'
    graders:
      - type: output-contains
        name: literal-phrase-present
        config:
          substring: "<literal phrase>"
EOF
            ;;
        output-matches)
            cat <<'EOF'
    graders:
      - type: output-matches
        name: pattern-present
        config:
          pattern: "(?i)<regex-source-of-truth>"
EOF
            ;;
    esac
}

hash="$(normalize_and_hash "$prompt_text")"
leaf="$(leaf_for "$artifact_path")"
name="${leaf}-conformance-${hash:0:8}"
category="$(category_for "$kind")"
artifact_path_yaml="$(yaml_dquote "$artifact_path")"

block=$(cat <<EOF
  - name: ${name}
    prompt: |
$(emit_prompt_block "$prompt_text")
    tags:
      category: ${category}
      kind: ${kind}
      target_artifact: ${artifact_path_yaml}
      advisory: "true"
      prompt_sha256: ${hash}
$(grader_block "$grader_type")
EOF
)

if [[ -z "$output_path" ]]; then
    printf '%s\n' "$block"
else
    if [[ ! -f "$output_path" ]]; then
        printf 'stimuli:\n' > "$output_path"
    fi
    printf '%s\n' "$block" >> "$output_path"
    printf "Appended stimulus '%s' (sha256=%s) to %s\n" "$name" "$hash" "$output_path"
fi
