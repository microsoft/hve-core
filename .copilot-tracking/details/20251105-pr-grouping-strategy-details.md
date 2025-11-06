<!-- markdownlint-disable-file -->
# Task Details: PR Grouping Strategy Implementation

## Research Reference

**Source Research**: .copilot-tracking/research/20251105-pr-grouping-strategy-research.md

## Phase 0: Repository Preparation

### Task 0.1: Verify CODEOWNERS file uses wildcard pattern

Verify the CODEOWNERS file already uses universal wildcard pattern. This file will be included in Issue #8 PR.

* **Files**:
  * .github/CODEOWNERS - Should already have wildcard pattern
* **Success**:
  * All `@microsoft/hve-core-admins` references replaced with `*`
  * Inline comments exist explaining wildcard pattern
  * File ready to be included in Issue #8 branch
  * No commit needed - file will be committed with Issue #8
* **Research References**:
  * .copilot-tracking/research/20251105-pr-grouping-strategy-research.md (Lines 520-580) - CODEOWNERS analysis and modification strategy
* **Dependencies**:
  * None - prerequisite verification
* **Verification Command**:
  ```bash
  # Verify CODEOWNERS content
  cat .github/CODEOWNERS
  # Should show * instead of @microsoft/hve-core-admins
  ```

### Task 0.2: Stash all existing changes

Create a comprehensive stash containing all untracked and modified files. This stash will be selectively restored for each PR.

* **Files**:
  * All untracked files (entire .github/, scripts/, .cspell/, .devcontainer/, root docs)
  * Modified files (.gitignore)
* **Success**:
  * All changes stashed with descriptive message
  * Working directory clean (git status shows no changes)
  * Stash preserved for selective restoration
  * Ready to create feature branches from clean main
* **Research References**:
  * .copilot-tracking/research/20251105-pr-grouping-strategy-research.md (Lines 1-50) - Repository context and structure
* **Dependencies**:
  * Task 0.1 complete - CODEOWNERS verified
* **Git Commands**:
  ```bash
  cd c:\Users\wberry\src\hve-core
  
  # Create comprehensive stash with all files
  git stash push --include-untracked -m "All repository files for PR grouping"
  
  # Verify clean working directory
  git status  # Should show "nothing to commit, working tree clean"
  
  # View stash contents
  git stash show -p stash@{0}
  
  # List stashed files
  git stash show stash@{0} --name-only
  ```
* **Research References**:
  * .copilot-tracking/research/20251105-pr-grouping-strategy-research.md (Lines 1-50) - Repository context and structure
* **Dependencies**:
  * None - prerequisite verification
* **Git Commands**:
  ```bash
  # Verify target repository exists (use GitHub API or web browser)
  # If target is a separate repository:
  
  # Clone target repository
  cd c:\Users\wberry\src
  git clone https://github.com/microsoft/hve-core hve-core-target
  cd hve-core-target
  
  # Verify default branch
  git branch --show-current
  
  # Verify remote access
  git remote -v
  
  # Test push access (if needed)
  git checkout -b test-access
  echo "test" > test.txt
  git add test.txt
  git commit -m "test: Verify write access"
  git push -u origin test-access
  # Delete test branch after verification
  git checkout main
  git branch -d test-access
  git push origin --delete test-access
  rm test.txt
  ```

## Phase 1: GitHub Issues Creation

### Task 1.1: Create Issue #1 - Repository Foundation & Documentation

Create GitHub issue for repository foundation files including all root documentation, community files, and git configuration.

* **Files**:
  * CODE_OF_CONDUCT.md, CONTRIBUTING.md, LICENSE, README.md, SECURITY.md, SUPPORT.md
  * .gitignore, .gitattributes, .npmrc
  * logs/ directory structure
* **Success**:
  * Issue created with "foundation" and "documentation" labels
  * Issue body contains complete file list
  * Acceptance criteria includes markdown validation
  * Issue marked as "Merge Priority 1"
* **Research References**:
  * .copilot-tracking/research/20251105-pr-grouping-strategy-research.md (Lines 408-430) - Foundation files list and rationale
* **Dependencies**:
  * None - this is the first issue to be created
* **GitHub Issue Body Template**:
  * Title: "Repository Foundation & Documentation"
  * Labels: `foundation`, `documentation`, `merge-priority-1`
  * Body: Include file list, rationale, testing strategy from research lines 408-430

### Task 1.2: Create Issue #2 - Development Tools Configuration

Create GitHub issue for all tool configuration files including spell check, linting, and security scanning configs.

* **Files**:
  * .cspell.json, .cspell/ directory (4 dictionary files)
  * .markdownlint.json, .markdownlint-cli2.jsonc
  * .gitleaks.toml, .checkov.yaml
  * scripts/linting/PSScriptAnalyzer.psd1, scripts/linting/markdown-link-check.config.json
* **Success**:
  * Issue created with "configuration" and "tooling" labels
  * All config file paths listed in issue body
  * Acceptance criteria includes config validation
  * Issue marked as "Merge Priority 1"
* **Research References**:
  * .copilot-tracking/research/20251105-pr-grouping-strategy-research.md (Lines 432-454) - Tool config files and testing strategy
* **Dependencies**:
  * None - independent issue
* **GitHub Issue Body Template**:
  * Title: "Development Tools Configuration"
  * Labels: `configuration`, `tooling`, `merge-priority-1`
  * Body: Include rationale from research about early config deployment

### Task 1.3: Create Issue #3 - NPM/Node Dependencies

Create GitHub issue for Node.js package management files.

* **Files**:
  * package.json
  * package-lock.json
* **Success**:
  * Issue created with "dependencies" and "npm" labels
  * Issue body explains npm script definitions
  * Acceptance criteria includes `npm ci` validation
  * Issue marked as "Merge Priority 1"
* **Research References**:
  * .copilot-tracking/research/20251105-pr-grouping-strategy-research.md (Lines 456-476) - NPM dependencies rationale and testing
* **Dependencies**:
  * None - independent issue
* **GitHub Issue Body Template**:
  * Title: "NPM/Node Dependencies"
  * Labels: `dependencies`, `npm`, `merge-priority-1`
  * Body: Emphasize that scripts depend on these definitions

### Task 1.4: Create Issue #4 - Security Scanning Scripts

Create GitHub issue for PowerShell security scripts in scripts/security/.

* **Files**:
  * scripts/security/README.md
  * scripts/security/Test-DependencyPinning.ps1
  * scripts/security/Test-SHAStaleness.ps1
  * scripts/security/Update-ActionSHAPinning.ps1
* **Success**:
  * Issue created with "security" and "scripts" labels
  * Issue body lists dependency on Issue #2
  * Acceptance criteria includes local script execution
  * Issue marked as "Merge Priority 2"
* **Research References**:
  * .copilot-tracking/research/20251105-pr-grouping-strategy-research.md (Lines 478-500) - Security scripts and dependencies
* **Dependencies**:
  * Issue #2 must be merged first (config files)
* **GitHub Issue Body Template**:
  * Title: "Security Scanning Scripts"
  * Labels: `security`, `scripts`, `merge-priority-2`
  * Body: Note dependency on Issue #2, emphasize supply chain security

### Task 1.5: Create Issue #5 - Linting & Validation Scripts

Create GitHub issue for PowerShell linting scripts and shared module.

* **Files**:
  * scripts/linting/README.md
  * scripts/linting/Invoke-LinkLanguageCheck.ps1
  * scripts/linting/Invoke-PSScriptAnalyzer.ps1
  * scripts/linting/Link-Lang-Check.ps1
  * scripts/linting/Markdown-Link-Check.ps1
  * scripts/linting/Validate-MarkdownFrontmatter.ps1
  * scripts/linting/Modules/LintingHelpers.psm1
  * scripts/README.md
* **Success**:
  * Issue created with "linting" and "scripts" labels
  * Issue body lists dependencies on Issues #2 and #3
  * Acceptance criteria includes module import test
  * Issue marked as "Merge Priority 2"
* **Research References**:
  * .copilot-tracking/research/20251105-pr-grouping-strategy-research.md (Lines 502-524) - Linting scripts dependencies and testing
* **Dependencies**:
  * Issue #2 must be merged (config files)
  * Issue #3 must be merged (npm packages)
* **GitHub Issue Body Template**:
  * Title: "Linting & Validation Scripts"
  * Labels: `linting`, `scripts`, `merge-priority-2`
  * Body: Emphasize dual dependencies on configs and npm

### Task 1.6: Create Issue #6 - GitHub Copilot Chat Modes

Create GitHub issue for Copilot chat mode definitions.

* **Files**:
  * .github/chatmodes/README.md
  * .github/chatmodes/pr-review.chatmode.md
  * .github/chatmodes/prompt-builder.chatmode.md
  * .github/chatmodes/task-planner.chatmode.md
  * .github/chatmodes/task-researcher.chatmode.md
* **Success**:
  * Issue created with "copilot" and "documentation" labels
  * Issue body explains chat mode purpose
  * Acceptance criteria includes markdown validation and chat mode testing
  * Issue marked as "Merge Priority 1"
* **Research References**:
  * .copilot-tracking/research/20251105-pr-grouping-strategy-research.md (Lines 526-548) - Copilot chat modes rationale
* **Dependencies**:
  * None - independent issue
* **GitHub Issue Body Template**:
  * Title: "GitHub Copilot Chat Modes"
  * Labels: `copilot`, `documentation`, `merge-priority-1`
  * Body: Note these are self-contained configuration files

### Task 1.7: Create Issue #7 - GitHub Copilot Instructions

Create GitHub issue for Copilot instruction files.

* **Files**:
  * .github/instructions/README.md
  * .github/instructions/markdown.instructions.md
* **Success**:
  * Issue created with "copilot" and "standards" labels
  * Issue body explains instruction file purpose
  * Acceptance criteria includes frontmatter validation
  * Issue marked as "Merge Priority 1"
* **Research References**:
  * .copilot-tracking/research/20251105-pr-grouping-strategy-research.md (Lines 550-572) - Copilot instructions rationale
* **Dependencies**:
  * None - independent issue
* **GitHub Issue Body Template**:
  * Title: "GitHub Copilot Instructions"
  * Labels: `copilot`, `standards`, `merge-priority-1`
  * Body: Note these define coding standards for Copilot

### Task 1.8: Create Issue #8 - GitHub Metadata

Create GitHub issue for GitHub-specific metadata files.

* **Files**:
  * .github/CODEOWNERS
  * .github/GITHUB_OVERVIEW.md
  * .github/dependabot.yml
  * .github/PULL_REQUEST_TEMPLATE.md
  * .github/ISSUE_TEMPLATE/general-issue.yml
  * .github/ISSUE_TEMPLATE/instruction-file-request.yml
  * .github/ISSUE_TEMPLATE/prompt-request.yml
  * .github/ISSUE_TEMPLATE/chatmode-request.yml
  * .github/ISSUE_TEMPLATE/bug-report.yml
  * .github/prompts/ (empty directory)
* **Success**:
  * Issue created with "github" and "governance" labels
  * Issue body notes CODEOWNERS must be modified to remove team-specific references
  * Acceptance criteria includes CODEOWNERS syntax validation
  * Issue marked as "Merge Priority 1"
* **Research References**:
  * .copilot-tracking/research/20251105-pr-grouping-strategy-research.md (Lines 574-596) - GitHub metadata rationale
* **Dependencies**:
  * None - independent issue
* **CRITICAL**: CODEOWNERS currently references `@microsoft/hve-core-admins` which must be changed to a wildcard pattern that works for any repository. Recommended approach: Use `*` (asterisk) as the owner to require review from any repository collaborator with write access, or remove specific owner references entirely and rely on branch protection rules.
* **GitHub Issue Body Template**:
  * Title: "GitHub Metadata & Governance"
  * Labels: `github`, `governance`, `merge-priority-1`
  * Body: Must include CODEOWNERS modification instructions - change `@microsoft/hve-core-admins` to `*` or remove team references

### Task 1.9: Create Issue #9 - Core GitHub Actions Workflows (Validation)

Create GitHub issue for validation reusable workflows.

* **Files**:
  * .github/workflows/spell-check.yml
  * .github/workflows/markdown-lint.yml
  * .github/workflows/table-format.yml
  * .github/workflows/psscriptanalyzer.yml
  * .github/workflows/frontmatter-validation.yml
  * .github/workflows/link-lang-check.yml
  * .github/workflows/markdown-link-check.yml
* **Success**:
  * Issue created with "workflows" and "validation" labels
  * Issue body lists dependencies on Issues #2, #3, #5
  * Acceptance criteria includes YAML validation and workflow_call verification
  * Issue marked as "Merge Priority 3"
* **Research References**:
  * .copilot-tracking/research/20251105-pr-grouping-strategy-research.md (Lines 598-620) - Validation workflows and dependencies
* **Dependencies**:
  * Issue #2 (config files)
  * Issue #3 (npm packages)
  * Issue #5 (linting scripts)
* **GitHub Issue Body Template**:
  * Title: "Core GitHub Actions Workflows (Validation)"
  * Labels: `workflows`, `validation`, `merge-priority-3`
  * Body: Emphasize these are reusable workflows required by orchestration

### Task 1.10: Create Issue #10 - Security GitHub Actions Workflows

Create GitHub issue for security scanning reusable workflows.

* **Files**:
  * .github/workflows/gitleaks-scan.yml
  * .github/workflows/gitleaks.yml
  * .github/workflows/checkov-scan.yml
  * .github/workflows/sha-staleness-check.yml
  * .github/workflows/weekly-security-maintenance.yml
* **Success**:
  * Issue created with "workflows" and "security" labels
  * Issue body lists dependencies on Issues #2, #4
  * Acceptance criteria includes SARIF upload validation
  * Issue marked as "Merge Priority 3"
* **Research References**:
  * .copilot-tracking/research/20251105-pr-grouping-strategy-research.md (Lines 622-644) - Security workflows and dependencies
* **Dependencies**:
  * Issue #2 (config files)
  * Issue #4 (security scripts)
* **GitHub Issue Body Template**:
  * Title: "Security GitHub Actions Workflows"
  * Labels: `workflows`, `security`, `merge-priority-3`
  * Body: Note both reusable and standalone workflows

### Task 1.11: Create Issue #11 - PR & Main Branch Orchestration Workflows

Create GitHub issue for orchestration workflows that compose reusable workflows.

* **Files**:
  * .github/workflows/pr-validation.yml
  * .github/workflows/main.yml
  * .github/workflows/README.md
* **Success**:
  * Issue created with "workflows" and "orchestration" labels
  * Issue body lists dependencies on Issues #9, #10
  * Acceptance criteria includes test PR execution
  * Issue marked as "Merge Priority 4 - FINAL"
* **Research References**:
  * .copilot-tracking/research/20251105-pr-grouping-strategy-research.md (Lines 646-668) - Orchestration workflows and rationale
* **Dependencies**:
  * Issue #9 (validation workflows)
  * Issue #10 (security workflows)
* **CRITICAL**: This MUST be the last workflow PR to avoid "workflow not found" errors
* **GitHub Issue Body Template**:
  * Title: "PR & Main Branch Orchestration Workflows"
  * Labels: `workflows`, `orchestration`, `merge-priority-4`
  * Body: Emphasize this completes the CI/CD pipeline

### Task 1.12: Create Issue #12 - Development Container Configuration

Create GitHub issue for VS Code dev container configuration.

* **Files**:
  * .devcontainer/devcontainer.json
  * .devcontainer/README.md
* **Success**:
  * Issue created with "devcontainer" and "tooling" labels
  * Issue body explains dev container purpose
  * Acceptance criteria includes container build test
  * Issue marked as "Merge Priority 1"
* **Research References**:
  * .copilot-tracking/research/20251105-pr-grouping-strategy-research.md (Lines 670-692) - Dev container configuration
* **Dependencies**:
  * None - independent issue
* **GitHub Issue Body Template**:
  * Title: "Development Container Configuration"
  * Labels: `devcontainer`, `tooling`, `merge-priority-1`
  * Body: Note this enables consistent dev environments

## Phase 2: Wave 1 PRs (Foundation - Merge Priority 1)

### Task 2.1: Create PR for Issue #1 - Repository Foundation

Use PR Review chat mode to create branch, commit files, and submit PR for Issue #1.

* **Files**:
  * All files listed in Issue #1
* **Success**:
  * Branch created: `feat/issue-1-repository-foundation`
  * All foundation files committed
  * PR created and linked to Issue #1
  * PR passes markdown validation
  * PR ready for review and merge
* **Research References**:
  * .copilot-tracking/research/20251105-pr-grouping-strategy-research.md (Lines 408-430) - Foundation implementation details
* **Dependencies**:
  * Issue #1 must exist
* **PR Chat Mode Instructions**:
  * Use #file:../../.github/chatmodes/pr-review.chatmode.md for PR creation workflow
  * Create feature branch from main
  * Copy all files from current repository to new branch
  * Ensure markdown compliance before committing

### Task 2.2: Create PR for Issue #2 - Tool Configs

Use PR Review chat mode to create branch, commit config files, and submit PR for Issue #2.

* **Files**:
  * All files listed in Issue #2
* **Success**:
  * Branch created: `feat/issue-2-tool-configs`
  * All config files committed
  * PR created and linked to Issue #2
  * PR passes JSON/YAML/TOML syntax validation
  * PR ready for review and merge
* **Research References**:
  * .copilot-tracking/research/20251105-pr-grouping-strategy-research.md (Lines 432-454) - Tool config implementation
* **Dependencies**:
  * Issue #2 must exist
  * Can be developed in parallel with Issue #1
* **PR Chat Mode Instructions**:
  * Create feature branch from main
  * Copy all config files ensuring proper directory structure
  * Test config file syntax locally before committing

### Task 2.3: Create PR for Issue #3 - NPM Dependencies

Use PR Review chat mode to create branch, commit package files, and submit PR for Issue #3.

* **Files**:
  * package.json
  * package-lock.json
* **Success**:
  * Branch created: `feat/issue-3-npm-dependencies`
  * Package files committed
  * PR created and linked to Issue #3
  * `npm ci` executes successfully
  * PR ready for review and merge
* **Research References**:
  * .copilot-tracking/research/20251105-pr-grouping-strategy-research.md (Lines 456-476) - NPM dependencies implementation
* **Dependencies**:
  * Issue #3 must exist
  * Can be developed in parallel with Issues #1, #2
* **PR Chat Mode Instructions**:
  * Create feature branch from main
  * Copy package.json and package-lock.json
  * Run `npm ci` to verify lock file integrity

### Task 2.4: Create PR for Issue #6 - Copilot Chat Modes

Use PR Review chat mode to create branch, commit chat mode files, and submit PR for Issue #6.

* **Files**:
  * All files listed in Issue #6
* **Success**:
  * Branch created: `feat/issue-6-copilot-chat-modes`
  * All chat mode files committed
  * PR created and linked to Issue #6
  * Markdown and frontmatter validation passes
  * PR ready for review and merge
* **Research References**:
  * .copilot-tracking/research/20251105-pr-grouping-strategy-research.md (Lines 526-548) - Chat modes implementation
* **Dependencies**:
  * Issue #6 must exist
  * Can be developed in parallel with all Wave 1 issues
* **PR Chat Mode Instructions**:
  * Create feature branch from main
  * Copy all chat mode files
  * Test chat modes in VS Code with Copilot extension

### Task 2.5: Create PR for Issue #7 - Copilot Instructions

Use PR Review chat mode to create branch, commit instruction files, and submit PR for Issue #7.

* **Files**:
  * All files listed in Issue #7
* **Success**:
  * Branch created: `feat/issue-7-copilot-instructions`
  * All instruction files committed
  * PR created and linked to Issue #7
  * Frontmatter applyTo patterns validated
  * PR ready for review and merge
* **Research References**:
  * .copilot-tracking/research/20251105-pr-grouping-strategy-research.md (Lines 550-572) - Instructions implementation
* **Dependencies**:
  * Issue #7 must exist
  * Can be developed in parallel with all Wave 1 issues
* **PR Chat Mode Instructions**:
  * Create feature branch from main
  * Copy instruction files
  * Verify frontmatter glob patterns

### Task 2.6: Create PR for Issue #8 - GitHub Metadata

Use PR Review chat mode to create branch, commit metadata files, and submit PR for Issue #8.

* **Files**:
  * All files listed in Issue #8
* **Success**:
  * Branch created: `feat/issue-8-github-metadata`
  * CODEOWNERS file modified to work with any repository
  * PR created and linked to Issue #8
  * CODEOWNERS syntax validated
  * PR ready for review and merge
* **Research References**:
  * .copilot-tracking/research/20251105-pr-grouping-strategy-research.md (Lines 574-596) - Metadata implementation
* **Dependencies**:
  * Issue #8 must exist
  * Can be developed in parallel with all Wave 1 issues
* **CRITICAL CODEOWNERS Modification**:
  * Current: `/.github/workflows/ @microsoft/hve-core-admins`
  * Updated: `/.github/workflows/ *` (requires review from any collaborator with write access)
  * Current: `/scripts/security/ @microsoft/hve-core-admins`
  * Updated: `/scripts/security/ *` (requires review from any collaborator with write access)
  * Alternative: Remove owner references entirely and rely solely on branch protection rules
* **PR Chat Mode Instructions**:
  * Create feature branch from main
  * Modify CODEOWNERS file to replace `@microsoft/hve-core-admins` with `*` on both lines
  * Add comment explaining that `*` requires review from any repository collaborator with write access
  * Test CODEOWNERS syntax with GitHub CODEOWNERS validator

### Task 2.7: Create PR for Issue #12 - Dev Container

Use PR Review chat mode to create branch, commit dev container files, and submit PR for Issue #12.

* **Files**:
  * All files listed in Issue #12
* **Success**:
  * Branch created: `feat/issue-12-dev-container`
  * Dev container files committed
  * PR created and linked to Issue #12
  * Container builds successfully in VS Code
  * PR ready for review and merge
* **Research References**:
  * .copilot-tracking/research/20251105-pr-grouping-strategy-research.md (Lines 670-692) - Dev container implementation
* **Dependencies**:
  * Issue #12 must exist
  * Can be developed in parallel with all Wave 1 issues
* **PR Chat Mode Instructions**:
  * Create feature branch from main
  * Copy dev container configuration
  * Test "Reopen in Container" in VS Code

## Phase 3: Wave 2 PRs (Scripts - Merge Priority 2)

### Task 3.1: Create PR for Issue #4 - Security Scripts (after Issue #2 merged)

Use PR Review chat mode to create branch, commit security scripts, and submit PR for Issue #4.

* **Files**:
  * All files listed in Issue #4
* **Success**:
  * Branch created: `feat/issue-4-security-scripts`
  * All security scripts committed
  * PR created and linked to Issue #4
  * Scripts execute successfully locally
  * PR ready for review and merge
* **Research References**:
  * .copilot-tracking/research/20251105-pr-grouping-strategy-research.md (Lines 478-500) - Security scripts implementation
* **Dependencies**:
  * Issue #2 PR must be merged (config files)
* **PR Chat Mode Instructions**:
  * Create feature branch from current main (after Issue #2 merged)
  * Copy security scripts
  * Test each script with `-Verbose` flag

### Task 3.2: Create PR for Issue #5 - Linting Scripts (after Issues #2, #3 merged)

Use PR Review chat mode to create branch, commit linting scripts, and submit PR for Issue #5.

* **Files**:
  * All files listed in Issue #5
* **Success**:
  * Branch created: `feat/issue-5-linting-scripts`
  * All linting scripts and module committed
  * PR created and linked to Issue #5
  * LintingHelpers module imports successfully
  * PR ready for review and merge
* **Research References**:
  * .copilot-tracking/research/20251105-pr-grouping-strategy-research.md (Lines 502-524) - Linting scripts implementation
* **Dependencies**:
  * Issue #2 PR must be merged (config files)
  * Issue #3 PR must be merged (npm packages)
* **PR Chat Mode Instructions**:
  * Create feature branch from current main (after Issues #2, #3 merged)
  * Copy all linting scripts
  * Test module import: `Import-Module ./scripts/linting/Modules/LintingHelpers.psm1`

## Phase 4: Wave 3 PRs (Reusable Workflows - Merge Priority 3)

### Task 4.1: Create PR for Issue #9 - Validation Workflows (after Issues #2, #3, #5 merged)

Use PR Review chat mode to create branch, commit validation workflows, and submit PR for Issue #9.

* **Files**:
  * All files listed in Issue #9
* **Success**:
  * Branch created: `feat/issue-9-validation-workflows`
  * All validation workflows committed
  * PR created and linked to Issue #9
  * YAML syntax validated
  * SHA pinning compliance verified
  * PR ready for review and merge
* **Research References**:
  * .copilot-tracking/research/20251105-pr-grouping-strategy-research.md (Lines 598-620) - Validation workflows implementation
* **Dependencies**:
  * Issue #2 PR must be merged (config files)
  * Issue #3 PR must be merged (npm packages)
  * Issue #5 PR must be merged (linting scripts)
* **PR Chat Mode Instructions**:
  * Create feature branch from current main (after dependencies merged)
  * Copy all validation workflow files
  * Test SHA pinning with `Test-DependencyPinning.ps1`

### Task 4.2: Create PR for Issue #10 - Security Workflows (after Issues #2, #4 merged)

Use PR Review chat mode to create branch, commit security workflows, and submit PR for Issue #10.

* **Files**:
  * All files listed in Issue #10
* **Success**:
  * Branch created: `feat/issue-10-security-workflows`
  * All security workflows committed
  * PR created and linked to Issue #10
  * YAML syntax validated
  * SARIF upload permissions verified
  * PR ready for review and merge
* **Research References**:
  * .copilot-tracking/research/20251105-pr-grouping-strategy-research.md (Lines 622-644) - Security workflows implementation
* **Dependencies**:
  * Issue #2 PR must be merged (config files)
  * Issue #4 PR must be merged (security scripts)
* **PR Chat Mode Instructions**:
  * Create feature branch from current main (after dependencies merged)
  * Copy all security workflow files
  * Verify SARIF upload paths

## Phase 5: Wave 4 PRs (Orchestration - Merge Priority 4)

### Task 5.1: Create PR for Issue #11 - Orchestration Workflows (after Issues #9, #10 merged)

Use PR Review chat mode to create branch, commit orchestration workflows, and submit PR for Issue #11.

* **Files**:
  * All files listed in Issue #11
* **Success**:
  * Branch created: `feat/issue-11-orchestration-workflows`
  * All orchestration workflows committed
  * PR created and linked to Issue #11
  * Test PR triggers pr-validation.yml successfully
  * All called workflows execute without errors
  * PR ready for review and merge
* **Research References**:
  * .copilot-tracking/research/20251105-pr-grouping-strategy-research.md (Lines 646-668) - Orchestration implementation
* **Dependencies**:
  * Issue #9 PR must be merged (validation workflows)
  * Issue #10 PR must be merged (security workflows)
* **CRITICAL**: This is the FINAL workflow PR - all reusable workflows must exist first
* **PR Chat Mode Instructions**:
  * Create feature branch from current main (after all dependencies merged)
  * Copy orchestration workflow files
  * Create test PR to verify pr-validation.yml executes
  * Verify all called workflows are found and execute successfully

## Dependencies

* GitHub repository with admin access for issue creation
* GitHub MCP server configured for issue operations
* PR Review chat mode available for PR creation workflow
* Target repository initialized with default branch

## Success Criteria

* All 12 GitHub issues created with accurate file lists and dependencies
* All PRs created using PR Review chat mode workflow
* CODEOWNERS file uses generic admin references (not specific team names)
* Each PR independently testable and mergeable
* Repository functional after each merge
* CI/CD pipeline fully operational after final orchestration PR merged
* No "workflow not found" errors in any workflow execution
