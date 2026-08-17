---
title: Experience Outline: Relationship Manager for FSI
description: Sample user experience brief for the financial services relationship manager workshop scenario
author: Microsoft
ms.date: 2026-08-17
ms.topic: reference
keywords:
  - sample
  - FSI
  - experience
  - workshop
estimated_reading_time: 5
---

# Experience outline: Relationship Manager for FSI

## Scenario summary

A relationship manager needs a trusted view of each account before customer conversations and follow-up work. The experience should help them quickly understand account health, surface risks and growth opportunities, and choose the next best action with confidence.

## Simple user journey

1. Prepare for the conversation
   * The relationship manager opens the account view for a priority client.
   * The experience gathers CRM data, email history, call notes, transaction activity, and internal knowledge into one place.

2. Review account context
   * The manager sees the latest signals, account health, and likely risks or opportunities.
   * The experience highlights which accounts need attention now and why.

3. Decide on the next step
   * The manager reviews suggested talking points, likely next actions, and the evidence behind each recommendation.
   * The experience helps them act quickly without starting from scratch.

4. Follow up after the interaction
   * The manager captures the next action and moves smoothly to execution.
   * The experience supports consistent follow-through and keeps the team aligned.

## Experience outline

* A unified view of customer, account, and activity signals
* Clear prioritization of accounts that need attention now
* Visible risk indicators and growth opportunities with supporting evidence
* Recommended next-best actions that are explainable and easy to trust
* A fast path from insight to follow-up so the manager can act promptly

## Key pain points

* Context is scattered across multiple tools, which slows preparation.
* Too much time is spent gathering information before each interaction.
* It is hard to tell which accounts need immediate attention.
* Risk exposure and growth potential are not always clear.
* Follow-through is inconsistent, which weakens retention and revenue outcomes.

## Accessibility requirements

* The experience must be fully keyboard accessible for reviewing account summaries, priority actions, and follow-up choices.
* Content must be structured with clear headings and labels so screen-reader users can navigate the account view efficiently.
* Priority signals, risks, and recommended actions must not rely on color alone; they should include text labels or icons with text alternatives.
* Text and interactive elements must meet strong contrast and readable sizing standards.
* Recommendations should be presented in plain language with visible evidence and a clear explanation of why the action matters.
* The experience should support predictable focus order and clear confirmation feedback for actions such as approve, defer, or escalate.

## Accessibility user needs

* Users need to understand the most important account information quickly without reading a long or dense screen.
* Users need to distinguish between priority actions, risks, opportunities, and evidence without ambiguity.
* Users need to trust and review recommendations through clear, readable explanations.
* Users need to complete core tasks with assistive technologies, including keyboard navigation and screen readers.
* Users need a low-cognitive-load experience that reduces confusion during time-sensitive interactions.

## Follow-up questions for implementation

* Which screens or components are most critical for keyboard and screen-reader testing?
* How should recommendation confidence and evidence be presented when data is incomplete or uncertain?
* What accessibility validation tools and assistive technologies should be used during implementation?
* Should the experience include a simplified view for high-pressure or time-sensitive workflows?
* How will users review, override, or dismiss a suggested action if they do not agree with it?
* How should the experience support users who need more time, clearer language, or reduced visual complexity?

## Responsible AI requirements

* Recommendations must be explainable and traceable to visible evidence.
* The experience should clearly label uncertain, low-confidence, or inferred recommendations.
* Users must be able to review, override, or reject suggested actions before they are acted on.
* The experience should avoid exposing sensitive or personally identifiable information beyond what is necessary for the task.
* The system should fail safely when data is missing, incomplete, or inconsistent.
* Human review should remain part of the workflow for high-impact actions.

## Potential harms

* Recommendations may be wrong, incomplete, or overly confident.
* Users may over-trust suggested actions without reviewing the evidence.
* Sensitive customer information could be exposed if data handling is not carefully limited.
* Bias in underlying data could lead to unfair or skewed prioritization.
* The experience could create automation bias by making users feel they should follow recommendations without question.

## Mitigation ideas

* Show the evidence, confidence level, and rationale for each recommendation.
* Require a human review step before operational action is taken.
* Use clear labels for uncertainty and provide an option to request more context.
* Limit visible data to approved fields and protect sensitive information.
* Review data sources and recommendation logic for bias, fairness, and quality issues.
* Capture user feedback and review outcomes to improve the experience over time.

## Microsoft 365 Copilot integration benefits

* End users could save time by asking Copilot to summarize account context, recent interactions, and likely next steps in natural language.
* Relationship managers could prepare more quickly for customer conversations by using Copilot to pull together evidence from existing documents, notes, and account history.
* The experience could help users draft follow-up emails, meeting notes, and action summaries more consistently.
* Copilot could reduce manual effort in reviewing fragmented data and support better focus on customer relationships rather than admin work.
* The integration could improve confidence if Copilot surfaces concise, evidence-based summaries that are easy to review and verify.

## Research needed to validate the value

* Run interviews with relationship managers, team leads, and reviewers to understand where they currently lose time and where Copilot would be most useful.
* Observe a sample of existing workflows to identify the most frequent preparation and follow-up tasks that could benefit from AI assistance.
* Test a prototype with users to measure whether Copilot-generated summaries and next-step suggestions improve speed, clarity, and trust.
* Validate whether users prefer Copilot output that is short, explainable, and grounded in visible evidence.
* Assess whether the integration changes behavior in a positive way, such as faster follow-up, better account coverage, or improved confidence in recommendations.
* Confirm that users understand the limits of Copilot and still want human review for important decisions.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
