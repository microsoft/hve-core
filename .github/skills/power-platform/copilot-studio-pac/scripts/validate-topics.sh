#!/usr/bin/env bash
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#
# validate-topics.sh
# Cross-platform launcher for the topic-integrity gate (validate-topics.mjs).
# Thin wrapper: runs the Node validator, forwarding all arguments and
# propagating its exit code (0 = all pass, 1 = fail-closed FAIL, 2 = usage/parse
# error). The .mjs holds all logic.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v node &>/dev/null; then
  printf 'ERROR: Node.js is required to run validate-topics.mjs but was not found on PATH.\n' >&2
  exit 2
fi

exec node "${script_dir}/validate-topics.mjs" "$@"
