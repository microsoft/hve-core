<!-- markdownlint-disable-file -->
# Task Details: Modular GitHub Actions Workflow Architecture

## Research Reference

**Source Research**: .copilot-tracking/research/20241104-modular-workflows-research.md

## Phase 1: Create Validation Workflows

### Task 1.1: Create reusable-spell-check.yml with result publishing

Create new reusable workflow for cspell validation with comprehensive result publishing.

* **Files**:
  * .github/workflows/reusable-spell-check.yml - New workflow (create)
* **Success**:
  * Workflow accepts `soft-fail` input (boolean, default: false)
  * Uses harden-runner, SHA-pinned actions, minimal permissions
  * Runs `npm run spell-check` with output capture
  * Creates PR annotations for spelling errors
  * Generates job summary with error counts and top errors
  * Uploads spell-check-output.txt artifact (30-day retention)
  * Fails job after publishing if errors found (respects soft-fail)
* **Research References**:
  * .copilot-tracking/research/20241104-modular-workflows-research.md (Lines 730-825) - Complete spell-check workflow implementation
  * .copilot-tracking/research/20241104-modular-workflows-research.md (Lines 283-291) - Principle 8: Descriptive Naming
  * .copilot-tracking/research/20241104-modular-workflows-research.md (Lines 257-275) - Principle 7: Result Publishing
* **Dependencies**:
  * None - can be created independently

### Task 1.2: Create reusable-markdown-lint.yml with result publishing

Create new reusable workflow for markdownlint validation with comprehensive result publishing.

* **Files**:
  * .github/workflows/reusable-markdown-lint.yml - New workflow (create)
* **Success**:
  * Workflow accepts `soft-fail` input (boolean, default: false)
  * Uses harden-runner, SHA-pinned actions, minimal permissions
  * Runs `npm run lint:md` with output capture
  * Creates PR annotations for markdown violations with rule IDs
  * Generates job summary with violation counts
  * Uploads markdownlint-output.txt artifact (30-day retention)
  * Fails job after publishing if violations found (respects soft-fail)
* **Research References**:
  * .copilot-tracking/research/20241104-modular-workflows-research.md (Lines 827-922) - Complete markdown-lint workflow implementation
  * .copilot-tracking/research/20241104-modular-workflows-research.md (Lines 283-291) - Principle 8: Descriptive Naming
  * .copilot-tracking/research/20241104-modular-workflows-research.md (Lines 257-275) - Principle 7: Result Publishing
* **Dependencies**:
  * None - can be created independently

### Task 1.3: Create reusable-table-format.yml with result publishing (CHECK ONLY mode)

Create new reusable workflow for markdown-table-formatter validation with result publishing emphasizing manual fixes.

* **Files**:
  * .github/workflows/reusable-table-format.yml - New workflow (create)
* **Success**:
  * Workflow accepts `soft-fail` input (boolean, default: false)
  * Uses harden-runner, SHA-pinned actions, minimal permissions
  * Runs `npm run format:tables:check` with output capture
  * Creates PR annotations for table formatting issues
  * Generates job summary with "⚠️ CHECK ONLY Mode" warning and manual fix instructions
  * Job summary includes command: `npm run format:tables` (without :check)
  * Uploads table-format-output.txt artifact (30-day retention)
  * Fails job after publishing if issues found (respects soft-fail)
* **Research References**:
  * .copilot-tracking/research/20241104-modular-workflows-research.md (Lines 924-1050) - Complete table-format workflow implementation with CHECK ONLY instructions
  * .copilot-tracking/research/20241104-modular-workflows-research.md (Lines 283-291) - Principle 8: Descriptive Naming
  * .copilot-tracking/research/20241104-modular-workflows-research.md (Lines 257-275) - Principle 7: Result Publishing
* **Dependencies**:
  * None - can be created independently

## Phase 2: Create Security Workflows

### Task 2.1: Create reusable-gitleaks-scan.yml with SARIF support and result publishing

Create new reusable workflow for Gitleaks secret scanning with SARIF upload and comprehensive result publishing.

* **Files**:
  * .github/workflows/reusable-gitleaks-scan.yml - New workflow (create)
* **Success**:
  * Workflow accepts `soft-fail` input (boolean, default: false)
  * Workflow accepts `upload-sarif` input (boolean, default: false)
  * Declares `security-events: write` permission at workflow level (conditional)
  * Uses harden-runner, SHA-pinned actions, minimal permissions
  * Runs `npm run security:gitleaks` generating both JSON and SARIF output
  * Creates PR annotations from JSON using jq parsing
  * Generates job summary with secret count and remediation guidance
  * Uploads SARIF to Security tab when `upload-sarif: true` (main branch only)
  * Uploads gitleaks.sarif and gitleaks-report.json artifacts (30-day retention)
  * Fails job after publishing if secrets found (respects soft-fail)
* **Research References**:
  * .copilot-tracking/research/20241104-modular-workflows-research.md (Lines 1052-1185) - Complete gitleaks workflow implementation with SARIF
  * .copilot-tracking/research/20241104-modular-workflows-research.md (Lines 283-291) - Principle 8: Descriptive Naming
  * .copilot-tracking/research/20241104-modular-workflows-research.md (Lines 257-275) - Principle 7: Result Publishing
  * .copilot-tracking/research/20241104-modular-workflows-research.md (Lines 1100-1600) - Result Publishing Strategies section with SARIF details
* **Dependencies**:
  * None - can be created independently

### Task 2.2: Create reusable-checkov-scan.yml with SARIF support and result publishing

Create new reusable workflow for Checkov IaC security scanning with SARIF upload and comprehensive result publishing.

* **Files**:
  * .github/workflows/reusable-checkov-scan.yml - New workflow (create)
* **Success**:
  * Workflow accepts `soft-fail` input (boolean, default: false)
  * Workflow accepts `upload-sarif` input (boolean, default: false)
  * Declares `security-events: write` permission at workflow level (conditional)
  * Uses harden-runner, SHA-pinned actions, minimal permissions
  * Sets up Python 3.11 with pip cache
  * Runs `npm run security:checkov` generating SARIF output
  * Creates PR annotations from SARIF using jq parsing
  * Generates job summary with violation count and frameworks scanned
  * Uploads SARIF to Security tab when `upload-sarif: true` (main branch only)
  * Uploads checkov-results.sarif and checkov-output.txt artifacts (30-day retention)
  * Fails job after publishing if violations found (respects soft-fail)
* **Research References**:
  * .copilot-tracking/research/20241104-modular-workflows-research.md (Lines 1187-1320) - Complete checkov workflow implementation with SARIF
  * .copilot-tracking/research/20241104-modular-workflows-research.md (Lines 283-291) - Principle 8: Descriptive Naming
  * .copilot-tracking/research/20241104-modular-workflows-research.md (Lines 257-275) - Principle 7: Result Publishing
  * .copilot-tracking/research/20241104-modular-workflows-research.md (Lines 1100-1600) - Result Publishing Strategies section with SARIF details
* **Dependencies**:
  * None - can be created independently

## Phase 3: Update Caller Workflows

### Task 3.1: Update pr-validation.yml to call 5 new workflows in parallel

Update PR validation workflow to call all 5 new reusable workflows with PR-appropriate configuration.

* **Files**:
  * .github/workflows/pr-validation.yml - Modify to call 5 workflows
* **Success**:
  * Removes old call to reusable-validation.yml
  * Adds 5 parallel jobs calling new reusable workflows:
    - spell-check → reusable-spell-check.yml (soft-fail: false)
    - markdown-lint → reusable-markdown-lint.yml (soft-fail: false)
    - table-format → reusable-table-format.yml (soft-fail: false)
    - gitleaks-scan → reusable-gitleaks-scan.yml (soft-fail: true, upload-sarif: false)
    - checkov-scan → reusable-checkov-scan.yml (soft-fail: true, upload-sarif: false)
  * Permissions remain minimal (contents: read) - no security-events needed since upload-sarif: false
  * No `needs` dependencies - all jobs run in parallel
  * Clear job names indicating what each validates
* **Research References**:
  * .copilot-tracking/research/20241104-modular-workflows-research.md (Lines 930-970) - Complete PR validation caller example
  * .copilot-tracking/research/20241104-modular-workflows-research.md (Lines 257-275) - Principle 7: Context-specific publishing (PRs: no SARIF)
  * .copilot-tracking/research/20241104-modular-workflows-research.md (Lines 336-338) - Current pr-validation.yml structure
* **Dependencies**:
  * Phase 1 and Phase 2 workflows must be created first

### Task 3.2: Update main.yml to call 5 new workflows with SARIF upload

Update main branch workflow to call all 5 new reusable workflows with strict enforcement and SARIF upload.

* **Files**:
  * .github/workflows/main.yml - Modify to call 5 workflows
* **Success**:
  * Removes old call to reusable-validation.yml
  * Adds 5 parallel jobs calling new reusable workflows:
    - spell-check → reusable-spell-check.yml (soft-fail: false)
    - markdown-lint → reusable-markdown-lint.yml (soft-fail: false)
    - table-format → reusable-table-format.yml (soft-fail: false)
    - gitleaks-scan → reusable-gitleaks-scan.yml (soft-fail: false, upload-sarif: true)
    - checkov-scan → reusable-checkov-scan.yml (soft-fail: false, upload-sarif: true)
  * Permissions elevated to include `security-events: write` for SARIF upload
  * No `needs` dependencies - all jobs run in parallel
  * Clear job names indicating what each validates
  * Strict enforcement (soft-fail: false) for all tools on main branch
* **Research References**:
  * .copilot-tracking/research/20241104-modular-workflows-research.md (Lines 985-1025) - Complete main.yml caller example
  * .copilot-tracking/research/20241104-modular-workflows-research.md (Lines 257-275) - Principle 7: Context-specific publishing (Main: with SARIF)
  * .copilot-tracking/research/20241104-modular-workflows-research.md (Lines 340-344) - Current main.yml structure
* **Dependencies**:
  * Phase 1 and Phase 2 workflows must be created first

## Phase 4: Validation and Testing

### Task 4.1: Add workflow_dispatch triggers for independent testing

Add manual workflow_dispatch triggers to all 5 reusable workflows for independent testing.

* **Files**:
  * .github/workflows/reusable-spell-check.yml - Add workflow_dispatch trigger
  * .github/workflows/reusable-markdown-lint.yml - Add workflow_dispatch trigger
  * .github/workflows/reusable-table-format.yml - Add workflow_dispatch trigger
  * .github/workflows/reusable-gitleaks-scan.yml - Add workflow_dispatch trigger
  * .github/workflows/reusable-checkov-scan.yml - Add workflow_dispatch trigger
* **Success**:
  * Each workflow has both `workflow_call` and `workflow_dispatch` triggers
  * workflow_dispatch includes same inputs as workflow_call for testing
  * Can manually trigger each workflow from Actions tab
  * Successful manual run validates workflow operates independently
* **Research References**:
  * .copilot-tracking/research/20241104-modular-workflows-research.md (Lines 86-89) - Phase 1 migration: independent testing strategy
* **Dependencies**:
  * Phase 1 and Phase 2 workflows must be created first

### Task 4.2: Validate result publishing (annotations, artifacts, SARIF, summaries)

Verify all 4 result publishing channels work correctly for each workflow.

* **Files**:
  * No files modified - validation task
* **Success**:
  * **PR Annotations**: Open test PR, confirm inline annotations appear in Files Changed tab for all validation errors
  * **Artifacts**: Confirm all workflows upload artifacts visible in workflow run page (30-day retention)
  * **Job Summaries**: Confirm markdown-formatted summaries render correctly on workflow run page with emoji, counts, links
  * **SARIF Upload**: Confirm Security tab shows Gitleaks and Checkov findings when run from main branch (not from PRs)
  * **Graceful Degradation**: Confirm publishing failures don't block workflow execution (if: always() works)
* **Research References**:
  * .copilot-tracking/research/20241104-modular-workflows-research.md (Lines 257-275) - Principle 7: Result Publishing channels
  * .copilot-tracking/research/20241104-modular-workflows-research.md (Lines 1100-1600) - Result Publishing Strategies section with validation criteria
* **Dependencies**:
  * Phase 3 must be complete (caller workflows updated)
  * Test PR must exist with validation errors for testing annotations

### Task 4.3: Verify performance improvement (210s → 150s)

Measure actual execution time to confirm 29% performance improvement from parallel execution.

* **Files**:
  * No files modified - validation task
* **Success**:
  * Compare execution time: old monolithic workflow vs new parallel workflows
  * Target: 210 seconds → 150 seconds (29% improvement)
  * Confirm all 5 workflows run in parallel (check workflow run timestamps)
  * Confirm no unnecessary sequential dependencies between jobs
  * Document actual execution times in changes file
* **Research References**:
  * .copilot-tracking/research/20241104-modular-workflows-research.md (Lines 240-247) - Principle 5: Performance optimization with expected improvement
* **Dependencies**:
  * Phase 3 must be complete (caller workflows updated)
  * Need baseline timing from old workflow for comparison

## Phase 5: Documentation and Cleanup

### Task 5.1: Update .github/workflows/README.md with architecture and naming rationale

Document new modular workflow architecture with clear explanation of naming conventions.

* **Files**:
  * .github/workflows/README.md - Update with new architecture details
* **Success**:
  * Architecture section shows 5 reusable workflows with descriptive names
  * Explains why `reusable-validation.yml` was a bad name (too generic, violates SRP)
  * Documents naming pattern: `reusable-<tool-name>-<action>.yml`
  * Shows composition pattern in pr-validation.yml and main.yml
  * Explains context-specific result publishing (PR vs main)
  * Includes migration notes and rollback procedure
  * Documents performance improvement (29% faster)
  * Links to research document for full details
* **Research References**:
  * .copilot-tracking/research/20241104-modular-workflows-research.md (Lines 283-322) - Principle 8: Complete naming rationale
  * .copilot-tracking/research/20241104-modular-workflows-research.md (Lines 433-443) - Project structure showing all workflows
  * .copilot-tracking/research/20241104-modular-workflows-research.md (Lines 79-80) - Task to update README
* **Dependencies**:
  * All workflows must be created and validated first

### Task 5.2: Add deprecation notices to old workflows

Add clear deprecation notices to legacy workflows that will be replaced.

* **Files**:
  * .github/workflows/reusable-validation.yml - Add deprecation notice at top
  * .github/workflows/gitleaks.yml - Add deprecation notice at top (standalone, non-reusable)
  * .github/workflows/checkov-scan.yml - Add deprecation notice at top (standalone, non-reusable)
* **Success**:
  * Each deprecated workflow has prominent comment at top explaining:
    - ⚠️ This workflow is deprecated
    - New replacement workflow name
    - Reason for deprecation (generic naming, monolithic design, or different implementation)
    - Planned removal date (after 1 sprint cycle)
    - Link to migration documentation
  * Workflows still function during deprecation period for rollback capability
  * Clear signal to future maintainers not to enhance these workflows
* **Research References**:
  * .copilot-tracking/research/20241104-modular-workflows-research.md (Lines 73-81) - Cleanup tasks with deprecation recommendations
  * .copilot-tracking/research/20241104-modular-workflows-research.md (Lines 283-322) - Naming rationale explaining why reusable-validation.yml is bad
* **Dependencies**:
  * Phase 3 must be complete (caller workflows updated to use new workflows)

### Task 5.3: Plan removal of deprecated workflows after validation period

Create removal plan for deprecated workflows after successful validation period.

* **Files**:
  * .copilot-tracking/changes/20241104-modular-workflows-changes.md - Document removal plan
* **Success**:
  * Removal plan documented with timeline (after 1 sprint cycle of stable operation)
  * Checklist created for removal:
    - [ ] Verify new workflows stable for 1 sprint (2 weeks)
    - [ ] Verify no errors in production
    - [ ] Verify result publishing working correctly
    - [ ] Verify performance target met (150s)
    - [ ] Confirm no other workflows depend on deprecated workflows
    - [ ] Delete reusable-validation.yml
    - [ ] Delete standalone gitleaks.yml
    - [ ] Delete standalone checkov-scan.yml
    - [ ] Update documentation to remove deprecation notices
  * Clear success criteria for when removal is safe
  * Rollback procedure documented in case issues arise
* **Research References**:
  * .copilot-tracking/research/20241104-modular-workflows-research.md (Lines 90-95) - Phase 4: Cleanup after validation period
* **Dependencies**:
  * Task 5.2 must be complete (deprecation notices added)
  * Validation period must pass successfully

## Dependencies

* Node.js 20 with npm (already configured)
* All npm packages: cspell, markdownlint-cli2, markdown-table-formatter, gitleaks
* Python 3.11 with pip for Checkov
* GitHub Actions marketplace actions (SHA-pinned versions)

## Success Criteria

* 5 new reusable workflows created with descriptive tool-specific names
* Each workflow implements 4-channel result publishing (annotations, artifacts, SARIF, summaries)
* Caller workflows updated to compose all 5 workflows in parallel
* Result publishing validated across all channels
* Performance improvement achieved (29% faster)
* Documentation updated with architecture and naming rationale
* Deprecated workflows marked for removal
* All workflows pass linting with no errors
