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
  echo "Installing actionlint..."
  ACTIONLINT_VERSION="1.7.7"
  ARCH=$(uname -m)
  if [[ "${ARCH}" == "x86_64" ]]; then
    ACTIONLINT_ARCH="amd64"
    ACTIONLINT_SHA256="023070a287cd8cccd71515fedc843f1985bf96c436b7effaecce67290e7e0757"
  elif [[ "${ARCH}" == "aarch64" ]]; then
    ACTIONLINT_ARCH="arm64"
    ACTIONLINT_SHA256="401942f9c24ed71e4fe71b76c7d638f66d8633575c4016efd2977ce7c28317d0"
  else
    echo "ERROR: Unsupported architecture: ${ARCH}" >&2
    exit 1
  fi
  curl -sSfL "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION}_linux_${ACTIONLINT_ARCH}.tar.gz" -o /tmp/actionlint.tar.gz

  echo "Checking actionlint tarball integrity..."
  if ! echo "${ACTIONLINT_SHA256} /tmp/actionlint.tar.gz" | sha256sum -c --quiet -; then
    echo "ERROR: SHA256 checksum verification failed for actionlint tarball" >&2
    rm /tmp/actionlint.tar.gz
    exit 1
  fi
  sudo tar -xzf /tmp/actionlint.tar.gz -C /usr/local/bin actionlint
  rm /tmp/actionlint.tar.gz

  echo "Installing PowerShell modules..."
  pwsh -NoProfile -Command "Install-Module -Name powershell-yaml -Force -Scope CurrentUser -Repository PSGallery"

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
