---
title: Financial Services Industry Context
description: Financial services industry context, vocabulary, and constraints for tailoring Design Thinking methods to this sector.
---

Load this file when the team identifies financial services as their industry context. It provides financial services-specific vocabulary, constraints, empathy tools, and a reference scenario that the coach weaves into method-specific guidance.

## Industry Profile

* **Sector**: Banking (retail, commercial, investment), insurance (property & casualty, life, health), payments, wealth management, fintech
* **Key stakeholders**: Relationship managers, underwriters, claims adjusters, compliance officers, credit risk officers, traders, operations teams, AML analysts, fraud analysts, actuaries, product managers, regulators
* **Decision cadence**: Real-time (payments, trading), intraday (liquidity monitoring), daily (settlement, reconciliation), quarterly (regulatory reporting, capital planning), annual (compliance cycles, rate filings)
* **Regulatory environment**: Dodd-Frank (U.S.), Basel III/IV (banking), GLBA/GDPR/CCPA (privacy), PCI DSS (payments), FINRA/FCA/MiFID II (market conduct), CFPB (consumer protection), state insurance regulators (NAIC), OFAC/BSA/AML (sanctions), CCAR stress testing (banking capital), fair lending laws
* **Missing voices to seek out**: Back-office operations staff, remote branch employees, customers with limited financial literacy, customers outside core market segments (immigrants, gig workers, minorities affected by fair lending concerns)

## Vocabulary Mapping

Bridge DT language and financial services language bidirectionally. Use financial services terms when coaching finance teams.

| DT Concept                | Financial Services Term                                      |
|---------------------------|--------------------------------------------------------------|
| Stakeholder map           | RACI chart, three-lines-of-defense alignment                 |
| Pain point                | Friction in customer journey, operational loss event         |
| User journey              | Customer onboarding flow, loan origination path, claims lifecycle |
| Observation / field study | Branch shadowing, call center side-by-side, ops center watch |
| Prototype                 | Controlled experiment, champion-challenger test, sandbox pilot |
| Iteration                 | Agile sprint, staged rollout (cohort expansion)              |
| Empathy                   | Customer perspective, operational staff perspective          |
| Success metric            | NPS, CSAT, STP rate (straight-through processing), first-call resolution |
| Workflow mapping          | Process swimlane, settlement workflow, approval workflow     |
| Risk assumption           | Conduct risk, model risk, operational risk, fair lending risk |
| Constraint-driven design  | Compliance gate, regulatory approval requirement             |
| Alert system concept      | AML SAR trigger, fraud alert, risk dashboard alert           |
| Integration timing        | Settlement window, regulatory reporting deadline             |

## Constraints and Considerations

### Regulatory Gating

Every meaningful change touches at least two regulatory frameworks. Dodd-Frank, Basel III, GLBA, GDPR, CCPA, PCI DSS, fair lending laws, and state insurance regulations create overlapping approval requirements. Customer-facing redesigns require legal and compliance pre-approval before any external testing. Solutions involving lending, pricing, or payments require regulatory review before pilot deployment. The review timeline is measured in weeks to months, not days.

### Three-Lines-of-Defense Governance

Financial institutions operate under a three-lines model: (1) business units manage day-to-day risk, (2) risk and compliance functions provide oversight and regulatory interface, (3) audit provides independent assurance. DT activities must engage all three lines from scope conversations forward. Business unit sponsors champion discovery. Risk/compliance teams have pre-deployment veto authority. Audit scrutinizes documentation and control effectiveness. Coaches must map all three lines and secure alignment before ideation.

### Conduct Risk

Financial services organizations operate in a "conduct risk" framework where customer harms, regulatory violations, or reputational damage cascade quickly. Conduct risk is career-affecting for managers whose business units generate incidents. Frame "fail fast" as rapid *learning cycles* within sandboxed environments (simulation, test data), not permission to deploy before regulatory approval. Staged rollout from low-risk cohorts (internal staff, low-balance accounts) to high-risk cohorts is the standard risk mitigation pattern.

### Operational Windows and Settlement

Financial systems operate in discrete operational windows tied to clearing, settlement, and regulatory reporting deadlines. End-of-day trade settlement (T+1 or T+2) has fixed cutoff times; no changes after cutoff. OFAC/KYC screening runs in batch windows (24-48 hours) during account onboarding; onboarding delays during these windows are non-negotiable. CCAR stress-test cycles (Feb-June) consume key stakeholders in risk, finance, and treasury; schedule DT activities during post-CCAR windows (July-Sept) to ensure stakeholder availability.

### Data Sensitivity and Privacy

Customer financial data falls under GLBA (U.S.), GDPR (EU), and CCPA (California) with severe breach penalties. Prototyping with real customer data requires legal clearance or data residency/de-identification approval. Payment card data must never appear in prototypes outside PCI-certified environments. Regulatory data (audit reports, compliance findings) may be classified. Prototypes handling financial data need privacy review even in pilot form.

### Model Risk and Fair Lending

Banking and insurance rely on statistical/ML models for credit underwriting, pricing, and risk assessment. Federal Reserve Supervisory Guidance (SR 11-7) requires independent model validation and bias testing for models affecting customer decisions. Fair lending laws (ECOA) require demonstrable neutrality in credit underwriting models and disparate impact analysis. Model redesigns cannot be prototyped rapidly; bias audit and explainability validation are pre-deployment gates, not post-launch learning activities.

## Empathy Tools

### Branch / Call Center Shadowing

Observe relationship managers, tellers, and customer service representatives during real customer interactions. Track questions asked repeatedly, moments of customer confusion, workarounds for system limitations, and handoffs to operations or compliance. Note the gap between what customers are told (e.g., "we need this document") and what information actually flows back to operations. Shadow during peak hours (morning deposits, quarter-end) and during off-peak hours to capture different operational rhythms.

### Customer Journey Diary (Multi-week)

Structured observation of customer experience during account opening, loan origination, or claims processing. Request a volunteer to complete a daily journal across 2-4 weeks capturing wait times, information requests, rework, delays, and emotional moments (frustration at ambiguous rejections, relief at approval). This reveals system friction invisible from staff perspective — particularly in regulatory gates where customers receive ambiguous rejection reasons or multi-day delays with no explanation.

### Back-Office Operations Observation

Watch reconciliation teams, AML analysts, and settlement operations during peak activity. Observe how they resolve exceptions, handle failed transactions, and coordinate across systems. Note where system constraints force manual workarounds. Identify the invisible handoff failures between front-office (customer-facing) and back-office (operations). Exception handling often surfaces the highest-value use cases.

### Anonymized Complaint and Regulatory Finding Review

Use customer complaints, regulatory examination findings, and conduct-incident documentation as empathy artifacts. These reveal repeated failure modes, systemic pain points, and the customer's experience of system failures. Fair lending complaints show where models or processes created unintended disparities. Claims complaints expose where customers felt treated unfairly or received inadequate information.

## Reference Scenario

**Context**: A regional bank's account opening process takes 3-5 days and has a 15% abandonment rate. Customer satisfaction during onboarding is the lowest NPS detractor in the quarterly survey.

**Discovery (Methods 1-3)**: Scope conversations reveal the initial request is "build a mobile account opening app." Customer journey diaries and call center shadows uncover the real problem: KYC/AML batch screening windows (24-48 hours) and ambiguous rejection reasons create customer anxiety and repeated support calls. Customers don't understand why they're rejected or what documents to provide. Back-office reconciliation observations reveal 40% of onboarding exceptions are documentation mismatches that staff manually resolve.
The core friction is not form-filling complexity; it's information asymmetry and regulatory batch-window timing.

**Solution (Methods 4-6)**: Brainstorming generates solution themes: proactive status communication during screening windows, clear rejection reason explanations, self-serve document re-submission, and account pre-staging (allow deposits while KYC completes). Lo-fi prototypes — paper mockups of status page templates, revised rejection email templates, and decision trees for self-remediation — reveal that customers need different communication during each KYC/AML phase (initial submission, review, approval). Compliance escalation surfaces OFAC requirements (sanctions list matching must complete before account activation) and fair lending risk (status communication must not vary by protected characteristics).

**Implementation (Methods 7-9)**: Hi-fi prototypes validate status communication integrated with the core banking system, tested through the KYC/AML batch environment before customer rollout. User testing reveals night-time/weekend account openings queue until Monday morning when compliance staff work — communicate this proactively. Staged rollout begins with existing customers adding linked accounts (low-risk), then new customers (high-risk). NPS improves 18 points during pilot. Iteration focuses on rejection handling — customers report clearer explanations reduce support volume and re-abandonment.

* All DT coaching artifacts are scoped to `.copilot-tracking/dt/{project-slug}/`. Never write DT artifacts directly under `.copilot-tracking/dt/` without a project-slug directory.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
