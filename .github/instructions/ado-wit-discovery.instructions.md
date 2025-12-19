---
description: "Required protocol for discovering, planning, and handing off Azure DevOps User Stories and Bugs."
applyTo: '**/.copilot-tracking/workitems/discovery/**'
---

# Azure DevOps Work Item Discovery & Handoff

Follow all instructions from #file:./ado-wit-planning.instructions.md while executing this workflow.

## Scope

Apply this procedure when research, plans, or repository changes must be translated into Azure DevOps User Stories or Bugs.

* Primary focus: Discover, update, or create work items of type `${input:witFocus}` (default: `User Story`).
* When `${input:witFocus}` is `User Story`:
  * Discover related Epics and Features for linking only; do not create or update Epics or Features unless explicitly requested by the user.
  * Link User Stories to existing parent Features when appropriate.
* When `${input:witFocus}` is `Bug`:
  * Skip Feature and Epic discovery entirely.
  * Bugs are standalone and do not require parent linking.
* Output planning files under `.copilot-tracking/workitems/discovery/<folder-name>/` where `<folder-name>` is determined by analyzing the work being discovered (documents, branch changes, requirements) and creating a descriptive kebab-case name that represents the work scope.
* Default Azure DevOps project: `${input:adoProject}`

## Deliverables

* `artifact-analysis.md`, `work-items.md`, `planning-log.md`, and `handoff.md` synchronized per #file:./ado-wit-planning.instructions.md
* `handoff.md` with Create actions before Update actions, then No Change entries.
* ACTIVE KEYWORD GROUPS, similarity calculations, and decisions logged in `planning-log.md`.
* When authoritative external sources inform requirements or notes, add an **External References** section into the Description-like section for the work item in the work-items.md file that lists links with a brief context and summary.
  * Omit the External References section when no qualified references exist.
* Final conversational recap summarizing counts, parent links, and planning folder path.

## Tooling

* `run_in_terminal` (zsh) for git context **only when `${input:includeBranchChanges}` is `true` and no documents are provided**:
   1. Extract remote name from `${input:baseBranch}` (e.g., `origin` from `origin/main`)
   2. Sync remote base branch: `git fetch <remote> <branch-name> --prune`
   3. Generate structured diff XML: `scripts/dev-tools/pr-ref-gen.sh --base-branch "${input:baseBranch}" --output ".copilot-tracking/workitems/discovery/<folder-name>/git-branch-diff.xml"`
   4. Read complete XML with `read_file` (page through entire file if >2000 lines)
   5. Extract commit history, changed files, and diff context from XML structure
* Azure DevOps MCP tools:
  * `mcp_ado_search_workitem` for discovery.
  * `mcp_ado_wit_get_work_item` or `mcp_ado_wit_get_work_items_batch_by_ids` for hydration.
* Workspace utilities: `list_dir`, `read_file`, `grep_search` to locate artifacts.
* Persist all tool output into planning files per #file:./ado-wit-planning.instructions.md

<!-- <example-git-branch-diff-xml> -->
**Example git-branch-diff.xml structure:**

```xml
<commit_history>
  <current_branch>feat/acr-private-public-update</current_branch>
  <base_branch>origin/main</base_branch>
  <commits>
    <commit hash="a1b2c3d" date="2025-01-15">
      <message>
        <subject><![CDATA[Add ACR dual access support]]></subject>
        <body><![CDATA[Implement both public and private endpoint access for ACR]]></body>
      </message>
    </commit>
  </commits>
  <full_diff>
    diff --git a/src/000-cloud/060-acr/terraform/main.tf...
  </full_diff>
</commit_history>
```
<!-- </example-git-branch-diff-xml> -->

## Artifact Selection & Context Gathering

1. Prioritize artifacts in this order:
   * Explicit `${input:documents}` paths or attachments.
   * Documents inferred from conversation context.
   * Git diff analysis when `${input:includeBranchChanges}` is `true` and no documents exist.
2. Determine a descriptive folder name for the planning workspace:
   * Analyze the work being discovered from documents, branch changes, requirements, and context.
   * Create a concise, descriptive kebab-case folder name (e.g., `acr-dual-access-support`, `telemetry-bug-fixes`, `oauth2-authentication`).
   * The folder name should represent the work scope, not mirror artifact filenames.
   * Create/reuse the planning folder at `.copilot-tracking/workitems/discovery/<folder-name>/`.
3. Log each artifact in `planning-log.md` under **Discovered Artifacts & Related Files** with status `Not Started` before analysis.
4. When using git context:
   * Generate `git-branch-diff.xml` using the workflow from **Tooling** section.
   * Read the complete XML file using `read_file` (page through if necessary).
   * Extract commit messages, changed file paths, and diff context from XML elements.
   * Log `git-branch-diff.xml` as an artifact in `planning-log.md`.
   * Use extracted information to derive requirements, affected components, and keyword groups.
   * Treat git context as supplemental artifacts for requirements derivation.

## Workflow

### Phase 1 – Analyze Artifacts

1. Read each provided or inferred document to completion (`read_file` paging to EOF as needed).
   * When `${input:includeBranchChanges}` is `true` and git context is used, read the complete `git-branch-diff.xml` file.
   * Parse XML to extract commit subjects/bodies, changed files, and diff hunks.
2. Capture key findings, requirements, and questions in `artifact-analysis.md` and `planning-log.md` per templates in #file:./ado-wit-planning.instructions.md
   * For git-based analysis, include commit messages, affected file paths, and code changes in findings.
3. Extract capability-oriented requirements grouped by persona or system impact.
   * Derive requirements from both explicit documents and git changes (commits + diffs).
4. Build ACTIVE KEYWORD GROUPS combining nouns, verbs, component names, and file paths for Azure DevOps search per #file:./ado-wit-planning.instructions.md
   * Include component names and file paths from git-branch-diff.xml changed files when applicable.

### Phase 2 – Discover Existing Work Items

**Primary Work Items**:

1. For each keyword group, call `mcp_ado_search_workitem` with:
   * `project`: `${input:adoProject}`
   * `searchText`: constructed from ACTIVE KEYWORD GROUPS using OR/AND syntax per #file:./ado-wit-planning.instructions.md
   * `workItemType`: Use `${input:witFocus}` value (e.g., `["User Story"]` or `["Bug"]`)
   * `state`: Parse `${input:workItemStates}` (default: `["New", "Active", "Resolved"]`)
   * `top`: 50; increment `skip` until fewer results return than requested.
   * Optional filters: `${input:areaPath}`, `${input:iterationPath}`
2. Hydrate results immediately via `mcp_ado_wit_get_work_item` (batch variant preferred) and log under **Discovered ADO Work Items** in `planning-log.md`.
3. Compute similarity using the matrix from #file:./ado-wit-planning.instructions.md Record scores (e.g., `ADO-1234=0.78`) in both `planning-log.md` and `work-items.md`.
4. Capture current `System.State`, titles, descriptions, and acceptance criteria (or repro steps for Bugs) in `artifact-analysis.md`.

**Features and Epics (Conditional - User Stories Only)**:

1. **Skip this section entirely when `${input:witFocus}` is `Bug`.**
2. Do not plan updates or creation for Features or Epics unless the user explicitly requests it.
3. When `${input:witFocus}` is `User Story`, search for `["Feature"]` using relevant keyword groups to identify potential parent Features.
   * If no suitable Features are found with initial search terms, broaden the search using more general keyword groups (e.g., remove file-specific terms, use higher-level component names, or use capability-area terms).
   * New User Stories must be linked to a parent Feature; continue broadening search terms until at least one suitable parent Feature is identified.
4. For each discovered Feature, capture its parent Epic reference if present.
5. Hydrate Feature and Epic details for context; log in `planning-log.md`.

### Phase 3 – Plan Work Items

**Update Existing Work Items**:

1. For each work item with similarity ≥ 0.70, plan an Update action:
   * Merge new requirements into existing description and acceptance criteria (or `Microsoft.VSTS.TCM.ReproSteps` for Bugs).
   * Preserve validated legacy content; extend rather than replace.
   * Update `System.Title` if the scope has broadened significantly.
2. For similarity 0.50-0.69, mark as **Needs Review** in `handoff.md` with rationale.
3. For similarity < 0.50, consider for new work item creation.

**Create New Work Items**:

1. Consolidate related requirements into the fewest work items that deliver unified outcomes:
   * Prefer creating **one** work item unless:
     * Work is large enough to require multiple items (e.g., multiple personas, distinct outcomes).
2. Author titles per #file:./ado-wit-planning.instructions.md
   * User Stories: `As a <persona>, I <need|want|would like> <outcome>`, do not include a `so that...` or rationale in the title as that will go into the description.
   * Bugs: Concise problem statement describing the defect.
3. Build descriptions:
   * User Stories: `As a <persona>, I <need|want|would like> <outcome> so that <rationale>`, include aggregated requirements covering artifacts and changes, include external references.
   * Bugs: Use `Microsoft.VSTS.TCM.ReproSteps` field with clear reproduction steps.
4. Populate acceptance criteria:
   * User Stories: Verifiable Markdown style checkbox list `- [ ]` in `Microsoft.VSTS.Common.AcceptanceCriteria`.
   * Bugs: Verification steps can be included in repro steps or as acceptance criteria.
     * Acceptance criteria should be a Markdown style checkbox list `- [ ]`.
     * Repro steps should be a Markdown style ordered list, with sub lists when needed `1.`, `2.`, etc.
5. Link User Stories to existing parent Features when appropriate; document the parent in `work-items.md`. Skip parent linking for Bugs.

**Resolved Work Items**:

1. When a `Resolved` work item satisfies the requirement without updates, set action to `No Change`.
2. If creating a new or updating an existing work item, add a `Related` link back to the `Resolved` item for traceability.

### Phase 4 – Assemble Handoff & Validate

1. Build `handoff.md` per template in #file:./ado-wit-planning.instructions.md
   * Create entries first, followed by Updates, then No Change entries.
   * Include checkboxes, summaries, relationships, and supporting artifact references.
2. Ensure planning file paths appear in **Planning Files** section.
3. Verify consistency across all planning files (aligned WI references, totals, decisions).
4. Deliver final conversational recap covering counts, parent links, and planning workspace location.
