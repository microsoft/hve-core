---
description: Human-readable Research, Design, and Implement gate approval record
---

# Approval Register: {{project_name}}

| Approval ID     | Gate                             | Status                                 | Approver and role                   | Rationale                | Decided at                        | Input digests     |
|-----------------|----------------------------------|----------------------------------------|-------------------------------------|--------------------------|-----------------------------------|-------------------|
| {{approval_id}} | {{research_design_or_implement}} | {{pending_approved_rejected_or_stale}} | {{contributor_and_role_or_pending}} | {{rationale_or_pending}} | {{ISO_8601_timestamp_or_pending}} | {{sha256_values}} |

## Gate State

| Gate                             | Status                                 | Approval ID             | Downstream invalidated | Invalidation reason and time              |
|----------------------------------|----------------------------------------|-------------------------|------------------------|-------------------------------------------|
| {{research_design_or_implement}} | {{pending_approved_rejected_or_stale}} | {{approval_id_or_none}} | {{true_or_false}}      | {{reason_and_ISO_8601_timestamp_or_none}} |

## Deploy Handoff

* Status: {{deferred_or_ready}}
* Target: 033 Fabric Ontology Edge AI Agent