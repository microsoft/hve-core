<!-- markdownlint-disable-file -->
# Implementation Prompt: PR Grouping Strategy

## Implementation Instructions

### Step 0: Repository Preparation

**MANDATORY FIRST STEP**: You WILL complete Phase 0 before creating any GitHub issues or PRs.

**Task 0.1 - Update CODEOWNERS in Source Repository**:
1. Navigate to hve-core source repository: `cd c:\Users\wberry\src\hve-core`
2. Open `.github/CODEOWNERS` file
3. Replace line: `/.github/workflows/ @microsoft/hve-core-admins` with `/.github/workflows/ *`
4. Replace line: `/scripts/security/ @microsoft/hve-core-admins` with `/scripts/security/ *`
5. Commit changes: `git add .github/CODEOWNERS && git commit -m "fix: Update CODEOWNERS to use universal wildcard pattern" && git push origin main`

**Task 0.2 - Verify Target Repository**:
1. Confirm target repository URL (e.g., https://github.com/microsoft/hve-core)
2. Verify write access (can create branches and PRs)
3. Ensure default branch is initialized (main or master)
4. If working with separate clone, set up target repository:
   ```bash
   cd c:\Users\wberry\src
   git clone https://github.com/microsoft/hve-core hve-core-target
   cd hve-core-target
   git branch --show-current
   git remote -v
   ```

### Step 1: Create Changes Tracking File

You WILL create `20251105-pr-grouping-strategy-changes.md` in `.copilot-tracking/changes/` if it does not exist.

### Step 2: Execute Implementation

**CRITICAL**: You WILL complete Phase 0 (Repository Preparation) before proceeding to Phase 1.

You WILL follow #file:../../.github/instructions/task-implementation.instructions.md
You WILL systematically implement #file:../plans/20251105-pr-grouping-strategy-plan.instructions.md task-by-task
You WILL follow ALL project standards and conventions

**Git Workflow Pattern for Each PR (Phases 2-5)**:
1. Ensure on main branch: `git checkout main && git pull`
2. Create feature branch: `git checkout -b feat/issue-{N}-{description}`
3. Restore specific files from stash: `git checkout stash@{0} -- <file-path-1> <file-path-2> ...`
4. Stage restored files: `git add .`
5. Verify only intended files staged: `git status`
6. Commit: `git commit -m "feat: Add {description} (#N)"`
7. Push: `git push -u origin feat/issue-{N}-{description}`
8. Use GitHub MCP tools to create PR linking to issue
9. Return to main for next PR: `git checkout main`
10. Stash remains intact for next issue (using `git checkout stash@{0} --` preserves stash)

**CRITICAL**: If ${input:phaseStop:true} is true, you WILL stop after each Phase for user review.
**CRITICAL**: If ${input:taskStop:false} is true, you WILL stop after each Task for user review.

### Implementation Notes

**Phase 1: GitHub Issues Creation**
* Use GitHub MCP server tools to create issues programmatically
* Each issue must include proper labels, milestone, and complete file list
* Issue bodies should reference research document for full context
* Ensure issue dependencies are documented in issue descriptions

**Phase 2-5: PR Creation Workflow**
* For each issue, use PR Review chat mode workflow:
  1. Create feature branch with naming pattern: `feat/issue-{number}-{description}`
  2. Copy files from current hve-core repository to new branch
  3. Commit files with descriptive commit messages
  4. Create PR using PR Review chat mode
  5. Link PR to corresponding GitHub issue
  6. Ensure PR passes all validation checks before requesting review

**CODEOWNERS Modification**
* When creating PR for Issue #8, modify CODEOWNERS file
* Current references: `@microsoft/hve-core-admins` (team-specific, won't work in new repos)
* Replace with: `*` (wildcard that requires review from any collaborator with write access)
* Specific changes:
  * Line: `/.github/workflows/ @microsoft/hve-core-admins`
  * Replace with: `/.github/workflows/ *`
  * Line: `/scripts/security/ @microsoft/hve-core-admins`
  * Replace with: `/scripts/security/ *`
* Add inline comment explaining `*` means "any repository collaborator with write access"
* Alternative: Remove owner assignments and rely on branch protection rules only
* This ensures the configuration works for any repository without requiring specific team setup

**Dependency Management**
* Wave 1 PRs (Issues #1, #2, #3, #6, #7, #8, #12): Can be created in parallel
* Wave 2 PRs: Wait for Wave 1 dependencies to merge before creating
* Wave 3 PRs: Wait for Wave 2 dependencies to merge before creating
* Wave 4 PR (Issue #11): MUST be last - wait for all reusable workflows to merge

### Step 3: Cleanup

When ALL Phases are checked off (`[x]`) and completed you WILL do the following:
  1. You WILL provide a markdown style link and a summary of all changes from #file:../changes/20251105-pr-grouping-strategy-changes.md to the user:
    * You WILL keep the overall summary brief
    * You WILL add spacing around any lists
    * You MUST wrap any reference to a file in a markdown style link
  2. You WILL provide markdown style links to .copilot-tracking/plans/20251105-pr-grouping-strategy-plan.instructions.md, .copilot-tracking/details/20251105-pr-grouping-strategy-details.md, and .copilot-tracking/research/20251105-pr-grouping-strategy-research.md documents. You WILL recommend cleaning these files up as well.
  3. **MANDATORY**: You WILL attempt to delete .copilot-tracking/prompts/implement-pr-grouping-strategy.prompt.md

## Success Criteria

* [ ] Changes tracking file created
* [ ] All 12 GitHub issues created with proper labels and dependencies
* [ ] All issues include complete file lists and acceptance criteria
* [ ] CODEOWNERS file modified to use generic admin references
* [ ] All Wave 1 PRs created and ready for merge
* [ ] All Wave 2 PRs created after dependencies merged
* [ ] All Wave 3 PRs created after dependencies merged
* [ ] Final orchestration PR (Issue #11) created last
* [ ] All PRs linked to corresponding issues
* [ ] Changes file updated continuously
