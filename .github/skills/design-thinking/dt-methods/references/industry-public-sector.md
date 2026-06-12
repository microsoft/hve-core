---
title: Public Sector & Government Industry Context
description: Public sector and government industry context, vocabulary, and constraints for tailoring Design Thinking methods to this sector.
---

Load this file when the team identifies public sector or government as their industry context. It provides government-specific vocabulary, constraints, empathy tools, and a reference scenario that the coach weaves into method-specific guidance.

## Industry Profile

* **Sector**: Federal, state, and local government agencies delivering public services (benefits, licensing, permitting, civil services)
* **Key stakeholders**: Caseworkers (frontline staff), program managers, policy officers, constituents/citizens, IT/security/privacy specialists, procurement officers, union representatives, compliance auditors
* **Decision cadence**: Real-time (caseworker interactions), daily (shift operations), weekly (program reviews), quarterly (compliance audits), multi-year (budget cycles), political (administration changes every 4-8 years)
* **Regulatory environment**: Section 508 (accessibility), FedRAMP (cloud security), Privacy Act, SORN (Systems of Records Notice), FOIA, Plain Language Act, Paperwork Reduction Act (PRA), FISMA, FAR (Federal Acquisition Regulation)
* **Missing voices to seek out**: Night/weekend shift caseworkers, constituent representatives from underserved populations, frontline supervisors, IT operations staff, prior unsuccessful pilot participants

## Vocabulary Mapping

Bridge DT language and government language bidirectionally. Use government terms when coaching government teams.

| DT Concept                | Government Term                                               |
|---------------------------|---------------------------------------------------------------|
| Stakeholder map           | RACI chart, organization chart, cross-agency workgroup roster |
| Pain point                | Service gap, process inefficiency, compliance violation       |
| User journey              | Service blueprint, customer journey, constituent experience   |
| Observation / field study | Ride-along, case study, site visit, constituent interview     |
| Prototype                 | Pilot project, demonstration site, test-and-learn initiative  |
| Iteration                 | PDSA cycle (Plan-Do-Study-Act), continuous improvement cycle  |
| Empathy                   | Constituent voice, lived experience, equity lens              |
| Success metric            | SLA (Service Level Agreement), KPI, compliance rate           |
| Workflow mapping          | Service blueprint, process flow, business process model       |
| Risk assumption           | Root cause analysis, compliance gap, failure mode analysis    |
| Constraint-driven design  | Regulatory requirement, policy mandate, appropriation limit   |
| Accessibility             | Section 508 compliance, WCAG 2.0 AA conformance               |
| Privacy/data              | PII handling, SORN requirement, Privacy Impact Assessment     |
| Solution adoption         | Change management, workforce communication, training rollout  |

## Constraints and Considerations

### Regulatory Non-Negotiables

Accessibility, privacy, and security are not preferences — they are legal requirements. **Section 508 of the Rehabilitation Act** mandates WCAG 2.0 AA conformance for all digital services. **The Privacy Act** restricts how citizen data is collected, used, and retained. **FedRAMP** pre-certification is required before federal agencies can use cloud services. Designs that violate these constraints will not be approved for deployment, regardless of user benefit. Build compliance into every prototype and test plan.

### Burden Hours and PRA Constraints

The Paperwork Reduction Act (PRA) limits how many questions government can ask of the public. Every new question or data collection requires OMB approval and counts against an agency's "burden hours" budget. This directly limits requirement discovery scope — you cannot simply ask citizens to fill out comprehensive surveys or participate in lengthy interviews without PRA approval. Leverage existing data collection authorities (forms already in use, systems already measuring) whenever possible. This constraint often blocks the DT instinct to ask "everything" in discovery research.

### Multi-Administration Transitions

Federal leadership changes every 4-8 years, bringing new policy directions and budget priorities. Prior investments may be deprioritized or canceled. Solutions must be framed in terms of durable public value, not incumbent administration objectives. Build sunset clauses, modular contracts, and vendor transition provisions into deployment plans. Expect that your innovation roadmap may be interrupted by political change.

### Civil Service Culture and Union Constraints

Government workforce culture emphasizes job security, seniority protection, and role specialization. Union agreements can constrain how work is reorganized, what tasks are automated, and what staffing changes are allowed. Labor negotiations can delay or block changes. Engage union representatives early in the coaching process — they have veto authority alongside security and compliance officers. Frame solutions as tools that support workers, not replacements for jobs.

### Digital Divide and Constituent Diversity

Citizens using government services have variable digital literacy, broadband access, language capability, and trust in government systems. Prior failed initiatives (security breaches, fraud, service outages) create skepticism. Solutions must offer phone and paper alternatives to digital pathways. Language access requirements (Title VI, Executive Orders) mandate translation and interpretation. Test extensively with low-literacy, non-English-speaking, and offline-first constituent segments. "Digital first" is not appropriate for public services — "digital and paper" is the public sector model.

### Procurement and Contracting Rigidity

Vendor selection is constrained by GSA schedules, competitive procurement rules, and incumbent relationships. Long procurement cycles (6-12+ months) delay implementation. Contracts often specify detailed requirements upfront, making agile iteration difficult without formal change orders. The Federal Acquisition Regulation (FAR) requires competitive bidding for most acquisitions. Engage procurement officers early — the **TechFAR Handbook** provides guidance for agile procurement, but not all teams are familiar with it. Modular contracting and frequent deliverables are possible within FAR but require intentional contract design.

### Legacy System Integration

Most government agencies operate decades-old mainframe systems (COBOL, older databases). New solutions must integrate with or augment legacy systems, not replace them wholesale. "Modernization" in government often means integration and data bridge-building, not greenfield development. Budget and timeline assumptions must account for legacy system constraints and integration testing complexity.

## Empathy Tools

### Caseworker Ride-Along

Observe a caseworker through a full shift or half-shift. Track case transitions, system navigation, manual workarounds, and information handoffs. Pay attention to moments where the caseworker improvises or works around system limitations — these reveal design gaps and regulatory constraints invisible from policy documents. Observe shift-change handoffs where information is transferred; note what gets lost. Use progressive questioning: "Walk me through a typical case" before drilling into specific workflows. Respect confidentiality — never access actual constituent data without proper authorization.

### Constituent Journey (Offline + Online)

Map a constituent's experience applying for a benefit or service across all touchpoints: online portal, phone calls, in-person visits, mailed documents, wait times, status uncertainty. Include the moments before application (research phase) and after approval (onboarding to service). Capture emotional trajectory alongside functional touchpoints. Identify where the constituent must re-explain information to multiple staff, where they lack status visibility, and where language/literacy barriers surface. This reveals system design failures that neither caseworkers nor policy documents surface.

### Frontline Supervisor Meeting

Schedule separate time with shift supervisors and team leads. They see patterns across multiple caseworkers and hear about recurring problems, workarounds, and compliance concerns. They often have more candid insights about system limitations and staff burnout than individual caseworkers (due to hierarchy dynamics). Supervisors also bridge to policy/compliance layers — understand what mandates flow down and where implementation constraints emerge.

### Regulatory Compliance Review

Request relevant policy documents, compliance audit reports, and prior failed pilot summaries. Compliance audit findings and incident reports (redacted appropriately) reveal the actual failure modes and risk patterns the organization is managing. Prior pilot retrospectives show what barriers blocked adoption or sustainability. These artifacts provide evidence-based starting points for DT discovery, more grounded than generic brainstorming.

## Reference Scenario

**Context**: A state benefits agency experiences 6-month processing delays for unemployment insurance applications, constituents must call weekly for status updates, and caseworkers work 10+ hour days navigating fragmented systems. Application abandonment rate is rising. Policy expects a new intake portal, but leadership is skeptical that digital-first design will solve for constituents without broadband or digital literacy.

**Discovery (Methods 1-3)**: Scope conversations reveal the initial request is "build a modern intake portal." Constituent journey mapping and caseworker ride-alongs uncover the real problem: information fragmentation. Constituents enter data through a 30-question online form, but caseworkers re-enter key information into three separate legacy systems because automated integration is incomplete. Processing delay is driven by caseworker re-data-entry, not constituent application complexity. Caseworkers report 10 workarounds per shift to bridge system gaps.

Wait times correlate with information handoffs, not system capacity. Constituents without broadband apply by phone, and phone applications bypass the intake portal entirely — caseworkers manually enter phone-collected data into all three legacy systems, creating 3× the work. The real solution involves data integration and caseworker workflow redesign, not a constituent-facing portal.

**Solution (Methods 4-6)**: Brainstorming generates four solution themes: data bridge (eliminate re-entry), caseworker workflow (reduce handoffs), constituent communication (proactive status updates via SMS), and phone-first parity (ensure phone paths are efficient). Lo-fi prototypes reveal that caseworkers struggle with new workflows when legacy system integration is incomplete — they revert to manual entry under time pressure. Prototypes identify that SMS status updates drive 40% fewer support calls (validation of a high-value use case).

**Implementation (Methods 7-9)**: Hi-fi prototypes validate that a middleware data layer reduces re-entry by 80% and caseworker processing time by 6+ hours per week. User testing with frontline caseworkers, supervisors, and constituent representatives (including low-literacy and non-English-speaking segments) reveals that phone-first parity is more critical than portal sophistication. A phone queue optimization experiment (faster routing to available caseworkers) reduces wait times by 2 weeks without IT investment.

Deployment includes: data integration (slow path, multi-phase), phone workflow redesign (fast path, 4-week pilot), SMS pilot (3-month test), and caseworker training. Sustainability depends on ongoing caseworker feedback loops and union partnership — any workflow changes require labor agreement consultation. Handoff to operations includes runbooks for multi-system monitoring, incident response, and admin oversight.

* All DT coaching artifacts are scoped to `.copilot-tracking/dt/{project-slug}/`. Never write DT artifacts directly under `.copilot-tracking/dt/` without a project-slug directory.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
