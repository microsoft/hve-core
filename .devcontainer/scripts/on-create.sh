#!/usr/bin/env bash
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#
# on-create.sh
# Install system dependencies for HVE Core development container

set -euo pipefail

sync_python_environments() {
  local repo_root
  local project_file
  local project_dir
  local failed=0

  repo_root="$(cd "${1}" && pwd)"

  while IFS= read -r -d '' project_file; do
    project_dir="$(dirname "${project_file}")"
    echo "Installing dependencies in ${project_dir}"

    if [[ ! -f "${project_dir}/uv.lock" ]]; then
      echo "ERROR: Missing uv.lock in ${project_dir}" >&2
      failed=1
      continue
    fi

    if ! (cd "${project_dir}" && uv sync --locked); then
      echo "ERROR: uv sync --locked failed in ${project_dir}" >&2
      failed=1
    fi
  done < <(
    find "${repo_root}" \
      -type d \( \
        -name node_modules -o \
        -path "${repo_root}/plugins" -o \
        -path "${repo_root}/scripts/evals/moderation" -o \
        -path "${repo_root}/scripts/tools" \
      \) -prune -o \
      -type f -name pyproject.toml -print0
  )

  return "${failed}"
}

main() {
  # Enterprise artifact hub overrides (public defaults when unset)
  GITHUB_RELEASES_URL="${HVE_GITHUB_RELEASES_URL:-https://github.com}"
  PSGALLERY_REPO="${HVE_PSGALLERY_REPOSITORY:-PSGallery}"
  PSGALLERY_SOURCE="${HVE_PSGALLERY_SOURCE_URL:-}"

  echo "Installing system dependencies..."

  # The pinned shellcheck release is a .tar.xz archive; only xz comes from the distribution.
  if ! command -v xz >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y xz-utils
  fi
  
  # Dependencies are pinned for stability. Dependabot and security workflows manage updates.
  ARCH=$(uname -m)

  echo "Installing shellcheck..."
  # The workflow validator requires this exact version; the distribution
  # package is older and unpinned.
  SHELLCHECK_VERSION="0.11.0"
  if [[ "${ARCH}" == "x86_64" ]]; then
    SHELLCHECK_ARCH="x86_64"
    SHELLCHECK_SHA256="8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198"
  elif [[ "${ARCH}" == "aarch64" ]]; then
    SHELLCHECK_ARCH="aarch64"
    SHELLCHECK_SHA256="12b331c1d2db6b9eb13cfca64306b1b157a86eb69db83023e261eaa7e7c14588"
  else
    echo "ERROR: Unsupported architecture for shellcheck: ${ARCH}" >&2
    exit 1
  fi
  curl -sSfL "${GITHUB_RELEASES_URL}/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/shellcheck-v${SHELLCHECK_VERSION}.linux.${SHELLCHECK_ARCH}.tar.xz" -o /tmp/shellcheck.tar.xz

  echo "Checking shellcheck tarball integrity..."
  if ! echo "${SHELLCHECK_SHA256}  /tmp/shellcheck.tar.xz" | sha256sum -c --quiet -; then
    echo "ERROR: SHA256 checksum verification failed for shellcheck tarball" >&2
    rm /tmp/shellcheck.tar.xz
    exit 1
  fi
  sudo tar -xJf /tmp/shellcheck.tar.xz -C /usr/local/bin --strip-components=1 "shellcheck-v${SHELLCHECK_VERSION}/shellcheck"
  rm /tmp/shellcheck.tar.xz

  echo "Installing zizmor..."
  # GitHub Actions static analysis at the version PR validation gates on.
  ZIZMOR_VERSION="1.30.1"
  if [[ "${ARCH}" == "x86_64" ]]; then
    ZIZMOR_SHA256="e65324f4430c2717591937edcec90ccbefaf14c174f8ec9415e03ca875b46e1a"
  elif [[ "${ARCH}" == "aarch64" ]]; then
    ZIZMOR_SHA256="7ff1dce33bdd18fd2a4affe63bdd47efcccca97b2cec1c1863ec26e9e2647540"
  else
    echo "ERROR: Unsupported architecture for zizmor: ${ARCH}" >&2
    exit 1
  fi
  curl -sSfL "${GITHUB_RELEASES_URL}/zizmorcore/zizmor/releases/download/v${ZIZMOR_VERSION}/zizmor-${ARCH}-unknown-linux-gnu.tar.gz" -o /tmp/zizmor.tar.gz

  echo "Checking zizmor tarball integrity..."
  if ! echo "${ZIZMOR_SHA256}  /tmp/zizmor.tar.gz" | sha256sum -c --quiet -; then
    echo "ERROR: SHA256 checksum verification failed for zizmor tarball" >&2
    rm /tmp/zizmor.tar.gz
    exit 1
  fi
  sudo tar -xzf /tmp/zizmor.tar.gz -C /usr/local/bin zizmor
  rm /tmp/zizmor.tar.gz

  echo "Installing PowerShell modules..."
  if [[ -n "${PSGALLERY_SOURCE}" ]]; then
    # shellcheck disable=SC2016  # PowerShell expands these environment variables.
    PSGALLERY_REPO="${PSGALLERY_REPO}" PSGALLERY_SOURCE="${PSGALLERY_SOURCE}" \
      pwsh -NoProfile -Command 'Register-PSRepository -Name $env:PSGALLERY_REPO -SourceLocation $env:PSGALLERY_SOURCE -InstallationPolicy Trusted -ErrorAction SilentlyContinue'
  fi
  pwsh -NoProfile -File scripts/security/Install-PSModules.ps1 -Repository "${PSGALLERY_REPO}"

  echo "Installing gitleaks..."
  # Download gitleaks tarball and verify checksum before extracting
  GITLEAKS_VERSION="8.30.0"
  if [[ "${ARCH}" == "x86_64" ]]; then
    GITLEAKS_ARCH="x64"
    GITLEAKS_SHA256="79a3ab579b53f71efd634f3aaf7e04a0fa0cf206b7ed434638d1547a2470a66e"
  elif [[ "${ARCH}" == "aarch64" ]]; then
    GITLEAKS_ARCH="arm64"
    GITLEAKS_SHA256="b4cbbb6ddf7d1b2a603088cd03a4e3f7ce48ee7fd449b51f7de6ee2906f5fa2f"
  else
    echo "ERROR: Unsupported architecture for gitleaks: ${ARCH}" >&2
    exit 1
  fi
  curl -sSfL "${GITHUB_RELEASES_URL}/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_${GITLEAKS_ARCH}.tar.gz" -o /tmp/gitleaks.tar.gz
  
  echo "Checking gitleaks tarball integrity..."
  if ! echo "${GITLEAKS_SHA256}  /tmp/gitleaks.tar.gz" | sha256sum -c --quiet -; then
    echo "ERROR: SHA256 checksum verification failed for gitleaks tarball" >&2
    rm /tmp/gitleaks.tar.gz
    exit 1
  fi
  sudo tar -xzf /tmp/gitleaks.tar.gz -C /usr/local/bin gitleaks
  rm /tmp/gitleaks.tar.gz

  echo "Installing cosign..."
  COSIGN_VERSION="3.0.5"
  if [[ "${ARCH}" == "x86_64" ]]; then
    COSIGN_ARCH="amd64"
    COSIGN_SHA256="db15cc99e6e4837daabab023742aaddc3841ce57f193d11b7c3e06c8003642b2"
  elif [[ "${ARCH}" == "aarch64" ]]; then
    COSIGN_ARCH="arm64"
    COSIGN_SHA256="d098f3168ae4b3aa70b4ca78947329b953272b487727d1722cb3cb098a1a20ab"
  else
    echo "ERROR: Unsupported architecture for cosign: ${ARCH}" >&2
    exit 1
  fi
  curl -sSfL "${GITHUB_RELEASES_URL}/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-linux-${COSIGN_ARCH}" -o /tmp/cosign

  echo "Checking cosign binary integrity..."
  if ! echo "${COSIGN_SHA256}  /tmp/cosign" | sha256sum -c --quiet -; then
    echo "ERROR: SHA256 checksum verification failed for cosign binary" >&2
    rm /tmp/cosign
    exit 1
  fi
  sudo install /tmp/cosign /usr/local/bin/cosign
  rm /tmp/cosign

  echo "Installing osv-scanner..."
  OSV_SCANNER_VERSION="2.3.8"
  if [[ "${ARCH}" == "x86_64" ]]; then
    OSV_ARCH="amd64"
    OSV_SCANNER_SHA256="bc98e15319ed0d515e3f9235287ba53cdc5535d576d24fd573978ecfe9ab92dc"
  elif [[ "${ARCH}" == "aarch64" ]]; then
    OSV_ARCH="arm64"
    OSV_SCANNER_SHA256="8158b18edd2d03b1a30d905ca91b032bc62262167be8f206c27114f08823e27c"
  else
    echo "ERROR: Unsupported architecture for osv-scanner: ${ARCH}" >&2
    exit 1
  fi
  curl -sSfL "${GITHUB_RELEASES_URL}/google/osv-scanner/releases/download/v${OSV_SCANNER_VERSION}/osv-scanner_linux_${OSV_ARCH}" -o /tmp/osv-scanner

  echo "Checking osv-scanner binary integrity..."
  if ! echo "${OSV_SCANNER_SHA256}  /tmp/osv-scanner" | sha256sum -c --quiet -; then
    echo "ERROR: SHA256 checksum verification failed for osv-scanner binary" >&2
    rm /tmp/osv-scanner
    exit 1
  fi
  sudo install /tmp/osv-scanner /usr/local/bin/osv-scanner
  rm /tmp/osv-scanner

  echo "Installing uv package manager..."
  # Dependencies are pinned for stability. Dependabot and security workflows manage updates.
  UV_VERSION="0.10.9"
  if [[ "${ARCH}" == "x86_64" ]]; then
    UV_ARCH="x86_64-unknown-linux-gnu"
    UV_SHA256="20d79708222611fa540b5c9ed84f352bcd3937740e51aacc0f8b15b271c57594"
  elif [[ "${ARCH}" == "aarch64" ]]; then
    UV_ARCH="aarch64-unknown-linux-gnu"
    UV_SHA256="cc0c5a8573e7d6d78aecb954e0a62b5c0d18217bb81f1e19363b428c57a9962a"
  else
    echo "ERROR: Unsupported architecture for uv: ${ARCH}" >&2
    exit 1
  fi
  curl -sSfL "${GITHUB_RELEASES_URL}/astral-sh/uv/releases/download/${UV_VERSION}/uv-${UV_ARCH}.tar.gz" -o /tmp/uv.tar.gz

  echo "Checking uv tarball integrity..."
  if ! echo "${UV_SHA256}  /tmp/uv.tar.gz" | sha256sum -c --quiet -; then
    echo "ERROR: SHA256 checksum verification failed for uv tarball" >&2
    rm -f /tmp/uv.tar.gz
    exit 1
  fi
  sudo tar -xzf /tmp/uv.tar.gz -C /usr/local/bin --strip-components=1 "uv-${UV_ARCH}/uv" "uv-${UV_ARCH}/uvx"
  rm /tmp/uv.tar.gz

  echo "Syncing lint-eligible Python environments..."
  if ! sync_python_environments "."; then
    echo "ERROR: One or more Python environment installations failed" >&2
    exit 1
  fi

  echo "Syncing Python environment for moderation eval..."
  (cd scripts/evals/moderation && uv sync --locked)

  echo "System dependencies installed successfully"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
