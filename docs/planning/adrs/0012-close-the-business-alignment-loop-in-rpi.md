---
id: "0012"
title: "Close the business-alignment loop between requirements and RPI implementations"
description: "Extend the existing RPI plan, implement, and review skills so planning finds and cites BRD, PRD, and ADR sources and checks their status, implementation records alignment-affecting changes and compares completed work against them, and review rates drift by business stake and owner awareness, routes source updates and architecture review follow-ups, and offers a copy-ready note to the source owner; Code Review applies the same shared procedure to pull requests, with no automatic outbound action."
author: "HVE Core Maintainers"
ms.date: "2026-10-09"
ms.topic: "reference"
status: "proposed"
proposed_date: "2026-10-09"
accepted_date: null
deciders:
  - "HVE Core Maintainers"
consulted:
  - "HVE Core Contributors"
informed:
  - "hve-core users"
  - "extension consumers"
effort: "M"
tags:
  - "rpi"
  - "requirements"
  - "traceability"
  - "adr"
  - "review"
affected_components:
  - ".github/skills/rpi/rpi-plan/SKILL.md"
  - ".github/skills/rpi/rpi-plan/references/planning.md"
  - ".github/skills/rpi/rpi-implement/SKILL.md"
  - ".github/skills/rpi/rpi-implement/references/implementation.md"
  - ".github/skills/rpi/rpi-implement/templates/changes-log.md"
  - ".github/skills/rpi/rpi-review/SKILL.md"
  - ".github/skills/rpi/rpi-review/references/review.md"
  - ".github/skills/rpi/rpi-review/references/business-alignment.md"
  - ".github/skills/rpi/rpi-review/templates/review-log.md"
  - ".github/agents/coding-standards/code-review.agent.md"
  - ".github/skills/coding-standards/code-review/references/output-formats.md"
supersedes: null
superseded-by: null
related:
  - path: "0001-adopt-phase-gated-adr-creator-aligned-with-peer-planners.md"
    relation: "influenced-by"
    note: "ADR lineage and status semantics from the ADR Creator determine how an ADR source is checked and how an ADR update is proposed as a superseding record."
  - path: "0003-generalize-requirements-author-skill-for-brd-and-prd.md"
    relation: "influenced-by"
    note: "The shared requirements-author templates define the BRD and PRD identifiers, owners, status, and lineage fields this decision reads."
asr_triggers:
  - kind: "maintainability"
    evidence: "Plans can cite BRD, PRD, and ADR identifiers, but no RPI phase reads those sources again, so delivered work can diverge from documented business intent without anyone recording or reporting it."
    note: "Divergence between requirements and implementation is a standing drift surface that compounds as more work is planned against stale sources."
success_criteria:
  - metric: "alignment-capture"
    target: "a plan update that touches a cited business source produces a Business Alignment entry naming the source, owner, change, and decision"
    measurement_window: "first RPI implementations after merge whose plans cite business sources"
    source: ".github/skills/rpi/rpi-implement/templates/changes-log.md"
  - metric: "review-alignment-routing"
    target: "review records divergence from a cited source as a routed finding and offers a copy-ready owner note without any outbound action"
    measurement_window: "first RPI reviews after merge whose plans cite business sources"
    source: ".github/skills/rpi/rpi-review/references/business-alignment.md"
  - metric: "knowledge-conformance"
    target: "advisory knowledge stimuli for the changed RPI skills pass"
    measurement_window: "every behavior-conformance eval run"
    source: "evals/behavior-conformance/skill-behavior.eval.yaml"
  - metric: "code-review-alignment"
    target: "a pull request reviewed with confirmed BRD, PRD, or ADR context reports rubric-rated alignment findings that count toward the verdict, and a review without that context reports none"
    measurement_window: "every agent-behavior eval run after merge"
    source: "evals/agent-behavior/stimuli/code-review.yml"
decisionMetadata:
  driverToTriggerMap:
    "Traceable business intent": "Cited BRD, PRD, and ADR sources are read again at plan, implement, and review time, so divergence is recorded instead of drifting silently."
    "Owner awareness": "Source owners and deciders come from document frontmatter, so the right person can be told when work diverges."
    "No silent outbound actions": "Notes are drafted only on request as copy-ready text, and source updates are routed as follow-ups rather than edited."
    "Reliable activation": "Explicit conditional steps in the RPI skills run whenever sources are cited instead of depending on description matching."
    "Low cost when unused": "Planning runs one bounded search, and the review procedure lives in an on-demand reference that loads only when a plan cites business sources."
---

## Context

Business intent lives in BRDs, PRDs, and ADRs, and is reflected in architecture reviews and diagrams. RPI plans can already cite those sources, but nothing after planning reads them again. When implementation changes direction, the change is recorded in the RPI plan and changes record, yet the source document and its owner are never told. Over time the requirements, decisions, and delivered behavior drift apart.

The existing contracts show where the gap sits:

> "Cite `FR-nnn`, `NFR-nnn`, PRD, BRD, or ADR identifiers under `Requirements:` when they exist" (rpi-plan skill, Flow)
>
> "`rpi-implement` follows the plan and does not discover extensions." (hve-builder extension guidance, RPI phase extensions)
>
> "Review may create or update only its one canonical review record." (rpi-review skill, Constraints)
>
> "Don't go back and edit accepted records." (Microsoft Azure Well-Architected Framework, Maintain an architecture decision record)

Plans cite sources, implementation cannot be extended by an add-on skill, review cannot write anything outside its record, and accepted ADRs must be superseded rather than edited. Any design must respect all four.

Upstream, requirement identifiers are also lost before they reach tracker work items: the planning hierarchy maps every PRD requirement to an item but carries no per-item source identifier into the tracker. That upstream carry is planned as a second increment and is outside the changes listed in Affected Components.

## Decision Drivers

* Traceable business intent
* Owner awareness
* No silent outbound actions
* Reliable activation
* Low cost when unused

## Considered Options

* Option A: Implement-only. Put detection, note drafting, and source-update offers entirely in `rpi-implement`.
* Option B: Separate review-time skill. Add a new alignment skill that `rpi-review` and `rpi-plan` discover by description.
* Option C: Extend the existing RPI skills. Add a citation and status rule to `rpi-plan`, a capture rule to `rpi-implement`, and a conditional alignment step with an on-demand reference to `rpi-review`.
* Option D: Deterministic CI fitness checks only. Validate trace data in a pipeline without any RPI behavior change.
* Option E: Native tracker links only. Rely on tracker link types and labels to connect work items to source documents.

## Decision Outcome

| Decision driver            | Option A: implement-only | Option B: separate skill | Option C: extend RPI skills | Option D: CI checks only | Option E: tracker links only |
|----------------------------|--------------------------|--------------------------|-----------------------------|--------------------------|------------------------------|
| Traceable business intent  | Partial                  | Yes                      | Yes                         | Partial                  | Partial                      |
| Owner awareness            | Yes                      | Yes                      | Yes                         | No                       | No                           |
| No silent outbound actions | Yes                      | Yes                      | Yes                         | Yes                      | Yes                          |
| Reliable activation        | Yes                      | Partial                  | Yes                         | Yes                      | Partial                      |
| Low cost when unused       | No                       | Yes                      | Yes                         | Yes                      | Yes                          |

Chosen option: **Option C**, because it is the only option that finds the sources during planning, records alignment changes where they happen, compares delivered work against the sources at review, and activates through explicit steps rather than description matching, while keeping the review procedure out of context when no sources are cited.

The decision has six parts.

**1. Planning finds and cites business sources and checks their status.** A business source is a BRD, PRD, or ADR.
Planning cites every source the user, research, or a tracker item supplies, and runs one quick bounded search of the repository's BRD, PRD, and ADR locations for other relevant sources.
Each task that implements a source cites the specific requirement or decision identifiers it satisfies and the committed path of the document.
`rpi-plan` holds the one definition of a business source, owns the fallback from an identifier to a path, and records a source it cannot resolve.
It reads each cited source's status and supersession fields and records a risk: medium when the source is superseded, deprecated, rejected, or withdrawn, and low when it is not yet approved, has no status, or cannot be resolved.
Planning always uses the latest copy of a source: a superseded search match, or a supplied or found source with a non-empty supersession field, is followed to its latest successor, which is cited instead.

**2. Implementation records alignment-affecting changes and compares before handoff.** When a plan update changes a requirement that cites a business source, or completed behavior differs from one, `rpi-implement` adds a Business Alignment entry to the changes record.
The entry names the source, cited identifiers, owner or deciders from the source frontmatter, the change, its rationale, the user decision, and an alignment value, including `pending-decision` for divergence awaiting the user.
Before handoff to review, implementation compares completed behavior with every cited source requirement and adds any missing entry, and a pending decision blocks review readiness.
Unconfirmed divergence still follows the existing rule that pauses affected work for a user decision.

**3. Review rates drift by business stake and owner awareness, routes source updates, and triggers an architecture review.** When sources are cited or alignment entries exist, `rpi-review` reads an on-demand business-alignment reference, compares delivered behavior against the cited sources, and records the result in its acceptance coverage.
Drift is meaningful only when delivered behavior changes a cited requirement's expected outcome or acceptance criterion, a business rule's enforcement, a non-negotiable constraint, a goal measure, or an ADR's decision outcome or accepted consequence; any other difference is a clarification.
Severity comes from two factors rather than from the document type.
Business stake is the highest MoSCoW priority of the goals a cited requirement traces to, with business rules and non-negotiable constraints counted as MUST; for an ADR, an accepted decision with a security, compliance, or availability trigger is MUST, another accepted decision is SHOULD, and a proposed decision drops one level.
Owner awareness is unrecorded, developer-confirmed, or owner-acknowledged, because a developer's decision to diverge is not the accountable owner's decision.
Owner-acknowledged needs owner evidence the developer does not control: a developer's own edit of the source, or a claim of approval, counts only as developer-confirmed.
A rubric table in the reference maps the two factors to Critical through Low, and owner acknowledgment lowers any stake to Low.
Two guards keep the rubric honest: severity above Medium requires a changed outcome or acceptance criterion, and a requirement with no goal link is treated as SHOULD with a recorded traceability gap.
MUST-level drift from a BRD is flagged as possible misalignment with business objectives.
This follows the shared position of ISO/IEC/IEEE 29148 on traceability and change impact, IIBA BABOK on assessing changes against business objectives, and PRINCE2 continued business justification, paraphrased here; none of them sets numeric thresholds, so the levels are this decision's own synthesis.
Two results sit outside the rubric as alerts to the user: a stale source (superseded, deprecated, rejected, or withdrawn) is a medium alert that names the successor or the update needed, and a source gap (the source does not cover the delivered behavior, or contradicts itself) is a low alert that suggests drafting a new ADR or revising the BRD or PRD.
Unconfirmed divergence follows the existing defect or decision-gap routes.
Confirmed divergence and source gaps become residual follow-ups that name the owning workflow: a BRD or PRD revision, or a new superseding ADR.
Any drift also adds a follow-up for an architecture review through the System Architecture Reviewer, so architecture records and diagrams are refreshed rather than cited as a source.

**4. Review offers a copy-ready note, and nothing is sent.** In a user-owned walkthrough, a residual source-update finding uses one suggested action that creates the follow-up and drafts a note to the source owner.
The user can keep the follow-up and decline the note, and the two decisions are recorded separately.
Only when the user accepts the note does review write a `Stakeholder Note Draft` section into its own review record and show the same text ready to copy.
The note has no approval gate because no automated action follows it.
Automatic review writes no draft and records the offer as a follow-up for the user.

**5. Code Review applies the same procedure to pull requests.** The business-alignment reference is one shared procedure: a core with the drift definition, evidence rule, rubric, and note format; business (BRD), product (PRD), and decision (ADR) alignment sub-sections that define stake for each source type; and a marked section that only RPI Review uses.
Code Review loads that reference by name through an extension modeled on its Security Plan Drift extension, without a new skill or review lane.
It takes business sources from an explicit input, from identifiers or paths in the pull request description and its linked issues, from changed files in the ADR folder or with `brd_id` or `prd_id` frontmatter, and from a quick search of the repository's BRDs, PRDs, and ADRs for the changed paths and components.
A pull request that adds or edits a business source therefore triggers a check against that source.
It accepts only repository paths that identify a business source and follows a superseded document to its latest successor, resolving supersession as it stands on the base branch: a supersession link or successor added in the pull request is a proposed source update and never moves the comparison. It confirms every discovered source with the human before use; workflow runs use only explicitly supplied sources.
It compares the change against each source as it was on the base branch, so editing the source in the same pull request cannot hide drift; when the base revision cannot be read, it compares each edited passage against the pull request's own removed lines and never against the edited text. It compares before findings are merged.
Alignment findings carry the source, requirement identifiers, evidence, and a resolution path, and they count toward the verdict like any other finding: Critical and High findings request changes until the code is aligned or the owner's acknowledgment is confirmed.
An in-PR source edit or a claim of approval in the pull request or a linked issue is developer-confirmed. Only the human reviewer can confirm an owner's acknowledgment, in the interactive pause before posting, which re-rates the finding; workflow runs never grant it.
In an interactive review, Code Review offers to draft a note to the source owner for each Critical or High finding and writes it into its local review record only when the user accepts; the note never becomes part of a posted comment.
Edits to the shared core must keep it usable without the RPI-only section.

**6. The rollout has two increments.** This decision's first increment changes only the RPI skills and Code Review files listed in Affected Components.
The second increment carries business context into tracker work items: one logical contract rendered natively per tracker, per-item source identifiers from the hierarchy planner, ADR handoff alignment, a sanitization exemption for source identifiers, and read-back of that context by RPI research and planning.

### Consequences

* Good, because divergence from a cited source is recorded at the moment it happens and reviewed against the source when work completes.
* Good, because the user can tell the TPM or architect about a divergence with a ready-made note instead of reconstructing the context.
* Good, because no RPI phase or Code Review step gains authority to write to trackers, send messages, or edit source documents.
* Good, because implementation and review of work that cites no business sources are unchanged.
* Good, because severity reflects what is at stake for the business and whether its owner knows, the same way in RPI Review and in Code Review.
* Bad, because plans must now carry source paths and requirement identifiers, and planning always runs a quick source search, which adds planning effort.
* Bad, because the rule is spread across three skills and Code Review, so a change to the alignment contract touches all of them.
* Bad, because Code Review can now request changes on a model-judged alignment finding, which may block a pull request incorrectly.
* Neutral, because the rubric's level boundaries are this decision's own synthesis and may be tuned after early use.

### Confirmation

This decision remains `proposed` until a qualified human reviewer approves it and a later human-owned change records the acceptance. The capture contract, the review routing, the rubric, and the copy-ready note are exercised by advisory knowledge stimuli in `evals/behavior-conformance/skill-behavior.eval.yaml`, and natively by the first RPI review of any plan that cites a business source. Code Review's context recognition and its silence without context are exercised by stimuli in `evals/agent-behavior/stimuli/code-review.yml`.

## Pros and Cons of the Options

### Option A: Implement-only

* Good, because implementation is where divergence first appears and the user is already engaged.
* Bad, because `rpi-implement` cannot load extensions, so all detection and drafting logic would sit in its always-loaded instructions.
* Bad, because a note drafted mid-implementation may describe a change that shifts again before the work completes.

### Option B: Separate review-time skill

* Good, because the alignment procedure would have one home and could serve consumers outside RPI.
* Bad, because activation depends on description matching rather than an explicit step.
* Bad, because review still needs a contract change to hold the note, removing the main benefit of an add-on.
* Neutral, because the chosen option also gives the procedure one home that serves Code Review, which loads another skill's reference by name as it already does for security plan drift.

### Option C: Extend the existing RPI skills

* Good, because each phase gets the smallest rule it needs and activation is explicit.
* Good, because the review procedure loads only when sources are cited.
* Good, because one shared reference serves both RPI Review and Code Review without a new skill.
* Bad, because the alignment contract spans three skills and Code Review, which must stay consistent.

### Option D: Deterministic CI fitness checks only

* Good, because checks are enforced and repeatable without model judgment.
* Bad, because a pipeline cannot capture why a change happened or help notify the owner.
* Neutral, because it remains a candidate complement once work items carry trace data.

### Option E: Native tracker links only

* Good, because it uses platform features users already know.
* Bad, because GitHub issues and Jira lack an equivalent to Azure DevOps hyperlinks for source documents, and labels are too coarse for requirement identifiers.

## Risks and Mitigations

| Risk                                                                            | Mitigation                                                                                                                                                                                                  |
|---------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| The widened review write rule is read as general write authority                | The rule names the single allowed section and permits it only after the user accepts the drafting action                                                                                                    |
| Plans cite identifiers without paths and the checks cannot find the source      | Planning owns an identifier-to-path fallback and records unresolved sources; later phases record them without guessing                                                                                      |
| Planning misses a relevant source that was not supplied                         | Planning runs a bounded search of BRD, PRD, and ADR locations and records what it searched and found                                                                                                        |
| Silent divergence never reaches an alignment entry                              | Implementation compares completed behavior with every cited requirement before handoff to review                                                                                                            |
| The three skills drift apart on the alignment contract                          | The changes-record section and field names are a stated contract consumed by review, covered by knowledge stimuli                                                                                           |
| Source text in a BRD, PRD, or ADR tries to redirect the workflow                | Every new rule treats source document text as data that cannot change the workflow                                                                                                                          |
| Code Review requests changes on an incorrect alignment finding                  | A finding needs a confirmed source, a requirement or decision identifier, and diff evidence; severity above Medium needs a changed outcome; owner acknowledgment resolves it                                |
| An RPI-motivated edit to the shared reference breaks Code Review                | The reference and the rpi-review skill state that Code Review consumes the shared core, and a Code Review stimulus exercises it                                                                             |
| The base-branch copy of a source is unavailable, for example in a shallow clone | Code Review compares each edited passage against the diff's removed lines, never the edited text, reports a passage with no pre-change text as unavailable, and caps owner awareness at developer-confirmed |

## Rollback / Exit Strategy

If this decision is reversed, the rollback path is:

1. Remove the business-alignment extension from the Code Review agent and the `business_alignment` field and sections from its output formats.
2. Remove the conditional alignment step from the `rpi-review` skill and delete its business-alignment reference and the optional note section from the review template.
3. Remove the Business Alignment section from the changes-record template and the capture rule from `rpi-implement`.
4. Remove the citation, search, and status rule from `rpi-plan`.
5. Record the reversal in a superseding ADR that links back to this one and sets `superseded-by` here.

No data migration is required. Existing plans, changes records, and review records remain readable because the added sections are optional.

## Affected Components

* .github/skills/rpi/rpi-plan/SKILL.md
* .github/skills/rpi/rpi-plan/references/planning.md
* .github/skills/rpi/rpi-implement/SKILL.md
* .github/skills/rpi/rpi-implement/references/implementation.md
* .github/skills/rpi/rpi-implement/templates/changes-log.md
* .github/skills/rpi/rpi-review/SKILL.md
* .github/skills/rpi/rpi-review/references/review.md
* .github/skills/rpi/rpi-review/references/business-alignment.md
* .github/skills/rpi/rpi-review/templates/review-log.md
* .github/agents/coding-standards/code-review.agent.md
* .github/skills/coding-standards/code-review/references/output-formats.md

## More Information

* Planning: `.github/skills/rpi/rpi-plan/SKILL.md` points to the citation and status rule in `.github/skills/rpi/rpi-plan/references/planning.md`.
* Implementation: `.github/skills/rpi/rpi-implement/SKILL.md` points to the capture rule in `.github/skills/rpi/rpi-implement/references/implementation.md`, and `.github/skills/rpi/rpi-implement/templates/changes-log.md` defines the Business Alignment section.
* Review: `.github/skills/rpi/rpi-review/SKILL.md` and `.github/skills/rpi/rpi-review/references/review.md` point to `.github/skills/rpi/rpi-review/references/business-alignment.md`, and `.github/skills/rpi/rpi-review/templates/review-log.md` defines the optional note section.
* Code Review: `.github/agents/coding-standards/code-review.agent.md` loads the shared core and sub-sections of `.github/skills/rpi/rpi-review/references/business-alignment.md`, and `.github/skills/coding-standards/code-review/references/output-formats.md` defines the `business_alignment` field and report sections.
* Source fields come from the requirements-author BRD and PRD templates (`owners`, `status`, `lineage`) and the ADR frontmatter (`deciders`, `status`, `superseded-by`).
* The second increment is expected to touch the backlog-management per-platform references, the functional-planner skill, and the ADR handoff instructions. A later decision may refine its design when it is planned.

## ADR Planning

> [!CAUTION]
> **Disclaimer:** This agent is an assistive tool only. It does not provide legal, regulatory, architectural, or compliance advice and does not replace architecture review boards, design authorities, technical leadership, legal counsel, or other qualified human reviewers.
> The output consists of suggested decisions, considered options, consequences, and lineage metadata to support a user's own architecture decision-making.
> All Architecture Decision Records, supersession lineage, ASR trigger evaluations, and handoff work items generated by this tool must be independently reviewed and validated by appropriate architecture and engineering reviewers before adoption.
> Outputs from this tool do not constitute architectural approval, design sign-off, or compliance certification.

* [ ] Reviewed and validated by a qualified human reviewer

---

🤖 *Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
