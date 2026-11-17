#!/usr/bin/env bash
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

set -euo pipefail

CLAIMS_PATH=""
CLAIMS_JSON=""
EVIDENCE_PATH=""
OUTPUT_PATH=""
FORMAT="json"
AS_OF=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--claims-path)
      CLAIMS_PATH="$2"
      shift 2
      ;;
    -j|--claims-json)
      CLAIMS_JSON="$2"
      shift 2
      ;;
    -e|--evidence-path)
      EVIDENCE_PATH="$2"
      shift 2
      ;;
    -o|--output-path)
      OUTPUT_PATH="$2"
      shift 2
      ;;
    -f|--format)
      FORMAT="$2"
      shift 2
      ;;
    --as-of)
      AS_OF="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARGS=(-NoProfile -File "$SCRIPT_DIR/Measure-HveBenefitValue.ps1" -Format "$FORMAT")
[[ -n "$CLAIMS_PATH" ]] && ARGS+=(-ClaimsPath "$CLAIMS_PATH")
[[ -n "$CLAIMS_JSON" ]] && ARGS+=(-ClaimsJson "$CLAIMS_JSON")
[[ -n "$EVIDENCE_PATH" ]] && ARGS+=(-EvidencePath "$EVIDENCE_PATH")
[[ -n "$OUTPUT_PATH" ]] && ARGS+=(-OutputPath "$OUTPUT_PATH")
[[ -n "$AS_OF" ]] && ARGS+=(-AsOf "$AS_OF")

exec pwsh "${ARGS[@]}"
