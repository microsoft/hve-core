---
name: code-review-standards
description: 'Review assigned changes against applicable repository instructions and domain skills, preserving criterion provenance. Use for Code Review standards work.'
license: CC-BY-4.0
user-invocable: false
---

# Standards review

## Goal

Identify consequential departures from the project's actual conventions.
Use `code-review-core`, activating it when not preloaded.

## Criteria and provenance

Read applicable repository instructions and select available skills by changed
language, framework, or literal file type. Keep each source's name, location or
origin label, applicable scope, and criterion together. Do not infer provenance
from prose.

For duplicate skill names, prefer identifiable Workspace, then User, then Bundled
sources. If origin is unknown, load one and disclose the ambiguity rather than
combining conflicting bodies. Load distinct matches needed for the changed
surface; there is no fixed skill-count cap. Apply instruction precedence and
record unresolved conflicts with both sources.

## Review

Assess structure, naming, typing, ownership, maintainability, and documentation
against the selected criteria and established local patterns. Cite the applicable
instruction or exact skill name and criterion in every finding. Preference alone
is insufficient. Explain the consequence of a departure rather than grading
unrelated style. Functional defects belong to functional review.

Review production telemetry emitters using `telemetry-foundations` and its
applicable semantic-convention references. Do not invent telemetry names.
Acceptance-criteria coverage belongs to the parent's designated owner; avoid
grading it again here.

## Completion

Record each applied criterion and its provenance in the result observations.
No applicable criteria means unavailable standards evidence, not a standards
pass. Stop blocked for a material criteria conflict that the parent must resolve.
