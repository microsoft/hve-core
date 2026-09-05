#!/usr/bin/env bash
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#
# Installs committed Node lockfiles beneath a skill directory.
#
# A skill may vendor its own runtime dependencies next to the modules that
# import them, so module resolution during tests needs those installs to have
# happened. This runs in reusable workflows that grant id-token: write for
# Codecov OIDC, which makes the install step a credential-bearing context:
#
#   * Installs use --ignore-scripts. A dependency lifecycle script would
#     otherwise execute arbitrary code in a job that can mint an identity
#     token, turning any transitive dependency into a token-exfiltration path.
#   * The number of installs is bounded. An unbounded walk lets a change that
#     adds lockfiles expand CI execution without review.
#   * The search root arrives in the environment rather than through workflow
#     template interpolation, so its contents cannot terminate a shell word and
#     inject commands.
#   * Optional dependencies are omitted. The real screen-reader driver is a
#     Windows-only optional dependency whose chain writes to the registry;
#     Linux CI never drives a screen reader, so installing it there adds
#     exposure for no coverage. Set INCLUDE_OPTIONAL=1 on a runner that needs it.
set -euo pipefail

search_root="${SEARCH_ROOT:?SEARCH_ROOT must be set to the directory to scan}"
max_installs="${MAX_INSTALLS:-5}"
include_optional="${INCLUDE_OPTIONAL:-0}"

install_args=(--ignore-scripts)
if [ "$include_optional" != "1" ]; then
  install_args+=(--omit=optional)
fi

if [ ! -d "$search_root" ]; then
  echo "Search root does not exist: $search_root" >&2
  exit 1
fi

lockfiles=()
while IFS= read -r lockfile; do
  lockfiles+=("$lockfile")
done < <(find "$search_root" -type d -name node_modules -prune -o -type f -name package-lock.json -print | sort)

if [ "${#lockfiles[@]}" -eq 0 ]; then
  echo "No package-lock.json under $search_root; skipping install"
  exit 0
fi

# Refuse rather than silently installing a subset: a truncated install would
# surface later as a confusing module-resolution failure in the test step.
if [ "${#lockfiles[@]}" -gt "$max_installs" ]; then
  echo "Found ${#lockfiles[@]} lockfiles under $search_root, which exceeds the limit of $max_installs." >&2
  echo "Raise MAX_INSTALLS deliberately if this growth is intended." >&2
  printf '  %s\n' "${lockfiles[@]}" >&2
  exit 1
fi

for lockfile in "${lockfiles[@]}"; do
  install_dir="$(dirname "$lockfile")"
  echo "Installing $install_dir"
  (cd "$install_dir" && npm ci "${install_args[@]}")
done
