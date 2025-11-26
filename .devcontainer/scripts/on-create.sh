#!/usr/bin/env bash
#
# on-create.sh
# Install system dependencies for HVE Core development container

set -euo pipefail

main() {
  echo "Installing system dependencies..."
  
  sudo apt update
  sudo apt install -y shellcheck
  
  # Dependencies are pinned for stability. Dependabot and security workflows manage updates.
  echo "Installing gitleaks..."
  curl -sSfL https://github.com/gitleaks/gitleaks/releases/download/v8.18.2/gitleaks_8.18.2_linux_x64.tar.gz | \
    sudo tar -xz -C /usr/local/bin gitleaks
  
  echo "System dependencies installed successfully"
}

main "$@"
