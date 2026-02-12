#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#
# post-create.sh
# Install NPM dependencies for HVE Core development container

set -euo pipefail

main() {
  echo "Creating logs directory..."
  mkdir -p logs

  echo "Installing NPM dependencies..."
  npm ci
  echo "NPM dependencies installed successfully"
}

main "$@"
