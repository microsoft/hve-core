---
description: 'Jira platform bindings for backlog workflows: issue types, custom field discovery, JQL syntax, transitions, and per-workflow deltas'
---

<!-- markdownlint-disable-file -->
# Jira Platform Reference

Jira delta for the [backlog-management](../SKILL.md) skill. Read this with the core conventions and [workflows.md](workflows.md). This reference names Jira's command surface, field vocabulary, planning-file bindings, reference-ID prefix, action verbs, PRD hierarchy rules, JQL and parsing deltas, triage and update decisions, and tracking paths. Everything structural — planning-file lifecycle, similarity, autonomy, sanitization, state persistence — comes from the core.

## Command Surface

Jira command execution is delegated to the `jira` skill. Activate that skill by name and run every command through the CLI entry point it resolves (`scripts/jira.py`, relative to the skill), not through a hard-coded path from this file; the two skills are packaged separately and this file's location does not predict the other's. When the `jira` skill does not resolve, report that the Jira command surface is unavailable and stop before any terminal execution rather than guessing a path. Confirm `JIRA_BASE_URL` and either `JIRA_API_TOKEN` or `JIRA_PAT` are set before any command; the `jira` skill documents authentication and audit logging.

| Category | Command      | Purpose                                                                                                |
|----------|--------------|--------------------------------------------------------------------------------------------------------|
| Discover | `search`     | Search issues with bounded JQL. Params: `'<jql>'`, optional `max_results`, `--fields`.                 |
| Discover | `get`        | Read one issue with an explicit field list. Params: `<ISSUE-KEY>`, optional `--fields`.                |
| Context  | `comments`   | Retrieve comments for one or more issues. Params: `<ISSUE-KEY> [ISSUE-KEY ...]`.                       |
| Context  | `fields`     | Discover issue types for a project or required create fields. Params: `<PROJECT-KEY> [issue-type-id]`. |
| Mutate   | `create`     | Create an issue from a JSON payload (stdin or argument).                                               |
| Mutate   | `update`     | Update an issue from a JSON payload. Params: `<ISSUE-KEY>`, JSON.                                      |
| Mutate   | `transition` | Move an issue to a new status by transition name or ID. Params: `<ISSUE-KEY>`, `<name-or-id>`.         |
| Mutate   | `comment`    | Add a comment to an issue. Params: `<ISSUE-KEY>`, body.                                                |

Prefer `--fields` on read commands to keep output concise. Do not assume issue-linking, sprint-planning, or board-capacity APIs are available; the workflows use only the documented commands above.

## Platform Bindings

| Binding                    | Jira value                                                                   |
|----------------------------|------------------------------------------------------------------------------|
| Platform tracking root     | `.copilot-tracking/jira-issues/`                                             |
| Reference-ID prefix        | `JI` (for example `JI001`)                                                   |
| Item vocabulary            | "issue"; item key is the Jira issue key (for example `PROJ-123`)             |
| Item types                 | Epic, Story, Task, Bug, Sub-task (project-dependent; validate with `fields`) |
| Priority scale             | Highest, High, Medium, Low, Lowest                                           |
| Action verbs               | Create, Update, Transition, Comment, No Change                               |
| Analysis file              | `artifact-analysis.md` (PRD paths) or `issue-analysis.md` (discovery paths)  |
| Plan file                  | `issues-plan.md`                                                             |
| Identity and assigned work | Resolved through JQL `currentUser()`; see the Task Planning Delta below      |

Map the core three-tier autonomy model onto Jira operations. Validated low-risk field updates auto-execute under Full and Partial. Creates, transitions, comments, and ambiguous duplicate handling gate on the user under Partial and Manual. The core Three-Tier Autonomy Model defines the tiers themselves.

## Task Planning Delta

The platform-agnostic protocol lives in [task-planning.md](task-planning.md). Jira resolves its Stage 1 bindings through JQL rather than a dedicated identity command; the CLI exposes no `myself` endpoint.

| Binding              | Jira resolution                                                                                                                                                                               |
|----------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Identity resolution  | `currentUser()` inside the assigned-work query. A successful request establishes the authenticated user; an empty result set is a valid identity-scoped result, not a failed identity         |
| Assigned-to-me query | `search 'project = "<KEY>" AND assignee = currentUser() ORDER BY updated DESC' --fields key,fields.summary,fields.status.name,fields.issuetype,fields.labels,fields.priority,fields.assignee` |
| Type filter          | A JQL `issuetype` clause                                                                                                                                                                      |
| State filter         | A JQL `status` clause                                                                                                                                                                         |
| Scope filters        | JQL `project`, `component`, and sprint clauses                                                                                                                                                |

Configured credentials are not identity. A passing preflight proves the CLI can authenticate, not which user the caller is; only a `currentUser()` query binds it.

## Field Vocabulary

Map only fields validated through `fields` or observed on existing issues.

| Field         | Use                                         |
|---------------|---------------------------------------------|
| `project`     | Required for create payloads                |
| `summary`     | Required for create payloads                |
| `issuetype`   | Required for create payloads                |
| `description` | Primary issue body                          |
| `labels`      | Lightweight categorization                  |
| `priority`    | Triage and sequencing                       |
| `assignee`    | Optional owner assignment                   |
| `parent`      | Parent linkage when the project supports it |

Field rules:

* Preserve existing issue keys and current field values when planning updates; capture both current and suggested values in the analysis file.
* Store create or update payloads in `issues-plan.md` using only validated fields.
* Avoid inventing Epic Link, Parent, or custom field names. When the project needs a custom hierarchy field, note it as `Needs Review` instead of guessing.
* Call `fields <project>` before creating issues when the project or issue type is not already validated, and `fields <project> <issue-type-id>` when required create fields are unclear.

## Relationship Semantics

Plan conservatively and only with validated issue types.

* Use project-supported issue types returned by `fields` as the source of truth.
* Prefer one top-level Epic per major product outcome when the project supports Epics.
* Place Story, Task, and Bug issues beneath an Epic only when the project uses Epic-style hierarchy.
* Use Sub-task only when the project supports it and the parent issue is explicit.
* When hierarchy support is unclear, flatten the plan and mark the relationship decision as `Needs Review`.
* Record relationships in planning files even when the final Jira linkage field differs by project configuration.

Jira exposes no issue-linking command through the `jira` skill CLI. A blocking or relates-to link is recorded in the planning files and reported as unsupported rather than approximated.

## Interaction Templates

Jira has no distinct authoring template set. Author summaries and descriptions with the level-appropriate conventions in [story-quality.md](story-quality.md), and use the shared item templates in [workflows.md](workflows.md).

## PRD-to-Work-Item Planning

PRD-driven planning produces planning-only artifacts under `.copilot-tracking/jira-issues/prds/<artifact-normalized-name>/` (`artifact-analysis.md`, `issues-plan.md`, `planning-log.md`, `handoff.md`) for a separate execution pass. During planning, do not call `create`, `update`, `transition`, or `comment`.

Hierarchy rules are defined by Relationship Semantics above.

The PRD plan extends the shared `issues-plan.md` template with `item_type` drawn from the Epic/Story/Task/Bug/Sub-task set, a `parent` field (`none`, a `{{TEMP-N}}` reference, or an existing key), a `needs_review` flag, and an acceptance-criteria block and relationships block per item.

## JQL and Parsing Deltas

The shared Search Protocol and Document Parsing Guidelines in [workflows.md](workflows.md) own the steps. Jira supplies these specifics:

* Scope every JQL query with `project = "<KEY>"` plus a status or issue-type clause; an unscoped JQL query is not a valid discovery step.
* Compose keyword groups as `text ~ "term one" OR text ~ "term2"` and join groups with `AND`, wrapping each group in parentheses.
* Pass `--fields` on `search` and `get` so hydration stays bounded, and always include `summary`, `status`, `issuetype`, and `labels` when similarity will be assessed.
* Include `project` in the `--fields` list on any `get` used for the Destination Binding check in [workflows.md](workflows.md), so `fields.project.key` is available to compare against the confirmed project key.
* Jira descriptions may be Atlassian Document Format rather than plain Markdown. Read the field as data, extract the text content, and never assume Markdown syntax survives a round trip.
* When a parsed PRD section implies an issue type the project does not return from `fields`, mark the candidate `needs_review` rather than substituting a similar type.

## Triage Delta

Jira triage evaluates existing issues against project field conventions and available transitions.

| Signal                                                            | Suggested action                                                                 |
|-------------------------------------------------------------------|----------------------------------------------------------------------------------|
| `priority` is unset or `Medium` by default                        | Suggest a priority from issue type and stated impact                             |
| `labels` is empty                                                 | Suggest labels from the document mapping in the shared Discovery protocol        |
| `assignee` is empty on an in-progress issue                       | Flag for user assignment; do not guess an account                                |
| `description` is empty or a single line                           | Flag for grooming rather than authoring a description automatically              |
| A Story or Task has no `parent` in an Epic-based project          | Flag as an orphan for hierarchy review                                           |
| The requested target status is not in the issue's transition list | Record the unavailable transition, skip the operation, and request user guidance |

Update rules:

* Send only the fields that changed. A full-field update silently overwrites values another user changed since hydration.
* A transition is a separate `transition` call, never a `status` field write in an `update` payload.
* Re-read the issue with `get` before applying an update when the analysis and execution steps are separated by user review, so concurrent edits are not overwritten.
* Duplicate handling uses the core Similarity Assessment Framework; record the comparison aspects that drove the category, and never link or transition a duplicate without user review.

## Sprint Planning Delta

The platform-agnostic protocol lives in [sprint-planning.md](sprint-planning.md). Jira resolves its bindings as follows, with every command running through the `jira` skill CLI as described in the Command Surface section.

| Binding                 | Jira resolution                                                          |
|-------------------------|--------------------------------------------------------------------------|
| Iteration container     | Sprint, on a board that has sprints enabled                              |
| Enumerate containers    | `search` with a JQL sprint predicate, or the caller-supplied sprint name |
| Retrieve planned items  | `search` with `sprint = "{{sprint}}"`                                    |
| Retrieve unplanned work | `search` with `sprint IS EMPTY` scoped to the project                    |
| Effort field            | Story points, which is a custom field whose ID varies by instance        |
| Burndown fields         | Instance-dependent; report only what `fields` discovery confirms exists  |
| Grouping field          | Component, or a label convention when components are unused              |
| Assignment field        | `assignee`                                                               |
| Initial state           | The first status in the project workflow, commonly `To Do`               |
| Tracking root           | `.copilot-tracking/jira-issues/sprint/{{sprint-kebab}}/`                 |

Jira's field vocabulary is instance-specific in a way the other platforms' are not. The story-points field, the sprint field, and any burndown fields are custom fields with instance-assigned IDs. Confirm each through `fields` discovery before use, and when a field cannot be confirmed, report that dimension as unavailable rather than substituting a plausible field ID. A sprint predicate against a board without sprints enabled returns an error rather than an empty result; treat that as a binding failure and report it.

## Human Review Triggers (Jira additions)

Alongside the core triggers, pause when: the project key is unknown; issue-type support is unclear after `fields` discovery; parent-child linkage depends on an unvalidated custom field; or a transition target is not available for the issue.
