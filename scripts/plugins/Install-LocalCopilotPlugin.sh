#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#
# Install a generated local Copilot CLI plugin for development testing.

set -euo pipefail

readonly DEFAULT_PLUGIN_ID="hve-core"
readonly DEFAULT_SOURCE_DIR="plugins/hve-core"
readonly INSTALL_ROOT="${HOME}/.copilot/installed-plugins"

plugin_id="${DEFAULT_PLUGIN_ID}"
source_dir="${DEFAULT_SOURCE_DIR}"
generate=false
dry_run=false
skip_uninstall=false

usage() {
  cat <<USAGE
Usage: ${0##*/} [OPTIONS]

Install a generated local Copilot CLI plugin into ~/.copilot/installed-plugins.

Options:
  --plugin-id NAME       Plugin id to replace (default: hve-core)
  --source-dir PATH      Generated plugin directory (default: plugins/hve-core)
  --generate             Run npm run plugin:generate before installing
  --skip-uninstall       Do not run 'copilot plugin uninstall'
  --dry-run              Show actions without changing installed plugins
  --help, -h             Show this help message

Examples:
  scripts/plugins/Install-LocalCopilotPlugin.sh
  scripts/plugins/Install-LocalCopilotPlugin.sh --generate
  scripts/plugins/Install-LocalCopilotPlugin.sh --dry-run
USAGE
}

log() {
  printf "==> %s\n" "$1"
}

print_reinstall_instructions() {
  cat <<INSTRUCTIONS

To reinstall the marketplace plugin after local testing:

  copilot plugin uninstall ${plugin_id}
  copilot plugin marketplace add microsoft/hve-core
  copilot plugin install ${plugin_id}@hve-core

Restart Copilot CLI after reinstalling.
INSTRUCTIONS
}

err() {
  printf "ERROR: %s\n" "$1" >&2
  exit 1
}

run() {
  if [[ "${dry_run}" == "true" ]]; then
    printf "DRY-RUN: %q" "$1"
    shift
    printf " %q" "$@"
    printf "\n"
    return 0
  fi

  "$@"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --plugin-id)
        if [[ -z "${2:-}" || "${2}" == --* ]]; then
          err "--plugin-id requires a value"
        fi
        plugin_id="$2"
        shift 2
        ;;
      --source-dir)
        if [[ -z "${2:-}" || "${2}" == --* ]]; then
          err "--source-dir requires a value"
        fi
        source_dir="$2"
        shift 2
        ;;
      --generate)
        generate=true
        shift
        ;;
      --skip-uninstall)
        skip_uninstall=true
        shift
        ;;
      --dry-run)
        dry_run=true
        shift
        ;;
      --help | -h)
        usage
        exit 0
        ;;
      *)
        err "Unknown option: $1"
        ;;
    esac
  done
}

require_command() {
  local command_name="$1"
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    err "'${command_name}' is required but was not found"
  fi
}

validate_plugin_id() {
  local value="$1"
  if [[ ! "${value}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ ]]; then
    err "Plugin id must be a safe slug containing only letters, numbers, dots, underscores, or hyphens"
  fi
}

repo_root() {
  git rev-parse --show-toplevel
}

safe_installed_path() {
  local candidate="$1"
  local resolved_install_root
  local resolved_candidate

  if [[ "${dry_run}" == "false" ]]; then
    # INSTALL_ROOT is guaranteed to exist after the mkdir -p above.
    resolved_install_root="$(cd "${INSTALL_ROOT}" && pwd -P)"
    resolved_candidate="$(cd "$(dirname "${candidate}")" && pwd -P)/$(basename "${candidate}")"
  else
    # dry-run: resolve via pwd -P when the directory exists; lexical fallback otherwise.
    if [[ -d "${INSTALL_ROOT}" ]]; then
      resolved_install_root="$(cd "${INSTALL_ROOT}" && pwd -P)"
    else
      resolved_install_root="${INSTALL_ROOT}"
    fi
    local candidate_parent
    candidate_parent="$(dirname "${candidate}")"
    if [[ -d "${candidate_parent}" ]]; then
      resolved_candidate="$(cd "${candidate_parent}" && pwd -P)/$(basename "${candidate}")"
    else
      resolved_candidate="${candidate}"
    fi
  fi

  case "${resolved_candidate}" in
    "${resolved_install_root}"|"${resolved_install_root}"/*)
      return 0
      ;;
    *)
      err "Refusing to modify path outside ${INSTALL_ROOT}: ${candidate}"
      ;;
  esac
}

verify_source_plugin() {
  local source_path="$1"

  [[ -d "${source_path}" ]] || err "Source plugin directory not found: ${source_path}"
  [[ -f "${source_path}/.github/plugin/plugin.json" ]] || \
    err "Missing plugin manifest: ${source_path}/.github/plugin/plugin.json"
  [[ -f "${source_path}/commands/hve-core/task-research.md" ]] || \
    err "Missing task-research command in generated plugin"

  grep -q "subagents={auto|true|false}" \
    "${source_path}/commands/hve-core/task-research.md" || \
    err "Generated task-research command does not include subagents input"

  local required_subagent
  for required_subagent in \
    codebase-analyzer \
    codebase-locator \
    codebase-pattern-finder \
    web-search-researcher; do
    [[ -e "${source_path}/agents/hve-core/subagents/${required_subagent}.md" ]] || \
      err "Missing generated named subagent: ${required_subagent}"
  done
}

backup_existing_install() {
  local installed_plugin_root="$1"
  local label="$2"

  if [[ ! -d "${installed_plugin_root}" ]]; then
    return 0
  fi

  local backup_dir
  backup_dir="${INSTALL_ROOT}/.backups/${plugin_id}-${label}-$(date -u +%Y%m%dT%H%M%SZ)"
  log "Backing up existing ${plugin_id} ${label} plugin to ${backup_dir}"
  run mkdir -p "$(dirname "${backup_dir}")"
  run cp -a "${installed_plugin_root}" "${backup_dir}"
}

install_local_plugin() {
  local root="$1"
  local source_path="${root}/${source_dir}"
  local marketplace_plugin_root="${INSTALL_ROOT}/${plugin_id}"
  local direct_plugin_root="${INSTALL_ROOT}/_direct/${plugin_id}"

  verify_source_plugin "${source_path}"

  if [[ "${dry_run}" == "false" ]]; then
    mkdir -p "${INSTALL_ROOT}" "${INSTALL_ROOT}/_direct"
  fi

  backup_existing_install "${marketplace_plugin_root}" "marketplace"
  backup_existing_install "${direct_plugin_root}" "direct"

  if [[ "${skip_uninstall}" == "false" ]]; then
    log "Uninstalling existing ${plugin_id} plugin registration"
    if [[ "${dry_run}" == "true" ]]; then
      printf "DRY-RUN: copilot plugin uninstall %q\n" "${plugin_id}"
    else
      copilot plugin uninstall "${plugin_id}" || true
    fi
  fi

  log "Removing stale installed plugin directories"
  safe_installed_path "${marketplace_plugin_root}"
  safe_installed_path "${direct_plugin_root}"
  run rm -rf "${marketplace_plugin_root}" "${direct_plugin_root}"

  log "Installing local plugin from ${source_path}"
  run copilot plugin install "${source_path}"
  log "Installed ${plugin_id} from local generated output"
  if [[ "${dry_run}" == "false" ]]; then
    copilot plugin list
  fi
}

main() {
  parse_args "$@"
  validate_plugin_id "${plugin_id}"
  require_command git
  require_command copilot

  local root
  root="$(repo_root)"
  cd "${root}"

  if [[ "${generate}" == "true" ]]; then
    require_command npm
    require_command pwsh
    log "Regenerating plugin outputs"
    run npm run plugin:generate
  fi

  install_local_plugin "${root}"

  log "Restart Copilot CLI, then test: /hve-core:task-research topic=\"...\" subagents=true"
  print_reinstall_instructions
}

main "$@"
