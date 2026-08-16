---
title: Workshop Requirements Draft
description: Concise requirements draft for the FSI relationship manager workshop scenario
sidebar_position: 2
author: Microsoft
ms.date: 2026-08-15
ms.topic: reference
keywords:
  - workshop
  - requirements
  - FSI
  - relationship manager
estimated_reading_time: 5
---

## Workshop Requirements Draft

This draft consolidates the relationship manager scenario into a concise product requirements view for workshop use. It is intended for review by design, product, and engineering before deeper backlog refinement.

### Problem Statement

Relationship managers spend too much time collecting fragmented customer context before conversations and follow-up work. They need a trusted, single view that highlights risks, opportunities, and next-best actions so they can prepare quickly and follow through consistently.

### Business Goals

* BR-01 Improve account coverage and retention by helping relationship managers act on the most important signals sooner.
* BR-02 Increase cross-sell and upsell opportunity capture through earlier identification of growth moments.
* BR-03 Reduce missed follow-up and delayed actions by surfacing clear next steps with supporting evidence.

### Target Users

* PR-01 Relationship manager: prepares for customer conversations and needs a trusted view of account health and recommended actions.
* PR-02 Team lead or account owner: needs to prioritize coverage and monitor which accounts require attention.
* PR-03 Risk or compliance reviewer: needs explainable recommendations and confidence in the evidence behind them.

### Scope

#### In Scope

* Consolidate customer, account, and activity signals from multiple sources into one view.
* Surface priority accounts and identify the most valuable next actions.
* Highlight risks and growth opportunities with supporting evidence.
* Support human-reviewable follow-up and action tracking.

#### Out of Scope

* Full workflow automation across all business processes.
* Production-sensitive customer data or credentials.
* A broad multi-industry platform release in the first version.

### Assumptions and Constraints

#### Assumptions

* Approved enterprise data sources will be available for the workshop scenario.
* Relationship managers and reviewers will help validate the signal set and recommendation quality.

#### Constraints

* C-01 No production credentials, personal data, customer secrets, or sensitive content may be used in the workshop scenario.
* C-02 The solution must remain concise, reviewable, and suitable for collaborative workshop use.
* C-03 The initial scope should remain scenario-specific rather than expanding into a generalized platform vision.

### Functional Requirements

* FR-01 The experience must consolidate customer, account, and activity signals from multiple sources into a single view.
* FR-02 The experience must highlight priority accounts and identify the most valuable next actions.
* FR-03 The experience must surface both risk indicators and growth opportunities with supporting evidence.
* FR-04 The experience must recommend actions that help the user deepen relationships and grow revenue.
* FR-05 The experience must support fast follow-up with clear, explainable recommendations that the user can trust.

### Non-Functional Requirements

* NFR-01 The experience must present recommendations with enough context for a human reviewer to understand why they were suggested.
* NFR-02 The experience must be usable in a fast-paced workflow, with response times that support real-time preparation for customer interactions.
* NFR-03 The experience must protect sensitive information and avoid exposing credentials, personal data, or production secrets.
* NFR-04 The experience must be reviewable and understandable for workshop stakeholders, including business, design, and technical participants.

### Data and AI Requirements

* DAI-01 The system must use approved enterprise data sources such as CRM records, email or call context, transaction history, and internal knowledge content.
* DAI-02 Recommendations must be grounded in cited evidence and must distinguish between observed facts and inferred suggestions.
* DAI-03 The experience must support human review of AI-generated recommendations before action is taken.
* DAI-04 The system must avoid using unverified or unsupported claims as customer facts.

### Business Rules

* Recommendations must be tied to visible evidence and understandable to a human reviewer.
* Human approval is required before any operational action is executed from a suggestion.
* The system must prioritize clarity and trust over automation when evidence is incomplete.
* Only approved enterprise data sources may be used in the experience.

### Known Failure Cases

* Source data is missing, stale, or inconsistent.
* Signals conflict and the system cannot determine a clear priority.
* The recommendation confidence is low and should be shown as uncertain.
* No reasonable next-best action can be produced for the current account state.

### Success Metrics

* Time to understand account context before an interaction: target less than 5 minutes.
* Percentage of prioritized actions completed within 24 hours: target greater than 70%.
* Conversion rate of recommended opportunities into customer actions: target greater than 12%.
* Improvement in account coverage for priority relationships: target greater than 85%.

### Acceptance Criteria

* AC-01 When a relationship manager opens the experience for an account, the system presents consolidated context and the most relevant next action within the first screen.
* AC-02 When an account shows elevated risk or growth potential, the system highlights that signal and provides supporting evidence.
* AC-03 When the user reviews a recommendation, the system shows the underlying evidence and allows the user to understand the reasoning.
* AC-04 When the user completes a recommended action, the system records that action as part of the follow-up workflow.

### AI Guardrails

* Do not fabricate evidence, customer facts, or actions that are not supported by approved data.
* Clearly label uncertainty, low-confidence outputs, and inferred recommendations.
* Show the rationale and evidence behind every recommendation so it can be reviewed by a human.
* Avoid exposing sensitive or personally identifiable information outside approved contexts.
* Fail safely when data is incomplete or the system cannot produce a trustworthy recommendation.
