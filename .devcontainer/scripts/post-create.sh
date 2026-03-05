#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#
# post-create.sh
# Post-creation setup for HVE Core development container

set -euo pipefail

main() {
  echo "Creating logs directory..."
  mkdir -p logs
}

main "$@"
