#!/usr/bin/env bash
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#
# get-code-scanning-alerts.sh
# Retrieves and groups GitHub code scanning alerts for a repository.
#
# Usage:
#   ./get-code-scanning-alerts.sh -o OWNER -r REPO [-b BRANCH] [-s SEVERITY] [-d]
#
# With -d, dismissed alerts that are still detected on the branch (their most
# recent instance there is not fixed) are appended with Kind
# 'dismissed-still-detected'. A dismissal never resolves an alert.
#
# Prerequisites:
#   - gh CLI installed and authenticated with security_events scope
#   - jq installed

set -euo pipefail

OWNER=''
REPO=''
BRANCH='main'
SEVERITY=''
INCLUDE_DISMISSED=false

usage() {
    echo "Usage: $0 -o OWNER -r REPO [-b BRANCH] [-s SEVERITY] [-d]" >&2
    echo "  -o  Repository owner (required)" >&2
    echo "  -r  Repository name (required)" >&2
    echo "  -b  Branch name (default: main)" >&2
    echo "  -s  Filter by security severity (critical, high, medium, low)" >&2
    echo "  -d  Also report dismissed alerts that are still detected" >&2
    exit 1
}

while getopts ':o:r:b:s:d' opt; do
    case "$opt" in
        o) OWNER="$OPTARG" ;;
        r) REPO="$OPTARG" ;;
        b) BRANCH="$OPTARG" ;;
        s) SEVERITY="$OPTARG" ;;
        d) INCLUDE_DISMISSED=true ;;
        *) usage ;;
    esac
done

if [[ -z "$OWNER" || -z "$REPO" ]]; then
    echo "Error: -o OWNER and -r REPO are required." >&2
    usage
fi

if [[ ! "$OWNER" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    echo "Error: -o OWNER contains invalid characters." >&2; exit 1
fi
if [[ ! "$REPO" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    echo "Error: -r REPO contains invalid characters." >&2; exit 1
fi
if [[ ! "$BRANCH" =~ ^[a-zA-Z0-9._/-]+$ ]]; then
    echo "Error: -b BRANCH contains invalid characters." >&2; exit 1
fi
if [[ -n "$SEVERITY" && ! "$SEVERITY" =~ ^(critical|high|medium|low)$ ]]; then
    echo "Error: -s SEVERITY must be critical, high, medium, or low." >&2; exit 1
fi

if ! command -v gh &>/dev/null; then
    echo "Error: gh CLI not found. Install from https://cli.github.com" >&2
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "Error: jq not found. Install from https://jqlang.github.io/jq/" >&2
    exit 1
fi

if ! gh auth status &>/dev/null; then
    echo "Error: gh CLI not authenticated. Run 'gh auth login' and ensure security_events scope." >&2
    exit 1
fi

SEVERITY_QUERY=''
if [[ -n "$SEVERITY" ]]; then
    SEVERITY_QUERY="&severity=${SEVERITY}"
fi

URL="repos/${OWNER}/${REPO}/code-scanning/alerts?state=open&ref=refs/heads/${BRANCH}&per_page=100${SEVERITY_QUERY}"

GROUP_FILTER='group_by(.rule.description) | map({
        RuleDescription: .[0].rule.description,
        RuleId:          .[0].rule.id,
        Tool:            .[0].tool.name,
        SecuritySeverity: .[0].rule.security_severity_level,
        Count:           length,
        SamplePaths:     ([.[].most_recent_instance.location.path] | unique | sort)
    }) | sort_by(-.Count)'

OPEN_GROUPS=$(GH_PAGER='' gh api "$URL" --paginate --jq '.[]' | jq -s "$GROUP_FILTER")

if [[ "$INCLUDE_DISMISSED" != true ]]; then
    printf '%s\n' "$OPEN_GROUPS"
    exit 0
fi

# The ref filter scopes most_recent_instance to the branch. A dismissed alert
# whose instance there is not fixed is still being detected.
DISMISSED_URL="repos/${OWNER}/${REPO}/code-scanning/alerts?state=dismissed&ref=refs/heads/${BRANCH}&per_page=100${SEVERITY_QUERY}"
DISMISSED_GROUPS=$(GH_PAGER='' gh api "$DISMISSED_URL" --paginate --jq '.[]' | \
    jq -s "map(select(.most_recent_instance.state != \"fixed\")) as \$alerts
        | \$alerts | ${GROUP_FILTER}
        | map(. as \$g | . + {
            Kind: \"dismissed-still-detected\",
            DismissedReason: ([\$alerts[] | select(.rule.id == \$g.RuleId)][0].dismissed_reason)
        })")

jq -n --argjson open "$OPEN_GROUPS" --argjson dismissed "$DISMISSED_GROUPS" '$open + $dismissed'
