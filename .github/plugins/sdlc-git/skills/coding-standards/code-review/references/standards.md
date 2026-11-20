---
description: 'Standards review reference for Code Review covering repository instructions, language/domain skills, and criterion provenance under the functional vector.'
---

# Standards review

## Goal

Identify consequential departures from the project's actual coding conventions and domain standards as part of the `functional` review vector. Follow [review-contract.md](review-contract.md).

## Criteria and provenance

Read applicable repository instruction files and select available coding-standards or language skills by changed language, framework, or literal file type. Keep each source's name, location or origin label, applicable scope, and criterion together. Do not infer provenance from prose, and do not load non-functional specialist skills (`security-planning`, `privacy-by-design`, `supply-chain-security`, `rai-standards`, `performance-slo-planner`, `accessibility`) here.

For duplicate skill names, prefer identifiable Workspace, then User, then Bundled sources. If origin is unknown, load one and disclose the ambiguity rather than combining conflicting bodies. Load distinct matches needed for the changed surface without an arbitrary cap. Apply instruction precedence and record unresolved conflicts with both sources.

## Review

Assess structure, naming, typing, ownership, maintainability, and inline documentation against the selected criteria and established local patterns. Cite the applicable instruction or exact skill name and criterion in every finding (`criterion` field). Personal preference alone is insufficient; explain the concrete consequence of each departure.

Review production telemetry emitters using `telemetry-foundations` and its applicable semantic-convention references without inventing telemetry names. Leave behavioral bug grading and acceptance-criteria tables to `functional`.

## Completion

Record each applied criterion source and its provenance in `observations`. When no instructions or skills apply to the assigned files, return `execution: "unavailable"` with a limitation rather than claiming a standards pass. Stop `blocked` on a material criteria conflict that the orchestrating agent must resolve.
