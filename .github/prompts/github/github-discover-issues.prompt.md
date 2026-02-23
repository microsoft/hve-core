---
description: 'Discover GitHub issues through user-centric queries, artifact-driven analysis, or search-based exploration and produce planning files for review'
agent: GitHub Backlog Manager
argument-hint: "documents=... [milestone=...] [searchTerms=...]"
---

# Discover GitHub Issues

Classify the discovery path based on user intent and available inputs, execute the appropriate discovery workflow, assess similarity against existing issues, and produce planning files for review. Three discovery paths are supported: user-centric queries (Path A), artifact-driven analysis from documents (Path B), and search-based exploration (Path C).

Follow all instructions from #file:../instructions/github-backlog-discovery.instructions.md while executing this workflow.
Follow all instructions from #file:../instructions/github-backlog-planning.instructions.md for shared conventions.

## Inputs

* `${input:documents}`: (Optional) Document paths or attached files (PRDs, RFCs, ADRs) to analyze for issue extraction. Triggers Path B when provided.
* `${input:milestone}`: (Optional) Target milestone name or number to scope searches.
* `${input:searchTerms}`: (Optional) Keywords or phrases for search-based discovery. Triggers Path C when provided without documents.
* `${input:includeSubIssues:false}`: (Optional, defaults to false) Fetch sub-issues for each discovered issue.
* `${input:autonomy:partial}`: (Optional, defaults to partial) Autonomy tier controlling confirmation gates during handoff review. Values: `full`, `partial`, `manual`.

## Required Steps

The workflow proceeds through four steps: classify the discovery path, execute discovery for the selected path, assess similarity and plan actions (Path B only), then assemble planning files and present for review (Path B only).

### Step 1: Classify and Initialize

Resolve the repository owner and name from the active workspace context or user input before classifying the discovery path.

1. Call `mcp_github_get_me` to verify repository access and determine the authenticated user.
2. Classify the discovery path based on inputs and user intent:
   * Path A (User-Centric): User requests assigned issues, milestone progress, or their own work without referencing artifacts or search terms.
   * Path B (Artifact-Driven): Documents, PRDs, or requirements are provided via `${input:documents}` or conversation. User requests issue creation or updates from artifacts.
   * Path C (Search-Based): User provides `${input:searchTerms}` directly without artifacts or assignment context.
3. Create the planning folder at `.copilot-tracking/github-issues/discovery/<scope-name>/` and initialize *planning-log.md*.
4. When Path B is selected and the organization supports issue types, call `mcp_github_list_issue_types` with the owner parameter.

When neither documents nor search terms are provided and user intent does not indicate assigned-issue retrieval, ask the user to clarify their discovery goal before proceeding.

### Step 2: Execute Discovery

Run the discovery workflow for the classified path. Paths A and C produce a conversational summary and complete the workflow. Path B continues to Steps 3 and 4.

#### Path A: User-Centric Discovery

1. Build a search query with `repo:{owner}/{repo} is:issue assignee:{username}`. Apply `milestone:` and `label:` qualifiers when `${input:milestone}` or label context is provided.
2. Execute `mcp_github_search_issues` and paginate until all results are retrieved.
3. Hydrate each result via `mcp_github_issue_read` with `method: 'get'`. When `${input:includeSubIssues}` is true, also fetch sub-issues with `method: 'get_sub_issues'`.
4. Present results grouped by state and labels.
5. Log discovered issues in *planning-log.md* and deliver a conversational summary with counts and relevant issue links.
6. The workflow is complete for Path A. Skip Steps 3 and 4.

#### Path B: Artifact-Driven Discovery

1. Read each document referenced in `${input:documents}` to completion.
2. Extract discrete requirements, acceptance criteria, and action items using the Document Parsing Guidelines in the discovery instructions.
3. Record each extracted requirement as a candidate issue entry in *issue-analysis.md* with: temporary ID, suggested title in conventional commit format, body summary, suggested labels, suggested milestone, and source reference.
4. When a document section contains more than 5 sub-requirements, flag the section for epic-level hierarchy grouping in *planning-log.md*.
5. Build keyword groups from extracted requirements per the Search Protocol in the planning specification.
6. Compose GitHub search queries scoped to `repo:{owner}/{repo}` using `mcp_github_search_issues`. Apply the `milestone:` qualifier when `${input:milestone}` is provided.
7. Execute searches for each keyword group and paginate results.
8. Hydrate each result via `mcp_github_issue_read` with `method: 'get'`. When `${input:includeSubIssues}` is true, also fetch sub-issues with `method: 'get_sub_issues'`.
9. Log search queries, result counts, and progress in *planning-log.md*.
10. Continue to Step 3.

#### Path C: Search-Based Discovery

1. Build search queries from `${input:searchTerms}` scoped to `repo:{owner}/{repo}` using `mcp_github_search_issues`. Apply the `milestone:` qualifier when `${input:milestone}` is provided.
2. Execute searches and paginate results.
3. Hydrate each result via `mcp_github_issue_read` with `method: 'get'`. When `${input:includeSubIssues}` is true, also fetch sub-issues with `method: 'get_sub_issues'`.
4. Present results grouped by state and labels.
5. Log discovered issues in *planning-log.md* and deliver a conversational summary with counts and relevant issue links.
6. The workflow is complete for Path C. Skip Steps 3 and 4.

### Step 3: Assess Similarity and Plan Actions

This step applies to Path B only. Assess similarity between discovered issues and extracted candidates, then categorize each into an action.

1. For each fetched issue, assess similarity against the candidate set using the Similarity Assessment Framework from the planning specification. Classify each pair as Match, Similar, Distinct, or Uncertain.
2. De-duplicate results across keyword groups. Retain the highest similarity category when the same issue appears in multiple searches.
3. Categorize each candidate into an action:
   * Create: Distinct candidates with no existing coverage. Draft new issues with conventional commit titles, labels, and milestones per the planning specification conventions.
   * Update: Match candidates where existing issues need field changes. Merge new requirements while preserving existing content.
   * Link: Candidates that establish parent-child or cross-reference relationships between issues.
   * Close: Existing issues superseded by new candidates or resolved by current work. Set `state_reason` per the Issue Field Matrix.
4. When a requirement decomposes into more than 5 sub-requirements, create an epic-level tracking issue as the parent and plan individual issues as sub-issues. Use `{{TEMP-N}}` placeholders for issues not yet created per the Temporary ID Mapping convention.
5. Record all planned operations in *issue-analysis.md* and *issues-plan.md* per templates in the planning specification. Include similarity assessments, recommended actions, and rationale for each entry.
6. Update *planning-log.md* with the current phase status and similarity assessment results.

Pause and request user guidance when human review triggers are met, including: ambiguous requirements, multiple Similar results for a single candidate, missing parent issues, `breaking-change` label candidates, Uncertain assessments, or planned milestone changes.

### Step 4: Assemble Handoff and Present

This step applies to Path B only. Produce the handoff file and present the discovery results for review.

1. Build *handoff.md* per the template in the planning specification. Order entries as: Create first, Update second, Link third, Close fourth, No Change last.
2. Include checkboxes, summaries, relationships, and artifact references for each entry.
3. Add a Planning Files section with project-relative paths to all generated files (*planning-log.md*, *issue-analysis.md*, *issues-plan.md*, *handoff.md*).
4. Apply the Three-Tier Autonomy Model from the planning specification to determine confirmation gates based on `${input:autonomy}`. When no tier is specified, default to Partial Autonomy.
5. Verify consistency across *issue-analysis.md*, *issues-plan.md*, and *handoff.md*. Resolve discrepancies before presenting.
6. Present the handoff for user review, highlighting items that trigger human review.
7. Record the final state in *planning-log.md* with phase completion status.

## Success Criteria

* The discovery path is classified before executing any searches or document parsing.
* All provided documents are analyzed for actionable items when Path B is selected.
* Existing backlog is searched using `mcp_github_search_issues` with keyword groups from extracted requirements or user-provided terms.
* Similarity assessments classify each candidate-to-existing-issue pair as Match, Similar, Distinct, or Uncertain.
* All four action categories (Create, Update, Link, Close) are represented in the plan when applicable.
* Hierarchy grouping produces epic-level tracking issues when a requirement has more than 5 sub-requirements.
* Path B produces *planning-log.md*, *issue-analysis.md*, *issues-plan.md*, and *handoff.md* in `.copilot-tracking/github-issues/discovery/<scope-name>/`.
* Paths A and C produce *planning-log.md* and a conversational summary.
* The handoff is presented for review before any execution occurs. Discovery does not execute issue operations.

## Error Handling

* No inputs provided: ask the user to provide documents, search terms, or clarify their discovery intent before proceeding.
* Search returns no results: suggest broadening search terms and retry with alternative keyword groups. Log the empty search in *planning-log.md*.
* Ambiguous matches: flag as Uncertain and present both candidates for user review rather than auto-categorizing.
* Large document: process sections incrementally with progress updates recorded in *planning-log.md* after each section.
* API rate limit: pause and retry with exponential backoff. Log the pause in *planning-log.md*.
* Missing labels in repository: warn the user and note the missing label in *planning-log.md*. Proceed with remaining labels.
* Context summarization: when conversation history is compressed, recover state from *planning-log.md* per the State Persistence Protocol in the planning specification before continuing.

---

Proceed with discovering GitHub issues following the Required Steps.
