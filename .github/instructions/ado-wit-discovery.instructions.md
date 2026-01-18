---
description: 'Protocol for discovering Azure DevOps work items via user assignment or artifact analysis with planning file output'
applyTo: '**/.copilot-tracking/workitems/discovery/**'
maturity: stable
---

# Azure DevOps Work Item Discovery

Discover Azure DevOps work items through two paths: user-centric queries ("show me my work items") or artifact-driven analysis (documents, branches, commits). Follow #file:ado-wit-planning.instructions.md for templates, field definitions, and search protocols.

## Scope

**Inputs**:

* `${input:adoProject}`: Azure DevOps project name or ID (required)
* `${input:witFocus}`: Work item type filter (default: `User Story`; options: `User Story`, `Bug`, `Task`)
* `${input:workItemStates}`: State filter (default: `["New", "Active", "Resolved"]`)
* `${input:documents}`: Explicit document paths for artifact-driven discovery (optional)
* `${input:includeBranchChanges}`: Enable git diff analysis (default: `false`)
* `${input:baseBranch}`: Base branch for diff comparison (default: `origin/main`)
* `${input:areaPath}`: Area path filter (optional)
* `${input:iterationPath}`: Iteration path filter (optional)

**Discovery path selection**:

* User-centric (Path A): User requests their assigned work items, current tasks, or work in a sprint
* Artifact-driven (Path B): Documents, branches, or commits require translation into work items
* Search-based (Path C): User provides search terms directly without artifacts or assignment context

**Output location**: `.copilot-tracking/workitems/discovery/<folder-name>/` where `<folder-name>` is a descriptive kebab-case identifier derived from the work scope.

## Deliverables

* `planning-log.md`: Search terms, discovered items, similarity assessments, and phase tracking
* `artifact-analysis.md`: Extracted requirements and working field values (artifact-driven path only)
* `work-items.md`: Source of truth for planned operations (artifact-driven path only)
* `handoff.md`: Create actions first, Update second, No Change last (artifact-driven path only)
* Conversational summary with counts, parent links, and planning folder path

Add an **External References** section to work item descriptions when authoritative sources inform requirements.

## Tooling

**User-centric discovery**:

* `mcp_ado_wit_my_work_items`: Retrieve work items assigned to or recently modified by the current user
  * Key params: `project` (required), `type` (enum: `assignedtome` | `myactivity`), `includeCompleted` (boolean, default: `false`), `top` (number, default: 50)
  * Returns all work item types; filter results client-side when `${input:witFocus}` is specified
* `mcp_ado_wit_get_work_items_for_iteration`: Retrieve work items for a specific sprint
  * Key params: `project` (required), `iterationId` (required), `team`
  * Use when `${input:iterationPath}` is specified; resolve iteration path to ID first

**Artifact-driven and search-based discovery**:

* `mcp_ado_search_workitem`: Full-text search across work items
  * Key params: `searchText` (required), `project` (string[]), `workItemType` (string[]), `state` (string[]), `assignedTo` (string[]), `areaPath` (string[]), `top` (default: 10), `skip` (default: 0), `includeFacets` (boolean, default: `false`)
  * All filter params accept arrays for multi-value filtering
  * Construct `searchText` from keyword groups using OR/AND syntax per #file:ado-wit-planning.instructions.md
* `mcp_ado_wit_get_query_results_by_id`: Execute a saved ADO query by ID or path
  * Key params: `id` (required), `project`, `team`, `responseType` (enum: `full` | `ids`, default: `full`), `top` (number, default: 50)
  * Use for complex queries already defined in ADO
* `mcp_ado_wit_get_work_item`: Retrieve single work item with full fields
* `mcp_ado_wit_get_work_items_batch_by_ids`: Batch retrieve work items by ID array

**Git context** (when `${input:includeBranchChanges}` is `true` and no documents exist):

* `run_in_terminal`: Generate diff XML via `scripts/dev-tools/pr-ref-gen.sh --base-branch "${input:baseBranch}" --output "<planning-folder>/git-branch-diff.xml"`
* Sync remote first: `git fetch <remote> <branch> --prune`

**Workspace utilities**: `list_dir`, `read_file`, `grep_search` for artifact location.

## Required Phases

### Phase 1 – Discover Work Items

Select the appropriate discovery path based on user intent.

#### Path A: User-Centric Discovery

Use when user requests:

* "Show me my work items" or "what's assigned to me"
* "My bugs" or "my tasks"
* Work items for a specific sprint or iteration
* No artifacts or documents are referenced

Execution:

1. Determine discovery tool:
   * Default: `mcp_ado_wit_my_work_items` with `type: "assignedtome"`
   * When `${input:iterationPath}` is specified: `mcp_ado_wit_get_work_items_for_iteration`
   * Set `includeCompleted: true` when `${input:workItemStates}` includes resolved states
2. Filter results client-side to match `${input:witFocus}` (the tool returns all types).
3. Filter results client-side by `${input:workItemStates}`.
4. Hydrate results via `mcp_ado_wit_get_work_items_batch_by_ids` for full field details.
5. Present results grouped by type and state.
6. Skip Phases 2-3; no planning files are required for user-centric discovery.

#### Path B: Artifact-Driven Discovery

Use when:

* Documents, PRDs, or requirements are provided via `${input:documents}` or conversation
* `${input:includeBranchChanges}` is `true`
* User explicitly requests work item creation or updates from artifacts

Skip conditions:

* No artifacts, documents, or branch changes are available—use Path A or Path C instead

Execution:

1. Determine folder name from work scope (descriptive kebab-case).
2. Create planning folder at `.copilot-tracking/workitems/discovery/<folder-name>/`.
3. Gather artifacts:
   * Explicit `${input:documents}` paths or attachments
   * Documents inferred from conversation
   * Git diff XML when `${input:includeBranchChanges}` is `true`
4. Log artifacts in `planning-log.md` under **Discovered Artifacts & Related Files**.
5. Read each artifact to completion; extract requirements grouped by persona or system impact.
6. Build keyword groups from nouns, verbs, component names, and file paths.
7. Execute searches with `mcp_ado_search_workitem` for each keyword group:
   * `project`: `["${input:adoProject}"]` (array)
   * `workItemType`: `["${input:witFocus}"]` (array)
   * `state`: `${input:workItemStates}` (array)
   * `areaPath`: `["${input:areaPath}"]` when specified (array)
   * `top`: 50; increment `skip` until fewer results return than `top`
8. Hydrate discovered items via batch retrieval.
9. Compute similarity per #file:ado-wit-planning.instructions.md and log in `planning-log.md`.
10. For User Stories, search for parent Features when linking is required.

#### Path C: Search-Based Discovery

Use when:

* User provides search terms directly ("find work items about authentication")
* No artifacts, documents, or assignment context apply

Execution:

1. Call `mcp_ado_search_workitem` with user-provided terms as `searchText`.
2. Apply filters as arrays:
   * `project`: `["${input:adoProject}"]`
   * `workItemType`: `["${input:witFocus}"]` when specified
   * `state`: `${input:workItemStates}`
3. Paginate: set `top: 50`, increment `skip` until fewer results return than `top`.
4. Hydrate results via `mcp_ado_wit_get_work_items_batch_by_ids` for full details.
5. Present results grouped by type and state.
6. Skip Phases 2-3; no planning files are required for search-based discovery.

### Phase 2 – Plan Work Items

Apply to artifact-driven discovery only.

**Similarity-based actions**:

* Match (≥0.70): Plan Update action; merge new requirements, preserve existing content
* Similar (0.50-0.69): Mark **Needs Review** in `handoff.md` with rationale
* Distinct (<0.50): Consider for new work item creation

**New work items**:

* Consolidate related requirements into minimal work items
* User Story titles: `As a <persona>, I <need|want|would like> <outcome>`
* Bug titles: Concise problem statement
* Populate acceptance criteria as markdown checkbox lists
* Link User Stories to parent Features; Bugs are standalone

**Resolved items**:

* Set action to `No Change` when existing item satisfies requirements
* Add `Related` link from new items back to resolved items for traceability

### Phase 3 – Assemble Handoff

Build `handoff.md` per template in #file:ado-wit-planning.instructions.md

1. Order: Create entries first, Update second, No Change last.
2. Include checkboxes, summaries, relationships, and artifact references.
3. Add **Planning Files** section with project-relative paths.
4. Verify consistency across all planning files.
5. Deliver conversational recap with counts, parent links, and planning folder path.
