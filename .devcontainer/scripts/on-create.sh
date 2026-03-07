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
  ACTIONLINT_VERSION="1.7.10"
  ARCH=$(uname -m)
  if [[ "${ARCH}" == "x86_64" ]]; then
    ACTIONLINT_ARCH="amd64"
    ACTIONLINT_SHA256="f4c76b71db5755a713e6055cbb0857ed07e103e028bda117817660ebadb4386f"
  elif [[ "${ARCH}" == "aarch64" ]]; then
    ACTIONLINT_ARCH="arm64"
    ACTIONLINT_SHA256="cd3dfe5f66887ec6b987752d8d9614e59fd22f39415c5ad9f28374623f41773a"
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
  pwsh -NoProfile -Command "Install-Module -Name PowerShell-Yaml -Force -Scope CurrentUser -Repository PSGallery"
  pwsh -NoProfile -Command "Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser -Repository PSGallery"
  pwsh -NoProfile -Command "Install-Module -Name Pester -RequiredVersion 5.7.1 -Force -Scope CurrentUser -Repository PSGallery"

  echo "Installing gitleaks..."
  # Download gitleaks tarball and verify checksum before extracting
  GITLEAKS_VERSION="8.18.2"
  if [[ "${ARCH}" == "x86_64" ]]; then
    GITLEAKS_ARCH="x64"
    GITLEAKS_SHA256="6298c9235dfc9278c14b28afd9b7fa4e6f4a289cb1974bd27949fc1e9122bdee"
  elif [[ "${ARCH}" == "aarch64" ]]; then
    GITLEAKS_ARCH="arm64"
    GITLEAKS_SHA256="4df25683f95b9e1dbb8cc71dac74d10067b8aba221e7f991e01cafa05bcbd030"
  else
    echo "ERROR: Unsupported architecture for gitleaks: ${ARCH}" >&2
    exit 1
  fi
  curl -sSfL "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_${GITLEAKS_ARCH}.tar.gz" -o /tmp/gitleaks.tar.gz
  
  echo "Checking gitleaks tarball integrity..."
  if ! echo "${GITLEAKS_SHA256} /tmp/gitleaks.tar.gz" | sha256sum -c --quiet -; then
    echo "ERROR: SHA256 checksum verification failed for gitleaks tarball" >&2
    rm /tmp/gitleaks.tar.gz
    exit 1
  fi
  sudo tar -xzf /tmp/gitleaks.tar.gz -C /usr/local/bin gitleaks
  rm /tmp/gitleaks.tar.gz

  echo "Installing uv..."
  UV_VERSION="0.10.8"
  UV_ARCH=$(uname -m)
  case "${UV_ARCH}" in
    x86_64)
      UV_SHA256="f0c566b55683395a62fefb9261a060fa09824914b5682c3b9629fa154762ae2f"
      UV_FILE="uv-x86_64-unknown-linux-gnu.tar.gz"
      ;;
    aarch64)
      UV_SHA256="661860e954f87dcd823251191866af3486484d1a9df60eed56f4586ed7559e3d"
      UV_FILE="uv-aarch64-unknown-linux-gnu.tar.gz"
      ;;
    *)
      echo "ERROR: Unsupported architecture for uv: ${UV_ARCH}" >&2
      exit 1
      ;;
  esac
  curl -sSfL "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/${UV_FILE}" -o "/tmp/${UV_FILE}"
  if ! echo "${UV_SHA256} /tmp/${UV_FILE}" | sha256sum -c --quiet -; then
    echo "ERROR: SHA256 checksum verification failed for uv" >&2
    rm -f "/tmp/${UV_FILE}"
    exit 1
  fi
  sudo tar -xzf "/tmp/${UV_FILE}" --strip-components=1 -C /usr/local/bin uv uvx
  rm "/tmp/${UV_FILE}"

  # Sync Python skill dependencies
  find .github/skills -name pyproject.toml -type f -execdir uv sync \;

  echo "System dependencies installed successfully"
}

main "$@"
