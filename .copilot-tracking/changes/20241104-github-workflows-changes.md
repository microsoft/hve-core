# Changes: GitHub Workflows with SHA Pinning and Security Hardening

**Date**: November 4, 2025  
**Implementation Plan**: `.copilot-tracking/plans/20241104-github-workflows-plan.instructions.md`

## Summary

Implementing comprehensive GitHub Actions workflows for PR validation and main branch CI with security best practices.

## Current State Analysis

**Discovered**: Workflow files already exist but need comprehensive updates:
* `.github/workflows/reusable-validation.yml` - Exists but needs restructuring
* `.github/workflows/pr-validation.yml` - Exists but uses outdated bridgecrewio/checkov-action
* `.github/workflows/main.yml` - Exists but uses outdated bridgecrewio/checkov-action
* `.github/workflows/checkov-scan.yml` - Standalone scan workflow (may consolidate)
* `.github/workflows/gitleaks.yml` - Standalone scan workflow (may consolidate)

**Key Issues to Fix**:
1. Remove outdated `bridgecrewio/checkov-action` (use npm scripts instead)
2. Update all SHA pins to latest versions from research
3. Implement proper SARIF upload strategy to Security tab
4. Restructure reusable workflow to match research requirements
5. Add proper artifact uploads with 30-day retention
6. Fix security scanning approach (soft-fail for PR, strict for main)

**Approach**: Update existing files rather than create new ones

## Changes Made

### Phase 1: Update Reusable Workflow Template ✅

**File**: `.github/workflows/reusable-validation.yml`

* Updated workflow_call inputs to support flexible security scanning modes
  * Added `run-security-scans` (boolean, default: true)
  * Added `soft-fail-security` (boolean, default: false) 
  * Added `upload-sarif` (boolean, default: false)
  * Removed unused `node-version` and `runs-on` inputs
* Split validation into separate jobs for better parallelization
  * `spell-check` - Independent spell checking job
  * `markdown-lint` - Independent markdown validation job
  * `security-scans` - Conditional security scanning job
* Updated all SHA pins to latest versions
  * step-security/harden-runner: v2.10.2
  * actions/checkout: v4.2.2
  * actions/setup-node: v4.1.0
  * actions/setup-python: v5.3.0
  * actions/upload-artifact: v4.4.3
  * github/codeql-action/upload-sarif: v3.27.0
* Removed outdated `bridgecrewio/checkov-action` (replaced with pip install)
* Implemented pip-based Checkov installation (modern version, not outdated action)
* Added conditional SARIF upload vs artifact upload based on input
* Added `continue-on-error` support for soft-fail security mode
* Set 30-day retention policy for all artifacts

### Phase 2: Update PR Validation Workflow ✅

**File**: `.github/workflows/pr-validation.yml`

* Simplified workflow to only call reusable workflow (eliminated duplication)
* Removed inline validation steps (now in reusable workflow)
* Removed outdated `bridgecrewio/checkov-action` usage
* Configured for soft-fail security scanning
  * `soft-fail-security: true` - Continue on security errors
  * `upload-sarif: false` - Upload artifacts instead of SARIF
* Updated permissions to minimal required set
* Removed `develop` branch trigger (main only per requirements)

### Phase 3: Update Main Branch CI Workflow ✅

**File**: `.github/workflows/main.yml`

* Simplified workflow to only call reusable workflow (eliminated duplication)
* Removed inline validation steps (now in reusable workflow)
* Removed outdated `bridgecrewio/checkov-action` usage
* Configured for strict security scanning
  * `soft-fail-security: false` - Fail workflow on security errors
  * `upload-sarif: true` - Upload SARIF to Security tab
* Updated permissions to include `security-events: write` for SARIF upload

### Phase 4: Create SHA Staleness Monitoring Workflow ✅

**File**: `.github/workflows/sha-staleness-check.yml` (NEW)

* Created weekly scheduled workflow (Sunday midnight UTC)
* Added manual dispatch with configurable threshold parameter
* Integrated with repository's `Test-SHAStaleness.ps1` PowerShell script
* Configured warnings-only mode (no automatic failures)
* Default 30-day staleness threshold
* SHA-pinned actions with latest versions
* Minimal permissions (contents: read only)

### Phase 5: Configure Repository Security Settings ✅

#### CODEOWNERS

**File**: `.github/CODEOWNERS` (NEW)

* Created CODEOWNERS file requiring core admin approval for:
  * `.github/workflows/*` - All workflow changes
  * `scripts/security/*` - All security automation scripts
* Configured owner: `@microsoft/hve-core-admins`

#### Branch Protection Documentation

**File**: `.github/BRANCH_PROTECTION.md` (NEW)

* Documented required branch protection rules for main branch
* Specified required status checks (pr-validation workflow)
* Documented pull request requirements (1 approval, code owner review)
* Included emergency procedures and bypass documentation
* Added monitoring and maintenance procedures
* Cross-referenced related documentation

#### Workflow Documentation

**File**: `.github/workflows/README.md` (NEW)

* Comprehensive documentation of all workflows
* Architecture diagrams showing workflow relationships
* Security best practices documentation
  * SHA pinning conventions
  * Minimal permissions principle
  * Credential protection
  * Network hardening
* Maintenance procedures and Dependabot integration
* Contributing guidelines for workflow changes

## Summary

**Total Files Created**: 4

* `sha-staleness-check.yml`
* `CODEOWNERS`
* `BRANCH_PROTECTION.md`
* `workflows/README.md`

**Total Files Updated**: 3

* `reusable-validation.yml`
* `pr-validation.yml`
* `main.yml`

**Key Improvements**:

* ✅ Removed outdated `bridgecrewio/checkov-action` (replaced with pip-based installation)
* ✅ Updated all SHA pins to latest versions (8 actions updated)
* ✅ Implemented proper SARIF upload strategy (Security tab with 30-day retention)
* ✅ Added soft-fail vs strict security scanning modes
* ✅ Eliminated code duplication with reusable workflow
* ✅ Added SHA staleness monitoring (complements Dependabot)
* ✅ Created CODEOWNERS for workflow protection
* ✅ Documented branch protection requirements
* ✅ Created comprehensive workflow documentation

**Security Enhancements**:

* All actions SHA-pinned with full 40-character commits
* Minimal permissions throughout (contents: read by default)
* Network hardening with step-security/harden-runner
* Credential protection with persist-credentials: false
* SARIF uploads to Security tab for vulnerability tracking
* Code owner approval required for workflow changes

