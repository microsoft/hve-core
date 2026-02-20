---
description: 'Healthcare industry context for DT coaching — vocabulary, constraints, empathy tools, and reference scenarios'
applyTo: ''
---

# Healthcare Industry Context

Load this file when the team identifies healthcare as their industry context. It provides healthcare-specific vocabulary, constraints, empathy tools, and a reference scenario that the coach weaves into method-specific guidance.

## Industry Profile

* **Sector**: Healthcare (hospitals, clinics, health systems, digital health)
* **Key stakeholders**: Physicians, nurses, physician assistants, patients, family members, administrators, IT/informatics, pharmacy, lab technicians, social workers, billing/coding specialists, regulatory/compliance officers
* **Decision cadence**: Clinical (real-time patient care), operational (daily staffing, weekly scheduling), strategic (annual budget, multi-year system implementations)
* **Regulatory environment**: HIPAA, CMS conditions of participation, Joint Commission, state licensing boards, FDA (for devices), IRB (for research)
* **Missing voices to seek out**: Night-shift nurses, patients with limited health literacy, non-English speakers, caregivers, outpatient/community health workers

## Vocabulary Mapping

Bridge DT language and healthcare language bidirectionally. Use healthcare terms when coaching healthcare teams.

| DT Concept                | Healthcare Term                                        |
|---------------------------|--------------------------------------------------------|
| Stakeholder map           | Care team mapping, interdisciplinary team roster       |
| Pain point                | Patient safety event, workflow friction, care gap      |
| User journey              | Patient journey, care pathway, clinical workflow       |
| Observation / field study | Patient shadowing, clinician ride-along                |
| Prototype                 | Clinical pilot, simulation exercise                    |
| Iteration                 | PDSA cycle (Plan-Do-Study-Act), QI iteration           |
| Empathy                   | Patient perspective, therapeutic rapport               |
| Success metric            | Length of stay, readmission rate, patient satisfaction |
| Workflow mapping          | Care process mapping, value stream analysis            |
| Risk assumption           | Root cause analysis, FMEA, sentinel event review       |
| Constraint-driven design  | Clinical protocol, standing order set                  |
| Alert system concept      | Rapid response team activation, code alert             |
| Integration timing        | Care transition window, discharge readiness            |

## Constraints and Considerations

### Patient Safety

Patient safety is the overriding constraint. Any design activity touching clinical workflows requires safety review. Solutions must never increase risk of adverse events, medication errors, or missed diagnoses. Changes involving patient-facing systems require clinical governance approval before deployment.

### HIPAA and Privacy

Research activities involving patient data require de-identification or IRB oversight. Empathy work must not access protected health information (PHI) without proper authorization. Prototypes handling clinical data need privacy review even in pilot form. Screen displays in shared spaces must account for incidental disclosure risk.

### Clinical Workflow Interruption

Clinicians operate under constant time pressure with high cognitive load. DT activities must minimize disruption to patient care. Schedule interviews and observation during natural pauses — shift changes, administrative blocks, or scheduled downtime. Never interrupt active patient care for research purposes.

### Hierarchy Dynamics

Medicine has a strong hierarchical culture. Attending physicians, residents, nurses, and support staff experience the same system differently. Stakeholder engagement must account for power dynamics — nurses and support staff may not voice concerns in the presence of attendings. Use separate sessions when hierarchy may suppress candid input.

### Evidence-Based Culture

Healthcare professionals expect evidence. DT insights must be framed in evidence-compatible language — pilot results, measurable outcomes, comparison data. Anecdotal observations carry less weight than in other industries. Connect DT findings to quality improvement frameworks the team already uses.

### Emotional Weight

Healthcare problems often involve patient suffering, loss, and moral distress. Empathy work requires emotional sensitivity and professional boundaries. Debrief after intense observation sessions. Respect that clinicians carry cumulative emotional burden.

## Empathy Tools

### Patient Journey Mapping

Follow a patient's experience through a complete care episode: scheduling, arrival, registration, clinical encounter, discharge, follow-up. Map every handoff, wait, and information exchange from the patient's perspective. Reveals system design gaps invisible from the clinician side.

### Clinician Shadow

Observe a clinician through a shift or half-shift. Track decision density, interruption frequency, documentation burden, and informal workarounds. Use progressive questioning: start with "walk me through a typical shift" before targeting specific workflow steps. Respect sterile environments and PPE requirements.

### Handoff Observation

Watch clinical handoffs at shift changes, unit transfers, and discharge. These transitions are where information loss, safety risks, and workaround patterns concentrate. Compare what the sending team documents versus what the receiving team actually uses.

### Wait Time Audit

Map all waiting that patients experience across a care episode. Reveals the system from the patient's perspective — where time is spent, where anxiety builds, and where information gaps create uncertainty. Often surfaces problems that clinicians cannot see from inside the workflow.

## Reference Scenario

**Context**: An emergency department experiences long patient wait times and clinician burnout; patient satisfaction scores are declining quarter over quarter.

**Discovery (Methods 1-3)**: Scope conversations reveal the initial request is "build a patient tracking dashboard." Patient journey mapping and clinician shadows across shifts uncover the real problem: information flow bottlenecks between triage, registration, and clinical assessment. Nurses repeat intake questions that registration already captured. Physicians lack triage severity context until they physically reach the patient.
Wait times are driven by information asymmetry, not insufficient capacity.

**Solution (Methods 4-6)**: Brainstorming generates solution themes: streamlined triage-to-treatment communication, shared intake data visibility, proactive patient status updates, and role-based information displays. Lo-fi prototypes — paper-based status boards and revised handoff checklists — reveal that nurses need different information than physicians, and that family members want progress visibility without clinical detail.
HIPAA constraints surface during prototype testing when screen placement in shared areas risks incidental PHI disclosure.

**Implementation (Methods 7-9)**: Hi-fi prototypes validate role-based views integrated with the EMR, tested through clinical simulation before live deployment. User testing across shifts reveals that night-shift workflows differ significantly from day-shift assumptions. ED throughput improves measurably during pilot, and nurse-reported handoff confidence increases. Iteration focuses on discharge communication gaps identified through patient follow-up calls.
