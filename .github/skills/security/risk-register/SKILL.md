---
name: risk-register
description: 'Create a qualitative risk register and mitigation plan using a Probability x Impact matrix. Use when a project needs structured risk identification, scoring, ownership, and response planning.'
argument-hint: '[project-name=...] [focus-area=...]'
license: MIT
user-invocable: true
disable-model-invocation: true
---

# Risk Register Generator

> [!CAUTION]
> This skill is an **assistive tool only** and does not replace professional security and risk management tooling or qualified human review. All generated risk registers, risk scores, and mitigation strategies must be reviewed and validated by qualified security and risk professionals before use. AI outputs may contain inaccuracies, miss critical risks, or produce assessments that are incomplete or inappropriate for your environment.

## Purpose and Role

Act as a risk management assistant. Help the user identify, document, and prioritize project risks using a qualitative risk assessment approach based on a Probability × Impact (P×I) risk matrix.

Use clear, simple, professional language and avoid unnecessary detail. Do not use abbreviations for field names or headings unless they are widely recognized and unambiguous. Place all outputs in the `docs/risks/` folder.

## Inputs

* `project-name` (optional): Project name used for context and, in multi-project repositories, file naming.
* `focus-area` (optional): Risk focus area, domain, component, milestone, or concern to emphasize.

## Step 1: Gather Project Context

If not already available in the repository, ask the user to provide:

* Project name and short description.
* Timeline and key milestones.
* Stakeholders and dependencies.
* Technical components or systems involved.
* Known risks or concerns.
* Sources of uncertainty.
* Assessment of potential consequences related to project objectives.

## Step 2: Prepare Risk Documentation Structure

* Ensure the folder `docs/risks/` exists. Create it if missing.
* Place all generated files inside the `docs/risks/` folder.
* Use clear and direct file names and headings.

File naming conventions:

* Primary register: `risk-register.md`.
* Versioned register snapshot: `risk-register-YYYY-MM-DD.md`.
* Mitigation plan: `risk-mitigation-plan.md`.
* Multi-project repository register: `risk-register-[project-name].md`.

## Step 3: Create `risk-register.md` in `docs/risks/`

Include these sections:

* Executive Summary.
* Project Overview.
* Risk Assessment Methodology.
* Overview Table of Risks.
* Detailed Risk Entries.

### Risk Assessment Methodology

Document this methodology in the register:

* Risks are scored using a P×I matrix with qualitative bands (Low, Medium, High) for both Probability and Impact.
* Default Probability scale:
  * Low: unlikely.
  * Medium: possible.
  * High: likely.
* Default Impact scale:
  * Low: minor effect.
  * Medium: moderate effect.
  * High: major effect.
* Risk Score (Qualitative) = Probability × Impact using qualitative labels, such as High × Medium.
* Risk Score (Numeric) converts qualitative ratings to numbers for sorting:
  * Low = 1.
  * Medium = 2.
  * High = 3.
  * Example: High × Medium = 3 × 2 = 6.
* Document rationale for each rating in 1 to 2 lines for consistency.

### Overview Table of Risks

Use these columns:

* Risk ID.
* Risk Title.
* Description (Cause → Event → Impact).
* Probability (Low, Medium, High).
* Impact (Low, Medium, High).
* Risk Score (Qualitative) = Probability × Impact, such as High × Medium.
* Risk Score (Numeric) = Numeric value for sorting, such as 6.

Example:

| Risk ID | Risk Title                 | Description (Cause → Event → Impact)                                                                                                    | Probability | Impact | Risk Score (Qualitative) | Risk Score (Numeric) |
|---------|----------------------------|-----------------------------------------------------------------------------------------------------------------------------------------|-------------|--------|--------------------------|----------------------|
| R-001   | API rate limits exceeded   | High request volume without effective throttling → API rate limits are exceeded → Requests fail and downstream workflows degrade        | High        | Medium | High × Medium            | 6                    |
| R-002   | Key developer unavailable  | Single point of knowledge in a key area → Key developer becomes unavailable → Delivery slows and defects increase                       | Medium      | High   | Medium × High            | 6                    |
| R-003   | Third-party service outage | Dependency on an external provider → Third-party service becomes unavailable → Features relying on it fail and user experience degrades | Medium      | Medium | Medium × Medium          | 4                    |

### Detailed Risk Entries

Include these fields for each risk:

* Risk ID and Title.
* Description (Cause → Event → Impact).
* Probability and Impact ratings plus rationale.
* Risk Score (Qualitative) = Probability × Impact, such as High × Medium.
* Risk Score (Numeric), such as 6.
* Category.
* Mitigation Strategy.
* Contingency Plan.
* Trigger Events.
* Owner.
* Status.

Use short, focused descriptions. Avoid jargon and unnecessary elaboration. Sort all risks by descending Risk Score (Numeric) to highlight the most critical risks.

## Step 4: Create `risk-mitigation-plan.md` in `docs/risks/`

Base the mitigation plan on the mitigation strategies already defined in `risk-register.md`. Focus on the highest priority risks, especially those with high probability and high impact, and summarize the planned responses.

Use this outline:

* Top Priority Risks (High Uncertainty and High Consequence).
* Risk Response Actions derived from mitigation strategies in `risk-register.md`.
* Resource Requirements.
* Communication Plan.
* Risk Reassessment Schedule.

## Guidelines

* Use Cause → Event → Impact format for risk statements.
* Define and document qualitative scales upfront.
* Record rationale for each rating.
* Include trigger events and assign a single accountable owner per risk.
* Establish reassessment cadence and closure criteria.
* Use clear, concise, and simple language throughout all sections.
* Avoid unnecessary detail or verbosity.
* Avoid abbreviations for field names or headings, for example use "Priority" instead of "P", unless they are widely recognized and unambiguous.
* Include both technical and non-technical risks.
* Focus on actionable mitigation strategies.
* Consider internal and external risk factors.

## Stop Rules

* Ask for missing project context when repository evidence and user input do not provide enough information to identify meaningful risks.
* Stop before writing tracker-bound or externally visible risk artifacts outside `docs/risks/`.
* Stop before treating generated risks, scores, or mitigations as final without qualified human review.

## Success Criteria

* `docs/risks/` contains the generated risk register and mitigation plan.
* The risk register defines the qualitative Probability × Impact scoring method and rating rationale.
* The overview table and detailed entries use the required fields.
* Risks are sorted by descending numeric score.
* The mitigation plan is derived from the register and focuses on the highest priority risks.
