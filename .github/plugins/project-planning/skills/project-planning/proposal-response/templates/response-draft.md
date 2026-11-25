---
title: Proposal Response Draft Template
description: Optional traceable internal-review response draft with qualifications and unresolved items.
---
<!-- markdownlint-disable-file -->

## Proposal Response Draft

* Response status: `internal_review_draft`
* External use status: `{{internal_review_only_or_external_use_prohibited}}`
* Release decision: `outside_skill_scope`
* Structural readiness: `{{not_ready_or_ready_for_internal_review}}` (advisory only)

Render one visible question record for every source question. For an unresolved question, show its source question, `UNR` state, and decision or evidence need instead of an unsupported draft response.

### Approved Sources

| Source ID  | Path     | Kind     | Version or date | Read date     | Sections used |
|------------|----------|----------|-----------------|---------------|---------------|
| {{SRC-ID}} | {{path}} | {{kind}} | {{version}}     | {{read-date}} | {{sections}}  |

### {{SQ-ID}}: {{Source Question}}

**Draft response**

{{response-text-supported-by-linked-claims}}

**Traceability**

* Source: {{source-reference}}
* Claims: {{CLM-IDs}}
* Evidence: {{approved-evidence-references}}
* Qualifications: {{qualifications-or-none}}
* Unresolved items: {{UNR-IDs-or-none}}

### Coverage

| Questions | Addressed | Qualified | Unresolved | Addressed percentage |
|-----------|-----------|-----------|------------|----------------------|
| {{count}} | {{count}} | {{count}} | {{count}}  | {{percentage}}       |

### Blocking Items

| ID         | Affected questions or claims | Need     | Human owner | Clearing action     |
|------------|------------------------------|----------|-------------|---------------------|
| {{UNR-ID}} | {{SQ-and-CLM-IDs}}           | {{need}} | {{owner}}   | {{clearing-action}} |

This draft is internal review material. Structural readiness does not grant approval, authorization, permission for external use, submission authority, or release authority.
