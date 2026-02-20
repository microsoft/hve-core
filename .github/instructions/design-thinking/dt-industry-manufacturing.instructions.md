---
description: 'Manufacturing industry context for DT coaching — vocabulary, constraints, empathy tools, and reference scenarios'
applyTo: ''
---

# Manufacturing Industry Context

Load this file when the team identifies manufacturing as their industry context. It provides manufacturing-specific vocabulary, constraints, empathy tools, and a reference scenario that the coach weaves into method-specific guidance.

## Industry Profile

* **Sector**: Discrete and process manufacturing
* **Key stakeholders**: Operators, shift supervisors, maintenance engineers, quality engineers, safety/compliance officers, plant managers, union representatives, IT support
* **Decision cadence**: Shift-level (8-12 hours), daily stand-ups, weekly production reviews, quarterly/annual capital investment
* **Regulatory environment**: OSHA, EPA, ISO 9001/14001, industry-specific standards (FDA for pharma, IATF 16949 for automotive)
* **Missing voices to seek out**: Night/weekend shift workers, seasonal or temporary staff, new hires, contract workers

## Vocabulary Mapping

Bridge DT language and manufacturing language bidirectionally. Use manufacturing terms when coaching manufacturing teams.

| DT Concept                | Manufacturing Term                            |
|---------------------------|-----------------------------------------------|
| Stakeholder map           | RACI chart, responsibility matrix             |
| Pain point                | Downtime cause, production bottleneck         |
| User journey              | Production workflow, value stream             |
| Observation / field study | Gemba walk, operator ride-along               |
| Prototype                 | Pilot run, trial batch, proof of concept      |
| Iteration                 | Continuous improvement, Kaizen cycle          |
| Empathy                   | Gemba (go and see), operator perspective      |
| Success metric            | OEE, MTTR, first-pass yield, downtime minutes |
| Workflow mapping          | SOP review, value stream mapping              |
| Risk assumption           | FMEA (Failure Mode and Effects Analysis)      |
| Constraint-driven design  | Poka-yoke (mistake-proofing)                  |
| Alert system concept      | Andon (signal for help)                       |
| Integration timing        | Takt time                                     |

## Constraints and Considerations

### Safety

Safety is non-negotiable scope, not a preference. Safety and compliance officers hold effective veto power over solutions affecting worker safety or regulatory status. Changes involving safety, environmental controls, or quality certification require regulatory review before deployment.

### Shifts

Day shifts have management oversight and support resources. Night and weekend shifts operate with reduced staffing and develop workarounds invisible to day management. A solution scoped entirely from day-shift observations may fail during off-hours. Include representatives from multiple shifts in stakeholder mapping and testing.

### Unions

Union representatives are stakeholders with effective veto power alongside regulators and safety officers. Labor agreements can constrain process changes and technology deployment. Engage union representatives early in the coaching process.

### Physical Environment

* **Noise**: 85-90 dB on production floors prevents normal voice interaction and requires hearing protection
* **Contamination**: Greasy or chemical-coated hands prevent touchscreen use; solutions need glove-friendly or hands-free interaction
* **Lighting**: Factory lighting affects screen readability and QR code scanning
* **Space**: Production line constraints limit device placement and prototype testing areas

### Data Sensitivity

Machine sensor data, production metrics, and maintenance logs contain operational IP. Telemetry collection requires alignment with plant management and IT. Performance reports used for synthesis may have access restrictions.

## Empathy Tools

### Gemba Walk

Structured observation on the factory floor. Walk the production line during active operations. Observe what workers actually do versus documented SOPs. Note workarounds, informal communication channels, and environmental constraints. Conversations are most productive during natural work pauses, not interruptions. Respect PPE requirements and designated observation areas.

### Shift Handoff Observation

Watch shift transitions to identify information loss, miscommunication, and undocumented workarounds. Shift handoff is a frequent source of scope-relevant problems. Compare what day shift documents versus what night shift actually receives.

### Operator Shadow

Follow an operator through a complete shift or task cycle. Observe actual workflow, not the documented version. Use progressive questioning: start with "walk me through your typical day" before drilling into specific tasks. Watch for moments where the operator hesitates, improvises, or works around a limitation.

### Safety Incident Narrative

Use anonymized incident reports and near-miss data as empathy artifacts. These reveal the operator's experience under pressure, failure cascade patterns, and gaps between documented procedures and real conditions. Emergency procedures often surface the highest-value use cases.

## Reference Scenario

**Context**: A manufacturing plant experiences quality variance across shifts. Day shifts consistently outperform night shifts on first-pass yield.

**Discovery (Methods 1-3)**: Scope conversations reveal the initial request is "build a quality dashboard." Gemba walks on both shifts and shift-handoff observations uncover the real problem: information asymmetry. Night-shift operators have the same equipment and SOPs but lack the informal knowledge transfer, rapid-response support, and management oversight that day shifts enjoy. Workers spend 10-15 minutes finding manual sections while actual repairs take 5-10 minutes.

**Solution (Methods 4-6)**: Brainstorming generates four solution themes: hands-free interaction, visual guidance, collaborative knowledge sharing, and proactive assistance. Lo-fi prototypes reveal touchscreen contamination, QR code lighting issues, and production-timing conflicts — constraints invisible from a desk.

**Implementation (Methods 7-9)**: Hi-fi prototypes validate industrial-grade microphones for 85-90 dB environments and glove-friendly interfaces. User testing across four operator types shows 40% higher adoption with glove-friendly design. Shift-change usage spikes lead to dedicated transition features. Emergency stop procedures are used 300% above forecast, revealing safety as the highest-value use case.
