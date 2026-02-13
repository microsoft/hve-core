---
description: 'Reference specification for GitHub backlog management tooling - planning files, search protocols, similarity assessment, and state persistence'
applyTo: '**/.copilot-tracking/github-issues/**'
---

# GitHub Backlog Planning File Instructions

## Purpose and Scope

Templates, field conventions, search protocols, and state persistence for GitHub backlog planning files. Workflow files must consume this specification by including a cross-reference at the top of their content.

Cross-reference pattern for consuming files:

```markdown
Follow all instructions from #file:./github-backlog-planning.instructions.md while executing this workflow.
```

Inline reference pattern when citing specific sections:

```markdown
per templates in #file:./github-backlog-planning.instructions.md
using the matrix from #file:./github-backlog-planning.instructions.md
```

## GitHub MCP Tool Catalog

Issue operations reference these MCP GitHub tools.

### Discovery and Retrieval

* `mcp_github_get_me`: Get authenticated user details. Agents should call this before operations requiring current user context. Key params: none.
* `mcp_github_list_issues`: List issues with filtering. Does not accept milestone or assignee filters; agents must use `mcp_github_search_issues` for those. Key params: `owner`, `repo`, `state`, `labels`, `since`, `direction`, `orderBy`, `perPage`, `after`.
* `mcp_github_search_issues`: Search issues with GitHub search syntax. Key params: `query` (required), `owner`, `repo`, `sort`, `order`, `perPage`, `page`.
* `mcp_github_issue_read`: Read issue details with multiple retrieval methods. Key params: `method` (required, one of: `get`, `get_comments`, `get_sub_issues`, `get_labels`), `owner`, `repo`, `issue_number`.
* `mcp_github_list_issue_types`: List supported issue types for an organization. Agents must call this before using the `type` param on `mcp_github_issue_write`. Key params: `owner`.
* `mcp_github_get_label`: Get label details for a repository. Key params: `owner`, `repo`, `name`.

### Creation and Updates

* `mcp_github_issue_write`: Create or update issues. Key params: `method` (required, one of: `create`, `update`), `owner`, `repo`, `title`, `body`, `labels`, `assignees`, `milestone`, `state`, `state_reason`, `type`, `duplicate_of`, `issue_number` (required for update).
* `mcp_github_add_issue_comment`: Add a comment to an issue or pull request. For community-facing comments, follow templates in the Community Communication section. Key params: `owner`, `repo`, `issue_number`, `body`.
* `mcp_github_assign_copilot_to_issue`: Assign Copilot coding agent to an issue. Key params: `owner`, `repo`, `issue_number`, `base_ref`, `custom_instructions`.

### Relationships

* `mcp_github_sub_issue_write`: Manage sub-issue relationships. Key params: `method` (required, one of: `add`, `remove`, `reprioritize`), `owner`, `repo`, `issue_number`, `sub_issue_id`, `after_id`, `before_id`.

### Project Management

* `mcp_github_search_pull_requests`: Search pull requests with GitHub search syntax. Key params: `query` (required), `owner`, `repo`, `sort`, `order`, `perPage`, `page`.
* `mcp_github_list_pull_requests`: List pull requests with filtering. Key params: `owner`, `repo`, `state`, `head`, `base`, `sort`, `direction`, `perPage`, `page`.
* `mcp_github_update_pull_request`: Update pull request metadata (title, body, state, base branch, reviewers, draft status). Does not support milestone, label, or assignee changes. Key params: `owner`, `repo`, `pullNumber`, `title`, `body`, `state`, `base`, `draft`, `reviewers`, `maintainer_can_modify`.

### Pull Request Field Operations

GitHub treats pull requests as a superset of issues sharing the same number space. The Issues API can read and write fields on pull requests that the Pull Requests API does not expose, including milestones, labels, and assignees.

To set a milestone, labels, or assignees on a pull request, call `mcp_github_issue_write` with `method: 'update'` and pass the PR number as `issue_number`. The `mcp_github_update_pull_request` tool cannot set these fields.

Common PR field operations via the Issues API:

| Operation         | Tool                           | Method   | Key Fields                                 |
|-------------------|--------------------------------|----------|--------------------------------------------|
| Set PR Milestone  | `mcp_github_issue_write`       | `update` | owner, repo, issue_number (PR#), milestone |
| Set PR Labels     | `mcp_github_issue_write`       | `update` | owner, repo, issue_number (PR#), labels    |
| Set PR Assignees  | `mcp_github_issue_write`       | `update` | owner, repo, issue_number (PR#), assignees |
| Add Comment to PR | `mcp_github_add_issue_comment` | N/A      | owner, repo, issue_number (PR#), body      |

> [!IMPORTANT]
> When setting milestones or labels on pull requests, always use `mcp_github_issue_write` with the PR number as `issue_number`. The `mcp_github_update_pull_request` tool does not accept milestone, label, or assignee parameters.

### Community Communication

When an operation produces a comment visible to external contributors, the comment body follows scenario templates from `community-interaction.instructions.md`. This applies to closure messages, information requests, acknowledgments, and redirects.

| Operation       | Scenario                                             | Template Guidance                    |
|-----------------|------------------------------------------------------|--------------------------------------|
| Close duplicate | Scenario 7: Closing a Duplicate Issue                | Duplicate closure with original link |
| Close completed | Scenario 8: Closing a Completed Issue                | Summary of resolution with thanks    |
| Close won't-fix | Scenario 9: Closing a Won't-Fix Issue                | Rationale with appreciation          |
| Close stale     | Scenario 10: Closing a Stale Issue                   | Neutral with reopen path             |
| Request info    | Scenario 14: Requesting More Information on an Issue | Specific questions with timeline     |

Apply the comment-before-closure pattern: call `mcp_github_add_issue_comment` with the appropriate scenario template before any state-changing call such as `mcp_github_issue_write` with closure. This ordering ensures contributors see the explanation before the issue closes.

Internal-only operations (label changes, milestone assignment, sub-issue linking) that produce no visible comment do not require community interaction templates.

## Planning File Definitions and Directory Conventions

Root planning workspace structure:

```text
.copilot-tracking/
  github-issues/
    <planning-type>/
      <scope-name>/
        issue-analysis.md
        issues-plan.md
        planning-log.md
        handoff.md
        handoff-logs.md
```

Valid `<planning-type>` values:

* `discovery`: Issue discovery from artifacts, PRDs, or user requests
* `triage`: Issue triage, label assignment, and duplicate detection
* `sprint`: Sprint planning and milestone organization
* `backlog`: Backlog refinement and prioritization
* `execution`: Issue creation, update, and closure from finalized plans

Normalization rules for `<scope-name>`:

* Use lower-case, hyphenated form without extension (for example, `docs/Customer Onboarding PRD.md` becomes `docs--customer-onboarding-prd`).
* Replace spaces and punctuation with hyphens.
* Choose the primary artifact when multiple artifacts and documents are provided.
* For triage scopes, use the date as the scope name (for example, `2026-02-05`).
* For sprint scopes, use the milestone name (for example, `v2-2-0`).

## Planning File Requirements

Planning markdown files must start with:

```markdown
<!-- markdownlint-disable-file -->
<!-- markdown-table-prettify-ignore-start -->
```

Planning markdown files must end with (before the final newline):

```markdown
<!-- markdown-table-prettify-ignore-end -->
```

## Planning File Templates

### issue-analysis.md

Agents must create issue-analysis.md when beginning issue discovery from PRDs, user requests, or codebase artifacts. This file captures the human-readable analysis of planned issue operations before finalizing in issues-plan.md.

Agents should populate sections by extracting requirements from referenced artifacts, searching GitHub for related issues, and incorporating user feedback. Agents should update the file iteratively as discovery progresses.

Found Issue Field Values records the current state retrieved from GitHub for existing issues. Suggested Issue Field Values records all fields as they should appear after the planned operation. When creating a new issue, Found Issue Field Values should be omitted.

#### Template

````markdown
# [Planning Type] Issue Analysis - [Summarized Title]

* **Artifact(s)**: [e.g., relative/path/to/artifact-a.md, relative/path/to/artifact-b.md]
  * [(Optional) Inline Artifacts (e.g., User provided the following: [markdown block follows])]
* **Repository**: [owner/repo]
* **Milestone**: [(Optional) Milestone name]

## Planned Issues

### IS[Reference Number (e.g., 001)] - [one of, Create|Update|Link|Close|No Change] - [Summarized Issue Title]

* **Working Title**: [Single line value (e.g., feat(agents): add batch triage support)]
* **Working Type**: [(Optional) Issue type if org supports issue types]
* **Key Search Terms**: [Keyword groups (e.g., "batch triage", "label automation", "needs-triage")]
* **Working Description**:
  ```markdown
  [Evolving description content constructed from artifacts and discovery]
  ```
* **Working Labels**: [Comma-separated labels (e.g., feature, agents)]
* **Working Milestone**: [(Optional) Milestone name (e.g., v2.2.0)]
* **Found Issue Field Values**:
  * [Field (e.g., state)]: [Value (e.g., open)]
  * [Field (e.g., labels)]: [Value (e.g., bug, needs-triage)]
* **Suggested Issue Field Values**:
  * [Field (e.g., labels)]: [Value (e.g., feature, agents)]
  * [Field (e.g., milestone)]: [Value (e.g., v2.2.0)]

#### IS[Reference Number] - Related and Discovered Information

* [(Optional) zero or more Requirements blocks (e.g., Related Requirements from relative/path/to/artifact-a.md)]
  * [(Optional) one or more requirement line items (e.g., REQ-001: details of requirement)]
* [one or more Key Details blocks (e.g., Related Key Details from relative/path/to/artifact-b.md)]
  * [one or more key detail line items (e.g., `Section 2.3` references dependency on data ingestion workflow)]
* [(Optional) zero or more Related Codebase blocks (e.g., Related Codebase Items Mentioned from User)]
  * [(Optional) one or more related codebase line items (e.g., src/components/example.ts: update with related functionality)]
````

### issues-plan.md

issues-plan.md is the source of truth for planned issue operations. Agents must capture the current `state` for every referenced issue, highlighting `closed` items. When a closed issue satisfies the requirement without updates, agents should keep the action as `No Change` and note the relationship.

#### Template

````markdown
# Issues Plan

* **Repository**: [owner/repo]
* **Milestone**: [(Optional) Milestone name]

## IS[Reference Number (e.g., 002)] - [Action (one of, Create|Update|Link|Close|No Change)] - [Summarized Title]

[1-5 Sentence Explanation of Change (e.g., Adding issue for batch triage support called out in Section 2.3 of the referenced document)]

[IS[Reference Number] - Similarity: [#issue_number=Category (e.g., #42=Similar, #38=Match, #55=Distinct)]]

* IS[Reference Number] - issue_number: [#number or {{TEMP-N}}]
* IS[Reference Number] - title: [Issue title]
* IS[Reference Number] - state: [open|closed]
* IS[Reference Number] - labels: [comma-separated labels]
* IS[Reference Number] - milestone: [milestone name or none]
* IS[Reference Number] - assignees: [comma-separated usernames or none]

### IS[Reference Number] - body

```markdown
[Issue body content]
```

### IS[Reference Number] - Relationships

* IS[Reference Number] - [Relationship Type (e.g., sub-issue-of, parent-of, linked-pr)] - [Target (e.g., #42, {{TEMP-1}})]: [Single line reason]
````

#### Example

````markdown
# Issues Plan

* **Repository**: microsoft/hve-core
* **Milestone**: v2.2.0

## IS002 - Update - Add batch label operations to triage workflow

Updating existing issue to include batch label operations from Section 2.3.

IS002 - Similarity: #38=Match, #55=Similar (titles align on triage workflow; #55 has broader scope)

* IS002 - issue_number: #38
* IS002 - title: feat(agents): add batch triage support
* IS002 - state: open
* IS002 - labels: feature, agents
* IS002 - milestone: v2.2.0
* IS002 - assignees: WilliamBerryiii

### IS002 - body

```markdown
## Summary

Add batch label operations to the triage workflow agent.

## Acceptance Criteria

* Batch apply labels to multiple issues in a single operation.
* Support undo of batch label changes.
```

### IS002 - Relationships

* IS002 - sub-issue-of - #30: Triage workflow epic
````

### planning-log.md

planning-log.md is a living document with sections that are routinely added, updated, extended, and removed in-place.

Phase tracking applies when the consuming workflow file defines phases (see the workflow file's Required Phases section for phase definitions):

* Agents must track all new, in-progress, and completed steps for each phase.
* Agents must update the Status section with in-progress review of completed and proposed steps.
* Agents must update Previous Phase when moving to any other phase (phases can repeat based on discovery needs).
* Agents must update Current Phase and Previous Phase when transitioning phases.

#### Template

````markdown
# [Planning Type] - Issue Planning Log

* **Repository**: [owner/repo]
* **Milestone**: [(Optional) Milestone name]
* **Previous Phase**: [(Optional) (e.g., Phase-1, Phase-2, N/A, Just Started)]
* **Current Phase**: [(e.g., Phase-1, Phase-2, N/A, Just Started)]

## Status

[e.g., 3/10 issues searched, 1/5 docs reviewed, 2/8 issues planned]

**Summary**: [e.g., Searching for existing issues based on keywords from PRD]

## Discovered Artifacts and Related Files

* AT[Reference Number (e.g., 001)] [relative/path/to/file] - [one of, Not Started|In-Progress|Complete] - [Processing|Related|N/A]

## Discovered GitHub Issues

* GH-[Issue Number (e.g., 42)] - [one of, Not Started|In-Progress|Complete] - [Processing|Related|N/A]

## Issue Progress

### **IS[Reference Number]** - [Label summary (e.g., feature, agents)] - [one of, In-Progress|Complete]

* IS[Reference Number] - Issue Section (see issue-analysis.md)
* Working Search Keywords: [Working Keywords (e.g., "batch triage OR label automation")]
* Related GitHub Issues - Similarity: [#number=Category (Rationale) (e.g., #42=Similar (overlapping scope), #38=Match (same user goal))]
* Suggested Action: [one of, Create|Update|Link|Close|No Change]

[Collected and Discovered Information]

[Possible Issue Field Values]

## Doc Analysis - issue-analysis.md

### [relative/path/to/referenced/doc.ext]

* IS[Reference Number] - Issue Section (see issue-analysis.md): [Summary of what was done]

## GitHub Issues

### GH-[Issue Number]

[All content from mcp_github_issue_read method get]
````

#### Field Value Example

````markdown
* Working `title`: feat(agents): add batch triage support
* Working `body`:
  ```markdown
  ## Summary
  Add batch label operations to the triage workflow agent.
  ```
* Working `labels`: feature, agents
* Working `milestone`: v2.2.0
````

### handoff.md

Handoff file requirements:

* Agents must include a reference to each issue defined in issues-plan.md.
* Agents must order entries with Create actions first, Update actions second, Link actions third, Close actions fourth, Comment actions fifth, and No Change entries last.
* Agents must include a markdown checkbox next to each issue with a summary.
* Agents must include project-relative paths to all planning files.
* Agents must update the Summary section whenever the Issues section changes.

Checkbox state semantics for execution consumption:

* `- [ ]` (unchecked): Pending operation. The execution stage must process this entry.
* `- [x]` (checked): Completed operation. The execution stage must skip this entry during resumed execution.

This convention enables resumable execution. When an execution run is interrupted and restarted, the execution stage reads checkbox states to determine which operations remain pending.

#### Template

```markdown
# GitHub Issue Operations Handoff

## Planning Files

* .copilot-tracking/github-issues/<planning-type>/<scope-name>/issue-analysis.md
* .copilot-tracking/github-issues/<planning-type>/<scope-name>/issues-plan.md
* .copilot-tracking/github-issues/<planning-type>/<scope-name>/planning-log.md
* .copilot-tracking/github-issues/<planning-type>/<scope-name>/handoff.md

## Summary

| Action    | Count               |
|-----------|---------------------|
| Create    | {{create_count}}    |
| Update    | {{update_count}}    |
| Link      | {{link_count}}      |
| Close     | {{close_count}}     |
| Comment   | {{comment_count}}   |
| No Change | {{no_change_count}} |

## Issues

### Create

- [ ] {{title}}
  - Labels: {{labels}}, Milestone: {{milestone}}, Assignee: {{assignee}}
  - Body: {{summary}}
  - Parent: #{{parent_issue_number}} (sub-issue link)
  - Similarity: {{similarity_category}} to #{{existing_issue}}, {{rationale}}

### Update

- [ ] #{{issue_number}}: {{title}}
  - Action: {{update_action}}
  - Changes: {{field_changes}}
  - Rationale: {{reason}}

### Link (Sub-Issues)

- [ ] Link #{{child}} as sub-issue of #{{parent}}

### Close

- [ ] Close #{{issue_number}}
  - Reason: {{state_reason}} (completed|not_planned|duplicate)
  - Duplicate of: #{{duplicate_of}} (if applicable)

### Comment

- [ ] Comment on #{{issue_number}}
  - Body: {{comment_body}}
  - Rationale: {{reason}}

### No Change

- [ ] (No Change) #{{issue_number}}: {{title}}
  - {{rationale}}
```

### handoff-logs.md

handoff-logs.md records per-issue processing results during execution. The execution workflow must create this file and append entries as each operation completes.

#### Template

```markdown
# GitHub Issue Operations Log

## Execution Summary

| Metric    | Value         |
|-----------|---------------|
| Started   | {{timestamp}} |
| Completed | {{timestamp}} |
| Succeeded | {{count}}     |
| Failed    | {{count}}     |
| Skipped   | {{count}}     |

## Operations

### {{action}} - IS[Reference Number] - {{title}}

* **Status**: [one of, Success|Failed|Skipped]
* **Issue Number**: #{{issue_number}} (or {{TEMP-N}} → #{{actual_number}})
* **Action**: {{action}}
* **Details**: {{details}}
* **Error**: [(Optional) error message if failed]
* **Timestamp**: {{timestamp}}
```

## Search Protocol

Goal: Deterministic, resumable discovery of existing GitHub issues.

### Step 1: Build Keyword Groups

Agents must build an ordered list where each group contains 1-4 specific terms (multi-word phrases allowed) joined by spaces or OR-equivalent constructs.

Example keyword groups for a batch triage feature:

* Group 1: `"batch triage" OR "bulk triage"`
* Group 2: `"label automation" OR "auto-label"`
* Group 3: `"needs-triage" OR "untriaged"`

### Step 2: Compose GitHub Search Syntax

Agents must format the `query` parameter for `mcp_github_search_issues`:

```text
# Issues by keyword
repo:owner/repo is:issue "search term"

# Issues by milestone
repo:owner/repo is:issue milestone:"v2.2.0" is:open

# Issues by label combination
repo:owner/repo is:issue label:needs-triage label:enhancement

# Issues with no milestone
repo:owner/repo is:issue no:milestone is:open

# Issues by assignee
repo:owner/repo is:issue assignee:username is:open

# Cross-label search for triage
repo:owner/repo is:issue label:needs-triage -label:bug -label:enhancement

# Text search within issue bodies
repo:owner/repo is:issue "acceptance criteria" in:body is:open
```

### Step 3: Execute Search and Paginate

Agents must execute `mcp_github_search_issues` with the constructed query and paginate results using `perPage` (max 100) and `page` parameters.

Agents must filter results to identify candidates for similarity assessment:

* Search results must contain terms matching the planned issue's core concepts.
* Issue state must align with the query intent (open for active work, any for comprehensive search).
* Issue must not already be tracked in the planning log.

### Step 4: Hydrate Results

For each candidate, agents must fetch full details using `mcp_github_issue_read` with method `get` and update planning-log.md under the Discovered GitHub Issues section.

### Step 5: Assess Similarity

Agents must perform similarity assessment for each candidate (see the Similarity Assessment Framework section).

## Similarity Assessment Framework

Analyze the relationship between a planned issue and each discovered issue through aspect-by-aspect comparison.

### Comparison Aspects

1. Compare titles to identify the core intent of each. Determine whether both describe the same goal or outcome.
2. Compare body content to determine whether both address the same problem or user need. Note scope differences.
3. Calculate label overlap between existing and proposed labels. High overlap is a strong signal of similarity.
4. Evaluate whether both issues target the same milestone or release scope.

When a field is absent from the discovered issue:

* Missing body: Agents should use title and labels to infer scope and must apply the Uncertain category when insufficient information remains.
* Missing labels: Agents should compare against title and body content only. Labels carry less weight in the assessment.
* Different issue types: Evaluate whether the planned issue should become a sub-issue of the discovered issue.

### Similarity Categories

| Category  | Meaning                                              | Action                           |
|-----------|------------------------------------------------------|----------------------------------|
| Match     | Same issue; creating both would duplicate effort     | Update existing issue            |
| Similar   | Related enough that consolidation may be appropriate | Review with user before deciding |
| Distinct  | Different issues with minimal overlap                | Create new issue                 |
| Uncertain | Insufficient information or conflicting signals      | Request user guidance            |

### Assessment Template

For each comparison, record the assessment using this format:

```markdown
### Issue Similarity Assessment

| Aspect           | Existing #{{number}}   | Proposed Issue         | Match Level                 |
|------------------|------------------------|------------------------|-----------------------------|
| Title            | {{existing_title}}     | {{proposed_title}}     | {{High/Medium/Low/None}}    |
| Body/Description | {{existing_summary}}   | {{proposed_summary}}   | {{High/Medium/Low/None}}    |
| Labels           | {{existing_labels}}    | {{proposed_labels}}    | {{overlap_count}}/{{total}} |
| Milestone        | {{existing_milestone}} | {{proposed_milestone}} | {{Same/Different/None}}     |

**Category:** {{Match/Similar/Distinct/Uncertain}}
**Recommended Action:** {{Update existing/Create new/Needs review/Skip}}
**Rationale:** {{explanation}}
```

### Recording Similarity Assessments

Record each assessment in planning-log.md under a Discovered GitHub Issues section with:

* Issue number and title of the discovered issue
* Category assigned (Match, Similar, Distinct, or Uncertain)
* Brief rationale explaining the classification
* Recommended action based on the category

Format: `GH-{number}: {Category} - {rationale}`

Example:

```markdown
## Discovered GitHub Issues

* GH-42: Similar - Batch triage feature overlaps with label automation goals; scope is broader (full triage vs label-only)
* GH-55: Match - Same user goal for automated milestone assignment; existing issue covers planned scope
* GH-71: Distinct - Infrastructure CI pipeline is unrelated to triage workflow
```

## Human Review Triggers

Agents must request user guidance when:

* Either issue lacks a title or body
* Labels diverge significantly but titles align
* Cross-milestone items are discovered (planned issue targets one milestone, discovered issue targets another)
* Security-labeled issues are found (issues carrying `security` or `vulnerability` labels)
* Milestone-changing operations are proposed (moving an issue from one milestone to another)
* The relationship is genuinely ambiguous after analysis
* Similarity assessment yields Uncertain for more than two candidates against the same planned issue
* A planned Close action targets an issue with open sub-issues

## Label Taxonomy Reference

The repository uses 17 labels organized by purpose. Labels influence milestone assignment through the milestone discovery protocol.

| Label              | Description                                           | Target Role  |
|--------------------|-------------------------------------------------------|--------------|
| `bug`              | Something is not working; targets stable for fixes    | stable       |
| `feature`          | New capability or functionality                       | pre-release  |
| `enhancement`      | Improvement to existing functionality                 | any          |
| `documentation`    | Improvements or additions to documentation            | any          |
| `maintenance`      | Chores, refactoring, dependency updates               | stable       |
| `security`         | Security vulnerability or hardening; may be expedited | stable       |
| `breaking-change`  | Incompatible API or behavior change; pre-release only | pre-release  |
| `needs-triage`     | Requires label and milestone assignment               | unclassified |
| `duplicate`        | This issue already exists; closed immediately         | unclassified |
| `wontfix`          | This will not be worked on; closed                    | unclassified |
| `good-first-issue` | Good for newcomers                                    | any          |
| `help-wanted`      | Extra attention is needed                             | any          |
| `question`         | Further information is requested; informational only  | unclassified |
| `agents`           | Related to agent files                                | any          |
| `prompts`          | Related to prompt files                               | any          |
| `instructions`     | Related to instructions files                         | any          |
| `infrastructure`   | CI/CD, workflows, build tooling                       | stable       |

### Label-to-Title Pattern Mapping

When issue titles follow conventional commit format, agents should map patterns to labels:

| Issue Title Pattern     | Suggested Labels            |
|-------------------------|-----------------------------|
| `feat(agents):`         | feature, agents             |
| `fix(scripts):`         | bug                         |
| `chore(ci):`            | maintenance, infrastructure |
| `refactor(workflows):`  | maintenance                 |
| `docs(templates):`      | documentation               |
| No conventional pattern | needs-triage (retain)       |

## Milestone Discovery Protocol

Discover the repository's milestone strategy at runtime by analyzing open milestones. This protocol replaces static versioning assumptions with dynamic classification.

### Discovery Steps

1. Discover open milestones by sampling recent open issues. Call `mcp_github_search_issues` with `repo:{owner}/{repo} is:issue is:open` sorted by `updated` descending, retrieving up to 100 results. Extract the `milestone` object from each result and aggregate unique milestones by title. Collect available fields (title, description, due_on, state, open_issues, closed_issues) from the milestone objects. Sort discovered milestones by due date ascending (nearest first). This approach may not surface milestones with zero open issues; when comprehensive coverage is required, optionally read the repo-specific override file `.github/milestone-strategy.yml` if it exists. When the file is not present, rely solely on the discovered milestones.
2. Detect the dominant naming pattern from milestone titles using the rules in Naming Pattern Detection.
3. Classify each milestone into an abstract role (`stable`, `pre-release`, `current`, `next`, `backlog`, `any`, `unclassified`) using the signal weighting in Role Classification. The `any` role means the label does not constrain milestone selection.
4. Build the assignment map linking issue characteristics to target roles using the Assignment Map.
5. Record the detected naming pattern, per-milestone role classification, generated assignment map, and confidence level (high, medium, low) in planning-log.md.
6. When confidence is low, optionally check for the repo-specific override file `.github/milestone-strategy.yml` in the repository. If the file exists, apply the declared strategy. If the file does not exist, treat its absence as expected, present the discovered milestones to the user and request classification. When no user input is available, assign `unclassified` and flag for human review.

### Naming Pattern Detection

Evaluate milestone titles to identify the dominant naming pattern. A pattern is dominant when it matches more than 50% of open milestones.

* SemVer: Titles match a major.minor.patch version pattern, optionally prefixed with `v` and optionally suffixed with a pre-release identifier (`-alpha`, `-beta`, `-rc`, `-preview`).
* CalVer: Titles match a year-period pattern such as `2025-Q1` or `2025-03`.
* Sprint: Titles match a sprint identifier such as `Sprint 12` or `sprint-12`.
* Feature: Titles contain descriptive names without version or date patterns.
* Mixed or unknown: No single pattern covers more than 50% of open milestones. Set confidence to low and proceed to the fallback in step 6.

### Role Classification

Classify each milestone into two orthogonal abstract roles using these signals in precedence order: one stability role and one proximity role.

1. Explicit pre-release suffix in the title (`-beta`, `-rc`, `-preview`, `-alpha`): assign `pre-release` stability role. Highest signal.
2. Description keywords: `stable`, `release`, `production`, `GA`, `LTS` suggest `stable` stability role. `pre-release`, `preview`, `beta`, `RC`, `experimental`, `development`, `canary`, `nightly` suggest `pre-release` stability role. Strong signal.
3. Version number parity (SemVer only): even minor version suggests `stable`, odd minor version suggests `pre-release`. Weak signal, used when stronger stability signals are absent.
4. Due date proximity (tiebreaker for proximity only): use date ordering only to choose between `current`, `next`, and `backlog` proximity roles. The nearest future due date with open issues is `current`, the second-nearest is `next`, and remaining milestones (including those without due dates) are `backlog`. Do not use due dates to distinguish `stable` versus `pre-release`; that distinction comes only from signals 1–3.

For CalVer, sprint, and feature naming patterns, apply the same date-based rule for proximity roles: nearest due date is `current`, second-nearest is `next`, and milestones without due dates or with distant due dates are `backlog`.

### Assignment Map

Map issue characteristics to target milestone roles after completing the discovery steps. Each entry specifies a stability target and a proximity target independently.

| Issue Characteristic        | Stability Target | Proximity Target |
|-----------------------------|------------------|------------------|
| Bug fix (production)        | stable           | current          |
| Security vulnerability      | stable           | current          |
| Maintenance and refactoring | stable           | current          |
| Documentation improvement   | stable           | current          |
| New feature                 | pre-release      | next             |
| Breaking change             | pre-release      | next             |
| Experimental capability     | pre-release      | next             |
| Infrastructure improvement  | stable           | current          |
| Low-risk enhancement        | stable           | current          |
| High-risk enhancement       | pre-release      | next             |

Resolve milestone selection deterministically using these targets:

* First, prefer milestones that match both the stability target and the proximity target. Among these, choose the nearest by due date.
* If no milestone matches both targets, relax stability and prefer any milestone with the target proximity. Among these, choose the nearest by due date.
* If neither the combined target nor the proximity target can be satisfied (for example, in very sparse backlogs), choose the nearest suitable milestone by due date regardless of stability or proximity and document the rationale in the planning notes.

Security vulnerabilities follow the same resolution logic but are escalated in priority: they skip lower-priority work in the target milestone and ship in the earliest available release.

When uncertain about milestone assignment, or when no milestone clearly matches these rules, default to the nearest pre-release or next milestone and flag for human review.
## Issue Field Matrix

Track field usage explicitly so downstream automation can rely on consistent data. The matrix defines required and optional fields per operation type. These field requirements apply to both issues and pull requests. When targeting a pull request, pass the PR number as `issue_number` (see the Pull Request Field Operations section in the MCP Tool Catalog).

| Field        | Create   | Update   | Link     | Close    | Comment  |
|--------------|----------|----------|----------|----------|----------|
| title        | REQUIRED | Optional | N/A      | N/A      | N/A      |
| body         | REQUIRED | Optional | N/A      | N/A      | REQUIRED |
| labels       | REQUIRED | Optional | N/A      | N/A      | N/A      |
| assignees    | Optional | Optional | N/A      | N/A      | N/A      |
| milestone    | Optional | Optional | N/A      | N/A      | N/A      |
| issue_number | N/A      | REQUIRED | REQUIRED | REQUIRED | REQUIRED |
| state        | N/A      | Optional | N/A      | REQUIRED | N/A      |
| state_reason | N/A      | N/A      | N/A      | REQUIRED | N/A      |
| sub_issue_id | N/A      | N/A      | REQUIRED | N/A      | N/A      |
| duplicate_of | N/A      | N/A      | N/A      | Optional | N/A      |
| type         | Optional | Optional | N/A      | N/A      | N/A      |

Rules:

* Create operations must provide title, body, and at least one label.
* Update operations must provide issue_number and at least one field to change.
* Link operations must provide both issue_number (parent) and sub_issue_id (child).
* Close operations must provide issue_number, state set to `closed`, and a state_reason (one of: `completed`, `not_planned`, `duplicate`).
* When closing as `duplicate`, the `duplicate_of` field should reference the original issue number.
* Comment operations must provide issue_number and body (passed to `mcp_github_add_issue_comment`).
* Call `mcp_github_list_issue_types` before using the `type` field to confirm the organization supports issue types.

## Content Sanitization Guards

Before composing any content destined for a GitHub API call (issue titles, bodies, comments, labels, milestone descriptions, and other text fields), scan for the patterns below and apply the corresponding resolution. Planning files (*issue-analysis.md*, *planning-log.md*, *issues-plan.md*, *handoff.md*, *handoff-logs.md*) may contain these references locally; however, any content copied from them into GitHub-bound fields must be sanitized using these guards before the API call.

Under Full Autonomy, log the replacement and proceed automatically. Under Partial or Manual autonomy, present the inlined content for user confirmation before the API call.

### Local-Only Path Guard

* **Detect**: Paths matching `.copilot-tracking/`.
* **Resolve**: Read the referenced file, extract relevant details (findings, data points, conclusions), and inline them into the content. Replace the path with a descriptive label such as "Internal research" or "Local analysis" followed by the extracted details.

### Planning Reference ID Guard

* **Detect**: Identifiers matching `IS` followed by digits and optional letter suffixes (for example, `IS001`, `IS002a`, `IS014`).
* **Resolve**:
  * When the actual GitHub issue number is known (from the `issue_number` field in *issues-plan.md* or *handoff.md*, or from the `{{TEMP-N}}` to `#N` mappings in *handoff-logs.md*), replace the planning reference ID with `#<issue_number>`.
  * When the actual issue number is not yet known, replace the planning reference ID with a descriptive phrase summarizing the referenced work.
  * When the reference is a self-reference, remove it or replace it with "this issue".

## Three-Tier Autonomy Model

The autonomy model controls confirmation gates during issue operations. The consuming workflow file must specify the active tier. When no tier is specified, agents should default to Partial Autonomy.

### Full Autonomy

No confirmation gates. Agents must execute all operations autonomously.

* Agents must create issues without user confirmation.
* Agents must update issues without user confirmation.
* Agents must establish sub-issue links without user confirmation.
* Agents must close issues without user confirmation.
* Suitable for well-defined, low-risk batch operations with high-confidence similarity assessments.

### Partial Autonomy

Gate on create and close operations. Auto-execute updates and links.

* Create operations: Agents must present the planned issue for user review before executing.
* Close operations: Agents must present the close rationale for user review before executing.
* Update operations: Agents must execute without confirmation.
* Link operations: Agents must execute without confirmation.
* Suitable for most TPM workflows where creation and deletion carry higher risk.

### Manual

Gate on all operations. Agents must present each for confirmation.

* Create operations: Agents must present for user review.
* Update operations: Agents must present for user review.
* Link operations: Agents must present for user review.
* Close operations: Agents must present for user review.
* Suitable for sensitive backlogs, unfamiliar repositories, or first-time pipeline execution.

## Temporary ID Mapping

Handoff files use `{{TEMP-N}}` placeholders for planned issues that do not yet exist. The execution stage maintains a mapping table as issues are created, resolving references in subsequent operations.

Placeholder format: `{{TEMP-1}}`, `{{TEMP-2}}`, `{{TEMP-3}}`, incrementing sequentially.

During execution, resolve each placeholder to the actual issue number returned by `mcp_github_issue_write`:

```text
{{TEMP-1}} → #42 (created)
{{TEMP-2}} → #43 (created)
{{TEMP-3}} → #44 (created)
```

Resolution rules:

* Agents must create parent issues before child issues so that parent issue numbers are available for sub-issue linking.
* When a `{{TEMP-N}}` reference appears in a sub-issue link operation, agents must resolve it from the mapping table before calling `mcp_github_sub_issue_write`.
* Agents must record the mapping in handoff-logs.md as each issue is created.
* If a `{{TEMP-N}}` reference cannot be resolved (creation failed), agents must skip dependent operations and log the failure.

## State Persistence Protocol

Agents must update planning-log.md as information is discovered to ensure continuity when context is summarized.

### Pre-Summarization Capture

Before summarization occurs, agents must capture in planning-log.md:

* Full paths to all working files with a summary of each file's purpose
* Any uncaptured information that belongs in planning files
* Issue numbers already reviewed
* Issue numbers pending review
* Current phase and remaining steps
* Outstanding search criteria

### Post-Summarization Recovery

VS Code Copilot periodically compresses conversation history into a `<summary>` block when the context window approaches capacity. When the recovered context contains a `<summary>` block with only one tool call, agents must recover state before continuing:

1. List the working folder with `list_dir` under `.copilot-tracking/github-issues/<planning-type>/<scope-name>/`.
2. Read planning-log.md to rebuild context.
3. Notify the user that context is being rebuilt and confirm the approach before proceeding.

Recovery notification format:

```markdown
## Resuming After Context Summarization

Context history was summarized. Rebuilding from planning files:

**Analyzing**: [planning-log.md summary]

Next steps:
* [Planned actions]

Proceed with this approach?
```

---

Brought to you by microsoft/hve-core
