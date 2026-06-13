---
description: 'Unified requirements-definition vocabulary, formats, and quality rubrics for the BRD Builder workflow - FR/AC/NFR/CON/BR taxonomy, acceptance criteria, and quality heuristics - Brought to you by microsoft/hve-core'
---

# Requirements Definition — Skill Entry

## Overview

This skill is the single requirements-definition bundle the BRD Builder loads whenever it captures, classifies, articulates, or scores requirements during the Discover and Define phases. It unifies three responsibilities that previously lived in separate skills:

* Requirement vocabulary - the five-namespace taxonomy (FR functional requirement, AC acceptance criterion, NFR non-functional requirement, CON constraint, BR business rule) and the canonical statement form used before an identifier is assigned.
* Acceptance-criteria authoring - Given/When/Then as the default format, the accepted alternative formats, and an original Microsoft atomicity checklist (CC BY 4.0) applied to every criterion.
* Quality assessment - the three Define-phase rubrics (ISO 29148 §5.2.5 0-3 individual-requirement scoring, ISO/IEC 25010 NFR category presence, SMART business-goal rubric) plus ISTQB testability heuristics.

The skill is consumed by:

* the `brd-author` skill (template population, Define-phase rewriting, per-partition acceptance-criteria sections, and self-scoring);
* the BRD Quality Reviewer (plan-mode rubric at Define exit, mid-Define on demand, and post-Govern drift detection);
* the BRD-phase instruction files for Discover, Define, and Govern.

This file is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The atomicity checklist in `references/atomicity-checklist.md` is also original Microsoft content under CC BY 4.0. External frameworks listed in the [cite-only registry](#cite-only-registry) are referenced by name and clause or section only; their prose is not embedded.

## When to Apply

Apply this skill in the following situations:

* Capturing or restating a business goal, stakeholder need, or proposed feature inside a BRD draft.
* Classifying an existing requirement as functional, non-functional, constraint, or business rule before assigning an identifier.
* Rewriting a candidate requirement into the [canonical statement form](#canonical-statement-form), or splitting a compound statement into atomic requirements.
* Deciding whether a candidate requirement belongs in the BRD or should be deferred to the downstream PRD.
* Writing or reviewing acceptance criteria for any captured requirement, or translating a stakeholder's free-form success statement into a structured triplet or equivalent format.
* Preparing acceptance-criteria sections for the approved BRD and downstream PRD handoff.
* Scoring a BRD draft against the nine ISO 29148 §5.2.5 individual-requirement characteristics ahead of the Define → Govern gate.
* Checking that every ISO/IEC 25010 quality characteristic is represented by at least one NFR before exiting Define.
* Refining a Discover-phase business-goal draft into a SMART goal during Define.
* Asking whether a requirement is testable, and if not, what minimum information would make it testable (per ISTQB testability).
* Producing the combined quality score the BRD Quality Reviewer emits in `BRD_STANDARD_FINDINGS_V1`.

## Requirement Categories

The BRD Builder classifies every captured requirement under the shared five-namespace taxonomy: `FR` (functional requirement), `AC` (acceptance criterion), `NFR` (non-functional requirement), `CON` (constraint), and `BR` (business rule). This section defines the four categories assigned during capture (FR, NFR, CON, BR); acceptance criteria (`AC`) attach to functional requirements and are defined in the [Acceptance Criteria](#acceptance-criteria) section. Identifier prefixes and digit rules for all five namespaces are owned by [id-schema.md](id-schema.md).

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

Constraints are stated in the present tense and identify the imposing source so downstream readers can validate whether the source remains in force. Each `CON-###` item records imposing source, affected boundary, non-negotiability, category, and impact.

### Business Rule (BR)

A policy, regulatory obligation, or operating rule the solution must respect but does not itself implement as a single behavior. Business rules are enforced *by* functional requirements rather than being behaviors themselves, and they typically outlive any single solution.

A business rule differs from a constraint. A constraint (`CON`) is an imposed boundary on how the solution may be built or delivered, such as an approved runtime, a fixed budget, or a mandated integration. A business rule (`BR`) is a standing policy the business operates under, such as an approval threshold, a data-residency obligation, or an eligibility rule. A constraint bounds how the solution is delivered; a business rule governs the outcomes the solution must uphold.

Common business-rule origins:

* Regulatory or statutory obligation expressed as an ongoing policy (residency, retention, disclosure).
* Organizational policy or operating procedure (approval thresholds, segregation-of-duties rules).
* Contractual or service-level commitment the solution must continuously honor.

Business rules are recorded under the `BR-###` namespace owned by [id-schema.md](id-schema.md); a functional requirement may declare the rules it enforces through an optional `enforces: [BR-###]` field.

## Canonical Statement Form

Every requirement captured by the BRD Builder is rewritten into the canonical form before it is assigned an identifier. The form has four positions:

1. Subject - the solution or a named component.
2. Modal verb - `shall` for binding statements, `should` for preferences, `may` for permissions. The BRD Builder emits `shall` by default and surfaces lower modality only when the stakeholder confirms it.
3. Behavior or property - the action (for FR) or measurable property (for NFR).
4. Condition - the triggering event, precondition, or applicable scope.

Each requirement is atomic: one subject, one behavior or property, one condition. Compound statements joined by `and`, `or`, or `,` are split into multiple requirements during Define-phase rewriting.

Each requirement carries:

* a stable identifier owned by [id-schema.md](id-schema.md);
* a rationale linking it back to the originating business goal or stakeholder need;
* a verification approach owned by the [Acceptance Criteria](#acceptance-criteria) section below.

## Acceptance Criteria

Acceptance criteria attach a verification approach to each captured requirement. The BRD Builder uses one default format and accepts a small set of alternatives; every criterion must satisfy the [atomicity checklist](#atomicity).

### Default Format - Given/When/Then

The BRD Builder emits acceptance criteria in [Given/When/Then](given-when-then.md) (Gherkin) form by default. Each criterion is a triplet:

* `Given` - the precondition or context that must hold before the behavior is exercised.
* `When` - the event, action, or input that triggers the behavior under test.
* `Then` - the observable outcome the solution must produce.

A criterion may extend the triplet with `And` or `But` clauses to chain additional preconditions or outcomes. Each Given/When/Then triplet expresses one and only one behavior; multi-behavior criteria are split before they are recorded.

The full pattern, generic examples, and BSD-3 attribution to the Cucumber project are documented in [given-when-then.md](given-when-then.md). The BRD Builder does not embed the Gherkin specification prose; it references the Cucumber upstream by name.

### Alternative Formats Accepted

The assessor accepts the following alternative formats as equivalent to Given/When/Then for quality purposes. Selection is at stakeholder preference; mixed formats inside one requirement set are flagged as a consistency defect.

* **Flat checklist (Cohn-style).** A bullet list of testable assertions about the post-condition state. Useful for tabular or batch behaviors where Given/When/Then becomes repetitive. Attribution: Mike Cohn.
* **Rule-with-examples.** A natural-language rule paired with one or more concrete example rows. Useful for business-rule-heavy requirements where the rule is the criterion and the examples are the test data.
* **Threshold statement (for NFRs).** For non-functional requirements, an acceptance criterion is a measurable threshold attached to the requirement (for example, "p95 latency under 200 ms at 100 RPS sustained for 10 minutes"). Threshold statements follow the [canonical statement form](#canonical-statement-form).

### Atomicity

Each acceptance criterion is atomic. The atomicity checklist in [atomicity-checklist.md](atomicity-checklist.md) is original Microsoft content (CC BY 4.0) and is the authoritative checklist the assessor applies. Summary of the rules:

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

The 0-3 anchor scale used by the BRD Quality Reviewer is defined in [iso-29148-quality-attrs.md](iso-29148-quality-attrs.md). See [requirements-quality-rubric.md](requirements-quality-rubric.md) for the combined scoring sheet the reviewer emits. Cross-cutting traceability is enforced by [traceability-naming.md](traceability-naming.md) rather than scored here.

### Dimension 2 - NFR Category Presence

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

The Define to Govern hard gate does not require every category to be populated; missing categories are flagged qualitatively in the reviewer's narrative but do not block exit by themselves. The BRD Builder does not enumerate ISO 25010 sub-characteristics for scoring; sub-characteristics are listed in [iso-25010-nfr-taxonomy.md](iso-25010-nfr-taxonomy.md) for awareness only.

### Dimension 3 - Business-Goal SMART

Scored per business goal, not per requirement. Each goal is evaluated against the SMART attributes (Specific, Measurable, Achievable, Relevant, Time-bound). Each attribute carries an anchor description in [smart-rubric.md](smart-rubric.md). A goal passes when all five attributes pass; any single attribute failure marks the goal as not-SMART.

The Define → Govern gate is a hard gate: every business goal must pass SMART before the BRD can advance to Govern. Discover-phase goals are accepted as drafts; Define-phase activity rewrites them into SMART form before the assessor runs.

## Testability Heuristics

Independent of the three scoring dimensions, the BRD Builder applies ISTQB-derived testability heuristics during requirement rewriting. The heuristics are listed in [istqb-testability.md](istqb-testability.md) and cited by name only (ISTQB Glossary). They are not scored; they are used to detect requirements that fail Dimension 1 *verifiable* before a formal score is assigned, and to suggest the smallest edit that restores testability.

## Cite-Only Registry

The frameworks and standards below are referenced by the BRD Builder by name and clause or section only. Their text is not embedded in this repository. When the workflow needs to point a stakeholder at a source, it links to the upstream publisher.

* IIBA BABOK v3 - Business Analysis Body of Knowledge, requirements classification taxonomy and elicitation techniques.
* ISO/IEC/IEEE 29148:2018 - Systems and software engineering: life cycle processes: requirements engineering, including the nine §5.2.5 individual-requirement characteristics. See [standards-excerpts.md](standards-excerpts.md#isoiecieee-291482018) and [iso-29148-quality-attrs.md](iso-29148-quality-attrs.md).
* ISO/IEC 25010:2011 and successor revisions - product-quality model, eight quality characteristics. See [standards-excerpts.md](standards-excerpts.md#isoiec-250102023) and [iso-25010-nfr-taxonomy.md](iso-25010-nfr-taxonomy.md).
* Volere Requirements Specification Template - shell template and requirement-shell concept. See [standards-excerpts.md](standards-excerpts.md#volere-requirements-specification-template).
* PMI Business Analysis for Practitioners - PMI BA Practice Guide.
* Karl Wiegers, *Software Requirements* (Microsoft Press) and Process Impact templates. See [standards-excerpts.md](standards-excerpts.md#karl-wiegers--software-requirements).
* arc42 - architecture documentation template, §1 (Introduction and Goals), §10 (Quality Requirements).
* joelparkerhenderson/business-requirements-document - community BRD reference.
* OMG BPMN 2.0 / DMN 1.4 / UML 2.5 - notation standards owned by the [`process-modeling`](process-modeling.md) skill.
* Cucumber project (Gherkin / Given-When-Then) - language pattern for acceptance criteria; BSD-3 attribution recorded in [given-when-then.md](given-when-then.md).
* Mike Cohn flat-checklist style - alternative acceptance-criteria format referenced by name when used.
* ISTQB Glossary - testability terminology. See [istqb-testability.md](istqb-testability.md).

The SMART mnemonic is a public-domain management-by-objectives convention and is not bound by the cite-only restriction; see [smart-rubric.md](smart-rubric.md) for the BRD Builder's anchor descriptions.

DO NOT QUOTE prose definitions from any framework above. When a paraphrase is needed, write it as original Microsoft content and cite the framework by name and clause.

## Decision Tree

Use this quick-select when classifying or assessing a candidate item:

1. Does the statement describe a behavior the solution must produce (verb + object + condition)? If yes, classify as a functional requirement and rewrite in the [canonical statement form](#canonical-statement-form).
2. Does the statement describe a measurable property of the solution rather than a behavior? If yes, classify as a non-functional requirement and ensure a threshold is recorded.
3. Is the statement imposed from outside the BRD scope and not negotiable? If yes, classify as a constraint and record the imposing source.
4. Is the statement a standing policy, regulatory obligation, or operating rule the solution must uphold but does not implement as a single behavior? If yes, classify as a business rule and, where known, record the functional requirements that enforce it.
5. Does the statement express a desired outcome without describing the solution? If yes, the statement is a goal, not a requirement; record it in the BRD goals section and decompose it into requirements during Define.
6. Is the statement compound (multiple subjects, behaviors, or conditions)? If yes, split it into atomic statements before classifying.
7. Authoring acceptance criteria? Use Given/When/Then by default; switch to an [alternative format](#alternative-formats-accepted) only when justified, and apply the [atomicity](#atomicity) rules to every criterion.
8. Assessing an individual requirement? Apply the ISO 29148 §5.2.5 0-3 scoring on the nine characteristics in [iso-29148-quality-attrs.md](iso-29148-quality-attrs.md). A score below 2 on *unambiguous*, *verifiable*, *singular*, or *necessary* blocks Define → Govern.
9. Assessing the BRD as a whole? Apply the ISO 25010 category-presence checklist in [iso-25010-nfr-taxonomy.md](iso-25010-nfr-taxonomy.md). Record presence (true/false) per category; missing categories are flagged but do not by themselves block Define → Govern.
10. Assessing a business goal? Apply the SMART rubric in [smart-rubric.md](smart-rubric.md). All five attributes must pass; any failure blocks Define → Govern.
11. Suspect a requirement is not testable? Apply the ISTQB heuristics in [istqb-testability.md](istqb-testability.md) before scoring, then return to Dimension 1.
12. Producing the combined reviewer output? Use the unified rubric in [requirements-quality-rubric.md](requirements-quality-rubric.md) to populate `BRD_STANDARD_FINDINGS_V1`.

## References

Internal:

* [standards-excerpts.md](standards-excerpts.md) - cite-only registry for ISO/IEC/IEEE 29148:2018, ISO/IEC 25010, Volere, Wiegers, and other standards.
* [iso-29148-quality-attrs.md](iso-29148-quality-attrs.md) - cite-only summary of the nine ISO 29148 §5.2.5 individual-requirement characteristics and 0-3 anchor descriptions.
* [iso-25010-nfr-taxonomy.md](iso-25010-nfr-taxonomy.md) - cite-only summary of the eight ISO/IEC 25010 quality characteristics presented as a category-presence checklist.
* [smart-rubric.md](smart-rubric.md) - SMART rubric with per-attribute anchor descriptions and binary pass/fail for the Define to Govern hard gate.
* [istqb-testability.md](istqb-testability.md) - cite-only testability heuristics from the ISTQB Glossary.
* [requirements-quality-rubric.md](requirements-quality-rubric.md) - combined HVE-Core rubric used by the BRD Quality Reviewer.
* [given-when-then.md](given-when-then.md) - canonical Given/When/Then pattern with generic examples and Cucumber attribution.
* [atomicity-checklist.md](atomicity-checklist.md) - original Microsoft atomicity checklist (CC BY 4.0).
* [id-schema.md](id-schema.md) - canonical requirement, business-goal, and design-decision identifier schema.
* [traceability-naming.md](traceability-naming.md) - requirement identifier routing and traceability matrix conventions.
* [prioritization-schemes.md](prioritization-schemes.md) - MoSCoW priority taxonomy referenced when authoring requirements.
* [process-modeling.md](process-modeling.md) - optional process, decision, and structural diagram guidance.

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

The atomicity checklist in [atomicity-checklist.md](atomicity-checklist.md) is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), copyright (C) Microsoft Corporation. This `SKILL.md` is also original Microsoft content under the same license.

### Third-Party Attribution

* The Cucumber Gherkin language pattern is attributed to the Cucumber project under the [BSD 3-Clause](https://opensource.org/licenses/BSD-3-Clause) license; this repository does not redistribute Cucumber prose.
* Karl Wiegers' *Software Requirements* and Process Impact templates remain the property of Karl Wiegers / Process Impact and are referenced by name only.
* ISO/IEC/IEEE 29148:2018, ISO/IEC 25010, IIBA BABOK v3, Volere, PMI BA Practice Guide, OMG BPMN/DMN/UML, and the ISTQB Glossary remain the property of their respective rights holders and are referenced by name and clause only.

> Brought to you by microsoft/hve-core

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
