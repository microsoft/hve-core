---
description: 'Triage workflow for GitHub issue backlog management - automated label suggestion, milestone assignment, and duplicate detection'
applyTo: '**/.copilot-tracking/github-issues/triage/**'
---

# GitHub Backlog Triage Instructions

## Purpose and Scope

This workflow analyzes untriaged GitHub issues, suggests labels based on conventional commit title patterns, assigns milestones using the repository's discovered versioning strategy, and detects duplicates through similarity assessment.

Follow all instructions from #file:./github-backlog-planning.instructions.md while executing this workflow.

Follow community interaction guidelines from #file:./community-interaction.instructions.md when posting comments visible to external contributors.

## Autonomy Behavior for Triage Operations

| Operation                         | Full         | Partial      | Manual       |
|-----------------------------------|--------------|--------------|--------------|
| Label assignment                  | Auto-execute | Auto-execute | Gate on user |
| Milestone assignment              | Auto-execute | Auto-execute | Gate on user |
| Duplicate closure                 | Auto-execute | Gate on user | Gate on user |
| needs-triage removal (classified) | Auto-execute | Auto-execute | Gate on user |

Unclassified issues (titles without a recognized conventional commit pattern) retain `needs-triage` across all autonomy tiers. Label and milestone suggestions still apply, but `needs-triage` is not removed.

## Required Phases

### Phase 1: Analyze

Fetch and analyze untriaged issues to build a comprehensive triage assessment. Proceed to Phase 2 when all fetched issues have been analyzed and recorded.

#### Step 1: Discover Available Milestones

Before analyzing issues, discover the repository's milestone strategy. When `milestone` is provided as an override, skip this step and use that value.

1. Invoke the milestone discovery protocol defined in the Milestone Discovery Protocol section of `github-backlog-planning.instructions.md` to fetch, classify, and build the milestone assignment map.
2. Record the detected naming pattern, per-milestone role classification, and generated assignment map in planning-log.md.
3. When discovery confidence is low, attempt to load `.github/milestone-strategy.yml` as an optional override; if the file is not present or does not define a clear strategy, prompt the user before proceeding.

When milestone discovery yields no results, prompt the user for milestone names before proceeding.

#### Step 2: Fetch Untriaged Issues

Search for issues carrying the `needs-triage` label using `mcp_github_search_issues` with the following query pattern:

```text
repo:{owner}/{repo} is:issue is:open label:needs-triage
```

Paginate results using `perPage` and `page` parameters, limiting to `maxIssues` total issues.

When no untriaged issues are found, inform the user and end the workflow. No further phases apply.

#### Step 3: Hydrate Issue Details

For each returned issue, fetch full details using `mcp_github_issue_read` with `method: 'get'` to retrieve body content, existing labels, and current milestone. Also fetch current labels using `mcp_github_issue_read` with `method: 'get_labels'` to capture the complete label set for each issue.

#### Step 4: Analyze Each Issue

For each untriaged issue, perform the following analysis:

1. Parse the title against the conventional commit title pattern mapping table to determine suggested type labels.
2. Extract scope keywords from `type(scope):` patterns and map them to scope labels. Scope extraction applies to all conventional commit types, not only specific patterns.
3. Examine the body content for additional context:
   * Identify scope indicators not captured by the title pattern (file paths, directory references, component names).
   * Note acceptance criteria that inform priority assessment.
   * Extract technical context that clarifies issue intent for similarity comparison.
4. Review existing labels for conflicts or gaps (for example, an issue labeled `enhancement` with a `fix:` title prefix).
5. Search for potential duplicates using the similarity assessment framework per templates in the planning specification.
6. Evaluate milestone fit based on the discovered milestone strategy and the priority assessment criteria defined in this file.

#### Step 5: Record Analysis

Create planning-log.md in `.copilot-tracking/github-issues/triage/{{YYYY-MM-DD}}/` to track progress. Update the log as each issue is analyzed, recording:

* Issue number and title
* Current labels (from hydration)
* Suggested labels with rationale
* Suggested milestone with rationale
* Duplicate candidates with similarity category
* Priority assessment result

### Phase 2: Plan

Produce a triage plan for user review and execute confirmed recommendations. This phase completes when all confirmed recommendations have been applied and planning-log.md reflects final state.

#### Step 1: Generate Triage Plan

Create triage-plan.md in `.copilot-tracking/github-issues/triage/{{YYYY-MM-DD}}/` with a recommendation row per issue. Use the triage plan template defined in the Output section of this file.

#### Step 2: Present for Review

Present the triage plan to the user, highlighting:

* Issues with high-confidence label and milestone suggestions
* Issues flagged as potential duplicates
* Issues requiring manual review (ambiguous titles, conflicting labels, uncertain similarity)

When `autonomy` is `full`, proceed directly to Step 3 without waiting for user confirmation. When `partial`, gate on duplicate closures only. When `manual`, wait for user confirmation of the entire plan.

#### Step 3: Execute Confirmed Recommendations

On user confirmation (or immediately under full autonomy), apply the approved recommendations. Before composing any content for a GitHub API call, apply the Content Sanitization Guards from #file:./github-backlog-planning.instructions.md.

For classified non-duplicate issues (title matched a recognized conventional commit pattern), consolidate label assignment, milestone assignment, and `needs-triage` removal into a single API call per issue:

1. Compute the new label set: `(current_labels - "needs-triage") + suggested_labels`.
2. Call `mcp_github_issue_write` with `method: 'update'`, `labels: [computed_set]`, and `milestone: suggested_milestone`.

The `labels` parameter uses replacement semantics. The computed set must include all labels to retain, all suggested labels to add, and must exclude `needs-triage`.

For unclassified non-duplicate issues (title did not match any recognized pattern), apply suggested labels while retaining `needs-triage`:

1. Compute the new label set: `current_labels + suggested_labels`.
2. Call `mcp_github_issue_write` with `method: 'update'`, `labels: [computed_set]`, and `milestone: suggested_milestone`.

The `labels` parameter uses replacement semantics. The computed set must include all existing labels (including `needs-triage`), plus any suggested labels.

For confirmed duplicates, apply the comment-before-closure pattern:

1. Post a comment using `mcp_github_add_issue_comment` with the Scenario 7 (Closing a Duplicate Issue) template from `community-interaction.instructions.md`, filling `{{original_number}}` with the matched issue number.
2. Close the issue using `mcp_github_issue_write` with `method: 'update'`, `state: 'closed'`, `state_reason: 'duplicate'`, and `duplicate_of` set to the original issue number.

For linked pull requests, propagate the milestone assignment to each associated PR:

1. Search for PRs referencing the issue by calling `mcp_github_search_pull_requests` with query `repo:{owner}/{repo} {issue_number}` to find PRs that mention the issue number in their title or body.
2. Inspect the issue body and comments via `mcp_github_issue_read` with `method: 'get'` and `method: 'get_comments'` for PR references (GitHub PR URLs or `#N` cross-references) that the search may have missed.
3. For each discovered PR missing the target milestone, call `mcp_github_issue_write` with `method: 'update'`, passing the PR number as `issue_number` and `milestone: suggested_milestone`.

The Issues API accepts PR numbers because GitHub treats pull requests as a superset of issues sharing the same number space (see the Pull Request Field Operations section in the planning specification).

Group issues by suggested label when multiple issues share the same recommendation to maintain batch efficiency. Update planning-log.md checkboxes as each operation completes.

## Conventional Commit Title Pattern to Label Mapping

When issue titles follow conventional commit format, map patterns to labels using this table.

| Title Pattern                    | Suggested Labels                | Description             |
|----------------------------------|---------------------------------|-------------------------|
| `feat:` or `feat(scope):`        | `feature`                       | New functionality       |
| `fix:` or `fix(scope):`          | `bug`                           | Bug fix                 |
| `docs:` or `docs(scope):`        | `documentation`                 | Documentation change    |
| `chore:` or `chore(scope):`      | `maintenance`                   | Maintenance task        |
| `refactor:`                      | `maintenance`                   | Code refactoring        |
| `test:`                          | `maintenance`                   | Test changes            |
| `ci:`                            | `maintenance`, `infrastructure` | CI/CD changes           |
| `perf:`                          | `enhancement`                   | Performance improvement |
| `style:`                         | `maintenance`                   | Code style changes      |
| `build:`                         | `infrastructure`                | Build system changes    |
| `security:`                      | `security`                      | Security fix            |
| `breaking:` or `BREAKING CHANGE` | `breaking-change`               | Breaking change         |

When a title does not match any conventional commit pattern, retain the `needs-triage` label and flag the issue for manual review.

## Scope Keyword to Scope Label Mapping

Extract scope keywords from the conventional commit title pattern `type(scope):` and map them to scope labels.

| Scope Keyword    | Scope Label    |
|------------------|----------------|
| `(agents)`       | `agents`       |
| `(prompts)`      | `prompts`      |
| `(instructions)` | `instructions` |

Additional scope keywords may be mapped when they align with the label taxonomy defined in the planning specification. Scope keywords not present in the taxonomy (for example, `scripts`, `ci`, `workflows`, `templates`) should be noted in the analysis log as body context rather than assigned as labels.

## Milestone Recommendation

Milestone assignment follows the versioning strategy discovered during Phase 1, Step 1. Apply these recommendations based on issue characteristics.

| Issue Characteristic       | Stability Target | Proximity Target | Rationale                                           |
|----------------------------|------------------|------------------|-----------------------------------------------------|
| Bug fix                    | stable           | current          | Production fixes target the nearest stable release  |
| Security fix               | stable           | current          | Security patches ship in the nearest stable release |
| Maintenance or refactoring | stable           | current          | Low-risk changes target stable releases             |
| Documentation improvement  | stable           | current          | Documentation ships with stable releases            |
| New feature                | pre-release      | next             | Features incubate before stable release             |
| Breaking change            | pre-release      | next             | Breaking changes land in development milestones     |
| Infrastructure improvement | stable           | current          | CI/CD and build changes target stable releases      |

When uncertain about milestone assignment, default to the nearest pre-release or next milestone and flag the issue for human review.

## Duplicate Detection

For each untriaged issue, search for potential duplicates using the similarity assessment framework from the planning specification.

### Search Strategy

Build search queries from the issue title and body:

1. Extract 2-4 keyword groups from the issue title.
2. Execute `mcp_github_search_issues` for each keyword group scoped to the repository.
3. Assess similarity of returned results against the untriaged issue using the assessment template from the planning specification.

### Duplicate Resolution

| Similarity Category | Action                                                                             |
|---------------------|------------------------------------------------------------------------------------|
| Match               | Suggest closing the untriaged issue as duplicate with a reference to the original. |
| Similar             | Flag both issues for user review with a comparison summary.                        |
| Distinct            | Proceed with label and milestone assignment.                                       |
| Uncertain           | Request user guidance before taking action.                                        |

When a Match is found, record the original issue number in the triage plan for the `duplicate_of` field. The Close operation must include `state_reason: 'duplicate'` per the issue field matrix in the planning specification.

Duplicate closure follows the comment-before-closure pattern:

1. Post a comment using `mcp_github_add_issue_comment` with the Scenario 7 (Closing a Duplicate Issue) template from `community-interaction.instructions.md`, filling `{{original_number}}` with the matched issue number.
2. Close the issue using `mcp_github_issue_write` with `method: 'update'`, `state: 'closed'`, `state_reason: 'duplicate'`, and `duplicate_of` set to the original issue number.

## Priority Assessment

Assess priority based on the suggested label to determine triage ordering. Process higher-priority issues first.

| Priority | Label(s)                       | Handling                                                                                                 |
|----------|--------------------------------|----------------------------------------------------------------------------------------------------------|
| Highest  | `security`                     | Flag for immediate attention. Assign to the nearest stable or current milestone with expedited notation. |
| High     | `bug`                          | Assign to the nearest stable or current milestone. Prioritize in triage plan.                            |
| Normal   | `feature`, `enhancement`       | Assign to the appropriate milestone per the discovered strategy.                                         |
| Lower    | `documentation`, `maintenance` | Assign to the nearest stable or current milestone. Process after higher-priority items.                  |

Issues with the `breaking-change` label are escalated to the nearest pre-release or next milestone regardless of other priority signals. Under partial and manual autonomy, flag `breaking-change` issues for human review before applying milestone assignment, consistent with the Human Review Triggers in the planning specification.

## Error Handling

Handle API failures and edge cases during triage execution:

* When a label or milestone update fails due to rate limiting, log the failure in planning-log.md and retry after the rate limit window resets. Continue processing remaining issues.
* When `mcp_github_issue_write` returns a validation error (for example, an invalid milestone name), log the error, skip the affected issue, and flag it for manual review in the triage plan.
* When `mcp_github_search_issues` returns no results for a duplicate search query, record "no duplicates found" and proceed with label and milestone assignment.
* When an issue has been modified between analysis and execution (labels or state changed externally), re-fetch the issue details before applying updates to avoid overwriting concurrent changes.
* When the comment step of a comment-before-closure pattern fails, log the failure in planning-log.md and proceed with the closure call. The closure carries the authoritative state change; the comment provides contributor context.

## Output

The triage workflow produces output files in `.copilot-tracking/github-issues/triage/{{YYYY-MM-DD}}/`.

### triage-plan.md Template

Planning markdown files must start and end with the directives defined in the planning specification.

```markdown
<!-- markdownlint-disable-file -->
<!-- markdown-table-prettify-ignore-start -->
# Triage Plan - {{YYYY-MM-DD}}

* **Repository**: {{owner}}/{{repo}}
* **Issues Analyzed**: {{count}}
* **Date**: {{YYYY-MM-DD}}

## Summary

| Action          | Count              |
| --------------- | ------------------ |
| Label + Assign  | {{label_count}}    |
| Close Duplicate | {{duplicate_count}} |
| Manual Review   | {{review_count}}   |

## Triage Recommendations

| Issue | Title | Suggested Labels | Suggested Milestone | Duplicates Found | Priority | Action |
| ----- | ----- | ---------------- | ------------------- | ---------------- | -------- | ------ |
| #{{number}} | {{title}} | {{labels}} | {{milestone}} | {{duplicate_refs}} | {{priority}} | {{action}} |

## Issues Requiring Manual Review

### #{{number}}: {{title}}

* **Reason**: {{reason for manual review}}
* **Current Labels**: {{existing_labels}}
* **Suggested Labels**: {{suggested_labels}}
* **Notes**: {{additional context}}

## Duplicate Pairs

### #{{untriaged_number}} duplicates #{{original_number}}

* **Similarity Category**: Match
* **Rationale**: {{explanation}}
* **Recommended Action**: Close #{{untriaged_number}} as duplicate of #{{original_number}}
<!-- markdown-table-prettify-ignore-end -->
```

### planning-log.md

Use the planning-log.md template from the planning specification. Set the planning type to `Triage` and track each issue through analysis, planning, and execution.

## Success Criteria

Triage is complete when:

* All fetched issues (up to `maxIssues`) with the `needs-triage` label have been analyzed for label suggestions, milestone recommendations, and duplicate candidates.
* A triage-plan.md exists with a recommendation row for every analyzed issue.
* The user has reviewed and confirmed (or adjusted) the triage plan, respecting the active autonomy tier.
* Confirmed recommendations have been executed via consolidated API calls (labels assigned, milestones set, `needs-triage` removed from classified issues, duplicates closed).
* planning-log.md reflects the final state of all operations with checkboxes marking completion.
* Any failed operations have been logged and either retried or flagged for manual follow-up.

---

Brought to you by microsoft/hve-core
