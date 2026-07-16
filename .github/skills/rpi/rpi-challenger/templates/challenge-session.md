---
description: "Challenge session record template for rpi-challenger"
---
<!-- markdownlint-disable-file -->

# Challenge Session: {{task_slug}}

## Session Details

| Field        | Value                                                                  |
|--------------|------------------------------------------------------------------------|
| Date         | {{YYYY-MM-DD}}                                                         |
| Status       | {{In progress \| Complete \| Partial \| Blocked}}                      |
| Record path  | .copilot-tracking/challenges/{{YYYY-MM-DD}}/{{task_slug}}-challenge.md |
| Scope source | {{caller-supplied targets, context, or bounded inspection}}            |
| Focus        | {{caller-supplied focus or none}}                                      |

## Confirmed Scope

* Subject: {{confirmed subject}}
* Boundary: {{included and excluded material}}
* Confirmation: {{user confirmation}}
* Evidence basis: {{facts, artifacts, or inspection used to form scope}}

## Related Artifacts

| Artifact                            | Relationship to the challenge   | Evidence used      |
|-------------------------------------|---------------------------------|--------------------|
| {{workspace-relative path or none}} | {{scope, context, or evidence}} | {{material facts}} |

## Challenge Coverage

| Angle or topic     | Material uncertainty examined                   | Status                                                | Notes              |
|--------------------|-------------------------------------------------|-------------------------------------------------------|--------------------|
| {{adaptive label}} | {{assumption, boundary, evidence, or decision}} | {{explored \| unresolved \| skipped \| out of scope}} | {{concise result}} |

## Q&A Log

### {{challenge topic}}

Question:

{{focused open-ended question}}

Answer:

{{claim-bearing user language, with nonmaterial wording condensed}}

Record note:

{{evidence basis, follow-up rationale, or coverage update}}

## Unresolved Items

| Item                       | Why unresolved            | Smallest missing evidence or decision | Suggested next owner                                                 |
|----------------------------|---------------------------|---------------------------------------|----------------------------------------------------------------------|
| {{assumption or decision}} | {{remaining uncertainty}} | {{specific evidence or decision}}     | {{user, rpi-research, rpi-plan, rpi-implement, rpi-review, or none}} |

## Session Outcome

* Coverage summary: {{topics explored and material conclusions}}
* Unresolved items: {{count or none}}
* Advisory next options: {{user-controlled options or none}}
