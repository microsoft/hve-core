---
description: Human-readable register of ontology lifecycle decisions
---

# Decision Register: {{project_name}}

Render each row from state `decisions` without changing its status or rationale.

| Decision ID     | Status                                       | Statement     | Rationale     | Decided by and role      | Decided at             | Evidence                                          |
|-----------------|----------------------------------------------|---------------|---------------|--------------------------|------------------------|---------------------------------------------------|
| {{decision_id}} | {{proposed_accepted_rejected_or_superseded}} | {{statement}} | {{rationale}} | {{contributor_and_role}} | {{ISO_8601_timestamp}} | {{evidence_document_and_source_node_ids_or_none}} |

## Supersession

| Superseded decision ID  | Replacing decision ID   | Reason                       |
|-------------------------|-------------------------|------------------------------|
| {{decision_id_or_none}} | {{decision_id_or_none}} | {{reason_or_not_applicable}} |