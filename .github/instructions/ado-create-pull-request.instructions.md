---
description: "Required protocol for creating Azure DevOps pull requests with work item discovery, reviewer identification, and automated linking."
applyTo: '**/.copilot-tracking/pr/new/**'
---

# Azure DevOps Pull Request Creation & Workflow

Follow all instructions from #file:./ado-wit-planning.instructions.md for planning file conventions while executing this workflow.

## Scope

Apply this procedure when creating a new Azure DevOps pull request with:

* Automated PR description generation from branch changes
* Discovery and linking of related User Stories and Bugs
* Identification of potential reviewers from git history
* Complete traceability through planning documents
* Automated PR creation via Azure DevOps MCP tools

* Output planning files under `.copilot-tracking/pr/new/<normalized-branch-name>/`
* Default Azure DevOps project: `${input:adoProject}`
* Default repository: `${input:repository}`

## Deliverables

* `pr-reference.xml` - Complete git diff and commit history
* `pr.md` - Generated pull request description
* `pr-analysis.md` - Analysis of changes and discovered work items
* `reviewer-analysis.md` - Potential reviewers with rationale
* `planning-log.md` - Structured operational log
* `handoff.md` - Final PR creation plan with all details
* Conversational recap summarizing PR creation results with URL

## Tooling

* `run_in_terminal` (zsh) for git operations:
   1. Sync remote base branch: `git fetch <remote> <branch-name> --prune`
   2. Generate PR reference XML: `scripts/dev-tools/pr-ref-gen.sh --base-branch "${input:baseBranch}" --output ".copilot-tracking/pr/new/<normalized-branch-name>/pr-reference.xml"`
   3. Get current user: `git config user.email`
   4. Get file contributors: `git log --all --pretty=format:'%H %an <%ae>' -- <file-pattern> | head -20`
* Azure DevOps MCP tools:
  * `mcp_ado_search_workitem` for work item discovery
  * `mcp_ado_wit_get_work_item` or `mcp_ado_wit_get_work_items_batch_by_ids` for hydration
  * `mcp_ado_repo_create_pull_request` for PR creation
  * `mcp_ado_wit_link_work_item_to_pull_request` for linking work items
  * `mcp_ado_core_get_identity_ids` for resolving reviewer emails to Azure DevOps identity IDs
  * `mcp_ado_repo_update_pull_request_reviewers` for adding/removing reviewers programmatically
* Workspace utilities: `list_dir`, `read_file`, `grep_search`
* Persist all tool output into planning files per #file:./ado-wit-planning.instructions.md

<!-- <tracking-directory-structure> -->
## Tracking Directory Structure

All PR creation tracking artifacts MUST reside in `.copilot-tracking/pr/new/{{normalized branch name}}`.

```plaintext
.copilot-tracking/
  pr/
    new/
      {{normalized branch name}}/
        pr-reference.xml          # Generated git diff and commit history
        pr.md                     # Generated PR description
        pr-analysis.md            # Change analysis and work item findings
        reviewer-analysis.md      # Potential reviewer analysis
        planning-log.md           # Operational log
        handoff.md                # Final PR creation plan
```

**Branch Name Normalization Rules**:

* Convert to lowercase characters
* Replace `/` with `-`
* Strip special characters except hyphens
* Example: `feat/ACR-Private-Public` → `feat-acr-private-public`
<!-- </tracking-directory-structure> -->

<!-- <planning-file-formats> -->
## Planning File Formats

### pr-analysis.md

<!-- <template-pr-analysis-md> -->
````markdown
# Pull Request Analysis - [Branch Name]
* **Source Branch**: [Source branch name]
* **Target Branch**: [Target branch name]
* **Project**: [Azure DevOps project]
* **Repository**: [Repository name or ID]

## Change Summary

[1-5 sentence summary of what changed based on pr-reference.xml analysis]

## Changed Files

* [file/path/one.ext]: [Brief description of changes]
* [file/path/two.ext]: [Brief description of changes]

## Commit Summary
* [Aggregated summary of commit messages]

## Work Item Discovery

### Keyword Groups for Search

1. [Keyword group 1]: [term1 OR term2 OR "multi word term"]
2. [Keyword group 2]: [term1 OR term2]

### Discovered Work Items

#### ADO-[Work Item ID] - [Similarity Score] - [Type]
* **Title**: [Work item title]
* **State**: [Current state]
* **Relevance Reasoning**: [Why this work item relates to the PR]
* **User Decision**: [Pending|Link|Skip]

## Notes

* [Optional notes about the analysis]
````
<!-- </template-pr-analysis-md> -->

### reviewer-analysis.md

<!-- <template-reviewer-analysis-md> -->
````markdown
# Reviewer Analysis - [Branch Name]
* **Current User**: [Current git user email]
* **Changed Files**: [Count]

## Contributor Analysis

### Changed File: [file/path/one.ext]
* **Recent Contributors** (last 20 commits):
  * [Contributor 1 Name] <[email]> - [commit count] commits
  * [Contributor 2 Name] <[email]> - [commit count] commits

### Changed File: [file/path/two.ext]
* **Recent Contributors** (last 20 commits):
  * [Contributor 1 Name] <[email]> - [commit count] commits

### Surrounding Files: [directory/**]
* **Recent Contributors** (last 20 commits):
  * [Contributor Name] <[email]> - [commit count] commits

## Potential Reviewers (excluding current user)

1. **[Reviewer 1 Name]** <[email]>
   * **Contribution Score**: [High|Medium|Low]
   * **Files**: [List of changed files they contributed to]
   * **Rationale**: [Why they would be a good reviewer]
   * **User Decision**: [Pending|Required|Optional|Skip]

2. **[Reviewer 2 Name]** <[email]>
   * **Contribution Score**: [High|Medium|Low]
   * **Files**: [List of changed files they contributed to]
   * **Rationale**: [Why they would be a good reviewer]
   * **User Decision**: [Pending|Required|Optional|Skip]

## Reviewer Recommendation

* **Recommended Reviewers**: [List of high-contribution reviewers]
* **Additional Reviewers**: [List of lower-contribution reviewers]
````
<!-- </template-reviewer-analysis-md> -->

### handoff.md

<!-- <template-handoff-md> -->
````markdown
# Pull Request Creation Handoff
* **Project**: [Azure DevOps project]
* **Repository**: [Repository name or ID]
* **Repository ID**: [Repository ID for MCP tool]
* **Source Branch**: [Source branch name]
* **Target Branch**: [Target branch name]
* **Is Draft**: [true|false]

## Planning Files

* .copilot-tracking/pr/new/[normalized-branch-name]/handoff.md
* .copilot-tracking/pr/new/[normalized-branch-name]/pr-analysis.md
* .copilot-tracking/pr/new/[normalized-branch-name]/reviewer-analysis.md
* .copilot-tracking/pr/new/[normalized-branch-name]/planning-log.md
* .copilot-tracking/pr/new/[normalized-branch-name]/pr.md

## PR Details

### Title

[Generated PR title from pr.md]

### Description

```markdown
[Complete PR description from pr.md]
```

## Work Items to Link

* [ ] ADO-[Work Item ID] - [Type] - [Title]
  * **Similarity**: [Score]
  * **Reason**: [Why linking this work item]
* [ ] ADO-[Work Item ID] - [Type] - [Title]
  * **Similarity**: [Score]
  * **Reason**: [Why linking this work item]

**Total Work Items**: [Count]

## Reviewers to Add

### Reviewers

* [ ] [Reviewer Name] <[email]>
  * **Rationale**: [Why they should review]

* [ ] [Reviewer Name] <[email]>
  * **Rationale**: [Why they should review]

**Total Reviewers**: [Count]

## MCP Tool Call Plan

### 2. Create Pull Request

**Tool**: `mcp_ado_repo_create_pull_request`

**Parameters**:
* `repositoryId`: "[Repository ID]"
* `sourceRefName`: "refs/heads/[source-branch-name]"
* `targetRefName`: "refs/heads/[target-branch-name]"
* `title`: "[PR title from pr.md first line WITHOUT the markdown heading marker hash]"
  * Example: `feat(scope): description` (NOT `# feat(scope): description`)
* `description`: "[PR description from pr.md body WITH full markdown formatting]"
* `isDraft`: [true|false]

**Expected Result**: Pull request created with ID [PR-ID]

### 2. Link Work Items

**Tool**: `mcp_ado_wit_link_work_item_to_pull_request` (call once per work item)

**Parameters for each work item**:
* `projectId`: "[Project ID]"
* `repositoryId`: "[Repository ID]"
* `pullRequestId`: [PR-ID from step 1]
* `workItemId`: [Work Item ID]

**Total Calls**: [Count of work items to link]

### 3. Add Reviewers

**Tool**: `mcp_ado_repo_update_pull_request_reviewers`

**Parameters**:
* `repositoryId`: "[Repository ID]"
* `pullRequestId`: [PR-ID from step 1]
* `reviewerIds`: [[Array of resolved identity GUIDs from mcp_ado_core_get_identity_ids]]
* `action`: "add"

**Expected Result**: Reviewers added to pull request [PR-ID]

**Note**: Reviewers without resolved identity IDs must be added manually via Azure DevOps UI.

## User Signoff

* [ ] PR details reviewed and approved
* [ ] Work items confirmed
* [ ] Reviewers confirmed
* [ ] Ready to create PR

**User Confirmation**: [Pending|Approved]
````
<!-- </template-handoff-md> -->
<!-- </planning-file-formats> -->

## Workflow Overview

This workflow follows a progressive confirmation model where user reviews and approves each section before proceeding:

1. **Setup & Analysis** (Phases 1-4): Silent preparation - generate artifacts, analyze changes, discover work items and reviewers
2. **User Review & Confirmation** (Phase 5): Present information in stages with confirmation gates
3. **PR Creation** (Phase 6): Execute after final user signoff
4. **Completion** (Phase 7): Deliver recap with PR URL

**Critical**: Do NOT present all information at once. Present each confirmation gate separately and wait for user response before proceeding to the next gate.

### No-Gates Mode

When `${input:noGates}` is true:

* Skip Phase 5 (all confirmation gates) entirely
* After completing Phase 4, proceed directly to Phase 6
* Use all discovered work items (no user selection)
* If Phase 3a created a work item, use that created work item automatically
* Add minimum of 2 optional reviewers (top 2 by contribution score)
* Create PR immediately with all discovered linkages
* Deliver final recap in Phase 7 as usual

## Workflow

### Phase 1 – Setup & PR Reference Generation (Silent)

Execute without presenting details to user:

1. Determine normalized branch name from `${input:sourceBranch}` or current git branch.
2. Create planning directory: `.copilot-tracking/pr/new/<normalized-branch-name>/`
3. Initialize `planning-log.md` with Phase-1 status.
4. Check if `pr-reference.xml` exists:
   * If exists: Use existing file silently.
   * If not exists: Generate using `scripts/dev-tools/pr-ref-gen.sh` with optional `--no-md-diff` flag if `${input:includeMarkdown}` is false.
5. Read complete `pr-reference.xml` (page through if >2000 lines).
6. Log artifact in `planning-log.md` with status `Complete`.

### Phase 2 – Generate PR Description (Silent)

Execute without presenting to user yet:

1. **CRITICAL**: Analyze `pr-reference.xml` completely before writing any content.
2. **CRITICAL**: Do NOT invent or assume changes not present in `pr-reference.xml`.
3. **CRITICAL**: Only include changes visible in `pr-reference.xml`.
4. Generate `pr.md` in the planning directory (NOT in root) following the PR File Format below.
5. Extract commit types, scopes, and key changes for PR title and description.
6. Use past tense for all descriptions.
7. Describe WHAT changed, not speculating WHY.
8. Use natural, conversational language that reads like human communication.
9. Match tone and terminology from commit messages.
10. Group and order changes by SIGNIFICANCE and IMPORTANCE (most significant first).
11. Combine related changes into single descriptive points.
12. Only add sub-bullets when they provide genuine clarification value.
13. Only include "Notes," "Important," or "Follow-up" sections if supported by commit messages or code comments.
14. Extract changed file list with descriptions for Gate 1 presentation.
15. Log generation in `planning-log.md`.

<!-- <pr-file-format> -->
**PR File Format for pr.md**:

```markdown
# {{type}}({{scope}}): {{concise description}}

{{Summary paragraph of overall changes in natural, human-friendly language}}

- **{{type}}**(_{{scope}}_): {{description of change with key context included}}

- **{{type}}**(_{{scope}}_): {{description of change}}
  - {{sub-bullet only if it adds genuine clarification value}}

- **{{type}}**: {{description of change without scope, including essential details}}

## Notes (optional)

- Note 1 identified from code comments or commit message
- Note 2 identified from code comments or commit message

## Important (optional)

- Critical information 1 identified from code comments or commit message
- Warning 2 identified from code comments or commit message

## Follow-up Tasks (optional)

- Task 1 with file reference
- Task 2 with specific component mention

{{emoji representing the changes}} - Generated by Copilot
```

**Type and Scope**:

* Determine from commits in `pr-reference.xml`
* Use branch name as primary source for type/scope
* Common types: feat, fix, docs, chore, refactor, test, ci
* Scope should reference component or area affected

**Title Construction Rules**:

* Format: `{type}({scope}): {concise description}`
* If branch name is not descriptive, rely on commit messages
* Keep concise but descriptive

**Never Include**:

* Changes related to linting errors or auto-generated documentation
* Speculative benefits ("improves security") unless explicit in commits
* Follow-up tasks for documentation or tests (unless in commit messages)
<!-- </pr-file-format> -->

### Phase 3 – Discover Related Work Items (Silent)

**Skip this phase entirely if `${input:workItemIds}` is provided by the user.**

Execute without presenting to user yet:

1. Build ACTIVE KEYWORD GROUPS from:
   * Changed file paths (component names, directories)
   * Commit messages (subjects and bodies)
   * Conventional commit scopes
   * Technical terms from diff content
2. For each keyword group, call `mcp_ado_search_workitem` with:
   * `project`: `${input:adoProject}`
   * `searchText`: constructed from keyword groups using OR/AND syntax
   * `workItemType`: ["User Story", "Bug"] (NEVER include Feature or Epic)
   * `state`: Parse `${input:workItemStates}` into array format
   * `top`: 50; increment `skip` as needed
   * Optional filters: `${input:areaPath}`, `${input:iterationPath}`
3. Hydrate results via `mcp_ado_wit_get_work_item` (batch variant preferred).
4. Compute similarity using semantic analysis of:
   * Work item title + description vs. PR title + description
   * Work item acceptance criteria vs. PR change summary
   * Boost for matching commit scopes, file paths, technical terms
5. Filter work items with similarity >= `${input:similarityThreshold}`.
6. Capture findings in `pr-analysis.md` with relevance reasoning.
7. Log discovered work items in `planning-log.md`.
8. If NO viable work items are discovered (zero work items with similarity >= threshold):
   * Proceed to Phase 3a - Create Work Item for PR
   * After Phase 3a completion, continue to Phase 4

### Phase 3a – Create Work Item for PR (Conditional)

**Execute this phase ONLY when Phase 3 discovers zero viable work items.**

Read in and follow instructions from ado-wit-discovery.instructions.md and ado-update-wit-items.instructions.md to create a work item for this PR:

1. **Setup Work Item Discovery Planning**:
   * Determine folder name from PR context (e.g., branch name without `feat/`, `fix/`, etc.)
   * Create planning directory: `.copilot-tracking/workitems/discovery/<folder-name>/`
   * Initialize planning files following ado-wit-discovery.instructions.md templates

2. **Reuse PR Analysis Artifacts**:
   * Copy or reference `pr-reference.xml` from PR planning directory
   * Use existing PR title, description, and change analysis from Phase 2
   * Use existing ACTIVE KEYWORD GROUPS from Phase 3
   * Skip git-branch-diff.xml generation (already have pr-reference.xml)

3. **Execute Work Item Discovery Workflow**:
   * Follow Phase 1 of ado-wit-discovery.instructions.md using PR artifacts
   * Create `artifact-analysis.md` from PR context (commits, files, changes)
   * Follow Phase 2 to discover Features for potential parent linking (User Stories only)
   * Follow Phase 3 to plan work item creation:
     * Create ONE User Story or Bug based on PR content
     * Derive work item type from branch name or commit type (feat → User Story, fix → Bug)
     * Title: Extract from PR title following work item conventions
     * Description: Adapt from PR description with rationale
     * Acceptance Criteria: Derive from PR changes and commit messages
     * Link to parent Feature if discovered (User Stories only)
   * Follow Phase 4 to assemble `handoff.md` with Create action

4. **Execute Work Item Creation**:
   * Follow instructions from ado-update-wit-items.instructions.md
   * Create `handoff-logs.md` in work item planning directory
   * Process the Create action from `handoff.md`
   * Use `mcp_ado_wit_create_work_item` to create the work item
   * Capture created work item ID in `handoff-logs.md`
   * Log creation result in PR `planning-log.md`

5. **Link Created Work Item to PR Flow**:
   * Store created work item ID for use in Phase 6 linking
   * Update PR `pr-analysis.md` with created work item details
   * Log in PR `planning-log.md` that work item was created for this PR

**Note**: This phase creates exactly ONE work item representing the PR's purpose. Skip Feature/Epic creation. Keep planning files in work item discovery folder separate from PR planning folder.

### Phase 4 – Identify Potential Reviewers (Silent)

Execute without presenting to user yet:

1. Get current user email: `git config user.email`
2. For each changed file in `pr-reference.xml`:
   * Extract file path
   * Get recent contributors: `git log --all --pretty=format:'%H %an <%ae>' -- <file-path> | head -20`
   * Parse output to count commits per author
3. For surrounding directories of changed files:
   * Use parent directory patterns (e.g., `path/to/dir/**`)
   * Get recent contributors: `git log --all --pretty=format:'%H %an <%ae>' -- <dir-pattern> | head -20`
4. Aggregate contributors across all changed files and directories:
   * Count total commits per contributor
   * Exclude current user
   * Rank by contribution score (High: >10 commits, Medium: 3-10, Low: 1-2)
5. Resolve Azure DevOps identity IDs:
   * For each unique reviewer email, call `mcp_ado_core_get_identity_ids` with `searchFilter` set to the email
   * Extract `id` (GUID) from response and store with reviewer record
   * If no match or multiple matches found, mark for manual addition
6. Capture analysis in `reviewer-analysis.md` with rationale and resolved identity IDs.
7. Log potential reviewers and resolution status in `planning-log.md`.

### Phase 5 – User Review & Confirmation (Progressive Gates)

**Skip this entire phase if `${input:noGates}` is true. Proceed directly to Phase 6 with:**

* All discovered work items from Phase 3
* If Phase 3a created a work item, use that created work item
* Top 2 reviewers by contribution score from Phase 4 (minimum 2 optional reviewers)
* Auto-approve all content from Phases 1-4

**Critical**: Present each gate separately. Wait for user approval/modification before proceeding to next gate.

#### Gate 1: Changed Files Review

1. Extract all changed files from `pr-reference.xml`.
2. For each file, provide brief description of changes from diff analysis.
3. Perform quality review and identify:
   * Accidental or unintended changes (e.g., debug code, commented code)
   * Missing files that should be tracked
   * Extra files that should not be included (e.g., build artifacts, temp files)
   * Security issues (secrets, credentials, PII)
   * Compliance issues (non-compliant language, FIXME, WIP, etc in committed code)
   * Code quality concerns (styling violations, linting issues)

**File Count Handling**:

* If ≤ 50 files: Present full list inline with change descriptions
* If > 50 files: Provide summary statistics and link to `pr-analysis.md`, instruct user to review and confirm when ready

<!-- <example-gate1-small-changeset> -->
**Presentation Format (≤50 files)**:

```markdown
## 📄 Changed Files Review

I've analyzed [count] changed files in your PR:

### Modified Files

1. **[path/to/file1.ext]**
   * [Brief description of changes]

2. **[path/to/file2.ext]**
   * [Brief description of changes]

### Quality Review

✅ **No Issues Found**

[OR if issues found:]

⚠️ **Issues Requiring Attention**:
* [Issue 1 with file reference]
* [Issue 2 with file reference]

Please review the changes. You can:
* Continue ("Approved" or "Continue")
* Remove files ("Remove [filename]")
* Add missing files ("Add [filename]")
* Make other modifications (specify what to change)
```
<!-- </example-gate1-small-changeset> -->

<!-- <example-gate1-large-changeset> -->
**Presentation Format (>50 files)**:

```markdown
## 📄 Changed Files Review

Your PR includes **[count] changed files** - this is a large changeset.

**Summary**:
* Modified: [count]
* Added: [count]
* Deleted: [count]

**Key Changes**:
* [Top 3-5 most significant changes with file paths]

**Quality Review**:
[✅ No major issues found OR ⚠️ List of issues requiring attention]

📋 **Complete file list**: `.copilot-tracking/pr/new/[normalized-branch]/pr-analysis.md`

Please review the full analysis and let me know when to continue or if you need modifications.
```
<!-- </example-gate1-large-changeset> -->

**Wait for user response before proceeding to Gate 2.**

#### Gate 2: PR Title & Description Review

1. Extract PR title from `pr.md` first line:
   * Remove leading `#` and whitespace
   * Example: `# feat(scope): description` → `feat(scope): description`
   * This cleaned title will be used for Azure DevOps PR creation
2. Present complete PR description from `pr.md` body (after first line):
   * Preserve all markdown formatting including headings with `#` markers
3. Perform security/compliance analysis on `pr-reference.xml`:
   * Customer information leaks (PII, customer data)
   * Secrets or credentials (API keys, passwords, tokens)
   * Non-compliant language (FIXME, WIP, etc in committed code)
   * Unintended changes or accidental file inclusion
   * Missing referenced files

<!-- <example-gate2> -->
**Presentation Format**:

```markdown
## 📝 Pull Request Title & Description

**Title**:
```text

[Generated title from pr.md]

```

**Description**:

```markdown
[Complete PR description from pr.md]
```

**Security & Compliance Check**:
[Details of security and compliance check]

Please review the PR content. You can:

* Continue ("Approved" or "Continue")
* Modify title ("Change title to: [new title]")
* Modify description ("Update description: [changes]")
* Request regeneration ("Regenerate description")

```text
<!-- </example-gate2> -->

**Wait for user response before proceeding to Gate 3.**

#### Gate 3: Work Items Review

1. If `${input:workItemIds}` was provided: Present those work items for confirmation.
2. If work item was created in Phase 3a: Present the created work item for confirmation.
3. If discovered in Phase 3: Present up to 10 highest similarity work items.
4. For each work item provide:
   * Work item ID and type
   * Title
   * Current state
   * Similarity score (percentage) - or "Created for this PR" if from Phase 3a
   * 1-2 sentence relevance reasoning

<!-- <example-gate3> -->
**Presentation Format**:

```markdown
## 🔗 Work Items to Link

[If work item was created in Phase 3a:]
I created a new work item for this PR since no existing work items matched:

### ADO-[ID] - [Type] - New
**Title**: [Work item title]
**Status**: Created for this PR
**Why link**: Work item created to track this pull request's changes

[If work items were discovered in Phase 3:]
I found [count] work items that may relate to your changes:

### ADO-[ID] - [Type] - [State]
**Title**: [Work item title]
**Similarity**: [XX]%
**Why link**: [1-2 sentence relevance explanation]

[Repeat for each work item, maximum 10]

Which work items should be linked to this PR?
* Link specific IDs: "Link [ID1], [ID2]"
* Link all: "Link all"
* Skip linking: "None" or "Skip"
* See more options: "Show more"
```
<!-- </example-gate3> -->

**Wait for user response and capture selections. Proceed to Gate 4.**

#### Gate 4: Reviewers Review

1. Present suggested reviewers from `reviewer-analysis.md`.
2. Separate into Recommended and Additional categories based on contribution score.
3. Provide contribution score and rationale for each.

<!-- <example-gate4> -->
**Presentation Format**:

```markdown
## 👥 Suggested Reviewers

Based on git history of changed files:

### Recommended Reviewers

1. **[Name]** ([email])
   * Contribution: [High/Medium] - [XX] commits to changed files
   * Rationale: [Why they should review]

### Additional Reviewers

1. **[Name]** ([email])
   * Contribution: [Medium/Low] - [XX] commits
   * Rationale: [Why they might be helpful]

Please confirm reviewers:
* Approve: "Approved" or "Continue"
* Modify: "Add [name/email]" or "Remove [name/email]"
* Skip: "None" or "Skip reviewers"
```
<!-- </example-gate4> -->

**Wait for user response and capture selections. Proceed to Gate 5.**

#### Gate 5: Final Summary & Signoff

1. Build complete `handoff.md` with all user-confirmed selections.
2. Present comprehensive summary of everything that will be created.
3. Request final signoff before executing PR creation.

<!-- <example-gate5> -->
**Presentation Format**:

```markdown
## ✨ Final Pull Request Summary

Ready to create your PR with these details:

**Pull Request**:
* **Title**: [Confirmed title]
* **Source**: [source-branch] → [target-branch]
* **Draft**: [Yes/No]
* **Files**: [count] changed files

**Work Items** ([count] to link):
* ADO-[ID]: [Title]
[List all confirmed work items]

**Reviewers** ([count] total):
* [Name] ([email]) - Required
[List all confirmed reviewers]

📄 **Planning Files**: `.copilot-tracking/pr/new/[normalized-branch]/`
📋 **Detailed Plan**: `handoff.md`

Everything looks good? Reply with:
* **"Create PR"** or **"Approved"** - I'll create the pull request now
* **"Modify [aspect]"** - Make changes before creating
* **"Cancel"** - Stop without creating the PR
```
<!-- </example-gate5> -->

**Wait for explicit "Create PR" or "Approved" confirmation before proceeding to Phase 6.**

### Phase 5 Modification Handling

When user requests modifications at any gate:

1. **File Changes** (Gate 1):
   * User can request file additions/removals
   * Regenerate `pr-reference.xml` if files added/removed via git commands
   * Re-run Phase 2 if significant changes
   * Return to Gate 1 for re-confirmation

2. **Title/Description Changes** (Gate 2):
   * Update `pr.md` with user-requested changes
   * Log modifications in `planning-log.md`
   * Re-present Gate 2 for confirmation

3. **Work Item Changes** (Gate 3):
   * Add/remove work items from link list
   * If user provides new IDs, fetch and validate them
   * Update `pr-analysis.md` with confirmed selections
   * Re-present Gate 3 for confirmation

4. **Reviewer Changes** (Gate 4):
   * Add/remove reviewers from list
   * Validate email addresses if new reviewers added
   * Update `reviewer-analysis.md` with confirmed selections
   * Re-present Gate 4 for confirmation

5. **Final Changes** (Gate 5):
   * Allow modifications to any aspect
   * Return to specific gate for that aspect
   * Rebuild summary after modifications

**Iteration Protocol**:

* Track modification count per gate in `planning-log.md`
* After 3+ iterations on same gate, suggest alternative approach or pause
* Always confirm changes before proceeding

### Phase 6 – Create Pull Request & Link Work Items

**Only proceed after user gives explicit approval.**

1. **Resolve Repository and Project IDs**:
   * **Repository ID**: If `${input:repository}` is a GUID format, use directly; otherwise:
     * Search workspace for repository configuration (`.azure/`, `azure-pipelines.yml`, or project docs)
     * Use `mcp_ado_repo_list_pull_requests_by_project` to discover repository ID from project
     * If unavailable, ask user to provide repository ID
   * **Project ID**: ADO project ID required for work item linking:
     * If `${input:adoProject}` is a GUID, use directly
     * Otherwise, use `mcp_ado_search_workitem` response metadata to extract project ID
     * If unavailable, note work item linking will require manual completion
   * Log both IDs in `planning-log.md`

2. **Prepare Source and Target Branch References**:
   * Source: `refs/heads/${input:sourceBranch}` (or current branch)
   * Target: Extract branch name from `${input:baseBranch}` (e.g., `origin/main` → `refs/heads/main`)

3. **Create Pull Request**:
   * Tool: `mcp_ado_repo_create_pull_request`
   * Required parameters:
     * `repositoryId`: [Repository ID from step 1]
     * `sourceRefName`: [Source ref from step 2]
     * `targetRefName`: [Target ref from step 2]
     * `title`: [PR title from pr.md with leading # and whitespace removed]
   * Optional parameters:
     * `description`: [Body of pr.md after first line with full markdown formatting]
     * `isDraft`: `${input:isDraft}`
   * Capture returned pull request ID and URL
   * Log PR creation result in `planning-log.md`
   * Update `handoff.md` with actual PR ID and URL

4. **Link Work Items** (if any were selected/provided):
   * For each work item to link:
     * Tool: `mcp_ado_wit_link_work_item_to_pull_request`
     * Required parameters:
       * `projectId`: [Project ID from step 1 - must be GUID format]
       * `repositoryId`: [Repository ID from step 1]
       * `pullRequestId`: [PR ID from step 3]
       * `workItemId`: [Work item ID to link]
     * Log each linking result in `planning-log.md`
     * Update `handoff.md` checkbox for each work item
   * If project ID unavailable, document work items for manual linking in final recap

5. **Add Reviewers** (if any were confirmed and resolved):
   * Tool: `mcp_ado_repo_update_pull_request_reviewers`
   * Parameters: `repositoryId`, `pullRequestId`, `reviewerIds` (array of GUIDs), `action: "add"`
   * **Important**: All reviewers are added as **optional** reviewers by default
   * **No-Gates Mode**: If `${input:noGates}` is true, add top 2 reviewers by contribution score (minimum 2 optional reviewers)
   * Add all reviewers with resolved identity IDs in a single batch call
   * For reviewers without resolved IDs, document in final recap for manual addition via Azure DevOps UI
   * Log reviewer addition results in `planning-log.md`

6. **Final Validation**:
   * Read back `handoff.md` to verify all checkboxes
   * Confirm PR URL is accessible
   * Verify work item links in Azure DevOps (if possible via tools)

<!-- <example-mcp-tool-calls> -->
## MCP Tool Call Examples

### Create Pull Request

```javascript
mcp_ado_repo_create_pull_request({
  repositoryId: "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  sourceRefName: "refs/heads/feat/acr-dual-access",
  targetRefName: "refs/heads/main",
  title: "feat(acr): add dual public/private access support",
  description: "## Summary\n\nAdds support for dual access patterns...",
  isDraft: false
})
```

### Link Work Item to Pull Request

```javascript
mcp_ado_wit_link_work_item_to_pull_request({
  projectId: "hve-core-project-id",  // Must be project ID, not name
  repositoryId: "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  pullRequestId: 1234,
  workItemId: 5678
})
```

### Resolve Reviewer Identity IDs

```javascript
// Resolve single reviewer email to Azure DevOps identity ID
mcp_ado_core_get_identity_ids({
  searchFilter: "sample.name@example.com"
})
// Returns: [{"id":"d291b0c4-a05c-4ea6-8df1-4b41d5f39eff","displayName":"Sample Name","descriptor":"aad.YTkz..."}]
```

### Add Reviewers to Pull Request

```javascript
// Add multiple reviewers in a single batch call
mcp_ado_repo_update_pull_request_reviewers({
  repositoryId: "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  pullRequestId: 1234,
  reviewerIds: [
    "d291b0c4-a05c-4ea6-8df1-4b41d5f39eff",  // Sample Name
    "f5e6d7c8-b9a0-1234-5678-90abcdef1234"   // Another reviewer
  ],
  action: "add"
})
```
<!-- </example-mcp-tool-calls> -->

### Phase 7 – Deliver Final Recap

Provide conversational summary covering:

* PR creation status and URL
* Work items linked (count and IDs)
* Reviewers status (added or manual action required)
* Planning workspace location
* Next steps if any

<!-- <example-final-recap> -->
```markdown
## ✅ Pull Request Created Successfully

**PR Number**: [PR ID number]
**URL**: [PR URL]
**Title**: [PR title]
**Status**: [Active|Draft]

### Linked Work Items
* ADO-[ID]: [Title]
* ADO-[ID]: [Title]

### Reviewers
* **Required**: [Name] ([email])
* **Optional**: [Name] ([email])
* **Note**: Reviewers added automatically or manually via [PR URL] if identity resolution failed

### Planning Files
All artifacts saved to: `.copilot-tracking/pr/new/[normalized-branch]/`

**Next Steps**:
1. Review the PR at [PR URL]
2. Add reviewers if not done automatically
3. Monitor for build status and feedback
```
<!-- </example-final-recap> -->

## Error Recovery

* **Phase 1**: PR reference generation fails → verify git state, branch existence, base branch validity
* **Phase 3**: Too many/no work items → adjust similarity threshold or keyword groups; if still none, proceed to Phase 3a to create work item
* **Phase 3a**: Work item creation fails → log error, inform user, proceed to Phase 4 without work item (user can link manually later)
* **Phase 4**: Identity resolution fails → mark reviewer for manual addition via Azure DevOps UI
* **Phase 6**: Repository/Project ID not found → search workspace config or request from user
* **Phase 6**: PR creation fails → verify branch refs, permissions, no duplicate PR
* **Phase 6**: Work item linking fails → verify work item exists, project ID is GUID format, PR created successfully
* **Phase 6**: Reviewer addition fails → provide manual addition instructions with PR URL

## Presentation Guidelines

* Use markdown: **bold** for emphasis, emoji for visual clarity (✅, 📄, 🔍)
* Present summaries before details; avoid information overload
* Provide clear options with suggested responses
* Confirm before irreversible actions

## State Persistence & Recovery

* Maintain `planning-log.md` after each major action
* Update phase transitions in `planning-log.md`
* If context is summarized:
  1. Read all planning files from `.copilot-tracking/pr/new/<normalized-branch>/`
  2. Rebuild context from `planning-log.md` current phase
  3. Resume from last incomplete step
  4. Inform user of recovery process

## Repository-Specific Conventions

When working in this repository:

* Follow PR description format specified in Phase 2 (pr-file-format block)
* Use conventional commit types in PR titles
* Include component scope when applicable
* Reference changed files for reviewer context
* Link related documentation when available
* Follow markdown linting rules per `.markdownlint.json`
* Use natural, human-friendly language in PR descriptions
* Group changes by significance and importance
* Avoid speculating about benefits not stated in commits
