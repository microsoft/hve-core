---
description: 'Plan a GitHub milestone sprint by analyzing issue coverage, identifying gaps, and organizing work into a prioritized sprint backlog'
agent: GitHub Backlog Manager
argument-hint: "milestone=... [documents=...] [sprintGoal=...] [capacity=...] [autonomy={full|partial|manual}]"
---

# Plan GitHub Sprint

Analyze a GitHub milestone, assess issue coverage against the full label taxonomy and optional planning documents, and produce a prioritized sprint plan with gap analysis and dependency awareness.

Follow all instructions from #file:../instructions/github-backlog-planning.instructions.md (the planning specification) for shared conventions, templates, and the label taxonomy.

When documents are provided, follow the Document Parsing Guidelines from [github-backlog-discovery.instructions.md](../instructions/github-backlog-discovery.instructions.md) (the discovery instructions) for requirement extraction and similarity assessment.

Follow the Conventional Commit Title Pattern to Label Mapping, Scope Keyword to Scope Label Mapping, Priority Assessment, and Milestone Recommendation sections from [github-backlog-triage.instructions.md](../instructions/github-backlog-triage.instructions.md) (the triage instructions) for label mapping, priority assessment, and milestone recommendations.

## Inputs

* `${input:milestone}`: (Required) Target milestone name or number for the sprint.
* `${input:documents}`: (Optional) File paths or URLs of source documents (PRDs, RFCs, ADRs) for cross-referencing against milestone issues.
* `${input:sprintGoal}`: (Optional) Sprint goal or theme description to focus prioritization.
* `${input:capacity}`: (Optional) Team capacity or issue count limit for the sprint.
* `${input:autonomy:partial}`: (Optional, defaults to partial) Autonomy tier controlling confirmation gates. Values: `full`, `partial`, `manual`. See the Three-Tier Autonomy Model in the planning specification.

## Required Steps

This workflow proceeds through four steps: fetch the milestone issues, analyze coverage and gaps, produce the sprint plan, then review and execute approved changes. Planning artifacts are written to `.copilot-tracking/github-issues/sprint/{{milestone-kebab}}/` where `{{milestone-kebab}}` is the milestone name normalized to kebab-case (for example, `v2-2-0`).

### Step 1: Fetch Milestone and Issues

Resolve the repository context, verify access, and retrieve all issues assigned to the target milestone.

1. Determine the repository owner and name from workspace context (remote URL, open files, or user input).
2. Call `mcp_github_get_me` to verify authenticated access to the repository.
3. Create the planning directory at `.copilot-tracking/github-issues/sprint/{{milestone-kebab}}/` and initialize *planning-log.md* following the template in the planning specification.
4. Fetch open issues for the milestone using `mcp_github_search_issues` with query `repo:{owner}/{repo} milestone:"{milestone}" is:open`. Paginate until all results are retrieved.
5. Fetch closed issues for progress context using `mcp_github_search_issues` with query `repo:{owner}/{repo} milestone:"{milestone}" is:closed`.
6. Hydrate each open issue via `mcp_github_issue_read` with `method: 'get'` to retrieve body content, labels, and assignments. Also fetch sub-issues with `method: 'get_sub_issues'` on issues with sub-issue relationships or titles suggesting tracking scope (epics, umbrella issues, feature aggregations).
7. Flag issues carrying the `needs-triage` label. When more than half of open issues are untriaged, recommend running triage via *github-triage-issues.prompt.md* before sprint planning and note this as a triage prerequisite in the planning log. Continue analysis on triaged issues.
8. Record the milestone inventory in *planning-log.md* with issue counts by state and label category.

### Step 2: Analyze Coverage and Gaps

Categorize milestone issues using the full label taxonomy, build a coverage matrix, and identify gaps through document cross-referencing when source documents are provided.

1. Categorize each open issue by its labels using the Label Taxonomy Reference in the planning specification. Map each issue to one or more of the 17 defined labels.
2. Build a coverage matrix showing which scope labels (`agents`, `prompts`, `instructions`, `infrastructure`) are represented in the milestone and which are absent.
3. Identify issues missing labels or carrying conflicting label combinations. Apply the conventional commit title pattern mapping from the triage instructions to suggest corrections.
4. When `${input:documents}` is provided, read each document and extract discrete requirements following the Document Parsing Guidelines in the discovery instructions. Assess similarity between extracted requirements and existing milestone issues using the Similarity Assessment Framework in the planning specification.
5. Record gap findings: requirements from documents with no matching milestone issue, scope labels with no coverage, and milestone issues with incomplete acceptance criteria.
6. Check for blocked or dependent issues by inspecting sub-issue hierarchy relationships discovered in Step 1.
7. Record the analysis in *sprint-analysis.md* within the planning directory, including the coverage matrix, gap list, and similarity assessments.

### Step 3: Produce Sprint Plan

Prioritize issues, apply capacity constraints, and assemble the sprint plan with work themes and dependency chains.

1. Assign priority ranks following the Priority Assessment table in the triage instructions: security issues highest, bugs high, features aligned with `${input:sprintGoal}` medium-high, other features and enhancements medium, documentation and maintenance lower.
2. When `${input:capacity}` is provided, include only the top-ranked issues up to the capacity limit. When not provided, include all open issues and note the total count.
3. Identify issues to defer to the next milestone based on priority rank exceeding capacity, missing readiness (no labels, incomplete descriptions), or misalignment with the EVEN/ODD versioning strategy in the planning specification.
4. Group prioritized issues into logical work themes based on shared scope labels (for example, `agents`, `prompts`, `instructions`).
5. Identify dependency chains where parent issues should complete before child issues, using sub-issue relationships from Step 1.
6. For each gap identified in Step 2 (unmatched document requirements), plan a new issue using `{{TEMP-N}}` placeholders per the Temporary ID Mapping convention in the planning specification. Include a suggested title in conventional commit format, labels, milestone, and source references.
7. Generate *sprint-plan.md* in the planning directory containing: sprint goal (from `${input:sprintGoal}` or inferred from milestone description), coverage matrix, prioritized issue table, gap analysis with suggested new issues, deferred issues with rationale, dependency chains, and risk items.
8. Generate *handoff.md* per the template in the planning specification, ordering entries as: Create (new issues from gaps) first, Update (label corrections, milestone moves) second, Link (sub-issue relationships) third, Close (duplicate or resolved items) fourth, No Change last.

### Step 4: Review and Execute

Present the sprint plan for review and execute approved changes according to the active autonomy tier.

1. Present the sprint plan as a structured summary including:
   * Prioritized issue table with columns: Priority Rank, Issue #, Title, Labels, Dependencies, Notes
   * Deferred issues table with columns: Issue #, Title, Reason for Deferral
   * New issues to create from gap analysis with suggested titles and labels
   * Risk items requiring attention (blocked issues, stale issues, missing acceptance criteria)
2. Apply autonomy gates from the Three-Tier Autonomy Model in the planning specification. Under full autonomy, proceed without confirmation. Under partial autonomy, gate on new issue creation and milestone moves. Under manual autonomy, gate on all operations.
3. Execute approved changes following the fixed processing order from the planning specification: Create (parents first, resolving `{{TEMP-N}}` placeholders to actual issue numbers), Update, Link, Close.
4. For each operation, call `mcp_github_issue_write` with `method: 'update'` or `method: 'create'` as appropriate. When updating labels, compute the full replacement set: `(current_labels - removed_labels) + added_labels`.
5. Propagate the sprint milestone to linked pull requests:
   1. Search for PRs already tagged with the milestone by calling `mcp_github_search_pull_requests` with `milestone:"{milestone}" repo:{owner}/{repo}`.
   2. Search for PRs associated with milestone issues by calling `mcp_github_search_pull_requests` with `repo:{owner}/{repo} {issue_number}` for each milestone issue, collecting PRs that mention the issue in their title or body.
   3. For each discovered PR missing the target milestone, call `mcp_github_issue_write` with `method: 'update'`, passing the PR number as `issue_number` and `milestone` set to the sprint milestone number. The Issues API accepts PR numbers because GitHub treats pull requests as a superset of issues sharing the same number space (see the Pull Request Field Operations section in the planning specification).
6. Create *handoff-logs.md* in the planning directory using the template from the planning specification if it does not already exist. Update checkboxes in *handoff.md* and append results to *handoff-logs.md* as each operation completes.
7. Update *planning-log.md* with execution results including issue numbers, actions taken, and final sprint statistics.

## Success Criteria

* All open issues assigned to the target milestone have been fetched, hydrated, and categorized by the full label taxonomy.
* A coverage matrix identifies which scope labels are represented and which have gaps.
* When documents are provided, extracted requirements have been assessed for similarity against existing milestone issues.
* The sprint plan includes prioritized issues within capacity constraints, deferred items with rationale, and dependency chains.
* Planning artifacts exist in `.copilot-tracking/github-issues/sprint/{{milestone-kebab}}/`: *planning-log.md*, *sprint-analysis.md*, *sprint-plan.md*, *handoff.md*, and *handoff-logs.md*.
* The user has reviewed the plan and confirmed or adjusted recommended changes, respecting the active autonomy tier.
* Approved changes have been executed and recorded in *handoff-logs.md* with checkbox tracking.

## Error Handling

* No issues in milestone: Report the empty milestone and suggest running discovery via *github-discover-issues.prompt.md* to populate it.
* Excessive untriaged issues (more than half carrying `needs-triage`): Recommend running triage via *github-triage-issues.prompt.md* before sprint planning. Continue analysis on triaged issues.
* Milestone not found: List available milestones by searching recent issues with `mcp_github_search_issues` and prompt for the correct milestone name.
* Circular dependencies: Flag the circular chain for user resolution and exclude affected issues from dependency ordering.
* Rate limiting: Log the failure in *planning-log.md*, wait for the rate limit window to reset, and retry the operation.
* Context summarization: When conversation context is summarized, recover state by reading *planning-log.md* and resuming from the last completed step.
* Authentication failure: Report the access error from `mcp_github_get_me` and prompt for repository details.

---

Proceed with planning the sprint for the specified milestone following the Required Steps.
