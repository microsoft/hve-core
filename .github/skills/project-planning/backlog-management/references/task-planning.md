---
description: 'Two-stage assigned-work retrieval and enrichment into an implementation-ready handoff, with a per-platform binding table'
---

<!-- markdownlint-disable-file -->
# Task Planning

Platform-agnostic protocol for turning a set of assigned work items into an implementation-ready handoff. Read this alongside the [core conventions](../SKILL.md), the [workflow protocols](workflows.md), and the active platform reference. Every command and field named below is a platform binding; resolve it through the platform reference before use.

This workflow is distinct from Discovery. Discovery turns requests and artifacts into candidate work items; task planning takes items that already exist and are already assigned, enriches them with repository context, and produces a handoff another workflow can research and implement from. It runs in two stages that can be invoked separately: retrieve, then enrich.

## Stage 1: Retrieve Assigned Work

Retrieve the items assigned to the current user, scoped by whatever filters the caller supplies.

### Step 1: Resolve identity and scope

Establish the authenticated user through the platform's identity binding, then apply the caller's filters. A platform that cannot resolve an authenticated identity cannot run this workflow; report that rather than falling back to an unfiltered query.

| Binding              | Resolve through the platform reference                         |
|----------------------|----------------------------------------------------------------|
| Assigned-to-me query | The platform's "my work" or assignee-scoped search             |
| Identity resolution  | The command that establishes the authenticated user            |
| Type filter          | The platform's item-type vocabulary                            |
| State filter         | The platform's workflow states                                 |
| Scope filters        | The platform's area, iteration, repository, or project scoping |

### Step 2: Hydrate

Retrieve full field detail for every item returned. Assignee-scoped queries return sparse items on every supported platform, so hydration is mandatory rather than an optimization.

### Step 3: Write planning files

Create the standard planning structure under the platform tracking root using the planning type the caller supplies, defaulting to `current-work`, and the scope name `my-assigned-work-items`. Use the analysis, plan, and log templates from [workflows.md](workflows.md), resolving the platform bindings.

When the planning files already exist, confirm with the user before replacing them. On confirmation, replace them; otherwise continue in the existing files. Never silently overwrite prior planning work.

### Error handling

* Failed retrieval of an individual item: surface the error and continue with the remaining items.
* Missing fields: record the gap in the planning files rather than inferring a value.
* Empty results: create the planning structure and record that no items are assigned. An empty result is a valid outcome, not a failure.

## Stage 2: Enrich for Handoff

Enrich the retrieved items with repository context and produce the handoff record.

### Step 1: Load and validate

Read the planning files from the target directory. When they are missing, direct the user to run Stage 1 first rather than re-deriving the item set from the tracker, because the planning files may carry user edits the tracker does not have.

### Step 2: Select the top recommendation

Apply the first rule that matches:

1. An explicitly supplied item identifier, when it is valid.
2. The item with the highest density of caller-supplied boost tags.
3. The first item in priority or stack-rank order.

### Step 3: Gather repository context

For each item, use semantic search and file analysis to identify related code. Capture the most relevant files with the rationale for each, key functions, classes, and integration points, configuration touchpoints and data dependencies, and connections to related items with the reason for the relationship.

Depth follows position: the top recommendation carries up to ten files, each additional item up to five.

### Step 4: Integrate item discussion

Retrieve comments or discussion for each item through the platform's comment binding.

Retain only materially useful content: problems, decisions, deployments, errors and stack traces, metrics, and blockers. Skip social, duplicate, and bot noise unless it carries unique technical detail. Preserve exact error strings and file or configuration names rather than paraphrasing them, because a paraphrased stack trace is not searchable.

Format each retained unit as a bullet beginning `Author - YYYY-MM-DD:`, split multi-topic comments into separate bullets, and order ascending by timestamp. Omit the section entirely when nothing is retained.

### Step 5: Write the handoff

Generate `task-planning-logs.md` in the planning directory and update `planning-log.md` with progress and discoveries.

Each item section carries:

* **Metadata** — identifier, type, title, state, priority, rank, parent relationships, tags, assignee, and last-changed date, resolved through the platform's field vocabulary.
* **Context analysis** — a two-to-five sentence narrative of intent and desired outcome, the description and acceptance criteria, and an assessment of blockers, risks, and current state.
* **Repository integration** — the ranked files with rationale, related patterns and codebase areas, key functions and integration touchpoints, configuration and data dependencies, and related-item connections.
* **Research seeds** — objective, unknowns, candidate files, risks, and immediate next steps.

### Resumable behavior

When `task-planning-logs.md` already exists, parse its existing sections to determine which items are already processed. Append only the missing items, preserve existing content and section order, never duplicate an item section, and update the progress summary. This mirrors the core State Persistence Protocol.

### Error handling

* Missing planning directory: direct the user to Stage 1.
* Invalid planning-file format: surface the specific validation error rather than proceeding on a partial parse.
* Repository context failure: continue with the planning-file information available and record the gap.
* Platform API failure: log the failure and proceed with offline analysis from the planning files.

## Output

### task-planning-logs.md structure

Planning markdown files start and end with the directives defined in the Planning File Requirements section of the core skill.

```markdown
<!-- markdownlint-disable-file -->
<!-- markdown-table-prettify-ignore-start -->
# Work Items - Task Planning Handoff ({{YYYY-MM-DD}})

## Top Recommendation - {{reference_id}} ({{item_type}})

### Summary

{{narrative_summary}}

### Metadata

{{metadata_block}}

### Repository Context

{{ranked_files_with_rationale}}

### Discussion

{{retained_comment_units}}

### Research Seeds

* Objective: {{objective}}
* Unknowns: {{unknowns}}
* Candidate files: {{candidate_files}}
* Risks: {{risks}}
* Next steps: {{next_steps}}

## Additional Handoffs

### {{reference_id}} - {{title}}

{{condensed_sections}}

## Progress Summary

Processed: {{x}} / Total: {{y}}
Top recommendation: {{reference_id}}
Additional items: {{reference_ids}}

## Handoff Payload

* Planning directory: {{planning_dir}}
* Platform: {{platform}}
* Top recommendation: {{reference_id}}
* All processed: {{reference_ids}}
* Processing date: {{YYYY-MM-DD}}
<!-- markdown-table-prettify-ignore-end -->
```

The handoff payload is deliberately terse and machine-readable so a downstream research or planning workflow can consume it without parsing prose.
