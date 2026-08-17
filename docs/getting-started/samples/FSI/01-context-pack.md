# Context Pack FSI

## Platform

* Platform: Operations Intelligence Platform
* Purpose: Help teams turn operational signals into timely decisions, coordinated actions, and measurable outcomes across business functions.
* Scope: Focus on high-value scenarios that combine data, workflow, and agent-assisted execution.

## Selected industry scenarios

* Financial services: Relationship Manager

## Active scenario

* Scenario title: Relationship Manager Intelligence Experience
* Business problem: Relationship managers often work from fragmented information spread across CRM systems, email threads, call notes, transaction history, and internal knowledge sources. They spend too much time gathering context and too little time acting on the most valuable opportunities. As a result, they can miss early warning signals, delay follow-up, and overlook high-potential cross-sell or upsell moments.
* Core challenges:
  * Fragmented customer and account insights across multiple tools
  * Manual research and data gathering before each client interaction
  * Difficulty prioritizing accounts that need attention now
  * Limited visibility into risk, growth potential, and next-best actions
  * Inconsistent follow-through that reduces retention and revenue outcomes
* Desired outcome: Give the relationship manager one trusted view of account health, customer signals, risk exposure, and recommended actions so they can respond faster, act with confidence, and focus on opportunities that matter most.
* Revenue impact: By surfacing timely, evidence-based recommendations, the organization can improve retention, increase cross-sell and upsell success, grow wallet share, and unlock new revenue through more proactive relationship management.
* User requirements for the product:
  * Consolidate customer, account, and activity signals into a single view
  * Highlight priority accounts and the most valuable next actions
  * Surface both risk indicators and growth opportunities with supporting evidence
  * Recommend actions that help the manager deepen relationships and grow revenue
  * Support fast follow-up with clear, explainable recommendations that the manager can trust

## Team

* PM: Workshop product lead
* SME: Relationship management subject matter expert
* Designer: Experience designer
* Technical lead: Solution architect or engineering lead

## Partner solution framing

* Target users:
  * Primary: Relationship managers who prepare for customer conversations and need timely, trusted guidance.
  * Secondary: Team leads, account owners, and risk or compliance reviewers who need visibility into account priorities and evidence-backed recommendations.
* Jobs to be done:
  * Understand account context quickly before a customer interaction.
  * Identify at-risk accounts and growth opportunities.
  * Prioritize the most valuable next actions.
  * Decide what to say or do next with confidence.
* Business outcomes:
  * Improve retention and account health.
  * Increase cross-sell and upsell opportunity capture.
  * Reduce missed follow-up and delayed actions.
  * Help the organization grow revenue through more proactive relationship management.
* Measurable success metrics:
  * Time to understand account context before an interaction: target less than 5 minutes.
  * Number of prioritized actions completed within 24 hours: target greater than 70%.
  * Conversion rate of recommended opportunities into customer actions: target greater than 12%.
  * Improvement in account coverage for priority relationships: target greater than 85%.
* Stakeholders:
  * Relationship managers as primary users.
  * Business leaders who care about growth, retention, and revenue outcomes.
  * Risk or compliance stakeholders who need explainable recommendations and governance.
  * Product, design, and technical teams building the experience.
  * Sales operations or CRM administrators who support data quality and workflow integration.
* Assumptions:
  * The solution will be framed as a scenario-specific experience rather than a one-size-fits-all platform.
  * The team will capture the scenario details, assumptions, and open questions in this file before expanding to other industries.
  * The product should support explainable recommendations rather than opaque automation.
  * The initial release will rely on approved enterprise data sources and human review of suggested actions.
* Exclusions:
  * No market research or competitor claims are included in this framing.
  * No production-sensitive customer data or credentials.
  * No detailed implementation decisions are assumed at this stage.

## Open questions

* Which customer or operational signals are most important for the first release?
* Which actions should be suggested to the relationship manager first?
* What evidence or approvals are required before the system recommends a next step?
* Which exact user roles should be included in the target-user definition?
* Which stakeholders need to review or sign off on the experience?

## Simple user journey

1. The relationship manager prepares for an upcoming customer conversation or follow-up.
2. They open the account view and quickly review recent signals, account health, and outstanding actions.
3. The experience highlights the highest-priority risks and growth opportunities with supporting evidence.
4. The manager reviews the recommended next-best action and decides whether to act, defer, or escalate.
5. The action is documented for follow-up, with the outcome visible for later review.

## Experience outline

* Account snapshot: a concise summary of recent customer activity, account status, and key signals.
* Priority view: a ranked list of the most important risks, opportunities, and next actions.
* Evidence panel: visible supporting context for each recommendation, including why it matters.
* Action decision: a simple path to review, approve, defer, or escalate a suggested step.
* Follow-up trail: a lightweight record of actions taken and outcomes for future conversations.

## Key pain points

* Context is scattered across multiple tools, which slows preparation.
* Managers spend too much time manually researching before each interaction.
* It is hard to tell which accounts need attention first.
* Recommendations are not always easy to trust without clear evidence.
* Follow-through is inconsistent, which reduces retention and growth opportunities.

## Constraints

* Do not add credentials, personal data, customer secrets, or production content.
* Keep the content concise, reviewable, and suitable for collaborative workshop use.
* The initial experience should remain scenario-specific and human-reviewable rather than fully automated.
