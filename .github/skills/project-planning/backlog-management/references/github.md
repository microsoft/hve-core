---
description: 'GitHub platform bindings for backlog workflows: issue types, labels, milestones, search syntax, community communication, and per-workflow deltas'
---

<!-- markdownlint-disable-file -->
# GitHub Platform Reference

GitHub delta for the [backlog-management](../SKILL.md) skill. Read this with the core conventions and [workflows.md](workflows.md). This reference names GitHub's command surface, supported operations, field vocabulary and field matrix, search query syntax, issue body and type strategy, label taxonomy, milestone protocol, reference-ID prefix, action verbs, community-communication guardrails, PRD hierarchy rules, and tracking paths. Everything structural — planning-file lifecycle, similarity, autonomy, sanitization, state persistence — comes from the core.

## Command Surface

GitHub backlog operations run through the MCP GitHub tools. Call `mcp_github_get_me` before operations that need the current user context. GitHub treats pull requests as a superset of issues sharing one number space, so the Issues API can set fields on a PR that the Pull Requests API cannot.

| Category      | Tool                                 | Purpose                                                                                                                                                                                                                                                                                       |
|---------------|--------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Discover      | `mcp_github_list_issues`             | List issues with filtering. No milestone or assignee filter — use search for those. Params: `owner`, `repo`, `state`, `labels`, `since`, `direction`, `orderBy`, `perPage`, `after`.                                                                                                          |
| Discover      | `mcp_github_search_issues`           | Search issues with GitHub search syntax. Params: `query` (required), `owner`, `repo`, `sort`, `order`, `perPage`, `page`.                                                                                                                                                                     |
| Context       | `mcp_github_issue_read`              | Read issue details. Params: `method` (one of `get`, `get_comments`, `get_sub_issues`, `get_labels`), `owner`, `repo`, `issue_number`.                                                                                                                                                         |
| Context       | `mcp_github_list_issue_types`        | List org-supported issue types. Call before using `type` on a write. Params: `owner`.                                                                                                                                                                                                         |
| Context       | `mcp_github_get_label`               | Get repository label details. Params: `owner`, `repo`, `name`.                                                                                                                                                                                                                                |
| Mutate        | `mcp_github_issue_write`             | Create or update issues (and set PR milestone/labels/assignees via the PR number). Params: `method` (one of `create`, `update`), `owner`, `repo`, `title`, `body`, `labels`, `assignees`, `milestone`, `state`, `state_reason`, `type`, `duplicate_of`, `issue_number` (required for update). |
| Mutate        | `mcp_github_add_issue_comment`       | Add a comment to an issue or PR. Params: `owner`, `repo`, `issue_number`, `body`.                                                                                                                                                                                                             |
| Relationships | `mcp_github_sub_issue_write`         | Manage sub-issue links. Params: `method` (one of `add`, `remove`, `reprioritize`), `owner`, `repo`, `issue_number`, `sub_issue_id`, `after_id`, `before_id`.                                                                                                                                  |
| Assignment    | `mcp_github_assign_copilot_to_issue` | Assign the Copilot coding agent to an issue. Params: `owner`, `repo`, `issue_number`, `base_ref`, `custom_instructions`.                                                                                                                                                                      |

To set a milestone, labels, or assignees on a pull request, call `mcp_github_issue_write` with `method: update` and pass the PR number as `issue_number`; `mcp_github_update_pull_request` cannot set those fields. Prefer scoped `mcp_github_search_issues` queries over broad listing to keep output bounded.

## Supported Operations

Every planned GitHub operation resolves to exactly one row. An action that has no row is not a supported GitHub operation and is not planned.

| Operation          | Tool                                 | Method   | Required fields                                                                                                 |
|--------------------|--------------------------------------|----------|-----------------------------------------------------------------------------------------------------------------|
| Create issue       | `mcp_github_issue_write`             | `create` | `owner`, `repo`, `title`; `body`, `labels`, `milestone`, `assignees`, `type` optional                           |
| Update issue       | `mcp_github_issue_write`             | `update` | `owner`, `repo`, `issue_number` plus the changed fields                                                         |
| Close issue        | `mcp_github_issue_write`             | `update` | `owner`, `repo`, `issue_number`, `state: closed`, `state_reason`; `duplicate_of` when the reason is `duplicate` |
| Add labels         | `mcp_github_issue_write`             | `update` | `owner`, `repo`, `issue_number`, full replacement `labels` set                                                  |
| Set milestone      | `mcp_github_issue_write`             | `update` | `owner`, `repo`, `issue_number`, `milestone`                                                                    |
| Add sub-issue link | `mcp_github_sub_issue_write`         | `add`    | `owner`, `repo`, `issue_number` (parent), `sub_issue_id`                                                        |
| Add comment        | `mcp_github_add_issue_comment`       | n/a      | `owner`, `repo`, `issue_number`, `body`                                                                         |
| Set PR milestone   | `mcp_github_issue_write`             | `update` | `owner`, `repo`, `issue_number` (the PR number), `milestone`                                                    |
| Set PR labels      | `mcp_github_issue_write`             | `update` | `owner`, `repo`, `issue_number` (the PR number), full replacement `labels` set                                  |
| Set PR assignees   | `mcp_github_issue_write`             | `update` | `owner`, `repo`, `issue_number` (the PR number), full replacement `assignees` set                               |
| Update PR fields   | `mcp_github_update_pull_request`     | n/a      | `owner`, `repo`, `pullNumber` plus the changed PR-specific fields (`title`, `body`, `base`, `draft`, `state`)   |
| Assign Copilot     | `mcp_github_assign_copilot_to_issue` | n/a      | `owner`, `repo`, `issue_number`; `base_ref`, `custom_instructions` optional                                     |

Operation rules:

* `labels` uses replacement semantics on every call. Compute the full target set as `(current_labels - removed) + added` before writing; a partial list silently drops labels.
* Close operations run after every field update and comment planned for the same issue, per the Operation Contract in [workflows.md](workflows.md).
* Sub-issue links run only after both the parent and the child exist.
* A community-visible explanatory comment posts before the state change it explains; see Community Communication below.

### Pull Request Field Operations

GitHub treats pull requests as a superset of issues sharing one number space, so the Issues API sets fields the Pull Requests API cannot.

* Milestone, labels, and assignees on a PR are set through `mcp_github_issue_write` with `method: update`, passing the PR number as `issue_number`.
* `mcp_github_update_pull_request` owns PR-specific fields (title, body, base, draft, state) and does not accept milestone, labels, or assignees.
* Discover PRs for a milestone with `mcp_github_search_pull_requests`; the Issues search surface does not reliably return PR-only results.
* Treat a PR field operation as a normal Update in the handoff, with the PR number recorded as the item key.

### Error Cases (GitHub specifics)

The shared Error Handling table in [workflows.md](workflows.md) defines the required behavior. These are the GitHub signals that select each row.

| GitHub signal                              | Shared error case               |
|--------------------------------------------|---------------------------------|
| `401` or `403`                             | Authentication or permission    |
| `404` on an issue number                   | Item not found                  |
| `429` or a secondary rate-limit message    | Rate limited                    |
| Label or milestone rejected as nonexistent | Invalid field or label payload  |
| `state_reason` rejected for the state      | Unavailable transition or state |
| `sub_issue_id` refers to a missing issue   | Missing relationship endpoint   |

## Platform Bindings

| Binding                 | GitHub value                                                                                           |
|-------------------------|--------------------------------------------------------------------------------------------------------|
| Platform tracking root  | `.copilot-tracking/github-issues/`                                                                     |
| Reference-ID prefix     | `IS` (for example `IS001`)                                                                             |
| Item vocabulary         | "issue"; item key is the issue number (for example `#42`)                                              |
| Item types              | Org issue types when enabled (validate with `mcp_github_list_issue_types`); sub-issues carry hierarchy |
| Priority scale          | Label-based (repository convention; no native priority field)                                          |
| Action verbs            | Create, Update, Link, Close, Comment, No Change                                                        |
| Planning-type additions | Beyond the core enum, GitHub uses `sprint` (milestone organization) and `backlog` (refinement)         |

Map the core three-tier autonomy model onto GitHub operations. Validated label and milestone updates are low-risk and auto-execute under Full and Partial. Creates, closes, sub-issue links, comments, and ambiguous duplicate handling gate on the user under Partial and Manual. The core Three-Tier Autonomy Model defines the tiers themselves.

## Field Vocabulary

Map only fields observed on existing issues or validated for the repository.

| Field          | Use                                                      |
|----------------|----------------------------------------------------------|
| `title`        | Required for create payloads                             |
| `body`         | Primary issue body (Markdown)                            |
| `labels`       | Categorization, priority signaling, and triage state     |
| `milestone`    | Sprint or release grouping                               |
| `assignees`    | Optional owner assignment                                |
| `state`        | `open` or `closed`                                       |
| `state_reason` | Close reason: `completed`, `not_planned`, or `duplicate` |
| `type`         | Org issue type (only when the org enables issue types)   |
| `duplicate_of` | Target issue when closing as a duplicate                 |

Field rules:

* Preserve existing issue numbers and current field values when planning updates; capture both current and suggested values in the analysis file.
* Store create or update payloads in `issues-plan.md` using only validated fields.
* Call `mcp_github_list_issue_types` before setting `type`, and `mcp_github_get_label` before applying a label that is not confirmed to exist.
* Do not invent labels or milestones; when a needed label or milestone is unconfirmed, note it as `Needs Review` instead of guessing.

### Issue Field Matrix

Required and optional fields per operation. These requirements apply to issues and to pull requests; when targeting a pull request, pass the PR number as `issue_number`.

| Field          | Create   | Update   | Link     | Close                                       | Comment  |
|----------------|----------|----------|----------|---------------------------------------------|----------|
| `title`        | Required | Optional | n/a      | n/a                                         | n/a      |
| `body`         | Required | Optional | n/a      | n/a                                         | Required |
| `labels`       | Required | Optional | n/a      | n/a                                         | n/a      |
| `milestone`    | Optional | Optional | n/a      | n/a                                         | n/a      |
| `assignees`    | Optional | Optional | n/a      | n/a                                         | n/a      |
| `type`         | Optional | Optional | n/a      | n/a                                         | n/a      |
| `issue_number` | n/a      | Required | Required | Required                                    | Required |
| `sub_issue_id` | n/a      | n/a      | Required | n/a                                         | n/a      |
| `state`        | n/a      | Optional | n/a      | Required                                    | n/a      |
| `state_reason` | n/a      | Optional | n/a      | Required                                    | n/a      |
| `duplicate_of` | n/a      | n/a      | n/a      | Required when `state_reason` is `duplicate` | n/a      |

`state_reason` accepts `completed`, `not_planned`, or `duplicate`.

## Search Query Syntax

The platform-agnostic Search Protocol in [workflows.md](workflows.md) owns the five steps. GitHub supplies the query syntax:

* Scope every query with `repo:{owner}/{repo}` plus `is:issue` and a state qualifier.
* Compose keyword groups as `("term one" OR term2)` and join groups with a space, which GitHub treats as `AND`.
* Add `label:`, `milestone:`, and `assignee:` qualifiers when the caller supplies that context; `mcp_github_list_issues` cannot filter on milestone or assignee, so those belong in search.
* Paginate with `perPage` and `page` until the result set is exhausted or the caller's limit is reached.
* Hydrate survivors with `mcp_github_issue_read` using `method: get`, adding `get_labels` when label replacement semantics matter and `get_sub_issues` when hierarchy matters.

## Issue Body Template

Every Create operation composes its body from this structure, and Updates move an existing body toward it.

```markdown
[1-5 sentence description of the issue's purpose and scope]

## Children

*(parent issues only)*

- #[child_issue_number] [brief title]

## Acceptance Criteria

- [ ] [Criterion 1]
- [ ] [Criterion 2]

## Related

- Parent: #[parent_issue_number]
- Depends on: #[dependency_number] ([brief description])
- [Additional context references]
```

Guidelines:

* Section labels are Markdown headings, not bold text. A heading carries programmatic structure that assistive technology can navigate; bold only changes how the text looks. Every section in this template is a real heading for that reason.
* Body headings start at `##`, because the issue title already occupies the page's top level.
* Every Create includes an Acceptance Criteria section with at least one checkbox. "Definition of Done" is an acceptable heading when it matches the team's convention.
* Acceptance criteria are specific, measurable, and verifiable rather than aspirational.
* A parent issue's criteria summarize the aggregate outcome of its children; a leaf issue's criteria describe its own concrete deliverable.
* Include the Children section only on issues that actually have sub-issues, placed after the description and before Acceptance Criteria.
* Use the Related section for relationships GitHub's sub-issue mechanism does not express: parent references, blocking dependencies, and supporting artifacts.
* Prefer acceptance-criteria checkboxes over narrative "expected output" prose.

## Issue Type Strategy

Apply this strategy only after `mcp_github_list_issue_types` confirms the organization enables issue types. Without type support, convey the same levels through labels and sub-issue nesting.

| Type    | Purpose                                                          | Children         |
|---------|------------------------------------------------------------------|------------------|
| Feature | Grouping container for related work that delivers one capability | Features, Tasks  |
| Task    | Individual actionable work item assignable to one person         | None (leaf node) |
| Bug     | Defect in existing functionality requiring a fix                 | Tasks (optional) |

Assignment rules:

* A Feature groups two or more related Tasks or sub-Features and describes the capability delivered, not the implementation.
* A Task is a leaf node describing one concrete deliverable with its own acceptance criteria.
* A Bug describes a defect and may carry Task sub-issues when the fix needs several steps.
* Nesting Feature into Feature into Task is supported when a capability decomposes into sub-capabilities.
* Do not create a Feature for a single Task. A requirement that maps to exactly one work item becomes a Task directly.

## Label Taxonomy Reference

The repository uses 17 labels. Each label carries a `Target Role`, which the Milestone Discovery and Recommendation protocol below consumes when selecting a milestone. A role of `any` means the label does not constrain milestone selection; `unclassified` means the label indicates the issue is not yet ready for milestone assignment.

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
| `duplicate`        | The issue already exists; closed immediately          | unclassified |
| `wontfix`          | The issue will not be worked on; closed               | unclassified |
| `good-first-issue` | Good for newcomers                                    | any          |
| `help-wanted`      | Extra attention is needed                             | any          |
| `question`         | Further information is requested; informational only  | unclassified |
| `agents`           | Related to agent files                                | any          |
| `prompts`          | Related to prompt files                               | any          |
| `instructions`     | Related to instructions files                         | any          |
| `infrastructure`   | CI/CD, workflows, build tooling                       | stable       |

Confirm a label exists with `mcp_github_get_label` before applying it. A repository that does not carry the full taxonomy uses only its confirmed subset; the missing labels are noted as `Needs Review` rather than created.

## Community Communication

GitHub backlog output is often visible to external contributors, so outbound comments carry extra guardrails beyond the core sanitization guards.

`community-interaction.instructions.md` and `content-policy-citation.instructions.md` are applied automatically through their own `applyTo` attachments and must be honored. The filenames below are provenance, not the enforcement mechanism; this reference is a bundled skill resource and does not path-reference a separately packaged instruction.

* When an operation produces a comment visible to external contributors (closure, information request, acknowledgment, redirect), the comment body follows the scenario templates in `community-interaction.instructions.md`.
* When GitHub-visible text references a suspected content-policy or terms-of-service concern, apply `content-policy-citation.instructions.md` before the API call. Public comments and issue bodies use neutral wording and must not include classification labels, rationale, quoted snippets, paraphrases, or payload examples.
* Apply the comment-before-closure pattern: call `mcp_github_add_issue_comment` with the appropriate scenario template before any state-changing call such as `mcp_github_issue_write` with a closure.
* Internal-only operations (label changes, milestone assignment, sub-issue linking) that produce no visible comment do not require community-interaction templates.

## Relationship Semantics

Plan conservatively.

* GitHub has no native Epic/Feature/Story taxonomy. Model hierarchy with sub-issue relationships (`mcp_github_sub_issue_write`) and, when the org enables issue types, the `type` field.
* Prefer one parent tracking issue per major product outcome, with child issues linked as sub-issues.
* Use org issue types only after `mcp_github_list_issue_types` confirms support; otherwise convey level through labels and sub-issue nesting.
* When hierarchy support is unclear, flatten the plan and mark the relationship decision as `Needs Review`.
* Record relationships in planning files even when the final GitHub linkage (sub-issue versus label) differs by repository configuration.

A sub-issue link is legal only when both the parent and the child already exist, so link operations always follow their creates.

## Interaction Templates

Use the Issue Body Template above for issue bodies, and the scenario templates named in Community Communication for any comment an external contributor can read.

## PRD-to-Work-Item Planning

PRD-driven planning produces planning-only artifacts under `.copilot-tracking/github-issues/prds/<artifact-normalized-name>/` (`issue-analysis.md`, `issues-plan.md`, `planning-log.md`, `handoff.md`) for a separate execution pass. During planning, do not call `mcp_github_issue_write`, `mcp_github_add_issue_comment`, or `mcp_github_sub_issue_write`.

Hierarchy rules are defined by Relationship Semantics above.

The PRD plan extends the shared `issues-plan.md` template with a `parent` field (`none`, a `{{TEMP-N}}` reference, or an existing `#number`), a `needs_review` flag, and an acceptance-criteria block and relationships block per item.

## Triage Delta

GitHub triage suggests labels from conventional-commit title patterns, assigns milestones from the repository's discovered versioning strategy, and detects duplicates via the core Similarity Assessment. Fetch untriaged issues with `mcp_github_search_issues` using `repo:{owner}/{repo} is:issue is:open label:needs-triage`.

### Conventional Commit Title to Label Mapping

| Title pattern                               | Suggested labels                | Meaning                 |
|---------------------------------------------|---------------------------------|-------------------------|
| `feat:` / `feat(scope):`                    | `feature`                       | New functionality       |
| `fix:` / `fix(scope):`                      | `bug`                           | Bug fix                 |
| `docs:`                                     | `documentation`                 | Documentation change    |
| `chore:` / `refactor:` / `test:` / `style:` | `maintenance`                   | Maintenance task        |
| `ci:`                                       | `maintenance`, `infrastructure` | CI/CD change            |
| `perf:`                                     | `enhancement`                   | Performance improvement |
| `build:`                                    | `infrastructure`                | Build system change     |
| `security:`                                 | `security`                      | Security fix            |
| `breaking:` / `BREAKING CHANGE`             | `breaking-change`               | Breaking change         |

Extract scope keywords from `type(scope):` using the mapping below. A title that matches no conventional-commit pattern retains `needs-triage` and is flagged for manual review; classified issues have `needs-triage` removed on triage.

### Scope Keyword to Scope Label Mapping

Map a scope keyword to a label only when the repository label taxonomy defines it. Note an unmapped scope as body context rather than assigning a label.

| Title scope     | Scope label                  |
|-----------------|------------------------------|
| `agents`        | `agents`                     |
| `prompts`       | `prompts`                    |
| `instructions`  | `instructions`               |
| `workflows`     | `infrastructure`             |
| `ci`            | `infrastructure`             |
| `build`         | `infrastructure`             |
| Any other scope | none; record as body context |

### Milestone Discovery and Recommendation

Milestone selection is a runtime discovery problem, not a static versioning assumption. Discover roles first, then resolve deterministically.

#### Step 1: Discover open milestones

Sample recent open issues with `mcp_github_search_issues` using `repo:{owner}/{repo} is:issue is:open` sorted by `updated` descending. Aggregate the unique `milestone` objects from the results, capturing title, description, due date, state, and open and closed issue counts, then sort by due date ascending. This sampling does not surface milestones with zero open issues.

#### Step 2: Detect the naming pattern

A pattern is dominant when it matches more than half of the discovered milestones:

* SemVer — `major.minor.patch`, optionally `v`-prefixed and optionally carrying a pre-release suffix.
* CalVer — a year-period form such as `2026-Q1` or `2026-03`.
* Sprint — a sprint identifier such as `Sprint 12` or `sprint-12`.
* Feature — descriptive titles with no version or date pattern.
* Mixed — no pattern reaches half. Set confidence to low and go to Step 5.

#### Step 3: Classify roles

Assign each milestone one stability role and one proximity role. Stability signals apply in precedence order; the first that fires wins.

| Precedence | Stability signal                                                                                                                                                                      | Strength |
|------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------|
| 1          | Explicit pre-release suffix in the title (`-alpha`, `-beta`, `-rc`, `-preview`) → `pre-release`                                                                                       | Highest  |
| 2          | Description keywords: `stable`, `release`, `production`, `GA`, `LTS` → `stable`; `beta`, `rc`, `preview`, `alpha`, `experimental`, `development`, `canary`, `nightly` → `pre-release` | Strong   |
| 3          | SemVer minor-version parity: even → `stable`, odd → `pre-release`                                                                                                                     | Weak     |

Parity is a fallback only. Use it when signals 1 and 2 produce nothing for that milestone, and never let it override a stronger signal or act as a standalone milestone strategy.

Proximity roles come from due-date ordering alone: the nearest future due date with open issues is `current`, the second-nearest is `next`, and everything else — including milestones without due dates — is `backlog`. Due dates never decide stability.

#### Step 4: Resolve the recommendation

Map the issue's labels to a stability and proximity target through the `Target Role` column of the Label Taxonomy Reference, then apply the issue-characteristic map:

| Issue characteristic                                      | Stability target | Proximity target |
|-----------------------------------------------------------|------------------|------------------|
| Bug, security, maintenance, documentation, infrastructure | stable           | current          |
| New feature, breaking change, experimental capability     | pre-release      | next             |
| Low-risk enhancement                                      | stable           | current          |
| High-risk enhancement                                     | pre-release      | next             |

Resolve deterministically:

1. Prefer a milestone matching both targets; among those, choose the nearest due date.
2. When nothing matches both, relax stability and prefer any milestone with the target proximity; among those, choose the nearest due date.
3. When neither can be satisfied, choose the nearest suitable milestone by due date and record the rationale in `planning-log.md`.

A `security` issue follows the same resolution but is expedited: it ships in the earliest available milestone that satisfies step 1 or 2. Expedited placement is a recommendation, not an approval — a `security` or vulnerability label pauses for user guidance before any mutation, per the GitHub Human Review Triggers below.

#### Step 5: Low-confidence fallback and repository override

When confidence is low — a mixed naming pattern, no discovered milestones, or an unresolvable role classification — read `.github/milestone-strategy.yml` in the target repository. When the file exists, its declared strategy is authoritative and overrides the discovered classification. When the file does not exist, treat its absence as expected: present the discovered milestones to the user and request classification. With no user input available, assign `unclassified` and flag the issue for human review rather than guessing.

Record the detected naming pattern, per-milestone role classification, the resolved recommendation, the confidence level, and whether the override file was used in `planning-log.md`.


### Priority Assessment

Process higher-priority issues first: `security` (highest, expedite) → `bug` (high) → `feature`/`enhancement` (normal) → `documentation`/`maintenance` (lower). `breaking-change` escalates to the nearest pre-release or `next` milestone regardless of other signals, and gates on the user under Partial and Manual autonomy.

## Sprint Planning Delta

The platform-agnostic protocol lives in [sprint-planning.md](sprint-planning.md). GitHub resolves its bindings as follows.

| Binding                 | GitHub resolution                                                                                                                                                                                                                                                      |
|-------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Iteration container     | Milestone                                                                                                                                                                                                                                                              |
| Enumerate containers    | Aggregate distinct milestone objects from `mcp_github_search_issues` results per Milestone Discovery step 1, using milestone `due_on` as the window end. GitHub MCP exposes no milestone-list tool, so report that milestones with zero open issues are undiscoverable |
| Retrieve planned items  | `mcp_github_search_issues` scoped by `milestone:`                                                                                                                                                                                                                      |
| Retrieve unplanned work | `mcp_github_search_issues` with `no:milestone`                                                                                                                                                                                                                         |
| Effort field            | None natively. Report item counts and state the substitution, or read a team-defined size label when the caller names one                                                                                                                                              |
| Burndown fields         | None. Report open versus closed counts instead                                                                                                                                                                                                                         |
| Grouping field          | Labels, using the component dimension of the label taxonomy                                                                                                                                                                                                            |
| Assignment field        | `assignees`                                                                                                                                                                                                                                                            |
| Initial state           | An open issue carrying no triage label                                                                                                                                                                                                                                 |
| Tracking root           | `.copilot-tracking/github-issues/sprint/{{milestone-kebab}}/`                                                                                                                                                                                                          |

Two differences from a work-item tracker matter. GitHub has no native effort field, so capacity analysis reports counts unless the caller supplies a size-label convention; never infer story points from issue text. GitHub models hierarchy through sub-issues rather than a fixed four-level tree, so the hierarchy coverage matrix reports only the parent-child levels that sub-issues express, using the mapping in the PRD-to-Work-Item Planning section above.

A milestone has no start date. Derive the window from the previous milestone's close or from a caller-supplied start, and record which was used in `planning-log.md`.

## Human Review Triggers (GitHub additions)

Alongside the core triggers, pause when: the target `owner/repo` is unknown; org issue-type support is unclear after `mcp_github_list_issue_types`; a required label or milestone is not confirmed to exist; a close would use a `state_reason` that is not clearly supported; or a community-visible comment would post without a matching `community-interaction.instructions.md` scenario template.

Also pause when an issue already carries a security or vulnerability label, or when triage would add either label. Request user guidance before applying any mutation to that issue, including a label, milestone, comment, or close. Expedited processing is not approval: a priority or milestone rule never authorizes acting on a security issue on its own.
