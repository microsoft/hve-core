#!/usr/bin/env bash
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#
# component-copy.sh
# Copies selected HVE-Core components into a target repository, preserving
# canonical .github paths and writing the schema version 2 .hve-tracking.json
# manifest. Membership, path-safety, and manifest-schema checks all run before
# the first write.
#
# Usage: component-copy.sh <hve_core_base_path> <target_root> <package_name> <selection_name> <component...>
#   component: marketplace path such as agents/hve-core/rpi-agent.md or skills/rpi/rpi-plan
# Environment:
#   REPORT_ONLY=true      run preflight and report maturity and collisions without writing
#   KEEP_EXISTING=true    leave components listed in COLLISIONS_FILE untouched
#   COLLISIONS_FILE=path  newline-delimited component paths to keep

set -euo pipefail

readonly SCHEMA_VERSION=2
# Local environment, cache, and test directories are never distributed, matching
# the extension skill-materialization exclusions.
readonly EXCLUDED_SKILL_PATH='(^|/)(tests|\.venv|\.hypothesis|node_modules|__pycache__|\.ruff_cache|\.pytest_cache)(/|$)|\.pyc$'

entries_file=""

cleanup() {
  [[ -n "$entries_file" ]] && rm -f "$entries_file"
  return 0
}
trap cleanup EXIT

usage() {
  echo "Usage: $0 <hve_core_base_path> <target_root> <package_name> <selection_name> <component...>" >&2
  exit 1
}

fail() {
  echo "❌ $1" >&2
  exit 1
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# Containment is decided by resolved path and real filesystem state, never by the
# shape of a joined string. Mirrors Assert-WithinTargetRoot in component-copy.ps1
# and must stay behaviourally identical to it.
#
# Ancestors are walked with -L rather than resolving the whole path with
# `realpath -m`, because -m is a GNU coreutils extension that is not dependable on
# macOS, and because the leaf does not exist yet on a first install.
assert_within_target_root() {
  local base="$1" relative="$2" component="$3"
  local current="$base" segment remainder="$relative"

  case "$relative" in
    /*) fail "Component '$component' resolves outside the target root." ;;
    *..*) fail "Component '$component' resolves outside the target root." ;;
  esac

  while [[ -n "$remainder" ]]; do
    segment="${remainder%%/*}"
    if [[ "$remainder" == */* ]]; then
      remainder="${remainder#*/}"
    else
      remainder=""
    fi
    [[ -n "$segment" ]] || continue
    current="$current/$segment"
    [[ -e "$current" || -L "$current" ]] || break
    if [[ -L "$current" ]]; then
      fail "Component '$component' resolves through a link at '$current', which may write outside the target root."
    fi
  done

  echo "$base/$relative"
}

# Maps a marketplace field to "<kind>|<source root>|<package suffix>|<source suffix>".
field_descriptor() {
  case "$1" in
    agents) echo "agent|.github/agents|.md|.agent.md" ;;
    commands) echo "prompt|.github/prompts|.md|.prompt.md" ;;
    rules) echo "instruction|.github/instructions|.instructions.md|.instructions.md" ;;
    skills) echo "skill|.github/skills||" ;;
    *) echo "" ;;
  esac
}

# Maps a canonical catalog root to "<field>|<source suffix>|<package suffix>".
catalog_root_descriptor() {
  case "$1" in
    agents) echo "agents|.agent.md|.md" ;;
    prompts) echo "commands|.prompt.md|.md" ;;
    instructions) echo "rules|.instructions.md|.instructions.md" ;;
    skills) echo "skills||" ;;
    *) echo "" ;;
  esac
}

# The marketplace catalog stores canonical source identities while installer input
# and manifests use package form. A path whose root is outside the four installable
# fields, such as hooks/, carries through unprojected so catalog load never fails.
to_package_component_path() {
  local catalog_path="$1"
  [[ "$catalog_path" == */* ]] || {
    echo "$catalog_path"
    return 0
  }

  local catalog_root="${catalog_path%%/*}"
  local relative="${catalog_path#*/}"
  local descriptor field source_suffix package_suffix
  descriptor=$(catalog_root_descriptor "$catalog_root")
  [[ -n "$descriptor" ]] || {
    echo "$catalog_path"
    return 0
  }

  IFS='|' read -r field source_suffix package_suffix <<<"$descriptor"
  if [[ -n "$source_suffix" ]]; then
    [[ "$relative" == *"$source_suffix" ]] || {
      echo "$catalog_path"
      return 0
    }
    relative="${relative%"$source_suffix"}$package_suffix"
  fi
  echo "$field/$relative"
}

# Trims and validates a component path, echoing the normalized value.
normalize_component_path() {
  local candidate="$1"
  candidate="${candidate#"${candidate%%[![:space:]]*}"}"
  candidate="${candidate%"${candidate##*[![:space:]]}"}"

  [[ -n "$candidate" ]] || fail "Component path must be a non-empty string."
  [[ "$candidate" =~ [[:cntrl:]] ]] && fail "Component path '$candidate' must not contain control characters."
  [[ "$candidate" == *\\* ]] && fail "Component path '$candidate' must use forward slashes."
  [[ "$candidate" == /* ]] && fail "Component path '$candidate' must be relative to the package root."
  [[ "$candidate" =~ ^[A-Za-z]: ]] && fail "Component path '$candidate' must be relative to the package root."
  while [[ "$candidate" == */ ]]; do candidate="${candidate%/}"; done

  local segment
  local remainder="$candidate"
  while [[ -n "$remainder" ]]; do
    segment="${remainder%%/*}"
    [[ -n "$segment" ]] || fail "Component path '$candidate' must not contain empty path segments."
    if [[ "$segment" == "." || "$segment" == ".." ]]; then
      fail "Component path '$candidate' must not contain relative path segments."
    fi
    if [[ "$remainder" == */* ]]; then
      remainder="${remainder#*/}"
    else
      remainder=""
    fi
  done

  echo "$candidate"
}

main() {
  [[ $# -ge 5 ]] || usage
  command -v jq >/dev/null 2>&1 || fail "jq is required by the Bash installer scripts. Install jq or use the PowerShell scripts."

  local hve_core_base_path="$1"
  local target_root_arg="$2"
  local package_name="$3"
  local selection_name="$4"
  shift 4

  [[ -d "$hve_core_base_path" ]] || fail "HVE-Core base path not found: $hve_core_base_path"
  [[ -d "$target_root_arg" ]] || fail "Target root not found: $target_root_arg"
  [[ -n "$package_name" ]] || fail "Package name must be a non-empty string."
  [[ -n "$selection_name" ]] || fail "Selection name must be a non-empty string."

  local source_root target_base
  source_root=$(cd "$hve_core_base_path" && pwd)
  target_base=$(cd "$target_root_arg" && pwd)
  local manifest_path="$target_base/.hve-tracking.json"

  local catalog_path="$source_root/.github/plugin/marketplace.json"
  [[ -f "$catalog_path" ]] || fail "Marketplace catalog not found: $catalog_path"

  local entry_bundle entry_count entry_json
  entry_bundle=$(jq -c --arg pkg "$package_name" '[.plugins[]? | select(.name == $pkg)]' "$catalog_path")
  entry_count=$(jq -r 'length' <<<"$entry_bundle")
  if [[ "$entry_count" == "0" ]]; then
    fail "Marketplace catalog '$catalog_path' declares no package named '$package_name'."
  fi
  if [[ "$entry_count" != "1" ]]; then
    fail "Marketplace catalog '$catalog_path' declares $entry_count packages named '$package_name'."
  fi
  entry_json=$(jq -c '.[0]' <<<"$entry_bundle")

  local -A membership=()
  local package_path
  while IFS= read -r package_path; do
    [[ -n "$package_path" ]] && membership["$(to_package_component_path "$package_path")"]=1
  done < <(jq -r '[(.agents // [])[], (.commands // [])[], (.rules // [])[], (.skills // [])[]] | .[]' <<<"$entry_json")
  [[ ${#membership[@]} -gt 0 ]] || fail "Marketplace package '$package_name' in '$catalog_path' declares no installable components."

  # One projected membership set backs both component validation and the manifest filter.
  local membership_json
  membership_json=$(printf '%s\n' "${!membership[@]}" | LC_ALL=C sort | jq -R -s -c 'split("\n") | map(select(length > 0))')

  local -A component_maturity=()
  local maturity_key maturity_value
  while IFS=$'\t' read -r maturity_key maturity_value; do
    [[ -n "$maturity_key" ]] && component_maturity["$(to_package_component_path "$maturity_key")"]="$maturity_value"
  done < <(jq -r '."x-hve".componentMaturity // {} | to_entries[] | "\(.key)\t\(.value)"' <<<"$entry_json")

  # An unsupported manifest must fail before the target is touched. Version 1 has
  # no upgrade path because it records flattened agent paths and package identity.
  local -A existing_entry=()
  local -A existing_status=()
  if [[ -f "$manifest_path" ]]; then
    local existing_schema
    existing_schema=$(jq -r '.schemaVersion // "missing"' "$manifest_path")
    if [[ "$existing_schema" != "$SCHEMA_VERSION" ]]; then
      fail "Unsupported .hve-tracking.json schemaVersion '$existing_schema' (expected $SCHEMA_VERSION). Delete .hve-tracking.json and re-run the installer for a clean reinstall."
    fi
    local entry_key existing_entry_json entry_status
    while IFS=$'\t' read -r entry_key entry_status existing_entry_json; do
      [[ -n "$entry_key" ]] || continue
      existing_status["$entry_key"]="$entry_status"
      existing_entry["$entry_key"]="$existing_entry_json"
    done < <(jq -rc '.files // {} | to_entries[] | "\(.key)\t\(.value.status)\t\(.value | tostring)"' "$manifest_path")
  fi

  local -A kept_components=()
  local keep_existing="${KEEP_EXISTING:-false}"
  local collisions_file="${COLLISIONS_FILE:-}"
  if [[ "$keep_existing" == "true" && -n "$collisions_file" && -f "$collisions_file" ]]; then
    local kept
    while IFS= read -r kept; do
      [[ -n "$kept" ]] && kept_components["$kept"]=1
    done <"$collisions_file"
  fi

  # Preflight: normalize, bound, and resolve every component before any write.
  local -a plan_components=()
  local -A plan_kinds=() plan_maturities=() plan_targets=() plan_files=()
  local -A seen_targets=()
  local raw candidate field descriptor kind root package_suffix source_suffix relative source_rel files
  for raw in "$@"; do
    candidate=$(normalize_component_path "$raw")

    field="${candidate%%/*}"
    descriptor=$(field_descriptor "$field")
    [[ -n "$descriptor" ]] || fail "Component path '$candidate' must start with one of: agents, commands, rules, skills."
    [[ -n "${membership[$candidate]+x}" ]] || fail "Component '$candidate' is not declared membership of the '$package_name' marketplace recipe."
    [[ -z "${plan_targets[$candidate]+x}" ]] || continue

    IFS='|' read -r kind root package_suffix source_suffix <<<"$descriptor"
    relative="${candidate#"$field"/}"
    if [[ -n "$package_suffix" ]]; then
      [[ "$relative" == *"$package_suffix" ]] || fail "Component path '$candidate' must end with '$package_suffix'."
      relative="${relative%"$package_suffix"}$source_suffix"
    fi
    source_rel="$root/$relative"
    [[ -z "${seen_targets[$source_rel]+x}" ]] || fail "Component '$candidate' resolves to duplicate target '$source_rel'."
    seen_targets["$source_rel"]=1

    if [[ "$kind" == "skill" ]]; then
      [[ -d "$source_root/$source_rel" ]] || fail "Skill component '$candidate' has no source directory at '$source_rel'."
      files=$(cd "$source_root" && find "$source_rel" -type f | grep -Eiv "$EXCLUDED_SKILL_PATH" | LC_ALL=C sort || true)
      [[ -n "$files" ]] || fail "Skill component '$candidate' has no files at '$source_rel'."
    else
      [[ -f "$source_root/$source_rel" ]] || fail "Component '$candidate' has no source file at '$source_rel'."
      files="$source_rel"
    fi

    plan_components+=("$candidate")
    plan_kinds["$candidate"]="$kind"
    plan_maturities["$candidate"]="${component_maturity[$candidate]:-stable}"
    plan_targets["$candidate"]="$source_rel"
    plan_files["$candidate"]="$files"
    assert_within_target_root "$target_base" "$source_rel" "$candidate" >/dev/null
  done

  local version installed
  version=$(jq -r '.version' "$source_root/package.json")
  installed=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  entries_file=$(mktemp)

  local existing_path
  while IFS= read -r existing_path; do
    [[ -n "$existing_path" ]] || continue
    jq -nc --arg path "$existing_path" --argjson value "${existing_entry[$existing_path]}" \
      '{($path): $value}' >>"$entries_file"
  done < <(printf '%s\n' "${!existing_entry[@]}" | LC_ALL=C sort)

  local -a sorted_components=()
  mapfile -t sorted_components < <(printf '%s\n' "${plan_components[@]}" | LC_ALL=C sort)

  if [[ "${REPORT_ONLY:-false}" == "true" ]]; then
    local -a collision_components=() collision_targets=()
    local reported exists
    for reported in "${sorted_components[@]}"; do
      if [[ -e "$target_base/${plan_targets[$reported]}" ]]; then
        exists=true
        collision_components+=("$reported")
        collision_targets+=("${plan_targets[$reported]}")
      else
        exists=false
      fi
      echo "COMPONENT=$reported|KIND=${plan_kinds[$reported]}|MATURITY=${plan_maturities[$reported]}|TARGET=${plan_targets[$reported]}|EXISTS=$exists"
    done
    if [[ ${#collision_components[@]} -gt 0 ]]; then
      echo "COLLISIONS_DETECTED=true"
      echo "COLLISION_COMPONENTS=$(
        IFS=','
        echo "${collision_components[*]}"
      )"
      echo "COLLISION_TARGETS=$(
        IFS=','
        echo "${collision_targets[*]}"
      )"
    else
      echo "COLLISIONS_DETECTED=false"
    fi
    return 0
  fi

  local component target file hash target_file
  for component in "${sorted_components[@]}"; do
    target="${plan_targets[$component]}"

    if [[ -n "${kept_components[$component]+x}" ]]; then
      while IFS= read -r file; do
        if [[ -n "${existing_entry[$file]+x}" ]]; then
          jq -nc --arg path "$file" --argjson value "${existing_entry[$file]}" '{($path): $value}' >>"$entries_file"
        fi
      done <<<"${plan_files[$component]}"
      echo "⏭️ Kept existing: $component"
      continue
    fi

    while IFS= read -r file; do
      if [[ "${existing_status[$file]:-}" == "ejected" ]]; then
        jq -nc --arg path "$file" --argjson value "${existing_entry[$file]}" '{($path): $value}' >>"$entries_file"
        echo "🔒 Skipped ejected: $file"
        continue
      fi
      # Re-verified immediately before the write. Preflight ran earlier, so a link
      # planted in between would otherwise be followed by mkdir and cp. This
      # narrows that window; it does not make the check and the write atomic.
      target_file=$(assert_within_target_root "$target_base" "$file" "$component")
      mkdir -p "$(dirname "$target_file")"
      cp "$source_root/$file" "$target_file"
      hash=$(sha256_of "$target_base/$file")
      jq -nc --arg path "$file" --arg component "$component" --arg kind "${plan_kinds[$component]}" \
        --arg maturity "${plan_maturities[$component]}" --arg ver "$version" --arg sha "$hash" \
        '{($path): {component: $component, kind: $kind, maturity: $maturity, version: $ver, sha256: $sha, status: "managed"}}' \
        >>"$entries_file"
    done <<<"${plan_files[$component]}"
    echo "✅ Copied $component → $target"
  done

  local files_json components_json
  files_json=$(jq -s 'reduce .[] as $entry ({}; . * $entry) | to_entries | sort_by(.key) | from_entries' "$entries_file")
  components_json=$(jq -c --argjson recipe "$membership_json" '
    [to_entries[].value.component as $component
      | select($component | type == "string" and length > 0)
      | select($recipe | index($component))
      | $component] | unique | sort' <<<"$files_json")

  jq -n --argjson schema "$SCHEMA_VERSION" --arg src "microsoft/hve-core" --arg ver "$version" \
    --arg inst "$installed" --arg package "$package_name" --arg profile "$selection_name" \
    --argjson components "$components_json" --argjson files "$files_json" \
    '{schemaVersion: $schema, source: $src, version: $ver, installed: $inst,
      selection: {package: $package, profile: $profile, components: $components}, files: $files}' >"$manifest_path"
  echo "✅ Created .hve-tracking.json"
}

main "$@"
