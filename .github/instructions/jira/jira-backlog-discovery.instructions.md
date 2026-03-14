---
description: 'Discovery protocol for Jira backlog management with user-centric, artifact-driven, and JQL-based issue discovery'
applyTo: '**/.copilot-tracking/jira-issues/discovery/**'
---

# Jira Backlog Discovery

Discover Jira issues through three paths: user-centric queries, artifact-driven analysis, or JQL-based exploration. Follow `jira-backlog-planning.instructions.md` for templates, field definitions, and state persistence rules.

## Scope

Discovery path selection:

* User-centric (Path A): User requests assigned work or backlog visibility without referencing artifacts
* Artifact-driven (Path B): Documents, PRDs, or requirements are provided for translation into Jira issues
* JQL-based (Path C): User provides JQL or search terms directly without artifacts

Output location: `.copilot-tracking/jira-issues/discovery/<scope-name>/`.

## Deliverables

| File                   | Path A | Path B | Path C |
|------------------------|--------|--------|--------|
| `planning-log.md`      | Yes    | Yes    | Yes    |
| `issue-analysis.md`    | No     | Yes    | No     |
| `issues-plan.md`       | No     | Yes    | No     |
| `handoff.md`           | No     | Yes    | No     |
| Conversational summary | Yes    | Yes    | Yes    |

Paths A and C produce a conversational summary with counts and relevant issue keys. Path B produces the full set of planning files.

## Tooling

Use the Jira skill through `.github/skills/jira/jira/scripts/jira.py`.

* Path A: `search`, `get`, optional `comments`
* Path B: `search`, `get`, `fields`, optional `comments`, plus workspace file reads
* Path C: `search`, `get`, optional `comments`

## Required Phases

### Phase 1: Discover Issues

#### Path A: User-Centric Discovery

Use when the user asks for assigned work, current backlog visibility, or project-specific issue lists without source documents.

Execution:

1. Build a bounded JQL query. Prefer `project = <project> AND assignee = currentUser() ORDER BY updated DESC` when a project key is available.
2. Execute `search` and hydrate selected issues with `get`.
3. When comment context matters, retrieve comments with `comments`.
4. Create the planning folder and initialize `planning-log.md`.
5. Log discovered issues and deliver a conversational summary.
6. Skip Phases 2 and 3.

#### Path B: Artifact-Driven Discovery

Use when documents or requirements are provided.

Execution:

1. Create the planning folder.
2. Read each document to completion and extract discrete requirements, acceptance criteria, and action items.
3. When the project key is known, call `fields <project>` to verify issue types and required create fields.
4. Record each extracted requirement as a candidate issue in `issue-analysis.md`.
5. Build bounded JQL search queries from the extracted requirements.
6. Execute `search` for each query and hydrate strong matches with `get`.
7. Assess similarity using the framework in the planning specification.
8. Log all progress in `planning-log.md`.
9. Continue to Phase 2.

##### Document Parsing Guidance

Map document patterns to Jira issue suggestions.

| Document Type | Content Pattern     | Suggested Issue Type | Suggested Label |
|---------------|---------------------|----------------------|-----------------|
| PRD           | Feature requirement | Story or Task        | `feature`       |
| BRD           | Business need       | Story                | `enhancement`   |
| ADR           | Implementation task | Task                 | `maintenance`   |
| RFC           | Proposed capability | Story                | `feature`       |
| Security plan | Remediation item    | Bug or Task          | `security`      |

When a document section contains acceptance criteria, include them in the candidate issue body as a markdown checklist.

#### Path C: JQL-Based Discovery

Use when the user provides JQL or plain-language search terms.

Execution:

1. Use the provided JQL directly, or convert the search terms into bounded JQL using project, status, assignee, labels, or text clauses.
2. Execute `search` and hydrate selected results with `get`.
3. When comment context matters, retrieve comments with `comments`.
4. Create the planning folder and initialize `planning-log.md`.
5. Log discovered issues and deliver a conversational summary.
6. Skip Phases 2 and 3.

### Phase 2: Plan Issues

Apply to artifact-driven discovery only.

#### Similarity-Based Actions

| Category  | Action                                                        |
|-----------|---------------------------------------------------------------|
| Match     | Plan an Update, Transition, or No Change based on field drift |
| Similar   | Flag for user review with a comparison summary                |
| Distinct  | Plan as a new issue                                           |
| Uncertain | Request user guidance before proceeding                       |

#### New Issue Construction

* Populate acceptance criteria as markdown checkbox lists when extracted from documents.
* Use `{{TEMP-N}}` placeholders for issues not yet created.
* Keep issue payloads within the validated Jira field set for the target project and issue type.

#### Existing Issue Handling

* Match: Plan an Update or Transition action when the issue needs refinement.
* Covered by current issue with no required mutation: Set action to No Change.
* Needs coordination only: Plan a Comment action.

Record all planned operations in `issues-plan.md`.

### Phase 3: Assemble Handoff

Apply to artifact-driven discovery only.

1. Build `handoff.md` using the planning template.
2. Order operations as Create, Update, Transition, Comment, No Change.
3. Include planning file references and autonomy mode.
4. Verify consistency across planning files.
5. Present the handoff for user review.
6. Record phase completion in `planning-log.md`.

## Human Review Triggers

Pause and request user guidance when:

* Requirements are ambiguous or contradictory.
* Multiple existing issues partially match one candidate.
* The project key or issue type for a new issue is not confirmed.
* The similarity assessment returns Uncertain.
* A planned transition target has not been validated.

## Cross-References

These sections in `jira-backlog-planning.instructions.md` inform discovery operations:

| Section                         | Used In    | Purpose                                              |
|---------------------------------|------------|------------------------------------------------------|
| Jira Command Catalog            | All phases | Command selection and constraints                    |
| Similarity Assessment Framework | Phases 1-2 | Candidate-to-existing issue classification           |
| Planning File Templates         | Phases 1-3 | Output file structure                                |
| Content Sanitization Guards     | Phases 2-3 | Strip local planning references from Jira-bound text |
| Three-Tier Autonomy Model       | Phase 3    | Confirmation gates during handoff review             |
| State Persistence Protocol      | All phases | Workflow resumption                                  |
| Human Review Triggers           | Phase 3    | Conditions that require user guidance                |

---

Brought to you by microsoft/hve-core