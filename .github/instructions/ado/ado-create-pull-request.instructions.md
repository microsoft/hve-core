---
description: "Required protocol for creating Azure DevOps pull requests with work item discovery, reviewer identification, and automated linking."
applyTo: '**/.copilot-tracking/pr/new/**'
---

# Azure DevOps Pull Request Creation

Follow all instructions from #file:./ado-wit-planning.instructions.md for planning file conventions while executing this workflow.

## Scope

Apply this procedure when creating a new Azure DevOps pull request with automated PR description generation, work item discovery and linking, reviewer identification from git history, and complete traceability through planning documents.

Output planning files to `.copilot-tracking/pr/new/<normalized-branch-name>/` using the specified Azure DevOps project `${input:adoProject}` and repository `${input:repository}`.

## Inputs

* `${input:adoProject}`: (Required) Azure DevOps project name or ID.
* `${input:repository}`: (Required) Repository name or ID.
* `${input:sourceBranch}`: (Optional) Source branch name. Defaults to current git branch.
* `${input:baseBranch:origin/main}`: (Optional) Base branch for comparison.
* `${input:similarityThreshold:50}`: (Optional) Minimum similarity score (0-100) for work item matching.
* `${input:workItemStates:["New", "Active", "Resolved"]}`: (Optional) Work item state filter.
* `${input:workItemIds}`: (Optional) Explicit work item IDs to link, bypassing discovery.
* `${input:isDraft:false}`: (Optional) Create PR as draft.
* `${input:noGates:false}`: (Optional) Skip user confirmation gates.
* `${input:includeMarkdown:true}`: (Optional) Include markdown file diffs in PR reference.

## Deliverables

* `pr-reference.xml` - Git diff and commit history
* `pr.md` - Pull request description
* `pr-analysis.md` - Change analysis and work item findings
* `reviewer-analysis.md` - Reviewer analysis with rationale
* `planning-log.md` - Operational log
* `handoff.md` - Final PR creation plan
* Conversational recap with PR URL

## Tooling

Generate a PR reference XML containing commit history and diffs using the `pr-reference` skill, comparing against `${input:baseBranch}` and saving to the tracking directory. After generation, use the pr-reference skill to query the XML: extract changed file paths with change type filters and output format options, and read diff content in chunks by number, line range, or specific file path.
When the skill is unavailable, parse the XML directly or use `git diff --name-status` and `git diff` commands for equivalent extraction.

Git operations via `run_in_terminal`:

* `git fetch <remote> <branch-name> --prune` to sync remote
* `git config user.email` for current user
* `git log --all --pretty=format:'%H %an <%ae>' -- <file-pattern> | head -20` for contributors

### Azure DevOps MCP Tools

* `mcp_ado_repo_get_repo_by_name_or_id` - Resolve repository IDs from name. Parameters: `project`, `repositoryNameOrId`.
* `mcp_ado_repo_create_pull_request` - Create pull request. Required: `repositoryId`, `sourceRefName`, `targetRefName`, `title`. Optional: `description`, `isDraft`, `labels` (array), `workItems` (space-separated IDs), `forkSourceRepositoryId`.
* `mcp_ado_repo_update_pull_request` - Update PR settings. Required: `repositoryId`, `pullRequestId`. Optional: `title`, `description`, `status` (Active|Abandoned), `isDraft`, `autoComplete`, `mergeStrategy` (NoFastForward|Squash|Rebase|RebaseMerge), `deleteSourceBranch`, `transitionWorkItems`, `bypassReason`, `labels`.
* `mcp_ado_repo_update_pull_request_reviewers` - Add or remove reviewers. Required: `repositoryId`, `pullRequestId`, `reviewerIds` (array of GUIDs), `action` (add|remove).
* `mcp_ado_wit_link_work_item_to_pull_request` - Link work item to PR. Required: `projectId` (GUID), `repositoryId`, `pullRequestId`, `workItemId`. Optional: `pullRequestProjectId` (for cross-project linking).
* `mcp_ado_search_workitem` - Search work items. Parameters: `searchText`, `project`, `workItemType`, `state`, `assignedTo`, `top`, `skip`.
* `mcp_ado_wit_get_work_item` - Get work item details. Parameters: `id`, `project`, `expand`, `fields`.
* `mcp_ado_wit_get_work_items_batch_by_ids` - Batch get work items. Parameters: `project`, `ids` (array), `fields`.
* `mcp_ado_core_get_identity_ids` - Resolve identity GUIDs from email or name. Parameters: `searchFilter`.

Workspace utilities: `list_dir`, `read_file`, `grep_search`

Persist all tool output into planning files per ado-wit-planning.instructions.md.

## Tracking Directory Structure

All PR creation tracking artifacts reside in `.copilot-tracking/pr/new/{{normalized branch name}}`.

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

## Planning File Formats

### pr-analysis.md

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

### reviewer-analysis.md

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
   * **Identity ID**: [Azure DevOps GUID or "Manual addition required"]
   * **Contribution Score**: [High|Medium|Low]
   * **Files**: [List of changed files they contributed to]
   * **Rationale**: [Why they would be a good reviewer]
   * **User Decision**: [Pending|Required|Optional|Skip]

2. **[Reviewer 2 Name]** <[email]>
   * **Identity ID**: [Azure DevOps GUID or "Manual addition required"]
   * **Contribution Score**: [High|Medium|Low]
   * **Files**: [List of changed files they contributed to]
   * **Rationale**: [Why they would be a good reviewer]
   * **User Decision**: [Pending|Required|Optional|Skip]

## Reviewer Recommendation

* **Recommended Reviewers**: [List of high-contribution reviewers]
* **Additional Reviewers**: [List of lower-contribution reviewers]
````

### handoff.md

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

### 1. Create Pull Request

**Tool**: `mcp_ado_repo_create_pull_request`

**Parameters**:
* `repositoryId`: "[Repository ID]"
* `sourceRefName`: "refs/heads/[source-branch-name]"
* `targetRefName`: "refs/heads/[target-branch-name]"
* `title`: "[PR title from pr.md first line WITHOUT the markdown heading marker hash]"
  * Example: `feat(scope): description` (NOT `# feat(scope): description`)
* `description`: "[PR description from pr.md body WITH full markdown formatting]"
* `isDraft`: [true|false]
* `labels`: ["label-name"] (optional)
* `workItems`: "[space-separated work item IDs]" (optional, alternative to separate linking calls)

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

### planning-log.md

````markdown
# Planning Log - [Branch Name]

* **Source Branch**: [branch name]
* **Target Branch**: [target branch]
* **Project**: [Azure DevOps project]
* **Repository**: [Repository name]
* **Current Phase**: [Phase number]
* **Previous Phase**: [Phase number or N/A]

## Phase Progress

| Phase                            | Status                                 | Notes   |
|----------------------------------|----------------------------------------|---------|
| Phase 1: Setup                   | [Complete/In Progress/Pending]         | [Notes] |
| Phase 2: PR Description          | [Complete/In Progress/Pending]         | [Notes] |
| Phase 3: Work Item Discovery     | [Complete/In Progress/Pending/Skipped] | [Notes] |
| Phase 3a: Work Item Creation     | [Complete/In Progress/Pending/Skipped] | [Notes] |
| Phase 4: Reviewer Identification | [Complete/In Progress/Pending]         | [Notes] |
| Phase 5: User Confirmation       | [Complete/In Progress/Pending/Skipped] | [Notes] |
| Phase 6: PR Creation             | [Complete/In Progress/Pending]         | [Notes] |
| Phase 7: Final Recap             | [Complete/In Progress/Pending]         | [Notes] |

## Artifacts

* **pr-reference.xml**: [Generated/Existing/Pending]
* **pr.md**: [Generated/Pending]
* **pr-analysis.md**: [Generated/Pending]
* **reviewer-analysis.md**: [Generated/Pending]
* **handoff.md**: [Generated/Pending]

## Work Items

* Discovered: [Count]
* Created: [Count or N/A]
* Selected for linking: [Count]
* IDs: [Comma-separated list]

## Reviewers

* Identified: [Count]
* Identity resolved: [Count]
* Pending manual addition: [Count]

## Recovery Information

If context is summarized, read all files from the planning directory and resume from the current phase recorded above.
````

## Protocol Overview

This workflow follows a progressive confirmation model where user reviews and approves each section before proceeding:

1. **Setup & Analysis** (Phases 1-4): Silent preparation - generate artifacts, analyze changes, discover work items and reviewers
2. **User Review & Confirmation** (Phase 5): Present information in stages with confirmation gates
3. **PR Creation** (Phase 6): Execute after final user signoff
4. **Completion** (Phase 7): Deliver recap with PR URL

Present each confirmation gate separately and wait for user response before proceeding to the next gate. Avoid presenting all information at once.

### No-Gates Mode

When `${input:noGates}` is true:

* Skip Phase 5 (all confirmation gates) entirely
* After completing Phase 4, proceed directly to Phase 6
* Use all discovered work items (no user selection)
* If Phase 3a created a work item, use that created work item automatically
* Add minimum of 2 optional reviewers (top 2 by contribution score)
* Create PR immediately with all discovered linkages
* Deliver final recap in Phase 7 as usual

## Required Phases

### Phase 1: Setup and PR Reference Generation

Execute without presenting details to user:

1. Determine normalized branch name from `${input:sourceBranch}` or current git branch.
2. Create planning directory: `.copilot-tracking/pr/new/<normalized-branch-name>/`
3. Initialize `planning-log.md` with Phase-1 status.
4. Check if `pr-reference.xml` exists:
   * If exists: Use existing file silently.
   * If not exists: Generate using the `pr-reference` skill with optional `--no-md-diff` flag if `${input:includeMarkdown}` is false.
5. Read complete `pr-reference.xml`. For files exceeding 2000 lines, read in 1000-2000 line chunks, capturing complete commit boundaries before advancing to the next chunk.
6. Log artifact in `planning-log.md` with status `Complete`.

### Phase 2: Generate PR Description

Execute without presenting to user yet:

1. Analyze `pr-reference.xml` completely before writing any content. Include only changes visible in the reference file; do not invent or assume changes.
2. Generate `pr.md` in the planning directory (not in root) following the PR File Format below.
3. Extract commit types, scopes, and key changes for PR title and description.
4. Use past tense for all descriptions.
5. Describe WHAT changed, not speculating WHY.
6. Use natural, conversational language that reads like human communication.
7. Match tone and terminology from commit messages.
8. Group and order changes by SIGNIFICANCE and IMPORTANCE (most significant first).
9. Combine related changes into single descriptive points.
10. Only add sub-bullets when they provide genuine clarification value.
11. Only include "Notes," "Important," or "Follow-up" sections if supported by commit messages or code comments.
12. Extract changed file list with descriptions for Gate 1 presentation.
13. Log generation in `planning-log.md`.

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

### Phase 3: Discover Related Work Items

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

### Phase 3a: Create Work Item for PR

Execute this phase when Phase 3 discovers zero viable work items.

Follow ado-wit-discovery.instructions.md and ado-update-wit-items.instructions.md to create a work item:

1. Create planning directory `.copilot-tracking/workitems/discovery/<folder-name>/` using the branch name without prefix.
2. Reuse `pr-reference.xml`, PR title, description, and keyword groups from previous phases.
3. Follow ado-wit-discovery.instructions.md phases to plan creation of ONE User Story or Bug based on PR content. Derive type from branch name or commit type (feat → User Story, fix → Bug).
4. Execute work item creation following ado-update-wit-items.instructions.md. Capture created work item ID in `handoff-logs.md`.
5. Store created work item ID for Phase 6 linking. Update `pr-analysis.md` with created work item details.

### Phase 4: Identify Potential Reviewers

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
   * For GitHub noreply emails (`*@users.noreply.github.com`): Search git history for alternative email addresses using `git log --author="<username>" --pretty=format:'%ae' | sort -u`, then retry identity resolution with discovered alternatives
   * If no match found after alternatives, mark reviewer for manual addition
   * If multiple matches found, use most recent activity or mark for user disambiguation
6. Capture analysis in `reviewer-analysis.md` with rationale and resolved identity IDs.
7. Log potential reviewers and resolution status in `planning-log.md`.

### Phase 5: User Review and Confirmation

Skip this phase when `${input:noGates}` is true; proceed directly to Phase 6 using all discovered work items, created work items from Phase 3a, and top 2 reviewers by contribution score.

Present each gate separately and wait for user approval before proceeding to the next gate.

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

**Presentation Format**:

```markdown
## 📄 Changed Files Review

I've analyzed [count] changed files in your PR:

### Modified Files
1. [path/to/file1.ext]: [Brief description of changes]
2. [path/to/file2.ext]: [Brief description of changes]

### Quality Review
✅ No Issues Found (or ⚠️ list issues requiring attention)

Please review the changes. Reply with "Continue", "Remove [filename]", or "Add [filename]".
```

For changesets over 50 files, provide summary statistics and link to `pr-analysis.md`.

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

**Presentation Format**:

```markdown
## 📝 Pull Request Title & Description

**Title**: [Generated title from pr.md]

**Description**:
[Complete PR description from pr.md with markdown preserved]

**Security & Compliance Check**: [Results]

Reply with "Continue", "Change title to: [new title]", or "Regenerate description".
```

**Wait for user response before proceeding to Gate 3.**

#### Gate 3: Work Items Review

1. If `${input:workItemIds}` was provided: Present those work items for confirmation.
2. If work item was created in Phase 3a: Present the created work item for confirmation.
3. If discovered in Phase 3: Present up to 10 highest similarity work items.
4. For each work item provide:
   * Work item ID and type
   * Title
   * Current state (for Closed items, add note: "Linking provides historical traceability")
   * Similarity score (percentage) - or "Created for this PR" if from Phase 3a
   * 1-2 sentence relevance reasoning
5. For work items in Closed state, ask user to confirm if linking for historical traceability is desired.

**Presentation Format**:

```markdown
## 🔗 Work Items to Link

I found [count] work items that may relate to your changes:

1. ADO-[ID] - [Type] - [State]: [Title] ([XX]% similarity)
   Why: [1-2 sentence relevance]

Reply with "Link [ID1], [ID2]", "Link all", or "Skip".
```

**Wait for user response and capture selections. Proceed to Gate 4.**

#### Gate 4: Reviewers Review

1. Present suggested reviewers from `reviewer-analysis.md`.
2. Separate into Recommended and Additional categories based on contribution score.
3. Provide contribution score and rationale for each.

**Presentation Format**:

```markdown
## 👥 Suggested Reviewers

Based on git history of changed files:

1. [Name] ([email]) - [High/Medium] - [XX] commits: [Rationale]
2. [Name] ([email]) - [Medium/Low] - [XX] commits: [Rationale]

Reply with "Continue", "Add [email]", "Remove [email]", or "Skip".
```

**Wait for user response and capture selections. Proceed to Gate 5.**

#### Gate 5: Final Summary & Signoff

1. Build complete `handoff.md` with all user-confirmed selections.
2. Present comprehensive summary of everything that will be created.
3. Request final signoff before executing PR creation.

**Presentation Format**:

```markdown
## ✨ Final Pull Request Summary

**Pull Request**: [Title] | [source-branch] → [target-branch] | [count] files
**Work Items**: [count] to link
**Reviewers**: [count] total

Reply with "Create PR", "Modify [aspect]", or "Cancel".
```

**Wait for explicit "Create PR" or "Approved" confirmation before proceeding to Phase 6.**

### Phase 5 Modification Handling

When user requests modifications at any gate, update the relevant planning file, log changes in `planning-log.md`, and re-present that gate for confirmation. Track modification count per gate; after 3+ iterations, suggest an alternative approach or pause.

### Phase 6: Create Pull Request and Link Work Items

Proceed after user gives explicit approval.

1. Resolve repository and project IDs:
   * Use `${input:repository}` directly if GUID format; otherwise call `mcp_ado_repo_get_repo_by_name_or_id` with project and repository name.
   * Use `${input:adoProject}` directly if GUID; otherwise extract from `mcp_ado_search_workitem` response metadata.
   * For GitHub-backed Azure DevOps projects where repository is not found: Verify the GitHub connection in Azure DevOps project settings (Project Settings → Repos → GitHub connections). The repository may require explicit configuration before appearing in ADO queries.
   * Log both IDs in `planning-log.md`.

2. Prepare branch references:
   * Source: `refs/heads/${input:sourceBranch}` (or current branch)
   * Target: Remove remote prefix from `${input:baseBranch}` and prepend `refs/heads/`. Examples:
     * `origin/main` → `refs/heads/main`
     * `upstream/develop` → `refs/heads/develop`
     * `main` → `refs/heads/main`

3. Create pull request using `mcp_ado_repo_create_pull_request` with `repositoryId`, `sourceRefName`, `targetRefName`, and `title` (from pr.md without leading #). Optionally include `description`, `isDraft`, and `labels`. The `workItems` parameter accepts space-separated IDs to link work items during creation, simplifying the workflow. Capture returned PR ID and URL.

4. Link additional work items using `mcp_ado_wit_link_work_item_to_pull_request` for each selected work item not linked during creation. Requires `projectId` (GUID format), `repositoryId`, `pullRequestId`, and `workItemId`. For cross-project linking, include `pullRequestProjectId`. Log results in `planning-log.md`.

5. Add reviewers using `mcp_ado_repo_update_pull_request_reviewers` with resolved identity GUIDs. All reviewers are added as optional by default. In no-gates mode, add top 2 by contribution score. Document unresolved reviewers for manual addition.

6. Validate completion by reading `handoff.md` to verify checkboxes and confirming PR URL accessibility.

## MCP Tool Reference

```javascript
// Resolve repository ID from name
mcp_ado_repo_get_repo_by_name_or_id({
  project: "<project-name-or-guid>",
  repositoryNameOrId: "<repo-name>"
})

// Create PR (with optional work item and label linking)
mcp_ado_repo_create_pull_request({
  repositoryId: "<guid>",
  sourceRefName: "refs/heads/<branch>",
  targetRefName: "refs/heads/main",
  title: "feat(scope): description",
  description: "## Summary\n\nChanges...",
  isDraft: false,
  labels: ["label-name"],           // Optional: add labels at creation
  workItems: "1234 5678"             // Optional: space-separated work item IDs
})

// Update PR (set autocomplete, merge strategy, labels)
mcp_ado_repo_update_pull_request({
  repositoryId: "<guid>",
  pullRequestId: 1234,
  autoComplete: true,                 // Enable autocomplete when policies pass
  mergeStrategy: "Squash",            // NoFastForward|Squash|Rebase|RebaseMerge
  deleteSourceBranch: true,           // Delete source after merge
  transitionWorkItems: true           // Transition linked work items
})

// Link work item (for cross-project, add pullRequestProjectId)
mcp_ado_wit_link_work_item_to_pull_request({
  projectId: "<project-guid>",
  repositoryId: "<repo-guid>",
  pullRequestId: 1234,
  workItemId: 5678,
  pullRequestProjectId: "<pr-project-guid>"  // Optional: cross-project linking
})

// Resolve identity (requires activate_ado_identity_and_search_tools)
mcp_ado_core_get_identity_ids({ searchFilter: "user@example.com" })

// Add reviewers
mcp_ado_repo_update_pull_request_reviewers({
  repositoryId: "<guid>",
  pullRequestId: 1234,
  reviewerIds: ["<identity-guid-1>", "<identity-guid-2>"],
  action: "add"
})
```

### Phase 7: Deliver Final Recap

Provide conversational summary covering PR creation status and URL, work items linked, reviewers status, planning workspace location, and next steps.

```markdown
## ✅ Pull Request Created Successfully

**PR**: [PR ID] | [PR URL] | [Active|Draft]
**Linked**: ADO-[ID], ADO-[ID]
**Reviewers**: [Name] (added) | [Name] (manual)
**Files**: `.copilot-tracking/pr/new/[branch]/`
```

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
