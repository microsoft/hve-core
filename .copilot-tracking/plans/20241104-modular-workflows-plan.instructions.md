---
applyTo: '.copilot-tracking/changes/20241104-modular-workflows-changes.md'
---
<!-- markdownlint-disable-file -->
# Task Checklist: Modular GitHub Actions Workflow Architecture

## Overview

Decompose monolithic reusable-validation.yml into 5 focused, single-responsibility reusable workflows with descriptive names, comprehensive result publishing, and parallel execution for 29% performance improvement.

## Objectives

* Replace poorly-named monolithic `reusable-validation.yml` with 5 descriptively-named single-responsibility workflows
* Implement comprehensive result publishing (PR annotations, artifacts, SARIF, job summaries)
* Enable parallel execution for 29% performance improvement (210s → 150s)
* Maintain security hardening (harden-runner, SHA pinning, minimal permissions)
* Preserve backward compatibility during migration with rollback capability

## Research Summary

### Project Files
* .github/workflows/reusable-validation.yml - Current monolithic workflow with generic name (Lines 1-138)
* .github/workflows/pr-validation.yml - PR caller workflow (Lines 1-25)
* .github/workflows/main.yml - Main branch caller workflow (Lines 1-25)
* package.json - npm scripts for validation tools (Lines 7-14)

### External References
* .copilot-tracking/research/20241104-modular-workflows-research.md - Complete architecture blueprint with naming rationale
* "github/docs reusable workflows" - Workflow composition patterns and best practices
* "step-security/harden-runner" - Security hardening implementation
* https://docs.github.com/en/actions/using-workflows/reusing-workflows - Official workflow_call documentation

### Standards References
* #file:../../.github/instructions/markdown.instructions.md - Markdown formatting conventions
* SHA Pinning: All actions use full commit SHA with version comment
* Security Hardening: Mandatory harden-runner as first step in every job
* Minimal Permissions: Default to contents:read, escalate only when necessary

## Implementation Checklist

### [ ] Phase 1: Create Validation Workflows

* [ ] Task 1.1: Create reusable-spell-check.yml with result publishing
  * Details: .copilot-tracking/details/20241104-modular-workflows-details.md (Lines 15-45)

* [ ] Task 1.2: Create reusable-markdown-lint.yml with result publishing
  * Details: .copilot-tracking/details/20241104-modular-workflows-details.md (Lines 47-77)

* [ ] Task 1.3: Create reusable-table-format.yml with result publishing (CHECK ONLY mode)
  * Details: .copilot-tracking/details/20241104-modular-workflows-details.md (Lines 79-112)

### [ ] Phase 2: Create Security Workflows

* [ ] Task 2.1: Create reusable-gitleaks-scan.yml with SARIF support and result publishing
  * Details: .copilot-tracking/details/20241104-modular-workflows-details.md (Lines 114-155)

* [ ] Task 2.2: Create reusable-checkov-scan.yml with SARIF support and result publishing
  * Details: .copilot-tracking/details/20241104-modular-workflows-details.md (Lines 157-198)

### [ ] Phase 3: Update Caller Workflows

* [ ] Task 3.1: Update pr-validation.yml to call 5 new workflows in parallel
  * Details: .copilot-tracking/details/20241104-modular-workflows-details.md (Lines 200-235)

* [ ] Task 3.2: Update main.yml to call 5 new workflows with SARIF upload
  * Details: .copilot-tracking/details/20241104-modular-workflows-details.md (Lines 237-272)

### [ ] Phase 4: Validation and Testing

* [ ] Task 4.1: Add workflow_dispatch triggers for independent testing
  * Details: .copilot-tracking/details/20241104-modular-workflows-details.md (Lines 274-295)

* [ ] Task 4.2: Validate result publishing (annotations, artifacts, SARIF, summaries)
  * Details: .copilot-tracking/details/20241104-modular-workflows-details.md (Lines 297-325)

* [ ] Task 4.3: Verify performance improvement (210s → 150s)
  * Details: .copilot-tracking/details/20241104-modular-workflows-details.md (Lines 327-345)

### [ ] Phase 5: Documentation and Cleanup

* [ ] Task 5.1: Update .github/workflows/README.md with architecture and naming rationale
  * Details: .copilot-tracking/details/20241104-modular-workflows-details.md (Lines 347-375)

* [ ] Task 5.2: Add deprecation notices to old workflows
  * Details: .copilot-tracking/details/20241104-modular-workflows-details.md (Lines 377-400)

* [ ] Task 5.3: Plan removal of deprecated workflows after validation period
  * Details: .copilot-tracking/details/20241104-modular-workflows-details.md (Lines 402-420)

## Dependencies

* Node.js 20 with npm (already configured in repository)
* cspell, markdownlint-cli2, markdown-table-formatter (installed via npm)
* Gitleaks (installed via package.json security:gitleaks script)
* Checkov (installed via pip in workflow)
* GitHub Actions: actions/checkout@v4, actions/setup-node@v4, actions/setup-python@v5
* Security: step-security/harden-runner@v2, github/codeql-action/upload-sarif@v3

## Success Criteria

* All 5 reusable workflows created with descriptive tool-specific names
* Each workflow implements complete 4-channel result publishing
* PR validation shows inline annotations in Files Changed tab
* Main branch uploads SARIF to Security tab for security scans
* Workflow artifacts uploaded with 30-day retention
* Job summaries render with markdown formatting
* Parallel execution achieves 29% performance improvement
* All workflows pass validation with no errors
* Security hardening maintained (harden-runner, SHA pinning, minimal permissions)
* Backward compatibility preserved during migration
* Documentation updated with architecture diagram and naming rationale
