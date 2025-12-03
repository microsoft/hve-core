#!/usr/bin/env bash
#
# post-create.sh
# Install NPM dependencies for HVE Core development container

set -euo pipefail

# Volume ownership is not set automatically due to a bug:
# https://github.com/microsoft/vscode-remote-release/issues/9931
#
# IMPORTANT: workaround requires Docker base image to have password-less sudo.
function fix_volume_ownership() {
  volume_path="$1"

  if [ ! -d "$volume_path" ]; then
    echo "ERROR: the volume path provided '$volume_path' does not exist."
    exit 1
  fi

  echo "Setting volume ownership for $volume_path"
  sudo chown "$USER:$USER" "$volume_path"
}

function fix_volume_ownerships() {
  echo "Applying volume ownership workaround (see microsoft/vscode-remote-release#9931)..."
  fix_volume_ownership "/home/${USER}/.config"
  fix_volume_ownership "/workspace/node_modules"
}

function npm_install() {
  echo "Installing NPM dependencies..."
  npm install
  echo "NPM dependencies installed successfully"
}

function update_ca_certs() {
  # Adds a root CA to the system certificate store. Useful if developer machines
  # have MITM TLS inspection happening, e.g. with ZScaler.
  echo "Updating container system CA certificates..."
  if compgen -G ".devcontainer/*.crt" > /dev/null; then
    sudo cp .devcontainer/*.crt /usr/local/share/ca-certificates/
    sudo update-ca-certificates
  fi
  echo "Container's system CA certificates updated successfully"
}

main() {
  fix_volume_ownerships
  npm_install
  update_ca_certs
}

main "$@"
