#!/usr/bin/env bash
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#
# generate-telemetry-report.sh
# Generates a self-contained telemetry report from hook JSONL files by
# embedding their contents into a copy of report.html. The generated report
# renders automatically without drag & drop.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly TEMPLATE_PATH="${SCRIPT_DIR}/report.html"

# Match the collector and anchor on the caller's workspace: the script itself
# may live outside the repo it reports on, so its location says nothing.
REPO_ROOT="${HVE_REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || true)}"
[[ -n "${REPO_ROOT}" ]] || REPO_ROOT="${PWD}"
readonly REPO_ROOT

usage() {
  cat <<'EOF'
Usage: generate-telemetry-report.sh [options]

Options:
  -d, --date DATE       Target date (yyyy-MM-dd). Default: today (UTC).
                        Use 'all' to include every sessions-*.jsonl file.
  -a, --all-dirs        Scan every per-project telemetry directory recorded in
                        the user-level registry (~/.hve/telemetry-dirs) for
                        a combined cross-project report. Ignored when --path is
                        given.
  -p, --path DIR        Telemetry directory. Scopes the report to this directory
                        alone, overriding --all-dirs.
                        Default: <repo>/.copilot-tracking/telemetry
  -l, --debug-log FILE  Optional debug log JSONL (e.g. main.jsonl) for tokens.
                        When omitted, VS Code debug logs are auto-discovered and
                        the precise model version (e.g. claude-opus-4.6) plus
                        token data are joined in by session id.
  -o, --output FILE     Output path. Default: <telemetry dir>/report.generated.html
      --open            Open the generated report in the default browser.
  -h, --help            Show this help.

EOF
}

err() {
  printf "ERROR: %s\n" "$1" >&2
  exit 1
}

# Best-effort enrichment: extract llm_request events (precise model, token, and
# duration data) from VS Code debug logs, filtered to the session ids already
# collected from hook files. Writes matching events to $1. Returns non-zero when
# python3 is unavailable or no matching events are found (e.g. CLI-only users).
aggregate_debug_requests() {
  local out="$1"; shift
  command -v python3 &>/dev/null || return 1
  python3 "${SCRIPT_DIR}/_telemetry_core.py" aggregate-debug "$out" "$@"
}

# Enrichment from CLI session state: reads ~/.copilot/session-state/{sid}/events.jsonl
# and produces llm_request-compatible events for the report. This provides model,
# token, and duration data for CLI sessions that have no VS Code debug logs.
aggregate_session_state() {
  local out="$1"; shift
  command -v python3 &>/dev/null || return 1
  python3 "${SCRIPT_DIR}/_telemetry_core.py" aggregate-session "$out" "$@"
}

# Emit the user-level registry of per-project telemetry directories (one path
# per line), pruning stale entries. Used by --all-dirs for cross-project reports.
registry_dirs() {
  command -v python3 &>/dev/null || return 0
  python3 "${SCRIPT_DIR}/_telemetry_core.py" list-dirs 2>/dev/null || true
}

main() {
  local target_date
  target_date="$(date -u +%Y-%m-%d)"
  local telemetry_path="${REPO_ROOT}/.copilot-tracking/telemetry"
  local debug_log=""
  local output_path=""
  local open_report=0
  local all_dirs=0
  local path_explicit=0

  # Temp files/dirs cleaned up on return (single trap to avoid overrides).
  # EXIT is listed too: several paths below exit outright, and RETURN alone
  # would leave the enrichment temp directory behind in /tmp on each of them.
  local -a tmp_files=()
  # shellcheck disable=SC2154  # 't' is the loop variable, assigned within the trap body.
  trap 'for t in "${tmp_files[@]:-}"; do [[ -n "$t" ]] && rm -rf "$t"; done' RETURN EXIT

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d|--date) target_date="$2"; shift 2 ;;
      -a|--all-dirs) all_dirs=1; shift ;;
      -p|--path) telemetry_path="$2"; path_explicit=1; shift 2 ;;
      -l|--debug-log) debug_log="$2"; shift 2 ;;
      -o|--output) output_path="$2"; shift 2 ;;
      --open) open_report=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) err "Unknown option: $1" ;;
    esac
  done

  command -v jq &>/dev/null || err "'jq' is required but not installed"
  [[ -f "${TEMPLATE_PATH}" ]] || err "Template not found: ${TEMPLATE_PATH}"

  # Default the output alongside the telemetry data it summarizes.
  [[ -n "${output_path}" ]] || output_path="${telemetry_path}/report.generated.html"

  # Determine which telemetry directories to scan. With --all-dirs, prepend
  # every directory recorded in the user-level registry (cross-project view).
  # An explicit --path wins so the generated cross-project launcher, which
  # always passes --all-dirs, can still be scoped to one store.
  if (( all_dirs && path_explicit )); then
    printf "Ignoring --all-dirs because --path was given; scanning '%s' only.\n" \
      "${telemetry_path}" >&2
  fi
  declare -a search_dirs=()
  if (( all_dirs && ! path_explicit )); then
    while IFS= read -r d; do
      [[ -n "$d" ]] && search_dirs+=("$d")
    done < <(registry_dirs)
  fi
  search_dirs+=("${telemetry_path}")

  # Collect session files for the target date across the chosen directories,
  # de-duplicating directories that appear more than once. The trailing '*'
  # also picks up any shard a collector wrote when it could not lock the shared
  # log; report.html orders every record it loads by ts.
  local prefix="sessions-${target_date}"
  [[ "${target_date}" == "all" ]] && prefix="sessions-"
  declare -a files=()
  local seen_dirs=""
  local dir f
  for dir in "${search_dirs[@]}"; do
    [[ -n "$dir" && "$seen_dirs" != *"|${dir}|"* ]] || continue
    seen_dirs+="|${dir}|"
    [[ -d "$dir" ]] || continue
    # A glob rather than find | sort -z: pathname expansion is already sorted
    # and needs no GNU-only flags, so this runs on macOS's BSD userland. Only
    # the '*' is unquoted, so a date holding a space cannot split into two
    # patterns; an unmatched glob expands to itself and the -f test discards it.
    for f in "$dir"/"$prefix"*.jsonl; do
      [[ -f "$f" ]] && files+=("$f")
    done
  done

  if [[ -n "${debug_log}" ]]; then
    [[ -f "${debug_log}" ]] || err "Debug log not found: ${debug_log}"
    files+=("${debug_log}")
  elif [[ ${#files[@]} -gt 0 ]]; then
    # Auto-enrich with precise model + token data from VS Code debug logs,
    # scoped to the sessions already collected. Silently skipped when none match.
    local agg_dir agg_file
    agg_dir="$(mktemp -d)"
    tmp_files+=("${agg_dir}")
    agg_file="${agg_dir}/debug-llm-requests.jsonl"
    if aggregate_debug_requests "${agg_file}" "${files[@]}"; then
      files+=("${agg_file}")
    fi

    # Also enrich from CLI session state (provides model/token data for CLI users).
    local cli_agg_file="${agg_dir}/cli-session-state.jsonl"
    if aggregate_session_state "${cli_agg_file}" "${files[@]}"; then
      files+=("${cli_agg_file}")
    fi
  fi

  if [[ ${#files[@]} -eq 0 ]]; then
    printf "No telemetry files found in '%s' for date '%s'.\n" \
      "${telemetry_path}" "${target_date}" >&2
    exit 0
  fi

  # Build a compact JSON array of {name, content} objects with jq, then escape
  # every '<' as \u003c. Session content routinely quotes markup, and inside a
  # <script> element the HTML tokenizer treats not only </script> but also an
  # unbalanced <!-- followed by <script as a state change, which swallows the
  # closing tag and corrupts the payload. Escaping '<' removes all three cases;
  # JSON.parse decodes \u003c back to '<'.
  declare -a obj_json=()
  local f
  for f in "${files[@]}"; do
    obj_json+=("$(jq -n \
      --arg name "$(basename "$f")" \
      --rawfile content "$f" \
      '{name: $name, content: $content}')")
  done

  local data
  data="$(printf '%s\n' "${obj_json[@]}" | jq -s -c '.' | sed 's#<#\\u003c#g')"

  # Inject the data into the embeddedData script element. The payload is
  # streamed from a temp file via getline rather than passed through argv or
  # the environment, which would exceed OS limits (E2BIG) on large logs.
  local data_file
  data_file="$(mktemp)"
  tmp_files+=("${data_file}")
  printf '%s' "${data}" > "${data_file}"

  awk -v data_file="${data_file}" \
      -v tag_open='<script id="embeddedData" type="application/json">' \
      -v tag_close='</script>' '
    /id="embeddedData"/ {
      printf "%s", tag_open
      while ((getline line < data_file) > 0) printf "%s", line
      close(data_file)
      print tag_close
      next
    }
    { print }
  ' "${TEMPLATE_PATH}" > "${output_path}"

  printf "Wrote self-contained report: %s\n" "${output_path}"
  printf "Embedded %d file(s): %s\n" "${#files[@]}" "$(IFS=', '; echo "${files[*]##*/}")"

  if [[ "${open_report}" -eq 1 ]]; then
    if command -v xdg-open &>/dev/null; then
      xdg-open "${output_path}"
    elif command -v open &>/dev/null; then
      open "${output_path}"
    fi
  fi
}

main "$@"
