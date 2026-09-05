#!/usr/bin/env bash
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
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
