<!-- markdownlint-disable-file -->
# Task Details: Edge AI Documentation Migration to HVE Core

## Research Reference

**Source Research**: .copilot-tracking/research/20251105-edge-ai-documentation-migration-research.md

## Phase 1: Critical Priority - CONTRIBUTING.md Azure DevOps Migration

### Task 1.1: Update CONTRIBUTING.md YAML frontmatter

Update author from "Edge AI Team" to "HVE Core Team", update description to reference HVE Core, update ms.date to 2025-11-05.

* **Files**:
  * CONTRIBUTING.md (Lines 1-11) - YAML frontmatter block
* **Success**:
  * Author field reads "HVE Core Team"
  * Description references "HVE Core project"
  * ms.date is 2025-11-05
* **Research References**:
  * .copilot-tracking/research/20251105-edge-ai-documentation-migration-research.md (Lines 285-299) - YAML frontmatter specification
* **Dependencies**:
  * None

### Task 1.2: Update CONTRIBUTING.md main title

Update main heading from "Contributing to AI on Edge Flagship Accelerator" to "Contributing to HVE Core".

* **Files**:
  * CONTRIBUTING.md (Line 13) - Main H1 heading
* **Success**:
  * Heading reads "# Contributing to HVE Core"
* **Research References**:
  * .copilot-tracking/research/20251105-edge-ai-documentation-migration-research.md (Lines 301-306) - Title update specification
* **Dependencies**:
  * Task 1.1 completion

### Task 1.3: Add build requirements section to CONTRIBUTING.md

Insert new section explaining build and validation requirements (markdownlint, cspell, markdown-table-formatter) after the opening paragraph and before "I Have a Question" section.

* **Files**:
  * CONTRIBUTING.md (After line 17, before "## I Have a Question") - New section insertion
* **Success**:
  * New "## Build and Validation Requirements" section added with subsections for tools and validation commands
  * Section includes npm script examples
  * DevContainer reference included
* **Research References**:
  * .copilot-tracking/research/20251105-edge-ai-documentation-migration-research.md (Lines 308-342) - Complete build requirements section
  * package.json - npm scripts for validation
* **Dependencies**:
  * Task 1.2 completion

### Task 1.4: Update "I Have a Question" section URLs

Replace Azure DevOps query URLs with GitHub Issues URLs in the "I Have a Question" section.

* **Files**:
  * CONTRIBUTING.md (Lines 62-71) - "I Have a Question" section
* **Success**:
  * All Azure DevOps URLs replaced with https://github.com/microsoft/hve-core/issues
  * Text flows naturally with GitHub terminology
* **Research References**:
  * .copilot-tracking/research/20251105-edge-ai-documentation-migration-research.md (Lines 344-354) - URL replacement specification
* **Dependencies**:
  * Task 1.3 completion

### Task 1.5: Update "Reporting Bugs" section URLs

Replace Azure DevOps bug tracker URLs with GitHub Issues URLs in the "Reporting Bugs" section.

* **Files**:
  * CONTRIBUTING.md (Lines 82-95) - "Reporting Bugs" section
* **Success**:
  * Azure DevOps issue tracker URL replaced with GitHub Issues
  * References to "GitHub Issues" instead of Azure DevOps
* **Research References**:
  * .copilot-tracking/research/20251105-edge-ai-documentation-migration-research.md (Lines 356-366) - Bug reporting section updates
* **Dependencies**:
  * Task 1.4 completion

### Task 1.6: Update "Suggesting Enhancements" section URLs

Replace Azure DevOps Features URLs with GitHub Issues URLs in the "Suggesting Enhancements" section.

* **Files**:
  * CONTRIBUTING.md (Lines 97-112) - "Suggesting Enhancements" section
* **Success**:
  * Azure DevOps search and Features URLs replaced with GitHub Issues
  * Enhancement tracking references GitHub Issues
* **Research References**:
  * .copilot-tracking/research/20251105-edge-ai-documentation-migration-research.md (Lines 368-376) - Enhancement section updates
* **Dependencies**:
  * Task 1.5 completion

### Task 1.7: Update "Your First Code Contribution" section terminology and URLs

Replace Azure DevOps work item terminology with GitHub issue terminology, update work item notation link to GitHub issue linking documentation, update all related URLs.

* **Files**:
  * CONTRIBUTING.md (Lines 116-145) - "Your First Code Contribution" section
* **Success**:
  * "workitem" replaced with "issue"
  * "User Story or Task item from the backlog" replaced with "issue from the issue tracker"
  * Azure DevOps work item notation link replaced with GitHub issue linking documentation
  * File an issue link points to GitHub
  * References to non-existent documentation removed
* **Research References**:
  * .copilot-tracking/research/20251105-edge-ai-documentation-migration-research.md (Lines 378-393) - Code contribution section updates
  * .copilot-tracking/research/20251105-edge-ai-documentation-migration-research.md (Lines 395-403) - Terminology updates and documentation cleanup
* **Dependencies**:
  * Task 1.6 completion

### Task 1.8: Add standard footer to CONTRIBUTING.md

Add standard Copilot attribution footer at end of CONTRIBUTING.md file.

* **Files**:
  * CONTRIBUTING.md (End of file, after line 198) - Footer insertion
* **Success**:
  * Footer added with blank line before horizontal rule
  * Footer text: "🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers."
* **Research References**:
  * .copilot-tracking/research/20251105-edge-ai-documentation-migration-research.md (Lines 675-692) - Standard footer format and placement
* **Dependencies**:
  * Task 1.7 completion

## Phase 2: High Priority - SUPPORT.md GitHub URL and Identity Updates

### Task 2.1: Update SUPPORT.md YAML frontmatter

Update author from "Edge AI Team" to "HVE Core Team", update description to reference HVE Core project, update ms.date to 2025-11-05.

* **Files**:
  * SUPPORT.md (Lines 1-11) - YAML frontmatter block
* **Success**:
  * Author field reads "HVE Core Team"
  * Description references "HVE Core project"
  * ms.date is 2025-11-05
* **Research References**:
  * .copilot-tracking/research/20251105-edge-ai-documentation-migration-research.md (Lines 436-450) - YAML frontmatter specification
* **Dependencies**:
  * Phase 1 completion

### Task 2.2: Update SUPPORT.md opening paragraph and community support section

Replace "Edge AI Accelerator project" with "HVE Core project", update opening paragraph and community support section references.

* **Files**:
  * SUPPORT.md (Lines 13-24) - Opening paragraph and community support section
* **Success**:
  * "HVE Core project" used in opening paragraph
  * "HVE Core is an open-source project" in community support section
  * Flow and readability maintained
* **Research References**:
  * .copilot-tracking/research/20251105-edge-ai-documentation-migration-research.md (Lines 452-465) - Opening paragraph updates
* **Dependencies**:
  * Task 2.1 completion

### Task 2.3: Update SUPPORT.md filing issues URLs

Replace microsoft/edge-ai GitHub URLs with microsoft/hve-core URLs in the "Filing Issues" section.

* **Files**:
  * SUPPORT.md (Lines 47-52) - Filing issues section
* **Success**:
  * All GitHub URLs point to microsoft/hve-core/issues
  * Link text matches updated URLs
* **Research References**:
  * .copilot-tracking/research/20251105-edge-ai-documentation-migration-research.md (Lines 467-477) - GitHub Issues URL updates
* **Dependencies**:
  * Task 2.2 completion

### Task 2.4: Update SUPPORT.md support performance section

Remove specific performance metrics and dashboard references while keeping response time commitments.

* **Files**:
  * SUPPORT.md (Lines 36-44) - Support performance section
* **Success**:
  * Response time commitments preserved (48 hours acknowledgment)
  * Specific metrics removed (95% within 2 days, 99% within 5 days)
  * Dashboard references removed
  * Generic language about timely responses added
* **Research References**:
  * .copilot-tracking/research/20251105-edge-ai-documentation-migration-research.md (Lines 479-494) - Support performance section updates
* **Dependencies**:
  * Task 2.3 completion

### Task 2.5: Update SUPPORT.md Microsoft Support Policy section

Update Microsoft Support Policy section to use generic phrasing suitable for a documentation repository.

* **Files**:
  * SUPPORT.md (Lines 82-87) - Microsoft Support Policy section
* **Success**:
  * Generic phrasing for open-source project maintained by Microsoft
  * GitHub Issues reference for repository-specific issues
  * Microsoft Support link for product/service support
  * No specific Azure service references
* **Research References**:
  * .copilot-tracking/research/20251105-edge-ai-documentation-migration-research.md (Lines 496-507) - Microsoft Support Policy updates
* **Dependencies**:
  * Task 2.4 completion

### Task 2.6: Add standard footer to SUPPORT.md

Add standard Copilot attribution footer at end of SUPPORT.md file.

* **Files**:
  * SUPPORT.md (End of file, after line 103) - Footer insertion
* **Success**:
  * Footer added with blank line before horizontal rule
  * Footer text: "🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers."
* **Research References**:
  * .copilot-tracking/research/20251105-edge-ai-documentation-migration-research.md (Lines 675-692) - Standard footer format
* **Dependencies**:
  * Task 2.5 completion

## Phase 3: Medium Priority - Workflow Documentation Metadata Updates

### Task 3.1: Update .github/workflows/README.md YAML frontmatter

Update author from "Edge AI Team" to "HVE Core Team", update ms.date to 2025-11-05.

* **Files**:
  * .github/workflows/README.md (Lines 1-11) - YAML frontmatter block
* **Success**:
  * Author field reads "HVE Core Team"
  * ms.date is 2025-11-05
  * All other metadata preserved
* **Research References**:
  * .copilot-tracking/research/20251105-edge-ai-documentation-migration-research.md (Lines 539-555) - Workflows README metadata updates
* **Dependencies**:
  * Phase 2 completion

### Task 3.2: Add standard footer to .github/workflows/README.md

Add standard Copilot attribution footer at end of .github/workflows/README.md file.

* **Files**:
  * .github/workflows/README.md (End of file, after line 447) - Footer insertion
* **Success**:
  * Footer added with blank line before horizontal rule
  * Footer text: "🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers."
* **Research References**:
  * .copilot-tracking/research/20251105-edge-ai-documentation-migration-research.md (Lines 675-692) - Standard footer format
* **Dependencies**:
  * Task 3.1 completion

### Task 3.3: Update .github/BRANCH_PROTECTION.md YAML frontmatter

Update author from "Edge AI Team" to "HVE Core Team", update ms.date to 2025-11-05.

* **Files**:
  * .github/BRANCH_PROTECTION.md (Lines 1-11) - YAML frontmatter block
* **Success**:
  * Author field reads "HVE Core Team"
  * ms.date is 2025-11-05
  * All other metadata preserved
* **Research References**:
  * .copilot-tracking/research/20251105-edge-ai-documentation-migration-research.md (Lines 557-573) - Branch protection metadata updates
* **Dependencies**:
  * Task 3.2 completion

### Task 3.4: Add standard footer to .github/BRANCH_PROTECTION.md

Add standard Copilot attribution footer at end of .github/BRANCH_PROTECTION.md file.

* **Files**:
  * .github/BRANCH_PROTECTION.md (End of file, after line 84) - Footer insertion
* **Success**:
  * Footer added with blank line before horizontal rule
  * Footer text: "🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers."
* **Research References**:
  * .copilot-tracking/research/20251105-edge-ai-documentation-migration-research.md (Lines 675-692) - Standard footer format
* **Dependencies**:
  * Task 3.3 completion

## Phase 4: Medium Priority - Chatmode Attribution Updates

### Task 4.1: Update .github/chatmodes/pr-review.chatmode.md attribution and terminology

Update description attribution from microsoft/edge-ai to microsoft/hve-core, optionally update "Work Items" to "Issues" terminology.

* **Files**:
  * .github/chatmodes/pr-review.chatmode.md (Line 2) - Description field in YAML frontmatter
  * .github/chatmodes/pr-review.chatmode.md (Line 92) - Template field "Linked Work Items"
  * .github/chatmodes/pr-review.chatmode.md (Line 148) - Instructions text "linked work items"
* **Success**:
  * Description reads "Brought to you by microsoft/hve-core"
  * Template field reads "Linked Issues" (optional)
  * Instructions reference "linked issues" (optional)
* **Research References**:
  * .copilot-tracking/research/20251105-edge-ai-documentation-migration-research.md (Lines 717-744) - pr-review chatmode updates
  * .copilot-tracking/research/20251105-edge-ai-documentation-migration-research.md (Lines 646-671) - Attribution format
* **Dependencies**:
  * Phase 3 completion

### Task 4.2: Update .github/chatmodes/prompt-builder.chatmode.md attribution

Update description attribution from microsoft/edge-ai to microsoft/hve-core.

* **Files**:
  * .github/chatmodes/prompt-builder.chatmode.md (Line 2) - Description field in YAML frontmatter
* **Success**:
  * Description reads "Brought to you by microsoft/hve-core"
* **Research References**:
  * .copilot-tracking/research/20251105-edge-ai-documentation-migration-research.md (Lines 746-759) - prompt-builder chatmode updates
  * .copilot-tracking/research/20251105-edge-ai-documentation-migration-research.md (Lines 646-671) - Attribution format
* **Dependencies**:
  * Task 4.1 completion

### Task 4.3: Update .github/chatmodes/task-researcher.chatmode.md attribution

Update description attribution from microsoft/edge-ai to microsoft/hve-core.

* **Files**:
  * .github/chatmodes/task-researcher.chatmode.md (Line 2) - Description field in YAML frontmatter
* **Success**:
  * Description reads "Brought to you by microsoft/hve-core"
* **Research References**:
  * .copilot-tracking/research/20251105-edge-ai-documentation-migration-research.md (Lines 615-628) - task-researcher chatmode updates
* **Dependencies**:
  * Task 4.2 completion

### Task 4.4: Update .github/chatmodes/task-planner.chatmode.md attribution

Update description attribution from microsoft/edge-ai to microsoft/hve-core.

* **Files**:
  * .github/chatmodes/task-planner.chatmode.md (Line 2) - Description field in YAML frontmatter
* **Success**:
  * Description reads "Brought to you by microsoft/hve-core"
* **Research References**:
  * .copilot-tracking/research/20251105-edge-ai-documentation-migration-research.md (Lines 630-643) - task-planner chatmode updates
* **Dependencies**:
  * Task 4.3 completion

## Phase 5: Low Priority - Security Script Reference Updates

### Task 5.1: Update scripts/security/Update-ActionSHAPinning.ps1 user-agent string

Replace edge-ai user-agent string with hve-core user-agent string.

* **Files**:
  * scripts/security/Update-ActionSHAPinning.ps1 (Line 315) - User-Agent header
* **Success**:
  * User-Agent reads 'hve-core-sha-pinning-updater'
  * Script functionality unchanged
* **Research References**:
  * Research agent validation results - Additional technical references discovered
  * Pattern: edge-ai → hve-core for technical identifiers
* **Dependencies**:
  * Phase 4 completion

### Task 5.2: Update scripts/security/Test-DependencyPinning.ps1 repository URL

Replace edge-ai repository URL with hve-core repository URL.

* **Files**:
  * scripts/security/Test-DependencyPinning.ps1 (Line 456) - informationUri field
* **Success**:
  * informationUri reads "https://github.com/microsoft/hve-core"
  * Test output metadata accurate
* **Research References**:
  * Research agent validation results - Additional technical references discovered
  * Pattern: microsoft/edge-ai → microsoft/hve-core for repository URLs
* **Dependencies**:
  * Task 5.1 completion

## Phase 6: Documentation Footer Standardization

### Task 6.1: Add standard footer to CODE_OF_CONDUCT.md

Add standard Copilot attribution footer at end of CODE_OF_CONDUCT.md file.

* **Files**:
  * CODE_OF_CONDUCT.md (End of file) - Footer insertion
* **Success**:
  * Footer added with blank line before horizontal rule
  * Footer text: "🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers."
* **Research References**:
  * .copilot-tracking/research/20251105-edge-ai-documentation-migration-research.md (Lines 675-692) - Standard footer format
* **Dependencies**:
  * Phase 5 completion

### Task 6.2: Add standard footer to SECURITY.md

Add standard Copilot attribution footer at end of SECURITY.md file.

* **Files**:
  * SECURITY.md (End of file) - Footer insertion
* **Success**:
  * Footer added with blank line before horizontal rule
  * Footer text: "🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers."
* **Research References**:
  * .copilot-tracking/research/20251105-edge-ai-documentation-migration-research.md (Lines 675-692) - Standard footer format
* **Dependencies**:
  * Task 6.1 completion

## Dependencies

* markdownlint - Markdown linting (defer validation until requested)
* cspell - Spell checking (defer validation until requested)
* markdown-table-formatter - Table formatting
* npm - Package management for validation scripts

## Success Criteria

* All YAML frontmatter updated with HVE Core Team author and 2025-11-05 date
* All Azure DevOps URLs migrated to GitHub Issues
* Build requirements section added to CONTRIBUTING.md
* All Edge AI references replaced with HVE Core
* Standard footer added to 6 root-level documentation files
* Security scripts reference hve-core identifiers
* All chatmode attributions reference microsoft/hve-core
