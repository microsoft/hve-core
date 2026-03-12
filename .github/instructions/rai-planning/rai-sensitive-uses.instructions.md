---
description: 'Sensitive Uses assessment for Phase 2: screening categories, restricted uses gate, and depth tier assignment'
applyTo: '**/.copilot-tracking/rai-plans/**'
---

# Sensitive Uses Screening

Phase 2 of the RAI Planner orchestration screens the target system against Microsoft's Responsible AI Standard v2 sensitive uses guidance. The screening determines which categories of sensitive use apply, enforces a restricted uses gate, and assigns a depth tier that governs the rigor of subsequent phases.

## Sensitive Uses Categories

Every system undergoes evaluation against the eight categories below. Each category maps to documented patterns of AI harm. A system may trigger multiple categories.

| Category                            | Description                                                                                     | Risk Indicators                                                    |
|-------------------------------------|-------------------------------------------------------------------------------------------------|--------------------------------------------------------------------|
| Consequential impact on individuals | Decisions affecting employment, housing, insurance, education, credit, or similar life outcomes | Automated scoring, ranking, or eligibility determinations          |
| Consequential impact on communities | System effects on public resources, infrastructure, or community services                       | Aggregate decision patterns with disparate group impact            |
| Potential for physical harm         | Risk of bodily injury from system output or downstream actions                                  | Safety-critical integration, robotic control, medical guidance     |
| Potential for psychological harm    | Risk of emotional distress, manipulation, or coercion                                           | Persuasive interfaces, mental health context, vulnerable users     |
| Surveillance and tracking           | Monitoring, identification, or tracking of individuals                                          | Biometric processing, location tracking, behavioral profiling      |
| Deception risk                      | Potential for users to be misled about system nature or outputs                                 | Synthetic content generation, impersonation, hidden AI involvement |
| Impacts on human autonomy           | Reduction in meaningful human choice or oversight                                               | Automated decision-making without appeal, nudging patterns         |
| Dual-use potential                  | System capabilities applicable to harmful secondary purposes                                    | General-purpose models, data enrichment, pattern recognition       |

### Consequential Impact on Individuals

Evaluate whether the system produces outputs that materially affect individual life outcomes:

* Does the system score, rank, or classify individuals for decisions about employment, housing, credit, insurance, or education?
* Can system outputs restrict access to essential services or benefits?
* Are affected individuals informed about the system's role in decisions about them?
* Do affected individuals have a mechanism to contest or appeal system-influenced decisions?
* What is the severity and reversibility of negative outcomes from incorrect system outputs?

### Consequential Impact on Communities

Evaluate whether the system produces aggregate effects on groups or communities:

* Does the system allocate public resources, infrastructure access, or community services?
* Can system behavior produce disparate outcomes across demographic or geographic groups?
* Are community stakeholders represented in the system's design and governance?

### Potential for Physical Harm

Evaluate whether the system operates in contexts where outputs could contribute to bodily injury:

* Does the system control or influence physical actuators, vehicles, or safety-critical equipment?
* Can system outputs guide medical treatment, dosing, or diagnostic decisions?
* Is the system deployed in environments where incorrect outputs could create hazardous conditions?
* What safeguards prevent dangerous outputs from reaching downstream systems?

### Potential for Psychological Harm

Evaluate whether the system could cause emotional distress or psychological manipulation:

* Does the system interact with individuals in mental health, crisis, or vulnerable contexts?
* Can the system's persuasive or generative capabilities be used to manipulate user behavior?
* Does the system produce content that could distress users through inaccuracy, bias, or inappropriate tone?

### Surveillance and Tracking

Evaluate whether the system processes data in ways that enable monitoring or identification of individuals:

* Does the system perform facial recognition, gait analysis, or other biometric identification?
* Can the system track individual movement, behavior, or communication patterns over time?
* Does the system aggregate data sources in ways that create detailed individual profiles?
* Are data subjects informed about the nature and extent of monitoring?
* What retention and access controls govern surveillance data?

### Deception Risk

Evaluate whether the system could mislead users or third parties about its nature or outputs:

* Does the system generate synthetic content (text, images, audio, video) that could be mistaken for human-created content?
* Are users clearly informed they are interacting with an AI system?
* Can system outputs be used to impersonate individuals or fabricate evidence?

### Impacts on Human Autonomy

Evaluate whether the system reduces meaningful human control over important decisions:

* Does the system make consequential decisions without human review or override capability?
* Can individuals opt out of system-influenced processes?
* Does the system employ persuasive design patterns that limit informed choice?
* Is the system's role in decision-making transparent to affected parties?

### Dual-Use Potential

Evaluate whether the system's capabilities could be repurposed for harmful applications:

* Does the system possess general-purpose capabilities applicable beyond its intended use?
* Can the system's data, models, or outputs be extracted and applied to harmful purposes?
* What access controls and use-case restrictions limit secondary applications?
* Does the system's design include safeguards against misuse scenarios?

## Restricted Uses Gate

The restricted uses gate is a hard stop. If any restricted use applies, the RAI Planner halts Phase 2 and records the finding. The system cannot proceed to Phase 3 or beyond without explicit organizational escalation and documented authorization.

### Restricted Use Categories

1. **Weapons and military applications.** Systems designed to cause physical harm, enable lethal autonomous decision-making, or support weapons targeting.
2. **Mass surveillance without consent.** Systems that monitor populations without informed consent or legal authorization, including indiscriminate facial recognition in public spaces.
3. **Social scoring.** Systems that assign behavioral scores to individuals for the purpose of restricting rights, services, or opportunities based on aggregated personal conduct data.
4. **Manipulation of vulnerable populations.** Systems that exploit cognitive vulnerabilities of specific groups (children, elderly, individuals in crisis) to influence behavior against their interests.
5. **Critical infrastructure without human override.** Fully autonomous control of critical infrastructure (power grids, water systems, transportation networks) with no human override capability.

### Gate Failure Behavior

When a restricted use is detected:

* The RAI Planner sets the state field `restrictedUsesCleared` to `false`.
* The state field `currentPhase` remains at `2`.
* The screening artifact records the specific restricted use category, the evidence supporting the determination, and the recommended escalation path.
* No subsequent phases execute until the gate is resolved through organizational review.
* Resolution requires documented authorization or system redesign that eliminates the restricted use.

## Depth Tiers

The depth tier determines the rigor, scope, and evidence requirements for Phases 3 through 6. Tier assignment is based on the sensitive uses screening results and the restricted uses gate outcome.

| Tier          | Criteria                                                                                        | Assessment Scope                                                                                  | Typical Duration                 |
|---------------|-------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------|----------------------------------|
| Basic         | No sensitive uses triggered, restricted uses gate cleared                                       | Core RAI principle review, standard documentation                                                 | 1-2 phases                       |
| Standard      | 1-3 sensitive uses triggered at low-to-moderate severity                                        | Targeted principle deep-dives, stakeholder consultation, mitigation planning                      | 3-4 phases                       |
| Comprehensive | 4+ sensitive uses triggered, any high-severity category, or restricted use requiring escalation | Full principle assessment, external review, ongoing monitoring plan, detailed mitigation evidence | All 6 phases with expanded scope |

### Basic Tier

The Basic tier applies when the system triggers no sensitive uses categories and clears the restricted uses gate.

* Trigger conditions: All 8 category scores at 0, restricted uses gate cleared.
* Required phases: Phase 3 (standards mapping) and Phase 6 (summary). Phases 4 and 5 are abbreviated.
* Evidence requirements: Per-category screening rationale, gate clearance confirmation.
* Review rigor: Self-assessment with documented rationale.

### Standard Tier

The Standard tier applies when the system triggers a limited number of sensitive uses at low-to-moderate severity.

* Trigger conditions: 1-3 categories scored at 1-2, no category scored at 3, restricted uses gate cleared.
* Required phases: All 6 phases execute. Phases 3-5 focus on triggered categories.
* Evidence requirements: Per-category screening rationale, targeted stakeholder input for triggered categories, mitigation plans for each triggered category.
* Review rigor: Internal review with stakeholder validation of mitigation plans.

### Comprehensive Tier

The Comprehensive tier applies when the system triggers extensive or high-severity sensitive uses.

* Trigger conditions: 4+ categories triggered, or any category scored at 3, or restricted use requiring escalation review.
* Required phases: All 6 phases execute with expanded scope. Phase 4 includes external stakeholder consultation. Phase 5 includes ongoing monitoring commitments.
* Evidence requirements: Per-category screening rationale, external stakeholder consultation records, detailed mitigation plans with effectiveness evidence, monitoring and reporting commitments, organizational sign-off.
* Review rigor: External review panel, organizational leadership approval, periodic reassessment schedule.

## Screening Templates

### Sensitive Uses Screening Template

The sensitive uses screening artifact follows this structure:

```markdown
# Sensitive Uses Screening

## Project Information

* System name: [name]
* Assessment date: [YYYY-MM-DD]
* Assessor: [role or identifier]
* System description: [1-2 sentence summary]

## Category Screening

### [Category Name]

* Score: [0-3]
* Applicable: [Yes/No]
* Evidence: [summary of findings]
* Screening questions reviewed: [list of questions evaluated]

[Repeat for all 8 categories]

## Restricted Uses Gate

* Gate result: [Cleared/Blocked]
* Restricted uses identified: [list or "None"]
* Escalation required: [Yes/No]

## Tier Assignment

* Assigned tier: [Basic/Standard/Comprehensive]
* Justification: [rationale referencing category scores and gate result]
* Override applied: [Yes/No, with justification if Yes]
```

### Use and Misuse Inventory Template

The use and misuse inventory accompanies the screening and documents intended and foreseeable system applications:

```markdown
# Use and Misuse Inventory

## Intended Uses

| Use Case      | Users          | Context              | Expected Outcome   |
|---------------|----------------|----------------------|--------------------|
| [description] | [target users] | [deployment context] | [intended benefit] |

## Foreseeable Misuses

| Misuse Scenario | Likelihood        | Severity          | Mitigation             |
|-----------------|-------------------|-------------------|------------------------|
| [description]   | [Low/Medium/High] | [Low/Medium/High] | [control or safeguard] |

## Unintended Consequences

| Consequence   | Affected Group | Detection Method | Response Plan          |
|---------------|----------------|------------------|------------------------|
| [description] | [population]   | [how detected]   | [remediation approach] |
```

## Scoring Guidance

### Per-Category Scoring

Each sensitive uses category receives a score from 0 to 3:

* **0: Not applicable.** The system has no characteristics relevant to this category.
* **1: Low relevance.** The system has indirect or minor relevance. Risk indicators are present but mitigated by design.
* **2: Moderate relevance.** The system directly engages with this category. One or more risk indicators apply and require active mitigation.
* **3: High relevance.** The system is centrally concerned with this category. Multiple risk indicators apply with potential for significant harm.

### Aggregation Method

Tier assignment uses both the maximum individual category score and the count of triggered categories:

1. If any category scores 3, assign Comprehensive tier.
2. If 4 or more categories score 1 or above, assign Comprehensive tier.
3. If 1-3 categories score 1-2 with none at 3, assign Standard tier.
4. If all categories score 0, assign Basic tier.

### Tier Override Rules

The RAI Planner may override the calculated tier in specific circumstances:

* Upgrade override: The assessor may increase the tier when qualitative factors (novel technology, regulatory scrutiny, public visibility) warrant additional rigor. Document the override justification in the screening artifact.
* Downgrade override: Tier reduction requires documented organizational authorization and a written rationale demonstrating that the lower tier provides sufficient coverage. Downgrade overrides are not permitted when any category scores 3.

### Documentation Requirements

Every screening must produce:

* A completed sensitive uses screening artifact using the template above.
* A completed use and misuse inventory using the template above.
* Per-category scoring rationale with specific evidence references.
* Tier assignment justification linking scores to tier criteria.
* Override documentation if any tier override was applied.
