---
description: 'Template for a repository-original Architecture Review Record'
---
<!-- markdownlint-disable-file -->
# Architecture Review Record: {{review_title}}

## Review Identity and Confirmed Scope

* Review slug: `{{review_slug}}`
* Review date: `{{YYYY-MM-DD}}`
* System or decision under review: {{review_target}}
* Confirmed focus areas: {{focus_areas}}
* Review participants and decision owners: {{participants_and_owners}}

## Evidence Sources and Research Artifacts

| Evidence ID | Source or artifact                    | Evidence state             | Review use                 |
|-------------|---------------------------------------|----------------------------|----------------------------|
| {{E1}}      | {{workspace_relative_path_or_source}} | {{verified_or_unverified}} | {{decision_or_focus_area}} |

## Context, Constraints, and Assumptions

| ID        | Type                                          | Statement     | Evidence IDs | Status or owner            |
|-----------|-----------------------------------------------|---------------|--------------|----------------------------|
| {{CTX-1}} | {{verified-context_constraint_or_assumption}} | {{statement}} | {{E1}}       | {{verified_open_or_owner}} |

## Pillar Findings and Non-Findings

| Focus area or pillar | Disposition                          | Evidence IDs | Finding, non-finding, or unassessed limit | Priority                              |
|----------------------|--------------------------------------|--------------|-------------------------------------------|---------------------------------------|
| {{focus_area}}       | {{finding_no-finding_or_unassessed}} | {{E1}}       | {{analysis}}                              | {{high_medium_low_or_not-applicable}} |

## Options, Drivers, Trade-Offs, and Research Recommendation

### Decision Drivers

* {{driver}}

### Candidate Options

| Option     | Benefits     | Trade-offs     | Evidence IDs | Current disposition             |
|------------|--------------|----------------|--------------|---------------------------------|
| {{option}} | {{benefits}} | {{trade_offs}} | {{E1}}       | {{viable_selected_or_rejected}} |

### Research Recommendation

* Recommendation: {{evidence_backed_direction_or_no_supported_selection}}
* Evidence IDs: {{E1}}
* Confidence: {{high_medium_or_low}}
* Rejected-alternative rationale: {{rationale}}
* Unresolved trade-offs: {{trade_offs}}

## Reviewer Disposition

| Recommendation or field | Disposition                               | Rationale     | Decision owner |
|-------------------------|-------------------------------------------|---------------|----------------|
| {{recommendation}}      | {{accepted_revised_rejected_or_deferred}} | {{rationale}} | {{owner}}      |

## Recommendations and Priorities

| Priority               | Recommendation     | Evidence IDs | Owner     | Next action |
|------------------------|--------------------|--------------|-----------|-------------|
| {{high_medium_or_low}} | {{recommendation}} | {{E1}}       | {{owner}} | {{action}}  |

## Escalations and Human Decision Owners

| Escalation | Why human judgment is required | Decision owner | Required evidence or action |
|------------|--------------------------------|----------------|-----------------------------|
| {{item}}   | {{reason}}                     | {{owner}}      | {{evidence_or_action}}      |

## ADR Links

| Significant decision | ADR path                        | Status                  | Authority note                                             |
|----------------------|---------------------------------|-------------------------|------------------------------------------------------------|
| {{decision}}         | {{workspace_relative_adr_path}} | {{planned_or_recorded}} | The ADR and its human decision owner remain authoritative. |

## Limits and Unassessed Areas

* {{blocked_evidence_unassessed_scope_or_other_limit}}
