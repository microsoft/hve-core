#!/usr/bin/env bash
#
# post-create.sh
# Install NPM dependencies for HVE Core development container

set -euo pipefail

main() {
  echo "Installing NPM dependencies..."
  npm ci
  echo "NPM dependencies installed successfully"
}

main "$@"
