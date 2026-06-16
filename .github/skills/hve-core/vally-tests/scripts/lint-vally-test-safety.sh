#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#
# Skill-local safety lint mirror of Lint-VallyTestSafety.ps1.
# Exit codes: 0=clean, 1=match, 2=ambiguous (multiple categories or parse error).

set -euo pipefail

usage() {
    cat <<'EOF' >&2
Usage: lint-vally-test-safety.sh PATH [PATH...]
Scans stimulus YAML, CSV, markdown, or text for refusal-taxonomy regex matches.
EOF
    exit "${1:-2}"
}

paths=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage 0 ;;
        --) shift; while [[ $# -gt 0 ]]; do paths+=("$1"); shift; done ;;
        -*) printf 'unknown argument: %s\n' "$1" >&2; usage 2 ;;
        *)  paths+=("$1"); shift ;;
    esac
done

[[ ${#paths[@]} -gt 0 ]] || usage 2

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_root="$(dirname "$script_dir")"
taxonomy="$skill_root/references/refusal-taxonomy.md"

if [[ ! -f "$taxonomy" ]]; then
    printf 'Refusal taxonomy not found at %s\n' "$taxonomy" >&2
    exit 2
fi

extract_categories() {
    awk '
        BEGIN { category=""; in_block=0; buf="" }
        /^## Category: / {
            category=$0
            sub(/^## Category: /, "", category)
            sub(/[[:space:]]+$/, "", category)
            next
        }
        /^## Lint script contract/ { exit }
        /^[[:space:]]*```regex[[:space:]]*$/ {
            in_block=1; buf=""; next
        }
        /^[[:space:]]*```[[:space:]]*$/ && in_block==1 {
            sub(/^[[:space:]]+/, "", buf)
            sub(/[[:space:]]+$/, "", buf)
            if (category != "" && buf != "") {
                printf "%s\t%s\n", category, buf
            }
            in_block=0; buf=""; next
        }
        in_block==1 {
            if (buf == "") { buf=$0 } else { buf=buf "\n" $0 }
        }
    ' "$taxonomy"
}

mapfile -t entries < <(extract_categories)
if [[ ${#entries[@]} -eq 0 ]]; then
    printf 'No regex categories parsed from %s\n' "$taxonomy" >&2
    exit 2
fi

declare -A combined
declare -A counts
for entry in "${entries[@]}"; do
    cat_name="${entry%%	*}"
    pattern="${entry#*	}"
    if [[ -z "${combined[$cat_name]:-}" ]]; then
        combined[$cat_name]="$pattern"
    else
        combined[$cat_name]="${combined[$cat_name]}|$pattern"
    fi
done

collect_files() {
    for p in "$@"; do
        if [[ ! -e "$p" ]]; then
            printf 'WARN: path not found: %s\n' "$p" >&2
            continue
        fi
        if [[ -d "$p" ]]; then
            find "$p" -type f \( -name '*.yml' -o -name '*.yaml' -o -name '*.csv' -o -name '*.md' -o -name '*.txt' \)
        else
            printf '%s\n' "$p"
        fi
    done
}

total_matches=0
categories_hit=0

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    for cat_name in "${!combined[@]}"; do
        pattern="${combined[$cat_name]}"
        if matches=$(grep -EnIo "$pattern" "$file" 2>/dev/null); then
            count=$(printf '%s\n' "$matches" | wc -l | tr -d ' ')
            if [[ "$count" -gt 0 ]]; then
                printf 'vally-test-safety: category=%s count=%d file=%s\n' "$cat_name" "$count" "$file"
                printf '%s\n' "$matches" | sed "s|^|  $file:|"
                counts[$cat_name]=$(( ${counts[$cat_name]:-0} + count ))
                total_matches=$(( total_matches + count ))
            fi
        fi
    done
done < <(collect_files "${paths[@]}")

categories_hit=${#counts[@]}

if [[ "$total_matches" -eq 0 ]]; then
    printf 'vally-test-safety: clean (0 matches)\n'
    exit 0
fi

if [[ "$categories_hit" -gt 1 ]]; then
    exit 2
fi

exit 1
