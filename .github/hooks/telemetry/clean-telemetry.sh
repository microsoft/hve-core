#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#
# clean-telemetry.sh
# Removes telemetry artifacts written by the Copilot telemetry hooks. By
# default it cleans this project's telemetry store; --all-dirs extends the
# cleanup to every registered project plus the user-level HVE home directory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly CORE_PY="${SCRIPT_DIR}/_telemetry_core.py"

# Repo root anchors the default telemetry path so the script works from any cwd.
REPO_ROOT="$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel 2>/dev/null || true)"
[[ -n "${REPO_ROOT}" ]] || REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly REPO_ROOT

usage() {
  cat <<'EOF'
Usage: clean-telemetry.sh [options]

Removes telemetry artifacts (sessions-*.jsonl, raw-input.jsonl, .stacks/,
report.generated.html) from a telemetry store. Unrelated files are preserved.

Options:
  -a, --all-dirs    Also clean every per-project telemetry directory recorded
                    in the user-level registry, plus the generated launchers,
                    report, and registry in the HVE home directory.
  -p, --path DIR    Telemetry directory. Default: <repo>/.copilot-tracking/telemetry
  -n, --dry-run     List what would be removed without deleting anything.
  -y, --yes         Skip the confirmation prompt (required for non-interactive
                    use).
  -h, --help        Show this help.

Runs via: npm run telemetry:clean
EOF
}

err() {
  printf "ERROR: %s\n" "$1" >&2
  exit 1
}

# Prompt before destructive deletion. Aborts when no interactive terminal is
# available so cleanup never proceeds unattended without an explicit --yes.
confirm_cleanup() {
  local scope_desc="$1"
  printf "About to permanently remove telemetry artifacts from: %s\n" "${scope_desc}"
  [[ -t 0 ]] || err "Confirmation required but no interactive terminal is available; re-run with --yes to proceed"
  local reply
  read -r -p "Continue? [y/N] " reply
  case "${reply}" in
    [yY]|[yY][eE][sS]) ;;
    *) printf "Aborted.\n"; exit 0 ;;
  esac
}

main() {
  local telemetry_path="${REPO_ROOT}/.copilot-tracking/telemetry"
  local all_dirs=0
  local dry_run=0
  local assume_yes=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -a|--all-dirs) all_dirs=1; shift ;;
      -p|--path) telemetry_path="$2"; shift 2 ;;
      -n|--dry-run) dry_run=1; shift ;;
      -y|--yes) assume_yes=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) err "Unknown option: $1" ;;
    esac
  done

  command -v python3 &>/dev/null || err "'python3' is required but not installed"
  [[ -f "${CORE_PY}" ]] || err "Telemetry engine not found: ${CORE_PY}"

  if (( ! dry_run && ! assume_yes )); then
    local scope_desc="${telemetry_path}"
    (( all_dirs )) && scope_desc="ALL registered telemetry stores plus the user-level HVE home directory"
    confirm_cleanup "${scope_desc}"
  fi

  local -a args=("clean")
  (( all_dirs )) && args+=("--all-dirs")
  (( dry_run )) && args+=("--dry-run")

  HVE_TELEMETRY_DIR="${telemetry_path}" python3 "${CORE_PY}" "${args[@]}"
}

main "$@"
