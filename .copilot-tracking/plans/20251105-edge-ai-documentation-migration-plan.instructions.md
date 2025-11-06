---
applyTo: '.copilot-tracking/changes/20251105-edge-ai-documentation-migration-changes.md'
---
<!-- markdownlint-disable-file -->
# Task Checklist: Edge AI Documentation Migration to HVE Core

## Overview

Migrate all Edge AI-specific documentation references to HVE Core identity, replacing Azure DevOps URLs with GitHub Issues, updating team names, adding standard footers, and updating security script references.

Follow all instructions from #file:../../.github/instructions/task-implementation.instructions.md

## Objectives

* Replace all Edge AI project references with HVE Core branding
* Migrate Azure DevOps URLs to GitHub Issues infrastructure
* Update author metadata to "HVE Core Team" across all documentation
* Add standard Copilot attribution footers to root-level documentation files
* Update security script references from edge-ai to hve-core identifiers

## Research Summary

### Project Files
* CONTRIBUTING.md - Contains 8+ Azure DevOps URLs and Edge AI team references
* SUPPORT.md - Contains Edge AI project name and incorrect GitHub repository URLs
* .github/workflows/README.md - Contains Edge AI team metadata
* .github/BRANCH_PROTECTION.md - Contains Edge AI team metadata
* .github/chatmodes/pr-review.chatmode.md - Contains edge-ai attribution and Work Items terminology
* .github/chatmodes/prompt-builder.chatmode.md - Contains edge-ai attribution
* .github/chatmodes/task-researcher.chatmode.md - Contains edge-ai attribution
* .github/chatmodes/task-planner.chatmode.md - Contains edge-ai attribution
* scripts/security/Update-ActionSHAPinning.ps1 - Contains edge-ai user-agent string
* scripts/security/Test-DependencyPinning.ps1 - Contains edge-ai repository URL

### External References
* .copilot-tracking/research/20251105-edge-ai-documentation-migration-research.md - Complete migration analysis with line-by-line specifications
* package.json - Confirms "hve-core" as official project name
* .markdownlint.json - Markdown linting standards

### Standards References
* #file:../../.github/instructions/markdown.instructions.md - Markdown formatting conventions

## Implementation Checklist

### [ ] Phase 1: Critical Priority - CONTRIBUTING.md Azure DevOps Migration

* [ ] Task 1.1: Update CONTRIBUTING.md YAML frontmatter
  * Details: .copilot-tracking/details/20251105-edge-ai-documentation-migration-details.md (Lines 27-41)

* [ ] Task 1.2: Update CONTRIBUTING.md main title
  * Details: .copilot-tracking/details/20251105-edge-ai-documentation-migration-details.md (Lines 43-51)

* [ ] Task 1.3: Add build requirements section to CONTRIBUTING.md
  * Details: .copilot-tracking/details/20251105-edge-ai-documentation-migration-details.md (Lines 53-91)

* [ ] Task 1.4: Update "I Have a Question" section URLs
  * Details: .copilot-tracking/details/20251105-edge-ai-documentation-migration-details.md (Lines 93-106)

* [ ] Task 1.5: Update "Reporting Bugs" section URLs
  * Details: .copilot-tracking/details/20251105-edge-ai-documentation-migration-details.md (Lines 108-120)

* [ ] Task 1.6: Update "Suggesting Enhancements" section URLs
  * Details: .copilot-tracking/details/20251105-edge-ai-documentation-migration-details.md (Lines 122-132)

* [ ] Task 1.7: Update "Your First Code Contribution" section terminology and URLs
  * Details: .copilot-tracking/details/20251105-edge-ai-documentation-migration-details.md (Lines 134-156)

* [ ] Task 1.8: Add standard footer to CONTRIBUTING.md
  * Details: .copilot-tracking/details/20251105-edge-ai-documentation-migration-details.md (Lines 158-167)

### [ ] Phase 2: High Priority - SUPPORT.md GitHub URL and Identity Updates

* [ ] Task 2.1: Update SUPPORT.md YAML frontmatter
  * Details: .copilot-tracking/details/20251105-edge-ai-documentation-migration-details.md (Lines 171-185)

* [ ] Task 2.2: Update SUPPORT.md opening paragraph and community support section
  * Details: .copilot-tracking/details/20251105-edge-ai-documentation-migration-details.md (Lines 187-203)

* [ ] Task 2.3: Update SUPPORT.md filing issues URLs
  * Details: .copilot-tracking/details/20251105-edge-ai-documentation-migration-details.md (Lines 205-217)

* [ ] Task 2.4: Update SUPPORT.md support performance section
  * Details: .copilot-tracking/details/20251105-edge-ai-documentation-migration-details.md (Lines 219-235)

* [ ] Task 2.5: Update SUPPORT.md Microsoft Support Policy section
  * Details: .copilot-tracking/details/20251105-edge-ai-documentation-migration-details.md (Lines 237-250)

* [ ] Task 2.6: Add standard footer to SUPPORT.md
  * Details: .copilot-tracking/details/20251105-edge-ai-documentation-migration-details.md (Lines 252-261)

### [ ] Phase 3: Medium Priority - Workflow Documentation Metadata Updates

* [ ] Task 3.1: Update .github/workflows/README.md YAML frontmatter
  * Details: .copilot-tracking/details/20251105-edge-ai-documentation-migration-details.md (Lines 265-282)

* [ ] Task 3.2: Add standard footer to .github/workflows/README.md
  * Details: .copilot-tracking/details/20251105-edge-ai-documentation-migration-details.md (Lines 284-293)

* [ ] Task 3.3: Update .github/BRANCH_PROTECTION.md YAML frontmatter
  * Details: .copilot-tracking/details/20251105-edge-ai-documentation-migration-details.md (Lines 295-311)

* [ ] Task 3.4: Add standard footer to .github/BRANCH_PROTECTION.md
  * Details: .copilot-tracking/details/20251105-edge-ai-documentation-migration-details.md (Lines 313-322)

### [ ] Phase 4: Medium Priority - Chatmode Attribution Updates

* [ ] Task 4.1: Update .github/chatmodes/pr-review.chatmode.md attribution and terminology
  * Details: .copilot-tracking/details/20251105-edge-ai-documentation-migration-details.md (Lines 326-348)

* [ ] Task 4.2: Update .github/chatmodes/prompt-builder.chatmode.md attribution
  * Details: .copilot-tracking/details/20251105-edge-ai-documentation-migration-details.md (Lines 350-363)

* [ ] Task 4.3: Update .github/chatmodes/task-researcher.chatmode.md attribution
  * Details: .copilot-tracking/details/20251105-edge-ai-documentation-migration-details.md (Lines 365-378)

* [ ] Task 4.4: Update .github/chatmodes/task-planner.chatmode.md attribution
  * Details: .copilot-tracking/details/20251105-edge-ai-documentation-migration-details.md (Lines 380-393)

### [ ] Phase 5: Low Priority - Security Script Reference Updates

* [ ] Task 5.1: Update scripts/security/Update-ActionSHAPinning.ps1 user-agent string
  * Details: .copilot-tracking/details/20251105-edge-ai-documentation-migration-details.md (Lines 397-412)

* [ ] Task 5.2: Update scripts/security/Test-DependencyPinning.ps1 repository URL
  * Details: .copilot-tracking/details/20251105-edge-ai-documentation-migration-details.md (Lines 414-429)

### [ ] Phase 6: Documentation Footer Standardization

* [ ] Task 6.1: Add standard footer to CODE_OF_CONDUCT.md
  * Details: .copilot-tracking/details/20251105-edge-ai-documentation-migration-details.md (Lines 433-442)

* [ ] Task 6.2: Add standard footer to SECURITY.md
  * Details: .copilot-tracking/details/20251105-edge-ai-documentation-migration-details.md (Lines 444-453)

## Dependencies

* markdownlint - Markdown linting (defer validation until requested)
* cspell - Spell checking (defer validation until requested)
* markdown-table-formatter - Table formatting
* npm - Package management for running validation scripts

## Success Criteria

* All Edge AI project references replaced with HVE Core
* All Azure DevOps URLs migrated to GitHub Issues
* All author metadata updated to "HVE Core Team"
* All ms.date fields updated to 2025-11-05
* Standard Copilot footer added to 6 root-level documentation files
* Security scripts reference hve-core identifiers
* All changes tracked in changes file
