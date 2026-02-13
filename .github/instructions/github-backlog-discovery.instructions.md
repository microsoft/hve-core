---
description: 'Discovery protocol for GitHub backlog management - artifact-driven, user-centric, and search-based issue discovery'
applyTo: '**/.copilot-tracking/github-issues/discovery/**'
---

# GitHub Backlog Discovery

Discover GitHub issues through three paths: user-centric queries, artifact-driven analysis, or search-based exploration. Follow *github-backlog-planning.instructions.md* for templates, field definitions, and search protocols.

## Scope

Discovery path selection:

* User-centric (Path A): User requests their issues, assigned work, or milestone progress without referencing artifacts
* Artifact-driven (Path B): Documents, PRDs, or requirements provided for translation into issues
* Search-based (Path C): User provides search terms directly without artifacts or assignment context

Output location: `.copilot-tracking/github-issues/discovery/<scope-name>/` where `<scope-name>` is a descriptive kebab-case slug derived from the discovery context (for example, `v2-features` or `security-audit`).

## Deliverables

| File                   | Path A | Path B | Path C |
|------------------------|--------|--------|--------|
| *planning-log.md*      | Yes    | Yes    | Yes    |
| *issue-analysis.md*    | No     | Yes    | No     |
| *issues-plan.md*       | No     | Yes    | No     |
| *handoff.md*           | No     | Yes    | No     |
| Conversational summary | Yes    | Yes    | Yes    |

Paths A and C produce a conversational summary with counts and relevant issue links. Path B produces the full set of planning files per templates in *github-backlog-planning.instructions.md*.

## Tooling

User-centric discovery (Path A):

* `mcp_github_get_me`: Retrieve authenticated user details for assignee-based queries
* `mcp_github_search_issues`: Search with `assignee:` qualifier scoped to `repo:{owner}/{repo}`
  * Key params: `query` (required), `owner`, `repo`, `perPage`, `page`
* `mcp_github_issue_read`: Hydrate results with `method: 'get'` for full details
  * When `includeSubIssues` is true, also call with `method: 'get_sub_issues'`

Artifact-driven discovery (Path B):

* `read_file`, `grep_search`: Read and parse source documents
* `mcp_github_get_me`: Verify access to the target repository
* `mcp_github_search_issues`: Execute keyword-group queries per the Search Protocol in *github-backlog-planning.instructions.md*
* `mcp_github_issue_read`: Hydrate results and fetch sub-issues when enabled
* `mcp_github_list_issue_types`: Retrieve valid issue types when the organization supports them

Search-based discovery (Path C):

* `mcp_github_search_issues`: Execute user-provided terms scoped to `repo:{owner}/{repo}`
* `mcp_github_issue_read`: Hydrate results with `method: 'get'` for full details

Workspace utilities: `list_dir`, `read_file`, `semantic_search` for artifact location and context gathering.

## Required Phases

### Phase 1: Discover Issues

Select the appropriate discovery path based on user intent and available inputs.

#### Path A: User-Centric Discovery

Use when:

* User requests "show me my issues", "what's assigned to me", or similar
* User asks about issues for a specific milestone or label scope
* No artifacts or documents are referenced

Execution:

1. Call `mcp_github_get_me` to determine the authenticated user.
2. Build a search query with `repo:{owner}/{repo} is:issue assignee:{username}`. Apply `milestone:` and `label:` qualifiers when `milestone` or label context is provided.
3. Execute `mcp_github_search_issues` and paginate until all results are retrieved.
4. Hydrate each result via `mcp_github_issue_read` with `method: 'get'`. When `includeSubIssues` is true, also fetch sub-issues.
5. Present results grouped by state and labels.
6. Create the planning folder at `.copilot-tracking/github-issues/discovery/<scope-name>/` and initialize *planning-log.md*.
7. Log discovered issues in *planning-log.md* and deliver a conversational summary.
8. Skip Phases 2-3; no additional planning files beyond *planning-log.md* are required for user-centric discovery.

#### Path B: Artifact-Driven Discovery

Use when:

* Documents, PRDs, or requirements are provided via `documents` or conversation
* User explicitly requests issue creation or updates from artifacts

Skip conditions:

* No artifacts or documents are available; use Path A or Path C instead

Execution:

1. Create the planning folder at `.copilot-tracking/github-issues/discovery/<scope-name>/`.
2. Call `mcp_github_get_me` to verify repository access. When the organization supports issue types, call `mcp_github_list_issue_types` with the `owner` parameter.
3. Read each document to completion and extract discrete requirements, acceptance criteria, and action items using the document parsing guidelines in this file.
4. Record each extracted requirement as a candidate issue entry in *issue-analysis.md* with: temporary ID, suggested title in conventional commit format, body summary, suggested labels, suggested milestone, and source reference.
5. Build keyword groups from extracted requirements per the Search Protocol in *github-backlog-planning.instructions.md*.
6. Compose GitHub search queries scoped to `repo:{owner}/{repo}`. Apply `milestone:` qualifier when `milestone` is provided.
7. Execute `mcp_github_search_issues` for each keyword group and paginate results.
8. Hydrate each result via `mcp_github_issue_read` with `method: 'get'`. When `includeSubIssues` is true, also fetch sub-issues.
9. Assess similarity between each fetched issue and the candidate set using the Similarity Assessment Framework in *github-backlog-planning.instructions.md*. Classify each pair as Match, Similar, Distinct, or Uncertain.
10. De-duplicate results across keyword groups; retain the highest similarity category when the same issue appears in multiple searches.
11. Log all progress in *planning-log.md* with search queries, result counts, and similarity assessments.
12. Continue to Phase 2.

##### Document Parsing Guidelines

Map document types and content patterns to issue attributes.

| Document Type | Content Pattern           | Suggested Label   | Issue Type  |
|---------------|---------------------------|-------------------|-------------|
| PRD           | Feature requirement       | `feature`         | Feature     |
| PRD           | User story                | `feature`         | User story  |
| BRD           | Business enhancement      | `enhancement`     | Enhancement |
| ADR           | Implementation task       | `maintenance`     | Task        |
| ADR           | Migration step            | `breaking-change` | Task        |
| RFC           | Proposed capability       | `feature`         | Feature     |
| Meeting notes | Action item               | `maintenance`     | Task        |
| Security plan | Vulnerability remediation | `security`        | Bug         |
| Security plan | Hardening requirement     | `security`        | Enhancement |

When a document section contains acceptance criteria, include them in the candidate issue body as a checklist.

#### Path C: Search-Based Discovery

Use when:

* User provides search terms directly ("find issues about authentication")
* No artifacts, documents, or assignment context apply

Execution:

1. Call `mcp_github_get_me` to verify repository access.
2. Build search queries from `searchTerms` scoped to `repo:{owner}/{repo}`. Apply `milestone:` qualifier when `milestone` is provided.
3. Execute `mcp_github_search_issues` for each query and paginate results.
4. Hydrate each result via `mcp_github_issue_read` with `method: 'get'`. When `includeSubIssues` is true, also fetch sub-issues.
5. Present results grouped by state and labels.
6. Create the planning folder at `.copilot-tracking/github-issues/discovery/<scope-name>/` and initialize *planning-log.md*.
7. Log discovered issues in *planning-log.md* and deliver a conversational summary.
8. Skip Phases 2-3; no additional planning files beyond *planning-log.md* are required for search-based discovery.

### Phase 2: Plan Issues

Apply to artifact-driven discovery (Path B) only.

#### Similarity-Based Actions

| Category  | Action                                                             |
|-----------|--------------------------------------------------------------------|
| Match     | Link candidate to existing issue; plan an Update if fields diverge |
| Similar   | Flag for user review with a comparison summary                     |
| Distinct  | Plan as a new issue                                                |
| Uncertain | Request user guidance before proceeding                            |

#### Hierarchy Grouping

Group related requirements into parent-child structures. When a requirement decomposes into more than 5 sub-requirements, create an epic-level tracking issue as the parent and link individual issues as sub-issues.

Issue title conventions:

* Feature and enhancement titles follow conventional commit format (for example, `feat(scope): description`).
* Assign labels per the Label Taxonomy Reference in *github-backlog-planning.instructions.md*.
* Assign milestones per the Milestone Discovery Protocol in *github-backlog-planning.instructions.md*.

#### New Issue Construction

* Populate acceptance criteria as markdown checkbox lists when extracted from documents.
* Use `{{TEMP-N}}` placeholders for issues not yet created, per the Temporary ID Mapping convention in #file:./github-backlog-planning.instructions.md.
* Include source references (document path and section) in issue body content only when the referenced path is committed to the repository. When referencing other planned issues, use `{{TEMP-N}}` placeholders (resolved to actual issue numbers during execution) or descriptive phrases. Apply the Content Sanitization Guards from #file:./github-backlog-planning.instructions.md before composing any GitHub-bound content.

#### Existing Issue Handling

* Match: Plan an Update action; merge new requirements while preserving existing content.
* Resolved or closed items satisfying the requirement: Set action to No Change and note the relationship for traceability.

Record all planned operations in *issues-plan.md* per templates in *github-backlog-planning.instructions.md*.

### Phase 3: Assemble Handoff

Apply to artifact-driven discovery (Path B) only.

1. Build *handoff.md* per the template in *github-backlog-planning.instructions.md*. Order: Create entries first, Update second, Link third, Close fourth, No Change last.
2. Include checkboxes, summaries, relationships, and artifact references for each entry.
3. Add a Planning Files section with project-relative paths to all generated files.
4. Apply the Three-Tier Autonomy Model from *github-backlog-planning.instructions.md* to determine confirmation gates. When no tier is specified, default to Partial Autonomy.
5. Verify consistency across *issue-analysis.md*, *issues-plan.md*, and *handoff.md*.
6. Present the handoff for user review, highlighting items that trigger human review.
7. Record the final state in *planning-log.md* with phase completion status.

## Human Review Triggers

Pause and request user guidance when:

* A requirement extracted from a document is ambiguous or contradicts another requirement.
* Multiple existing issues partially match a single candidate (two or more Similar results).
* A candidate implies a parent-child hierarchy, but the parent issue does not exist in the repository or candidate set.
* A candidate carries the `breaking-change` label, indicating potential release impact.
* The similarity assessment returns Uncertain for any pair.
* A planned operation changes an issue's milestone.

Additional triggers are defined in the Human Review Triggers section of *github-backlog-planning.instructions.md*.

## Cross-References

These sections in *github-backlog-planning.instructions.md* inform discovery operations:

| Section                         | Used In         | Purpose                                                |
|---------------------------------|-----------------|--------------------------------------------------------|
| Search Protocol                 | Phase 1, Path B | Keyword group construction and query composition       |
| Similarity Assessment Framework | Phase 1, Path B | Classifying candidate-to-existing issue pairs          |
| Planning File Templates         | Phases 1-3      | Structure for all output files                         |
| Content Sanitization Guards     | Phase 2         | Strip local paths and planning IDs from GitHub content |
| Temporary ID Mapping            | Phase 2         | `{{TEMP-N}}` placeholders for new issues               |
| Three-Tier Autonomy Model       | Phase 3         | Confirmation gates during handoff review               |
| State Persistence Protocol      | All phases      | Context recovery after summarization                   |
| Issue Field Matrix              | Phase 2         | Required and optional fields per operation type        |
| Milestone Discovery Protocol    | Phase 2         | Role-based milestone classification for assignment     |
| Label Taxonomy Reference        | Phase 2         | Label selection and title pattern mapping              |
| Human Review Triggers           | Phase 3         | Additional conditions for pausing execution            |

---

Brought to you by microsoft/hve-core
