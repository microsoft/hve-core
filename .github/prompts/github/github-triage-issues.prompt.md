---
description: 'Triage GitHub issues not yet triaged with automated label suggestions, milestone assignment, and duplicate detection'
agent: GitHub Backlog Manager
---

# Triage GitHub Issues

Fetch all open GitHub issues carrying the `needs-triage` label, analyze each for label and milestone recommendations, detect duplicates, and produce a triage plan for review before execution.

Follow all instructions from #file:../../instructions/github/github-backlog-triage.instructions.md while executing this workflow.
Follow all instructions from #file:../../instructions/github/github-backlog-planning.instructions.md for shared conventions.

## Inputs

* `${input:milestone}`: (Optional) Target milestone override. When provided, skip milestone discovery and use this value for all non-duplicate issues.
* `${input:maxIssues:20}`: (Optional, defaults to 20) Maximum issues to process per batch.
* `${input:autonomy:partial}`: (Optional, defaults to partial) Autonomy tier controlling confirmation gates. Values: `full`, `partial`, `manual`.

## Required Steps

The workflow proceeds through three steps: fetch untriaged issues with milestone context, analyze each issue for labels and duplicates, then present a triage plan and execute confirmed recommendations.

### Step 1: Fetch Untriaged Issues

Resolve the repository owner and name from the active workspace context or user input before constructing queries.

1. When `${input:milestone}` is not provided, discover the current EVEN and next ODD milestones by searching recent issues with milestone assignments via `mcp_github_search_issues`. Record the discovered milestones in planning-log.md. Delegate EVEN/ODD classification to the Milestone Recommendation section of the triage instructions.
2. Search for open issues carrying the `needs-triage` label using `mcp_github_search_issues` with the query `repo:{owner}/{repo} is:issue is:open label:needs-triage`.
3. Limit results to the `${input:maxIssues}` count using the `perPage` parameter.
4. For each returned issue, fetch full details with `mcp_github_issue_read` using method `get`, then fetch the complete label set using method `get_labels`. Both calls are needed for replacement semantics during execution.
5. Create the planning directory at `.copilot-tracking/github-issues/triage/{{YYYY-MM-DD}}/` and record fetched issues in planning-log.md.

When no untriaged issues are found, inform the user and suggest broadening the search (for example, removing label filters or checking for issues without any labels).

### Step 2: Analyze and Classify

For each fetched issue, perform these analyses and build triage recommendations.

1. Parse the title against the Conventional Commit Title Pattern to Label Mapping table in the triage instructions. Titles without a recognized pattern retain the `needs-triage` label for manual review.
2. Extract scope keywords from the title and map them to scope labels per the Scope Keyword to Scope Label Mapping in the triage instructions. Note unrecognized scopes as body context rather than assigning them as labels.
3. Assess priority using the Priority Assessment table in the triage instructions. Issues carrying the `breaking-change` or `security` label trigger escalation to the user regardless of autonomy tier.
4. Recommend a milestone using the discovered EVEN/ODD context. When `${input:milestone}` is provided, use it as the default target. Delegate assignment logic to the Milestone Recommendation section of the triage instructions.
5. Search for similar open issues using keyword groups from the title. Assess similarity using the Similarity Assessment Framework from the planning specification and flag potential duplicates with their category (Match, Similar, Distinct, or Uncertain).
6. Review existing labels (from the `get_labels` hydration in Step 1) for conflicts with suggested labels. Flag divergences for user review per the human review triggers in the planning specification.

Record the analysis in triage-plan.md using the template from the Output section of the triage instructions.

### Step 3: Present and Execute

Present the triage plan to the user as a summary table.

```markdown
| Issue | Title | Suggested Labels | Suggested Milestone | Duplicates Found | Priority | Action |
| ----- | ----- | ---------------- | ------------------- | ---------------- | -------- | ------ |
```

Execution follows the `${input:autonomy}` tier per the Three-Tier Autonomy Model in the planning specification. Under `partial` (default), label assignments, milestone assignments, and `needs-triage` removal auto-execute, but duplicate closures gate on user approval. Under `full`, all operations execute immediately. Under `manual`, every operation gates on user confirmation.

1. Collect user confirmation or modifications per the active autonomy tier before applying gated changes.
2. For each confirmed non-duplicate issue whose title matched a recognized conventional commit pattern, compute the replacement label set as `(current_labels - "needs-triage") + suggested_labels` and apply labels, milestone, and `needs-triage` removal in a single `mcp_github_issue_write` call with `method: 'update'`. The `labels` parameter uses replacement semantics: include all labels to retain, all labels to add, and exclude `needs-triage`.
3. For each confirmed non-duplicate issue whose title did not match a recognized pattern, compute the replacement label set as `current_labels + suggested_labels` (retaining `needs-triage`) and apply labels and milestone in a single `mcp_github_issue_write` call with `method: 'update'`. The `labels` parameter uses replacement semantics: include all existing labels including `needs-triage`, plus all suggested labels.
4. For confirmed Match-category duplicates, close using `mcp_github_issue_write` with `state: 'closed'`, `state_reason: 'duplicate'`, and `duplicate_of` referencing the original issue.
5. Update planning-log.md with execution results for each processed issue.

## Success Criteria

* All fetched issues have triage recommendations with label suggestions, milestone assignments, and duplicate assessments.
* The triage plan has been reviewed per the active autonomy tier before execution.
* Labels and milestones are applied using replacement semantics in consolidated API calls.
* The `needs-triage` label is removed from all classified issues. Unclassified issues retain `needs-triage` for manual review.
* Planning artifacts are created in `.copilot-tracking/github-issues/triage/{{YYYY-MM-DD}}/`.

## Error Handling

* No untriaged issues found: inform the user and suggest broadening search criteria or checking for issues without any labels.
* API rate limit: pause and retry with exponential backoff. Log the pause in planning-log.md.
* Missing label: warn the user and skip label application for that issue. Log the missing label in planning-log.md.
* Duplicate detection ambiguous: flag the issue as Uncertain and present both candidates for user review rather than auto-closing.
* Concurrent modification: when an issue has been modified between analysis and execution (labels or state changed externally), re-fetch details before applying updates to avoid overwriting changes.
* Bulk operation threshold: when processing more than 10 issues in a single batch, present a confirmation summary before executing, even under full autonomy.

---

Proceed with triaging untriaged GitHub issues following the Required Steps.
