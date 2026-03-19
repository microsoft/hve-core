---
description: 'Energy industry context for DT coaching — vocabulary, constraints, empathy tools, and reference scenarios'
applyTo: ''
---

# Energy Industry Context

Load this file when the team identifies energy as their industry context. It provides energy-sector vocabulary, constraints, empathy tools, and a reference scenario that the coach weaves into method-specific guidance.

## Industry Profile

* **Sector**: Energy (generation, transmission, distribution, renewables integration)
* **Key stakeholders**: Control room operators, field technicians, grid engineers, reliability engineers, environmental compliance officers, asset managers, regulatory affairs, community relations, market traders, renewable generation forecasters
* **Decision cadence**: Real-time operations (seconds to minutes), maintenance scheduling (weekly to monthly), asset investment (5-30 year horizons), regulatory compliance (annual and multi-year cycles)
* **Regulatory environment**: NERC CIP (critical infrastructure protection), FERC, state utility commissions, EPA, DOE, emerging climate disclosure requirements
* **Missing voices to seek out**: Night-shift control room operators, field crews in remote locations, substation technicians, community members near generation or transmission assets, contract workers during seasonal peaks

## Vocabulary Mapping

Bridge DT language and energy language bidirectionally. Use energy terms when coaching energy teams.

| DT Concept                | Energy Term                                              |
|---------------------------|----------------------------------------------------------|
| Stakeholder map           | RACI, interconnection stakeholder register               |
| Pain point                | Reliability concern, outage root cause                   |
| User journey              | Asset lifecycle, outage management workflow              |
| Observation / field study | Control room observation, field ride-along               |
| Prototype                 | Pilot project, demonstration site                        |
| Iteration                 | Continuous reliability improvement cycle                 |
| Empathy                   | Ride-along, control room observation                     |
| Success metric            | SAIDI, SAIFI, CAIDI, forced outage rate, capacity factor |
| Workflow mapping          | Switching order sequence, outage coordination process    |
| Risk assumption           | Contingency analysis, N-1 / N-2 reliability criteria     |
| Constraint-driven design  | Operating procedure, protection scheme                   |
| Alert system concept      | SCADA alarm, energy management system alert              |
| Integration timing        | Interconnection queue position, in-service date          |

## Constraints and Considerations

### Critical Infrastructure

Energy systems are critical infrastructure where failure has direct public safety implications. DT activities must never compromise operational reliability. Observation and research activities in control rooms and substations require coordination with operations management before scheduling. Solutions touching grid operations need reliability review before any pilot deployment.

### Regulatory Weight

Many energy processes exist because of regulation, not preference. NERC CIP standards govern cybersecurity for bulk electric systems. FERC orders define market rules and transmission access. State commissions set rate structures and service standards. Understanding the regulatory driver behind a process is essential before redesigning it — what looks like inefficiency may be a compliance requirement.

### Long Asset Lifecycles

Energy infrastructure operates on 30-50 year asset lifecycles. Transmission lines, substations, and generation facilities represent decades of capital investment. Solutions must account for this time horizon — what is innovative today must integrate with assets that will operate for decades. Design decisions carry long-term operational consequences that are difficult to reverse.

### Jurisdiction Complexity

Energy problems often span multiple regulatory jurisdictions with different rules. A single transmission project may cross state lines, involve multiple utility territories, and require federal, state, and local approvals. Stakeholder mapping must account for this multi-jurisdictional landscape. Solutions that work in one jurisdiction may face different requirements in the next.

### Workforce Transition

The energy transition from fossil fuels to renewables creates anxiety about job security and skill relevance. Empathy work must be sensitive to this context. Workers with decades of experience in conventional generation may feel threatened by changes. Frame design thinking as enhancing their expertise, not replacing it. Include transition-affected workers as stakeholders, not just subjects.

### Security Classification

Some operational data falls under NERC CIP critical infrastructure protection rules. SCADA data, network topology, and protection settings may be classified. Empathy artifacts (photos, diagrams, notes) from control rooms and substations may require security review before sharing outside the utility. Prototypes handling grid operational data need cybersecurity review even in pilot form.

## Empathy Tools

### Control Room Observation

Observe operators managing grid operations during normal and high-stress periods. Track decision speed, information density, screen navigation patterns, and alarm fatigue. Control rooms operate 24/7 with shift rotations — observe multiple shifts to capture different operating conditions. Morning peak and evening ramp are high-cognitive-load periods where workarounds surface. Coordinate scheduling with the shift supervisor and respect operational priority at all times.

### Field Ride-Along

Accompany field technicians to substations, transmission corridors, or generation sites. Observe the physical environment, safety rituals (tailboard meetings, lockout/tagout), tool limitations, and communication challenges in remote locations. Field work is weather-dependent and physically demanding — respect conditions that affect scheduling. Note the gap between what planning systems assume and what field crews actually encounter.

### Regulatory Timeline Mapping

Map the regulatory calendar to understand when stakeholders are available versus consumed by compliance deadlines. NERC CIP audits, FERC filings, integrated resource plan submissions, and rate case proceedings consume significant staff attention on fixed schedules. Schedule DT activities during regulatory lulls, not during filing seasons when key stakeholders are unavailable.

### Intergenerational Knowledge Capture

Structured approach to understanding what experienced workers know that is not documented. Senior operators and engineers carry decades of institutional knowledge about system behavior, failure patterns, and informal procedures. Pair experienced workers with newer staff during observation sessions. Capture knowledge about edge cases, seasonal patterns, and historical context that formal documentation misses.

## Reference Scenario

**Context**: A grid operations center struggles with renewable energy integration as intermittent wind and solar generation creates operational challenges that traditional grid management assumptions do not address.

**Discovery (Methods 1-3)**: Scope conversations reveal the initial request is "build a better renewable forecasting dashboard." Control room observations and field ride-alongs across shifts uncover the real problem: operators are creating informal workarounds to manage generation variability that existing tools do not support.
Experienced operators mentally compensate for forecast errors using pattern knowledge they cannot articulate. Newer operators lack this tacit expertise and fall back on conservative dispatch decisions that increase costs.

**Solution (Methods 4-6)**: Brainstorming generates solution themes: operator decision support for variable generation, forecast confidence visualization, automated pre-positioning of reserves, and shift handoff tools for renewable conditions.
Lo-fi prototypes — paper mockups of enhanced dispatch screens and revised handoff checklists — reveal that operators need different information granularity depending on renewable penetration levels. Security constraints surface when prototype screen designs expose grid topology details restricted under NERC CIP.

**Implementation (Methods 7-9)**: Hi-fi prototypes validate operator decision support tools integrated with the energy management system, tested through grid simulation before live deployment. User testing across shifts reveals that night-shift operators face different renewable challenges (wind peaks) than day-shift operators (solar ramps).
Operator confidence in managing high-renewable periods improves measurably during pilot. Iteration focuses on alarm management — operators report alarm fatigue from renewable variability triggers that existing thresholds were not designed to handle.

* All DT coaching artifacts are scoped to `.copilot-tracking/dt/{project-slug}/`. Never write DT artifacts directly under `.copilot-tracking/dt/` without a project-slug directory.
