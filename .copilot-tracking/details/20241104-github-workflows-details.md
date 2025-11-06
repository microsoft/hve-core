<!-- markdownlint-disable-file -->
# Task Details: GitHub Workflows with SHA Pinning and Security Hardening

## Research Reference

**Source Research**: .copilot-tracking/research/20241104-github-workflows-research.md

## Phase 1: Create Reusable Workflow Template

### Task 1.1: Create `.github/workflows/reusable-validation.yml`

Create the foundational reusable workflow file that will be called by both PR and main workflows to eliminate duplication and ensure consistent validation across all environments.

* **Files**:
  * `.github/workflows/reusable-validation.yml` - New reusable workflow template with validation jobs
* **Success**:
  * File created with proper workflow_call trigger
  * Contains spell-check, markdown lint, and validation jobs
  * All actions SHA-pinned with version comments
  * Minimal permissions configured
* **Research References**:
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 580-675) - Reusable workflow scenario with complete implementation
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 182-220) - Current SHA pins for all required actions
* **Dependencies**:
  * None - foundational file

### Task 1.2: Configure workflow_call trigger with inputs

Configure the reusable workflow to accept inputs for flexible behavior across different calling contexts (PR vs main branch).

* **Files**:
  * `.github/workflows/reusable-validation.yml` - Update with workflow_call trigger configuration
* **Success**:
  * workflow_call trigger defined
  * Input parameters declared (artifact_retention_days with default 30)
  * Secret inheritance configured (secrets: inherit)
* **Research References**:
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 590-610) - workflow_call trigger syntax and input configuration
* **Dependencies**:
  * Task 1.1 completion

### Task 1.3: Implement validation jobs (spell-check, markdown lint, security scans)

Implement the core validation jobs that will be reused across workflows, including npm-based spell checking, markdown linting, and basic validation steps.

* **Files**:
  * `.github/workflows/reusable-validation.yml` - Add validation jobs with SHA-pinned actions
* **Success**:
  * spell-check job implemented using npm scripts
  * markdown-lint job implemented using npm scripts
  * All jobs use step-security/harden-runner for network hardening
  * All actions SHA-pinned with version comments
  * persist-credentials: false on all checkouts
  * Minimal permissions (contents: read, checks: write)
* **Research References**:
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 620-670) - Complete reusable workflow implementation with job definitions
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 142-148) - Repository npm scripts (spell-check, lint:md)
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 780-830) - Security best practices (SHA pinning, minimal permissions, credential protection)
* **Dependencies**:
  * Task 1.2 completion

## Phase 2: Create PR Validation Workflow

### Task 2.1: Create `.github/workflows/pr-validation.yml`

Create the PR validation workflow that runs on pull requests with soft-fail security scanning to provide feedback without blocking PRs.

* **Files**:
  * `.github/workflows/pr-validation.yml` - New PR validation workflow with security scanning
* **Success**:
  * Workflow file created with pull_request trigger
  * Name set to "PR Validation"
  * Proper file structure with workflow-level permissions
* **Research References**:
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 338-488) - Complete PR validation workflow scenario
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 7-8) - Task requirement for PR validation mandatory before merge
* **Dependencies**:
  * Phase 1 completion (reusable workflow must exist)

### Task 2.2: Configure pull_request trigger and permissions

Configure the workflow to trigger on pull request events with minimal permissions following security best practices.

* **Files**:
  * `.github/workflows/pr-validation.yml` - Add trigger and permissions configuration
* **Success**:
  * pull_request trigger configured for types: [opened, synchronize, reopened]
  * Workflow-level permissions set to contents: read
  * Job-level permissions will be granted as needed
* **Research References**:
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 345-365) - PR validation trigger and permissions configuration
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 793-798) - Minimal permissions best practices
* **Dependencies**:
  * Task 2.1 completion

### Task 2.3: Implement security scanning with soft-fail and artifact uploads

Implement Gitleaks and Checkov security scanning jobs with soft-fail mode for PR feedback and artifact uploads for review.

* **Files**:
  * `.github/workflows/pr-validation.yml` - Add gitleaks-scan and checkov-scan jobs
* **Success**:
  * gitleaks-scan job with soft-fail (continue-on-error: true)
  * checkov-scan job with pip-based installation (NOT bridgecrewio/checkov-action)
  * Both jobs use step-security/harden-runner
  * Artifact uploads with 30-day retention
  * All actions SHA-pinned with version comments
  * Python 3.11 setup for Checkov
* **Research References**:
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 370-470) - PR workflow security scanning implementation with soft-fail
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 90) - DO NOT USE bridgecrewio/checkov-action (outdated March 2022)
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 16) - Use pip-based Checkov installation
  * .copilot-tracking/research/20241104-github-workflows-subagent/checkov-integration-research.md (Lines 1-262) - Complete Checkov action analysis showing pip superiority
* **Dependencies**:
  * Task 2.2 completion

### Task 2.4: Call reusable validation workflow

Add job to call the reusable validation workflow for consistent spell-check and markdown linting.

* **Files**:
  * `.github/workflows/pr-validation.yml` - Add call-reusable-validation job
* **Success**:
  * Job defined using uses: ./.github/workflows/reusable-validation.yml
  * Proper permissions passed (contents: read, checks: write)
  * secrets: inherit configured
* **Research References**:
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 475-488) - Reusable workflow call pattern
* **Dependencies**:
  * Task 2.3 completion
  * Phase 1 completion (reusable workflow must exist)

## Phase 3: Create Main Branch CI Workflow

### Task 3.1: Create `.github/workflows/main.yml`

Create the main branch CI workflow that runs post-merge with strict security scanning and SARIF uploads to Security tab.

* **Files**:
  * `.github/workflows/main.yml` - New main branch CI workflow with strict security
* **Success**:
  * Workflow file created with push trigger for main branch
  * Name set to "Main Branch CI"
  * Proper file structure with workflow-level permissions
* **Research References**:
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 490-578) - Complete main branch workflow scenario
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 8) - Task requirement for main workflow mandatory post-merge
* **Dependencies**:
  * Phase 1 completion (reusable workflow must exist)

### Task 3.2: Configure push trigger for main branch

Configure the workflow to trigger only on pushes to the main branch with minimal permissions.

* **Files**:
  * `.github/workflows/main.yml` - Add trigger and permissions configuration
* **Success**:
  * push trigger configured with branches: [main]
  * Workflow-level permissions set to contents: read
  * security-events: write permission will be granted at job level for SARIF uploads
* **Research References**:
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 497-512) - Main branch trigger and permissions
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 43-47) - Implementation decisions for mandatory post-merge workflow
* **Dependencies**:
  * Task 3.1 completion

### Task 3.3: Implement strict security scanning with SARIF uploads

Implement Gitleaks and Checkov security scanning jobs with strict mode (fail on issues) and SARIF uploads to GitHub Security tab for permanent audit trail.

* **Files**:
  * `.github/workflows/main.yml` - Add gitleaks-scan and checkov-scan jobs with SARIF
* **Success**:
  * gitleaks-scan job with strict mode (continue-on-error: false)
  * checkov-scan job with pip-based installation (NOT bridgecrewio/checkov-action)
  * SARIF uploads using github/codeql-action/upload-sarif
  * Job-level security-events: write permission for SARIF uploads
  * All jobs use step-security/harden-runner
  * All actions SHA-pinned with version comments
  * Python 3.11 setup for Checkov
  * 30-day retention configured via SARIF (automatic)
* **Research References**:
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 518-572) - Main workflow security scanning with SARIF uploads
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 16) - Use pip-based Checkov installation
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 64-69) - SARIF strategy: Security tab uploads with 30-day retention
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 550-560) - SARIF upload configuration with if: always()
* **Dependencies**:
  * Task 3.2 completion

### Task 3.4: Call reusable validation workflow

Add job to call the reusable validation workflow for consistent spell-check and markdown linting.

* **Files**:
  * `.github/workflows/main.yml` - Add call-reusable-validation job
* **Success**:
  * Job defined using uses: ./.github/workflows/reusable-validation.yml
  * Proper permissions passed (contents: read, checks: write, security-events: write)
  * secrets: inherit configured
* **Research References**:
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 574-578) - Main workflow reusable call with security-events permission
* **Dependencies**:
  * Task 3.3 completion
  * Phase 1 completion (reusable workflow must exist)

## Phase 4: Create SHA Staleness Monitoring Workflow

### Task 4.1: Create `.github/workflows/sha-staleness-check.yml`

Create the SHA staleness monitoring workflow that runs weekly to detect outdated SHA pins using repository's existing PowerShell automation scripts.

* **Files**:
  * `.github/workflows/sha-staleness-check.yml` - New staleness monitoring workflow
* **Success**:
  * Workflow file created with name "SHA Staleness Check"
  * Proper file structure with workflow-level permissions
  * Weekly schedule trigger configured
* **Research References**:
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 1015-1132) - Complete SHA staleness workflow scenario
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 9) - Task requirement for weekly staleness monitoring
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 56-61) - SHA staleness decisions: weekly, warnings only, complements Dependabot
* **Dependencies**:
  * None - independent workflow

### Task 4.2: Configure weekly schedule and manual dispatch

Configure the workflow to run automatically every Sunday at midnight UTC with manual dispatch option for ad-hoc checks.

* **Files**:
  * `.github/workflows/sha-staleness-check.yml` - Add schedule and workflow_dispatch triggers
* **Success**:
  * schedule trigger with cron: '0 0 * * 0' (Sunday midnight UTC)
  * workflow_dispatch trigger with threshold input (type: number, default: 30)
  * Workflow-level permissions set to contents: read
  * No issues: write permission (warnings only, no automatic issue creation)
* **Research References**:
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 1021-1043) - Schedule and manual dispatch configuration
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 56-61) - Weekly frequency, warnings only (no automatic issues)
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 835-855) - Implemented workflow integration with warnings-only approach
* **Dependencies**:
  * Task 4.1 completion

### Task 4.3: Implement staleness check with repository scripts

Implement the staleness check job using repository's `Test-SHAStaleness.ps1` PowerShell script with GitHub annotations output format.

* **Files**:
  * `.github/workflows/sha-staleness-check.yml` - Add check-staleness job
* **Success**:
  * check-staleness job with ubuntu-latest runner
  * step-security/harden-runner configured
  * actions/checkout with SHA pinning
  * PowerShell script execution with -OutputFormat github
  * Threshold input handling (default 30 days)
  * GITHUB_TOKEN environment variable configured
  * Artifact upload for JSON report with 30-day retention
  * if: always() on artifact upload
* **Research References**:
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 1045-1110) - Complete staleness check job implementation
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 143-145) - Repository script Test-SHAStaleness.ps1 documentation
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 915-935) - Test-SHAStaleness.ps1 capabilities (GraphQL, multiple output formats)
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 1105-1110) - Key features: weekly schedule, warnings only, complements Dependabot
* **Dependencies**:
  * Task 4.2 completion
  * Repository script scripts/security/Test-SHAStaleness.ps1 must exist

## Phase 5: Configure Repository Security Settings

### Task 5.1: Create `.github/CODEOWNERS` file

Create CODEOWNERS file to require core project admin approval for workflow file changes, ensuring workflow security is protected.

* **Files**:
  * `.github/CODEOWNERS` - New code owners configuration
* **Success**:
  * File created with workflow file pattern (.github/workflows/*)
  * Core project admins configured as owners (@microsoft/hve-core-admins)
  * Security scripts pattern excluded from separate approval
  * Proper comment documentation
* **Research References**:
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 10) - Task requirement for CODEOWNERS with core admin approval
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 48-54) - CODEOWNERS configuration decisions
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 1150-1158) - CODEOWNERS implementation requirements with example
* **Dependencies**:
  * None - configuration file

### Task 5.2: Document branch protection rule configuration

Create documentation file explaining the required GitHub branch protection rule configuration to enforce workflow requirements.

* **Files**:
  * `.github/BRANCH_PROTECTION.md` - New branch protection documentation
* **Success**:
  * Document created explaining required settings
  * Target branch: main
  * Required status checks: pr-validation workflow
  * Required code owner reviews enabled
  * Clear step-by-step configuration guide
  * Screenshots or UI path guidance included
* **Research References**:
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 11) - Task requirement for branch protection configuration
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 41-47) - Branch protection decisions: both workflows mandatory
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 1160-1171) - Branch protection implementation requirements with settings
* **Dependencies**:
  * All workflow files created (Phase 1-4 completion)

### Task 5.3: Create workflow documentation README

Create comprehensive README documenting all workflows, their purposes, triggers, and maintenance procedures.

* **Files**:
  * `.github/workflows/README.md` - New workflow documentation
* **Success**:
  * Document created with overview of all 4 workflows
  * Each workflow documented with purpose, triggers, and jobs
  * Security best practices section (SHA pinning, permissions, credential protection)
  * Maintenance section (Dependabot + PowerShell scripts)
  * SARIF upload and Security tab integration explained
  * Staleness monitoring and update procedures documented
  * Links to research and subagent documents
* **Research References**:
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 1-1188) - Complete research document with all implementation details
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 780-875) - Security best practices and ongoing maintenance
  * .copilot-tracking/research/20241104-github-workflows-research.md (Lines 877-1012) - 12 Key Findings from SHA pinning scripts
  * .copilot-tracking/research/20241104-github-workflows-subagent/checkov-integration-research.md (Lines 1-262) - Checkov integration research
* **Dependencies**:
  * All workflow files created (Phase 1-4 completion)

## Dependencies

* GitHub-hosted ubuntu-latest runners
* Repository npm scripts (spell-check, lint:md, security:scan, security:checkov:report)
* Repository PowerShell scripts (scripts/security/Test-SHAStaleness.ps1)
* GitHub Security tab access for SARIF uploads
* Dependabot configuration (complements SHA staleness monitoring)
* Python 3.11 for Checkov installation
* PowerShell 7.0+ for staleness checks

## Success Criteria

* All 4 workflow files created (.github/workflows/pr-validation.yml, main.yml, reusable-validation.yml, sha-staleness-check.yml)
* CODEOWNERS file created (.github/CODEOWNERS)
* Branch protection documentation created (.github/BRANCH_PROTECTION.md)
* Workflow documentation README created (.github/workflows/README.md)
* All actions SHA-pinned with version comments (40+ actions from research)
* PR validation uses soft-fail security scanning with artifact uploads
* Main workflow uses strict security scanning with SARIF uploads to Security tab
* SHA staleness monitoring runs weekly with warnings only (no automatic issues)
* All workflows use minimal permissions (contents: read default)
* All workflows use credential protection (persist-credentials: false)
* All workflows use network hardening (step-security/harden-runner)
* Reusable workflow eliminates duplication across primary workflows
* 30-day retention policy configured for security results
* Workflows complement existing Dependabot configuration
