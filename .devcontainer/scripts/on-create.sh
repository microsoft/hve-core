#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
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
  # Download gitleaks tarball and verify checksum before extracting
  EXPECTED_SHA256="6298c9235dfc9278c14b28afd9b7fa4e6f4a289cb1974bd27949fc1e9122bdee"
  curl -sSfL https://github.com/gitleaks/gitleaks/releases/download/v8.18.2/gitleaks_8.18.2_linux_x64.tar.gz -o /tmp/gitleaks.tar.gz
  
  echo "Checking gitleaks tarball integrity..."
  if ! echo "${EXPECTED_SHA256} /tmp/gitleaks.tar.gz" | sha256sum -c --quiet -; then
    echo "ERROR: SHA256 checksum verification failed for gitleaks tarball" >&2
    rm /tmp/gitleaks.tar.gz
    exit 1
  fi
  sudo tar -xzf /tmp/gitleaks.tar.gz -C /usr/local/bin gitleaks
  rm /tmp/gitleaks.tar.gz
  
  echo "System dependencies installed successfully"
}

main "$@"
