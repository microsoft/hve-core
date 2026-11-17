#!/usr/bin/env bash
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

set -euo pipefail

REPO_ROOT="."
OUTPUT_PATH=""
ACCOUNTING_PATH=""
TEST_REPORT_PATH="testResults.xml"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -r|--repo-root)
      REPO_ROOT="$2"
      shift 2
      ;;
    -o|--output-path)
      OUTPUT_PATH="$2"
      shift 2
      ;;
    -a|--accounting-path)
      ACCOUNTING_PATH="$2"
      shift 2
      ;;
    -t|--test-report-path)
      TEST_REPORT_PATH="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$OUTPUT_PATH" ]]; then
  echo "Error: --output-path is required." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARGS=(-NoProfile -File "$SCRIPT_DIR/Collect-HveValueEvidence.ps1" -RepoRoot "$REPO_ROOT" -OutputPath "$OUTPUT_PATH" -TestReportPath "$TEST_REPORT_PATH")
if [[ -n "$ACCOUNTING_PATH" ]]; then
  ARGS+=(-AccountingPath "$ACCOUNTING_PATH")
fi

exec pwsh "${ARGS[@]}"
