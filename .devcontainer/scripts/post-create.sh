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

	fix_volume_ownerships
  npm_install
}

# Volume ownership is not set automatically due to a bug:
# https://github.com/microsoft/vscode-remote-release/issues/9931
#
# IMPORTANT: workaround requires Docker base image to have password-less sudo.
fix_volume_ownership() {
  local volume_path="$1"

  if [[ ! -d "$volume_path" ]]; then
    echo "ERROR: the volume path provided '$volume_path' does not exist."
    exit 1
  fi

  echo "Setting volume ownership for $volume_path"
  sudo -n chown "${USER}":"${USER}" "$volume_path"
}

fix_volume_ownerships() {
  echo "Applying volume ownership workaround (see microsoft/vscode-remote-release#9931)..."
  fix_volume_ownership "/home/${USER}/.config"
  fix_volume_ownership "/workspace/node_modules"
}

npm_install() {
  echo "Installing NPM dependencies..."
  npm install
  echo "NPM dependencies installed successfully"
}

main "$@"
