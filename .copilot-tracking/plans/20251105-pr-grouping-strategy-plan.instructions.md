---
applyTo: '.copilot-tracking/changes/20251105-pr-grouping-strategy-changes.md'
---
<!-- markdownlint-disable-file -->
# Task Checklist: PR Grouping Strategy Implementation

## Overview

Implement a 12-issue PR grouping strategy to populate an empty repository with all HVE Core components through independent, parallelizable PRs that respect dependencies and maintain repository functionality at each merge point.

Follow all instructions from #file:../../.github/instructions/task-implementation.instructions.md

## Objectives

* Create 12 distinct GitHub issues with proper labels, milestones, and dependencies
* Implement each issue as an independent PR using PR Review chat mode
* Ensure repository remains functional after each merge
* Maximize parallel development opportunities
* Deploy infrastructure and tooling early in the sequence

## Research Summary

### Project Files
* .copilot-tracking/research/20251105-pr-grouping-strategy-research.md - Comprehensive repository analysis with complete file inventory, dependency mapping, and 12-issue grouping strategy

### External References
* .copilot-tracking/research/20251105-pr-grouping-strategy-research.md (Lines 115-119) - GitHub Actions best practices for reusable workflows
* "microsoft/hve-core workflow architecture" - Modular GitHub Actions patterns with orchestration and reusable workflows

### Standards References
* #file:../../.github/chatmodes/pr-review.chatmode.md - PR review and submission process
* #file:../../.github/instructions/markdown.instructions.md - Markdown documentation standards

## Implementation Checklist

### [x] Phase 0: Repository Preparation

* [x] Task 0.1: Verify CODEOWNERS file uses wildcard pattern
  * Details: .copilot-tracking/details/20251105-pr-grouping-strategy-details.md (Lines 17-45)
  * Confirm `@microsoft/hve-core-admins` is replaced with `*` (any collaborator with write access)
  * File should already be updated locally - just verify
  * Will be included in Issue #8 PR

* [x] Task 0.2: Stash all existing changes
  * Details: .copilot-tracking/details/20251105-pr-grouping-strategy-details.md (Lines 47-67)
  * Create comprehensive stash of all untracked and modified files
  * Use `git stash push --include-untracked -m "All repository files for PR grouping"`
  * Verify working directory is clean
  * This stash will be selectively popped for each issue/PR

### [ ] Phase 1: GitHub Issues Creation

* [ ] Task 1.1: Create Issue #1 - Repository Foundation & Documentation
  * Details: .copilot-tracking/details/20251105-pr-grouping-strategy-details.md (Lines 17-37)

* [ ] Task 1.2: Create Issue #2 - Development Tools Configuration
  * Details: .copilot-tracking/details/20251105-pr-grouping-strategy-details.md (Lines 39-59)

* [ ] Task 1.3: Create Issue #3 - NPM/Node Dependencies
  * Details: .copilot-tracking/details/20251105-pr-grouping-strategy-details.md (Lines 61-81)

* [ ] Task 1.4: Create Issue #4 - Security Scanning Scripts
  * Details: .copilot-tracking/details/20251105-pr-grouping-strategy-details.md (Lines 83-103)

* [ ] Task 1.5: Create Issue #5 - Linting & Validation Scripts
  * Details: .copilot-tracking/details/20251105-pr-grouping-strategy-details.md (Lines 105-125)

* [ ] Task 1.6: Create Issue #6 - GitHub Copilot Chat Modes
  * Details: .copilot-tracking/details/20251105-pr-grouping-strategy-details.md (Lines 127-147)

* [ ] Task 1.7: Create Issue #7 - GitHub Copilot Instructions
  * Details: .copilot-tracking/details/20251105-pr-grouping-strategy-details.md (Lines 149-169)

* [ ] Task 1.8: Create Issue #8 - GitHub Metadata
  * Details: .copilot-tracking/details/20251105-pr-grouping-strategy-details.md (Lines 171-191)

* [ ] Task 1.9: Create Issue #9 - Core GitHub Actions Workflows (Validation)
  * Details: .copilot-tracking/details/20251105-pr-grouping-strategy-details.md (Lines 193-213)

* [ ] Task 1.10: Create Issue #10 - Security GitHub Actions Workflows
  * Details: .copilot-tracking/details/20251105-pr-grouping-strategy-details.md (Lines 215-235)

* [ ] Task 1.11: Create Issue #11 - PR & Main Branch Orchestration Workflows
  * Details: .copilot-tracking/details/20251105-pr-grouping-strategy-details.md (Lines 237-257)

* [ ] Task 1.12: Create Issue #12 - Development Container Configuration
  * Details: .copilot-tracking/details/20251105-pr-grouping-strategy-details.md (Lines 259-279)

### [ ] Phase 2: Wave 1 PRs (Foundation - Merge Priority 1)

**Git Workflow for Wave 1**: For each PR task below:
1. Ensure on main branch: `git checkout main && git pull`
2. Create feature branch: `git checkout -b feat/issue-{N}-{description}`
3. Pop stash and restore specific files: `git stash pop` then `git restore --source stash@{0} --worktree -- <file-paths>`
4. OR selectively add files from stash: `git checkout stash@{0} -- <file-paths>` (keeps stash intact)
5. Stage only files for this issue: `git add <specific-files>`
6. Commit with message: `git commit -m "feat: Add {description} (#N)"`
7. Push branch: `git push -u origin feat/issue-{N}-{description}`
8. Use GitHub MCP tools to create PR linking to issue
9. Keep stash preserved for remaining issues: `git stash` (if needed)

* [ ] Task 2.1: Create PR for Issue #1 - Repository Foundation
  * Details: .copilot-tracking/details/20251105-pr-grouping-strategy-details.md (Lines 281-301)
  * Branch: `feat/issue-1-repository-foundation`
  * Files: CODE_OF_CONDUCT.md, CONTRIBUTING.md, LICENSE, README.md, SECURITY.md, SUPPORT.md, .gitignore, .gitattributes, .npmrc, logs/

* [ ] Task 2.2: Create PR for Issue #2 - Tool Configs
  * Details: .copilot-tracking/details/20251105-pr-grouping-strategy-details.md (Lines 303-323)
  * Branch: `feat/issue-2-tool-configs`
  * Files: .cspell.json, .cspell/, .markdownlint.json, .markdownlint-cli2.jsonc, .gitleaks.toml, .checkov.yaml, config files

* [ ] Task 2.3: Create PR for Issue #3 - NPM Dependencies
  * Details: .copilot-tracking/details/20251105-pr-grouping-strategy-details.md (Lines 325-345)
  * Branch: `feat/issue-3-npm-dependencies`
  * Files: package.json, package-lock.json

* [ ] Task 2.4: Create PR for Issue #6 - Copilot Chat Modes
  * Details: .copilot-tracking/details/20251105-pr-grouping-strategy-details.md (Lines 347-367)
  * Branch: `feat/issue-6-copilot-chat-modes`
  * Files: .github/chatmodes/

* [ ] Task 2.5: Create PR for Issue #7 - Copilot Instructions
  * Details: .copilot-tracking/details/20251105-pr-grouping-strategy-details.md (Lines 369-389)
  * Branch: `feat/issue-7-copilot-instructions`
  * Files: .github/instructions/

* [ ] Task 2.6: Create PR for Issue #8 - GitHub Metadata (CODEOWNERS already updated)
  * Details: .copilot-tracking/details/20251105-pr-grouping-strategy-details.md (Lines 391-411)
  * Branch: `feat/issue-8-github-metadata`
  * Files: .github/CODEOWNERS, .github/GITHUB_OVERVIEW.md, .github/prompts/
  * **Note**: CODEOWNERS already updated in Phase 0, copy updated version

* [ ] Task 2.7: Create PR for Issue #12 - Dev Container
  * Details: .copilot-tracking/details/20251105-pr-grouping-strategy-details.md (Lines 413-433)
  * Branch: `feat/issue-12-dev-container`
  * Files: .devcontainer/

### [ ] Phase 3: Wave 2 PRs (Scripts - Merge Priority 2)

**Git Workflow for Wave 2**: Follow same workflow as Wave 1, but ensure dependencies are merged first:
- Task 3.1 requires Issue #2 PR merged to main
- Task 3.2 requires Issues #2 and #3 PRs merged to main
- Always start from updated main: `git checkout main && git pull`

* [ ] Task 3.1: Create PR for Issue #4 - Security Scripts (WAIT: Issue #2 merged)
  * Details: .copilot-tracking/details/20251105-pr-grouping-strategy-details.md (Lines 435-455)
  * Branch: `feat/issue-4-security-scripts`
  * Files: scripts/security/
  * **Dependency Check**: Verify Issue #2 PR is merged before starting

* [ ] Task 3.2: Create PR for Issue #5 - Linting Scripts (WAIT: Issues #2, #3 merged)
  * Details: .copilot-tracking/details/20251105-pr-grouping-strategy-details.md (Lines 457-477)
  * Branch: `feat/issue-5-linting-scripts`
  * Files: scripts/linting/, scripts/README.md
  * **Dependency Check**: Verify Issues #2 and #3 PRs are merged before starting

### [ ] Phase 4: Wave 3 PRs (Reusable Workflows - Merge Priority 3)

**Git Workflow for Wave 3**: These PRs have multiple dependencies - verify all are merged:
- Task 4.1 requires Issues #2, #3, #5 PRs merged to main
- Task 4.2 requires Issues #2, #4 PRs merged to main
- Always start from updated main: `git checkout main && git pull`

* [ ] Task 4.1: Create PR for Issue #9 - Validation Workflows (WAIT: Issues #2, #3, #5 merged)
  * Details: .copilot-tracking/details/20251105-pr-grouping-strategy-details.md (Lines 479-499)
  * Branch: `feat/issue-9-validation-workflows`
  * Files: .github/workflows/ (7 reusable workflow files)
  * **Dependency Check**: Verify Issues #2, #3, #5 PRs are merged before starting

* [ ] Task 4.2: Create PR for Issue #10 - Security Workflows (WAIT: Issues #2, #4 merged)
  * Details: .copilot-tracking/details/20251105-pr-grouping-strategy-details.md (Lines 501-521)
  * Branch: `feat/issue-10-security-workflows`
  * Files: .github/workflows/ (5 security workflow files)
  * **Dependency Check**: Verify Issues #2, #4 PRs are merged before starting

### [ ] Phase 5: Wave 4 PRs (Orchestration - Merge Priority 4 - FINAL)

**Git Workflow for Wave 4**: This is the FINAL PR that completes the CI/CD pipeline:
- Task 5.1 requires Issues #9, #10 PRs merged to main
- This PR activates the full CI/CD pipeline - test thoroughly
- Always start from updated main: `git checkout main && git pull`

* [ ] Task 5.1: Create PR for Issue #11 - Orchestration Workflows (WAIT: Issues #9, #10 merged) **[FINAL PR]**
  * Details: .copilot-tracking/details/20251105-pr-grouping-strategy-details.md (Lines 523-543)
  * Branch: `feat/issue-11-orchestration-workflows`
  * Files: .github/workflows/pr-validation.yml, .github/workflows/main.yml, .github/workflows/README.md
  * **Dependency Check**: Verify Issues #9, #10 PRs are merged before starting
  * **CRITICAL**: Create a test PR after this merges to verify full CI/CD pipeline works
  * **SUCCESS**: When this PR merges, repository is fully operational with complete CI/CD

## Dependencies

* GitHub MCP server access for issue creation
* PR Review chat mode for creating and submitting PRs
* Target empty repository with default admin permissions configured
* Branch protection rules configured after initial foundation PRs

## Success Criteria

* All 12 GitHub issues created with proper labels, assignees, and milestone
* All issues include clear acceptance criteria and file lists
* Each PR created using PR Review chat mode workflow
* Repository remains functional and testable after each merge
* CODEOWNERS file uses default admin team references
* All PRs merged in correct dependency order
* CI/CD pipeline fully functional after final PR merge
