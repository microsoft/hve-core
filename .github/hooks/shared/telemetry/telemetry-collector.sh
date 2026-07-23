#!/usr/bin/env bash
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#
# telemetry-collector.sh
# Copilot hook handler that appends structured JSONL telemetry events.
# Uses Python3 for JSON processing. Fast no-op when telemetry is disabled.

set -euo pipefail

main() {
  local input
  input=$(cat)

  # Resolve repository root for reliable path anchoring across all surfaces
  # (CLI, VS Code, cloud agent). Falls back to HVE_REPO_ROOT or cwd.
  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  [[ -z "$repo_root" ]] && repo_root="${HVE_REPO_ROOT:-.}"

  # Opt-in gate — exit immediately if telemetry is not enabled
  if [[ "${HVE_TELEMETRY:-}" != "1" ]]; then
    if [[ ! -f "$repo_root/.hve-telemetry" ]]; then
      echo '{"continue":true}'
      return 0
    fi
  fi

  # Require Python3 for JSON processing
  if ! command -v python3 &>/dev/null; then
    echo "WARNING: HVE telemetry enabled but python3 not found — events will not be recorded" >&2
    echo '{"continue":true}'
    return 0
  fi

  # Resolve the shared telemetry engine from the skill directory.
  local script_dir core_py
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  core_py="${script_dir}/_telemetry_core.py"

  local telemetry_dir="${HVE_TELEMETRY_DIR:-$repo_root/.copilot-tracking/telemetry}"
  mkdir -p "$telemetry_dir" "$telemetry_dir/.stacks"

  # Dump raw input for diagnostics (first 5 events only). This records hook
  # payloads verbatim, including the full prompt text and tool inputs such as
  # file contents and shell command strings, which can contain secrets. The
  # processed sessions-*.jsonl stream already provides the diagnostic signal,
  # so the verbatim dump is a separate explicit opt-in (off by default) layered
  # on top of the telemetry gate. See docs/customization/local-telemetry.md.
  if [[ "${HVE_TELEMETRY_RAW:-}" == "1" ]]; then
    local raw_log="$telemetry_dir/raw-input.jsonl"
    local raw_count=0
    if [[ -f "$raw_log" ]]; then
      raw_count=$(wc -l < "$raw_log")
    fi
    if (( raw_count < 5 )); then
      echo "$input" >> "$raw_log"
    fi
  fi

  # Delegate all JSON processing to the shared telemetry engine. The engine
  # records the event and, at Stop, SessionEnd, and PreCompact, enriches the
  # session with token/cost data.
  export HVE_REPO_ROOT="$repo_root"
  export HVE_TELEMETRY_DIR="$telemetry_dir"
  echo "$input" | python3 "$core_py" collect || true

  echo '{"continue":true}'
}

main "$@"
