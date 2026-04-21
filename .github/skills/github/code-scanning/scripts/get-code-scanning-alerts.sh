#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#
# get-code-scanning-alerts.sh
# Retrieves and groups GitHub code scanning alerts for a repository.
#
# Usage:
#   ./get-code-scanning-alerts.sh -o OWNER -r REPO [-b BRANCH] [-s SEVERITY]
#
# Prerequisites:
#   - gh CLI installed and authenticated with security_events scope
#   - jq installed

set -euo pipefail

OWNER=''
REPO=''
BRANCH='main'
SEVERITY=''

usage() {
    echo "Usage: $0 -o OWNER -r REPO [-b BRANCH] [-s SEVERITY]" >&2
    echo "  -o  Repository owner (required)" >&2
    echo "  -r  Repository name (required)" >&2
    echo "  -b  Branch name (default: main)" >&2
    echo "  -s  Filter by security severity (critical, high, medium, low)" >&2
    exit 1
}

while getopts ':o:r:b:s:' opt; do
    case "$opt" in
        o) OWNER="$OPTARG" ;;
        r) REPO="$OPTARG" ;;
        b) BRANCH="$OPTARG" ;;
        s) SEVERITY="$OPTARG" ;;
        *) usage ;;
    esac
done

if [[ -z "$OWNER" || -z "$REPO" ]]; then
    echo "Error: -o OWNER and -r REPO are required." >&2
    usage
fi

if ! command -v gh &>/dev/null; then
    echo "Error: gh CLI not found. Install from https://cli.github.com" >&2
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "Error: jq not found. Install from https://stedolan.github.io/jq/" >&2
    exit 1
fi

if ! gh auth status &>/dev/null; then
    echo "Error: gh CLI not authenticated. Run 'gh auth login' and ensure security_events scope." >&2
    exit 1
fi

URL="repos/${OWNER}/${REPO}/code-scanning/alerts?state=open&ref=refs/heads/${BRANCH}&per_page=100"

if [[ -n "$SEVERITY" ]]; then
    URL="${URL}&severity=${SEVERITY}"
fi

GH_PAGER='' gh api "$URL" --paginate --jq '.[]' | \
    jq -s 'group_by(.rule.description) | map({
        RuleDescription: .[0].rule.description,
        RuleId:          .[0].rule.id,
        Tool:            .[0].tool.name,
        SecuritySeverity: .[0].rule.security_severity_level,
        Count:           length,
        SamplePaths:     ([.[].most_recent_instance.location.path] | unique | sort)
    }) | sort_by(-.Count)'
