---
applyTo: '.copilot-tracking/changes/20241104-github-workflows-changes.md'
---
<!-- markdownlint-disable-file -->
# Task Checklist: GitHub Workflows with SHA Pinning and Security Hardening

## Overview

Implement comprehensive GitHub Actions workflows for PR validation and main branch CI with security best practices including SHA pinning, minimal permissions, reusable templates, and automated staleness monitoring.

Follow all instructions from #file:../../.github/instructions/task-implementation.instructions.md

## Objectives

* Create PR validation workflow with soft-fail security scanning for feedback
* Create main branch CI workflow with strict security scanning and SARIF uploads
* Implement reusable workflow template to eliminate duplication
* Create SHA staleness monitoring workflow with weekly schedule
* Configure CODEOWNERS file requiring core admin approval for workflow changes
* Document branch protection rules for enforcing workflow requirements

## Research Summary

### Project Files
* `package.json` - Contains npm scripts for security tooling (checkov, gitleaks, spell-check, markdown lint)
* `scripts/security/*.ps1` - 5 PowerShell scripts for comprehensive SHA pinning automation
* `.github/workflows/` - Target directory for new workflow files

### External References
* .copilot-tracking/research/20241104-github-workflows-research.md - Complete implementation research with 12 key findings
* .copilot-tracking/research/20241104-github-workflows-subagent/checkov-integration-research.md - Checkov action analysis (outdated, use pip)
* "step-security/harden-runner" - Network hardening for GitHub Actions
* "github/codeql-action/upload-sarif" - SARIF upload for Security tab integration

### Standards References
* #file:../../.github/instructions/markdown.instructions.md - Markdown conventions for workflow documentation
* GitHub Actions security best practices - SHA pinning, minimal permissions, credential protection

## Implementation Checklist

### [ ] Phase 1: Create Reusable Workflow Template

* [ ] Task 1.1: Create `.github/workflows/reusable-validation.yml`
  * Details: .copilot-tracking/details/20241104-github-workflows-details.md (Lines 30-82)

* [ ] Task 1.2: Configure workflow_call trigger with inputs
  * Details: .copilot-tracking/details/20241104-github-workflows-details.md (Lines 84-124)

* [ ] Task 1.3: Implement validation jobs (spell-check, markdown lint, security scans)
  * Details: .copilot-tracking/details/20241104-github-workflows-details.md (Lines 126-198)

### [ ] Phase 2: Create PR Validation Workflow

* [ ] Task 2.1: Create `.github/workflows/pr-validation.yml`
  * Details: .copilot-tracking/details/20241104-github-workflows-details.md (Lines 200-242)

* [ ] Task 2.2: Configure pull_request trigger and permissions
  * Details: .copilot-tracking/details/20241104-github-workflows-details.md (Lines 244-268)

* [ ] Task 2.3: Implement security scanning with soft-fail and artifact uploads
  * Details: .copilot-tracking/details/20241104-github-workflows-details.md (Lines 270-324)

* [ ] Task 2.4: Call reusable validation workflow
  * Details: .copilot-tracking/details/20241104-github-workflows-details.md (Lines 326-348)

### [ ] Phase 3: Create Main Branch CI Workflow

* [ ] Task 3.1: Create `.github/workflows/main.yml`
  * Details: .copilot-tracking/details/20241104-github-workflows-details.md (Lines 350-390)

* [ ] Task 3.2: Configure push trigger for main branch
  * Details: .copilot-tracking/details/20241104-github-workflows-details.md (Lines 392-414)

* [ ] Task 3.3: Implement strict security scanning with SARIF uploads
  * Details: .copilot-tracking/details/20241104-github-workflows-details.md (Lines 416-482)

* [ ] Task 3.4: Call reusable validation workflow
  * Details: .copilot-tracking/details/20241104-github-workflows-details.md (Lines 484-506)

### [ ] Phase 4: Create SHA Staleness Monitoring Workflow

* [ ] Task 4.1: Create `.github/workflows/sha-staleness-check.yml`
  * Details: .copilot-tracking/details/20241104-github-workflows-details.md (Lines 508-548)

* [ ] Task 4.2: Configure weekly schedule and manual dispatch
  * Details: .copilot-tracking/details/20241104-github-workflows-details.md (Lines 550-582)

* [ ] Task 4.3: Implement staleness check with repository scripts
  * Details: .copilot-tracking/details/20241104-github-workflows-details.md (Lines 584-634)

### [ ] Phase 5: Configure Repository Security Settings

* [ ] Task 5.1: Create `.github/CODEOWNERS` file
  * Details: .copilot-tracking/details/20241104-github-workflows-details.md (Lines 636-668)

* [ ] Task 5.2: Document branch protection rule configuration
  * Details: .copilot-tracking/details/20241104-github-workflows-details.md (Lines 670-714)

* [ ] Task 5.3: Create workflow documentation README
  * Details: .copilot-tracking/details/20241104-github-workflows-details.md (Lines 716-768)

## Dependencies

* GitHub-hosted ubuntu-latest runners
* Repository npm scripts (spell-check, lint:md, security:scan, security:checkov:report)
* Repository PowerShell scripts (scripts/security/Test-SHAStaleness.ps1)
* GitHub Security tab access for SARIF uploads
* Dependabot configuration (complements SHA staleness monitoring)

## Success Criteria

* All 4 workflow files created with SHA-pinned actions and version comments
* PR validation workflow runs on pull requests with soft-fail security scanning
* Main workflow runs on main branch with strict security scanning
* SHA staleness monitoring runs weekly with warning annotations only
* CODEOWNERS file protects workflow files requiring core admin approval
* Branch protection documentation guides repository configuration
* All workflows use minimal permissions and credential protection
* Security scan results uploaded to Security tab with 30-day retention
* Reusable workflow eliminates duplication across primary workflows
