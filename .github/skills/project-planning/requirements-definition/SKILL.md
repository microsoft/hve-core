---
name: requirements-definition
description: 'Unified requirements-definition vocabulary, formats, and quality rubrics for the BRD Builder workflow - FR/NFR/CON taxonomy and canonical statement form, Given/When/Then and alternative acceptance-criteria formats with an original CC BY 4.0 atomicity checklist, ISO 29148 §5.2.5 individual-requirement 0-3 scoring, ISO/IEC 25010 NFR category presence (DD-12), SMART business-goal rubric (DD-08), and ISTQB testability heuristics, all cited by name without redistributing third-party text - Brought to you by microsoft/hve-core'
license: CC-BY-4.0
---

# Requirements Definition — Skill Entry

## Overview

This skill is the single requirements-definition bundle the BRD Builder loads whenever it captures, classifies, articulates, or scores requirements during the Discover and Define phases. It unifies three responsibilities that previously lived in separate skills:

* Requirement vocabulary - three requirement categories (functional, non-functional, constraint) and the canonical statement form used before an identifier is assigned.
* Acceptance-criteria authoring - Given/When/Then as the default format, the accepted alternative formats, and an original Microsoft atomicity checklist (CC BY 4.0) applied to every criterion.
* Quality assessment - the three Define-phase rubrics (ISO 29148 §5.2.5 0-3 individual-requirement scoring, ISO/IEC 25010 NFR category presence per DD-12, SMART business-goal rubric per DD-08) plus ISTQB testability heuristics.

The skill is consumed by:

* the `brd-author` skill (template population, Define-phase rewriting, per-partition acceptance-criteria sections, and self-scoring);
* the `brd-standard-assessor` subagent (plan-mode rubric at Define exit, mid-Define on demand, and post-Govern drift detection);
* the BRD-phase instruction files for Discover, Define, and Govern.

This file is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The atomicity checklist in `references/atomicity-checklist.md` is also original Microsoft content under CC BY 4.0. External frameworks listed in the [cite-only registry](#cite-only-registry) are referenced by name and clause or section only; their prose is not embedded.

## When to Apply

Apply this skill in the following situations:

* Capturing or restating a business goal, stakeholder need, or proposed feature inside a BRD draft.
* Classifying an existing requirement as functional, non-functional, or constraint before assigning an identifier.
* Rewriting a candidate requirement into the [canonical statement form](#canonical-statement-form), or splitting a compound statement into atomic requirements.
* Deciding whether a candidate requirement belongs in the BRD or should be deferred to the downstream PRD.
* Writing or reviewing acceptance criteria for any captured requirement, or translating a stakeholder's free-form success statement into a structured triplet or equivalent format.
* Generating per-partition acceptance-criteria sections inside a Govern-phase work-item payload (`WI-BRD-{NNN}` for ADO, `{{BRD-TEMP-N}}` for GitHub).
* Scoring a BRD draft against the nine ISO 29148 §5.2.5 individual-requirement characteristics ahead of the Define → Govern gate.
* Checking that every ISO/IEC 25010 quality characteristic is represented by at least one NFR before exiting Define (per DD-12).
* Refining a Discover-phase business-goal draft into a SMART goal during Define (per DD-08).
* Asking whether a requirement is testable, and if not, what minimum information would make it testable (per ISTQB testability).
* Producing the combined quality score the `brd-standard-assessor` subagent emits in `BRD_STANDARD_FINDINGS_V1`.

## Requirement Categories

The BRD Builder partitions every captured requirement into one of three top-level categories. Identifier prefixes are owned by the [`traceability-naming`](../traceability-naming/SKILL.md) skill.

### Functional Requirement (FR)

A statement of what the solution must do. Functional requirements describe observable behaviors, transformations, or services the solution exposes to a stakeholder or another system.

* Subject: the solution (or a named component of it).
* Verb: an active verb describing the behavior (calculate, route, notify, persist, authorize).
* Object: the data or entity the behavior acts on.
* Conditions: the triggering event, precondition, or input range under which the behavior applies.

Functional requirements are testable through observation of solution behavior. If a candidate cannot be expressed as a verifiable behavior, it is not a functional requirement and is reclassified as a non-functional requirement, a constraint, or a goal.

### Non-Functional Requirement (NFR)

A statement of how well the solution must perform a behavior, or what quality attribute it must exhibit. Non-functional requirements describe properties of the solution rather than specific behaviors.

Quality attribute families the BRD Builder recognizes:

* Performance (latency, throughput, capacity).
* Availability and reliability (uptime targets, recovery objectives, fault tolerance).
* Security (authentication, authorization, confidentiality, integrity, auditability).
* Privacy (data minimization, consent, retention, residency).
* Usability and accessibility (task completion rates, WCAG conformance level).
* Maintainability and operability (change effort, observability, deployability).
* Portability and interoperability (target platforms, standard data formats).
* Compliance (regulatory regime, certification, evidence retention).

Each non-functional requirement must include a measurable threshold or target value. Statements without a threshold ("the system shall be fast") are flagged by the quality rubric as ambiguous and rewritten.

### Constraint (CON)

A condition on the solution or its delivery that is imposed from outside the requirements-engineering activity and is not negotiable within the BRD scope. Constraints differ from non-functional requirements: they are imposed, not derived.

Common constraint origins:

* Regulatory or contractual obligation (data residency, certification, audit retention).
* Pre-existing organizational standard (approved language, runtime, cloud, identity provider).
* Integration with a fixed external system (protocol, schema, SLA).
* Budget, timeline, or staffing boundary recorded as in-scope for the BRD.

Constraints are stated in the present tense and identify the imposing source so downstream readers can validate whether the source remains in force.

## Canonical Statement Form

Every requirement captured by the BRD Builder is rewritten into the canonical form before it is assigned an identifier. The form has four positions:

1. Subject - the solution or a named component.
2. Modal verb - `shall` for binding statements, `should` for preferences, `may` for permissions. The BRD Builder emits `shall` by default and surfaces lower modality only when the stakeholder confirms it.
3. Behavior or property - the action (for FR) or measurable property (for NFR).
4. Condition - the triggering event, precondition, or applicable scope.

Each requirement is atomic: one subject, one behavior or property, one condition. Compound statements joined by `and`, `or`, or `,` are split into multiple requirements during Define-phase rewriting.

Each requirement carries:

* a stable identifier owned by [`traceability-naming`](../traceability-naming/SKILL.md);
* a rationale linking it back to the originating business goal or stakeholder need;
* a verification approach owned by the [Acceptance Criteria](#acceptance-criteria) section below.

## Acceptance Criteria

Acceptance criteria attach a verification approach to each captured requirement. The BRD Builder uses one default format and accepts a small set of alternatives; every criterion must satisfy the [atomicity checklist](#atomicity).

### Default Format - Given/When/Then

The BRD Builder emits acceptance criteria in [Given/When/Then](references/given-when-then.md) (Gherkin) form by default. Each criterion is a triplet:

* `Given` - the precondition or context that must hold before the behavior is exercised.
* `When` - the event, action, or input that triggers the behavior under test.
* `Then` - the observable outcome the solution must produce.

A criterion may extend the triplet with `And` or `But` clauses to chain additional preconditions or outcomes. Each Given/When/Then triplet expresses one and only one behavior; multi-behavior criteria are split before they are recorded.

The full pattern, generic examples, and BSD-3 attribution to the Cucumber project are documented in [references/given-when-then.md](references/given-when-then.md). The BRD Builder does not embed the Gherkin specification prose; it references the Cucumber upstream by name.

### Alternative Formats Accepted

The assessor accepts the following alternative formats as equivalent to Given/When/Then for quality purposes. Selection is at stakeholder preference; mixed formats inside one requirement set are flagged as a consistency defect.

* **Flat checklist (Cohn-style).** A bullet list of testable assertions about the post-condition state. Useful for tabular or batch behaviors where Given/When/Then becomes repetitive. Attribution: Mike Cohn.
* **Rule-with-examples.** A natural-language rule paired with one or more concrete example rows. Useful for business-rule-heavy requirements where the rule is the criterion and the examples are the test data.
* **Threshold statement (for NFRs).** For non-functional requirements, an acceptance criterion is a measurable threshold attached to the requirement (for example, "p95 latency under 200 ms at 100 RPS sustained for 10 minutes"). Threshold statements follow the [canonical statement form](#canonical-statement-form).

### Atomicity

Each acceptance criterion is atomic. The atomicity checklist in [references/atomicity-checklist.md](references/atomicity-checklist.md) is original Microsoft content (CC BY 4.0) and is the authoritative checklist the assessor applies. Summary of the rules:

1. One behavior per criterion. Multiple behaviors joined by `and` or `or` are split into separate criteria.
2. One precondition cluster per criterion. Independent preconditions get their own criterion.
3. One observable outcome per criterion. `Then` clauses chained with `and` are split when the outcomes can fail independently.
4. No solution-internal references. The criterion describes externally observable behavior, not implementation details.
5. No quantifiers without thresholds. Words such as `quickly`, `easily`, `most`, `usually` are rewritten with measurable thresholds or removed.
6. No compound subjects. Each criterion has one actor and one system under test.

A criterion that fails any rule is rewritten before it is recorded in the BRD.

## Quality Dimensions and Rubrics

The BRD Builder partitions quality into three independent dimensions. Each dimension has its own scoring rule; the dimensions do not aggregate into a single number.

### Dimension 1 - Individual-Requirement Characteristics (ISO 29148 §5.2.5)

Scored per individual requirement. The BRD Builder recognizes the nine §5.2.5 individual-requirement characteristics, paraphrased from ISO/IEC/IEEE 29148:2018:

1. *Necessary* - the requirement addresses a real stakeholder need or organizational objective and would leave a real gap if removed.
2. *Appropriate* - the requirement sits at the right level of the architecture and aligns with the system strategy expressed in the BRD.
3. *Unambiguous* - the requirement admits only one reading; vague modifiers (`fast`, `easy`, `secure`) are replaced or quantified.
4. *Complete* - the requirement carries every element of the [canonical statement form](#canonical-statement-form) (subject, modal verb, behavior or property, condition, rationale, verification-approach pointer).
5. *Singular* - the requirement states one and only one requirement; compound statements joined by `and`, `or`, or punctuation are split.
6. *Feasible* - the requirement can be implemented within the cost, schedule, technical, and resource constraints recorded in or referenced from the BRD.
7. *Verifiable* - the requirement names or implies an objective method (inspection, analysis, demonstration, or test) that can decide whether it is met.
8. *Correct* - the requirement accurately reflects the underlying stakeholder intent and is free of factual, semantic, or scope errors.
9. *Conforming* - the requirement follows the format, structure, and language standards established for the BRD's requirement set, including the canonical statement form and the BRD glossary.

The 0-3 anchor scale used by the `brd-standard-assessor` subagent is defined in [references/iso-29148-quality-attrs.md](references/iso-29148-quality-attrs.md). See [references/quality-rubric.md](references/quality-rubric.md) for the combined scoring sheet the subagent emits. Cross-cutting traceability is enforced by the [`traceability-naming`](../traceability-naming/SKILL.md) skill rather than scored here.

### Dimension 2 - NFR Category Presence (ISO/IEC 25010, per DD-12)

Scored per BRD draft, not per requirement. The BRD Builder treats ISO/IEC 25010's eight product-quality characteristics as a presence checklist. For each category, the rubric asks a single question: *is at least one non-functional requirement in the BRD that targets this category?*

The eight categories are:

* Functional suitability
* Performance efficiency
* Compatibility
* Usability
* Reliability
* Security
* Maintainability
* Portability

Per DD-12, the Define → Govern hard gate does not require every category to be populated; missing categories are flagged qualitatively in the assessor's narrative but do not block exit by themselves. The BRD Builder does not enumerate ISO 25010 sub-characteristics for scoring; sub-characteristics are listed in [references/iso-25010-nfr-taxonomy.md](references/iso-25010-nfr-taxonomy.md) for awareness only.

### Dimension 3 - Business-Goal SMART (per DD-08)

Scored per business goal, not per requirement. Each goal is evaluated against the SMART attributes (Specific, Measurable, Achievable, Relevant, Time-bound). Each attribute carries an anchor description in [references/smart-rubric.md](references/smart-rubric.md). A goal passes when all five attributes pass; any single attribute failure marks the goal as not-SMART.

The Define → Govern gate is a hard gate: every business goal must pass SMART before the BRD can advance to Govern. Discover-phase goals are accepted as drafts; Define-phase activity rewrites them into SMART form before the assessor runs.

## Testability Heuristics

Independent of the three scoring dimensions, the BRD Builder applies ISTQB-derived testability heuristics during requirement rewriting. The heuristics are listed in [references/istqb-testability.md](references/istqb-testability.md) and cited by name only (ISTQB Glossary). They are not scored; they are used to detect requirements that fail Dimension 1 *verifiable* before a formal score is assigned, and to suggest the smallest edit that restores testability.

## Cite-Only Registry

The frameworks and standards below are referenced by the BRD Builder by name and clause or section only. Their text is not embedded in this repository. When the workflow needs to point a stakeholder at a source, it links to the upstream publisher.

* IIBA BABOK v3 - Business Analysis Body of Knowledge, requirements classification taxonomy and elicitation techniques.
* ISO/IEC/IEEE 29148:2018 - Systems and software engineering: life cycle processes: requirements engineering, including the nine §5.2.5 individual-requirement characteristics. See [references/iso-29148-pointer.md](references/iso-29148-pointer.md) and [references/iso-29148-quality-attrs.md](references/iso-29148-quality-attrs.md).
* ISO/IEC 25010:2011 (and successor revisions) - product-quality model, eight quality characteristics (DD-12 category presence). See [references/iso-25010-nfr-taxonomy.md](references/iso-25010-nfr-taxonomy.md).
* Volere Requirements Specification Template - shell template and requirement-shell concept. See [references/volere-pointer.md](references/volere-pointer.md).
* PMI Business Analysis for Practitioners - PMI BA Practice Guide.
* Karl Wiegers, *Software Requirements* (Microsoft Press) and Process Impact templates. See [references/wiegers-templates.md](references/wiegers-templates.md).
* arc42 - architecture documentation template, §1 (Introduction and Goals), §10 (Quality Requirements).
* joelparkerhenderson/business-requirements-document - community BRD reference.
* OMG BPMN 2.0 / DMN 1.4 / UML 2.5 - notation standards owned by the [`process-modeling`](../process-modeling/SKILL.md) skill.
* Cucumber project (Gherkin / Given-When-Then) - language pattern for acceptance criteria; BSD-3 attribution recorded in [references/given-when-then.md](references/given-when-then.md).
* Mike Cohn flat-checklist style - alternative acceptance-criteria format referenced by name when used.
* ISTQB Glossary - testability terminology. See [references/istqb-testability.md](references/istqb-testability.md).

The SMART mnemonic is a public-domain management-by-objectives convention and is not bound by the cite-only restriction; see [references/smart-rubric.md](references/smart-rubric.md) for the BRD Builder's anchor descriptions.

DO NOT QUOTE prose definitions from any framework above. When a paraphrase is needed, write it as original Microsoft content and cite the framework by name and clause.

## Decision Tree

Use this quick-select when classifying or assessing a candidate item:

1. Does the statement describe a behavior the solution must produce (verb + object + condition)? If yes, classify as a functional requirement and rewrite in the [canonical statement form](#canonical-statement-form).
2. Does the statement describe a measurable property of the solution rather than a behavior? If yes, classify as a non-functional requirement and ensure a threshold is recorded.
3. Is the statement imposed from outside the BRD scope and not negotiable? If yes, classify as a constraint and record the imposing source.
4. Does the statement express a desired outcome without describing the solution? If yes, the statement is a goal, not a requirement; record it in the BRD goals section and decompose it into requirements during Define.
5. Is the statement compound (multiple subjects, behaviors, or conditions)? If yes, split it into atomic statements before classifying.
6. Authoring acceptance criteria? Use Given/When/Then by default; switch to an [alternative format](#alternative-formats-accepted) only when justified, and apply the [atomicity](#atomicity) rules to every criterion.
7. Assessing an individual requirement? Apply the ISO 29148 §5.2.5 0-3 scoring on the nine characteristics in [references/iso-29148-quality-attrs.md](references/iso-29148-quality-attrs.md). A score below 2 on *unambiguous*, *verifiable*, *singular*, or *necessary* blocks Define → Govern.
8. Assessing the BRD as a whole? Apply the ISO 25010 category-presence checklist in [references/iso-25010-nfr-taxonomy.md](references/iso-25010-nfr-taxonomy.md). Record presence (true/false) per category; missing categories are flagged but do not by themselves block Define → Govern.
9. Assessing a business goal? Apply the SMART rubric in [references/smart-rubric.md](references/smart-rubric.md). All five attributes must pass; any failure blocks Define → Govern.
10. Suspect a requirement is not testable? Apply the ISTQB heuristics in [references/istqb-testability.md](references/istqb-testability.md) before scoring, then return to Dimension 1.
11. Producing the combined assessor output? Use the unified rubric in [references/quality-rubric.md](references/quality-rubric.md) to populate `BRD_STANDARD_FINDINGS_V1`.

## References

Internal:

* [references/iso-29148-pointer.md](references/iso-29148-pointer.md) - cite-only summary of ISO/IEC/IEEE 29148:2018 and outbound link.
* [references/iso-29148-quality-attrs.md](references/iso-29148-quality-attrs.md) - cite-only summary of the nine ISO 29148 §5.2.5 individual-requirement characteristics and 0-3 anchor descriptions.
* [references/iso-25010-nfr-taxonomy.md](references/iso-25010-nfr-taxonomy.md) - cite-only summary of the eight ISO/IEC 25010 quality characteristics presented as a category-presence checklist per DD-12.
* [references/volere-pointer.md](references/volere-pointer.md) - cite-only summary of the Volere Requirements Specification Template and outbound link.
* [references/smart-rubric.md](references/smart-rubric.md) - SMART rubric per DD-08, with per-attribute anchor descriptions and binary pass/fail for the Define → Govern hard gate.
* [references/istqb-testability.md](references/istqb-testability.md) - cite-only testability heuristics from the ISTQB Glossary.
* [references/quality-rubric.md](references/quality-rubric.md) - combined HVE-Core rubric used by the `brd-standard-assessor` subagent.
* [references/given-when-then.md](references/given-when-then.md) - canonical Given/When/Then pattern with generic examples and Cucumber attribution.
* [references/atomicity-checklist.md](references/atomicity-checklist.md) - original Microsoft atomicity checklist (CC BY 4.0).
* [references/wiegers-templates.md](references/wiegers-templates.md) - cite-only pointer to Karl Wiegers, *Software Requirements*.
* [`traceability-naming`](../traceability-naming/SKILL.md) - requirement identifier schema and traceability matrix.
* [`prioritization-schemes`](../prioritization-schemes/SKILL.md) - priority taxonomy referenced when authoring requirements.
* [`process-modeling`](../process-modeling/SKILL.md) - BPMN / DMN / UML notation guidance.

External (cite-only, no embedded text):

* IIBA BABOK v3 - [https://www.iiba.org/standards-and-resources/babok/](https://www.iiba.org/standards-and-resources/babok/)
* ISO/IEC/IEEE 29148:2018 - [https://www.iso.org/standard/72089.html](https://www.iso.org/standard/72089.html)
* ISO/IEC 25010 - [https://www.iso.org/standard/35733.html](https://www.iso.org/standard/35733.html)
* Volere Requirements Specification Template - [https://www.volere.org/](https://www.volere.org/)
* ISTQB Glossary - [https://glossary.istqb.org/](https://glossary.istqb.org/)
* Cucumber project (Gherkin parser and language) - [https://github.com/cucumber/gherkin](https://github.com/cucumber/gherkin)
* Karl Wiegers, *Software Requirements* (3rd ed., Microsoft Press, 2013) and Process Impact templates - [https://www.wiegers.net/](https://www.wiegers.net/)

## License

Original content in this skill is licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), copyright (C) Microsoft Corporation. Third-party frameworks and standards listed in the [cite-only registry](#cite-only-registry) are referenced by name and clause only and remain the property of their respective rights holders.

### CC BY 4.0 Original Microsoft Content

The atomicity checklist in [references/atomicity-checklist.md](references/atomicity-checklist.md) is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), copyright (C) Microsoft Corporation. This `SKILL.md` is also original Microsoft content under the same license.

### Third-Party Attribution

* The Cucumber Gherkin language pattern is attributed to the Cucumber project under the [BSD 3-Clause](https://opensource.org/licenses/BSD-3-Clause) license; this repository does not redistribute Cucumber prose.
* Karl Wiegers' *Software Requirements* and Process Impact templates remain the property of Karl Wiegers / Process Impact and are referenced by name only.
* ISO/IEC/IEEE 29148:2018, ISO/IEC 25010, IIBA BABOK v3, Volere, PMI BA Practice Guide, OMG BPMN/DMN/UML, and the ISTQB Glossary remain the property of their respective rights holders and are referenced by name and clause only.

> Brought to you by microsoft/hve-core

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
