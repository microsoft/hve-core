---
description: 'Deep expertise for Method 7: High-Fidelity Prototypes; fidelity translation, architecture, and specification writing'
applyTo: ''
---

# Method 7: Deep Expertise

Advanced reference material for the DT coach when facing complex hi-fi prototyping questions. Load this file via `read_file` during Method 7 work requiring depth beyond the method-tier instruction file. Content is organized by hat affinity for fast lookup.

## Fidelity Translation

### Fidelity Mapping Matrix

For each lo-fi prototype element, assign a treatment category before beginning hi-fi work:

| Category              | Treatment                                         | Selection Criteria                                                                      |
|-----------------------|---------------------------------------------------|-----------------------------------------------------------------------------------------|
| Elevate to functional | Build working implementation with real data       | Element tests the core hypothesis; user feedback depends on authentic behavior          |
| Keep rough            | Preserve lo-fi representation with minimal polish | Element supports context but is not under test; roughness does not distort results      |
| Defer                 | Exclude from hi-fi prototype entirely             | Element is out of scope for the current hypothesis or introduces unnecessary complexity |

Tie each assignment to specific Method 6 constraint discoveries. Elements without a traceable constraint warrant re-evaluation.

### Fidelity Gradient

Five stages from roughest to most functional. Each stage has an advancement criterion and an over-engineering signal:

1. Paper or cardboard serves as the Method 6 output. Advance when the hypothesis requires interactive behavior paper cannot provide.
2. A static digital mockup provides visual layout without logic. Advance when users need to interact with the system to provide meaningful feedback.
3. An interactive simulation introduces logic with simulated data. Advance when simulated data masks behaviors the hypothesis depends on.
4. A functional prototype uses real data within constrained scope and represents the target state for Method 7. Advance to production only in Method 9.
5. Reaching production-ready during Method 7 is an anti-pattern; redirect effort to testing preparation.

### Learning Preservation

Patterns for carrying lo-fi insights forward without losing context during technical translation:

* Constraint inventory: catalog all Method 6 environmental findings (noise levels, lighting, physical dimensions, workflow sequences) as testable technical requirements.
* Assumption traceability: link each hi-fi design decision to the lo-fi assumption it validates or invalidates.
* User-quote anchoring: attach direct user observations from Method 6 testing to the technical requirements they generated, preserving the human reasoning behind specifications.

### Translation Anti-Patterns

| Anti-Pattern          | Signal                                                                     | Remediation                                                                               |
|-----------------------|----------------------------------------------------------------------------|-------------------------------------------------------------------------------------------|
| Gold plating          | Non-critical elements receive full fidelity treatment                      | Return to fidelity map; re-evaluate each element against the core hypothesis              |
| Constraint amnesia    | Technical decisions ignore Method 6 environmental findings                 | Cross-reference the constraint inventory before each design decision                      |
| Fidelity leapfrogging | Jump from paper prototype to near-production implementation                | Enforce intermediate validation stages in the fidelity gradient                           |
| Audience confusion    | Prototype built for stakeholder presentation instead of hypothesis testing | Clarify prototype purpose: functional proof, not demo                                     |
| Feature creep         | Scope expands beyond the original constraint-validated concept             | Lock the element list from the fidelity map; new items require explicit re-prioritization |

## Technical Architecture

### Build-vs-Simulate Decision Tree

Select build or simulate based on the primary question the prototype must answer:

* Does the hypothesis require real system behavior? Build the component.
* Is the integration point the core question? Build the interface; simulate the backend.
* Is the constraint environmental (noise, vibration, lighting)? Build and test in-situ.
* Is timeline the primary risk? Simulate with documented assumptions; build only validated paths.
* Is cost the primary risk? Simulate first; build only after simulation confirms viability.

When multiple factors conflict, prioritize the factor that most directly tests the hypothesis.

### Architecture Trade-Off Analysis

Evaluate implementation approaches across these dimensions:

* Assess implementation complexity by evaluating effort, skills required, and tooling dependencies.
* Evaluate constraint compliance through alignment with noise, safety, environmental, and workflow constraints from Method 6.
* Gauge integration risk by examining compatibility with existing systems, data format requirements, and protocol support.
* Measure iteration speed as the time to modify and retest after Method 8 user feedback.
* Characterize the technical debt profile by identifying the nature and volume of shortcuts and whether debt blocks user testing.

Each approach receives a comparative rating per dimension. The optimal choice minimizes integration risk and maximizes iteration speed, accepting complexity trade-offs that do not block testing.

### Technical Debt Budget

Acceptable debt in prototypes:

* Hardcoded configurations, manual deployment steps, limited error handling, single-user assumptions, simplified authentication.

Unacceptable debt:

* Security bypasses exposing real data, data corruption risks, silent failures masking test results, untested integration points the hypothesis depends on.

Review trigger: reassess the debt budget when accumulated debt would prevent Method 8 user testing from producing reliable results.

## Specification Writing

### Specification Audience Mapping

Different stakeholders need different views of the prototype documentation:

| Audience                       | Documentation Needs                                                                                     |
|--------------------------------|---------------------------------------------------------------------------------------------------------|
| Developers                     | Architecture decisions, API contracts, data flows, known limitations, build and deployment instructions |
| Product managers               | Feature scope boundaries, trade-off rationale, user impact summary, deferred decisions                  |
| Testers (Method 8)             | Test boundaries, known failure modes, environment setup requirements, expected vs unexpected behaviors  |
| Future implementors (Method 9) | Scalability assumptions, production gaps, deployment constraints, rebuild-vs-extend guidance            |

### Decision Rationale Capture

For each significant technical decision, document five fields:

* What was decided.
* What alternatives were considered and why they were rejected.
* What constraints drove the decision.
* What assumptions the decision depends on.
* What conditions would invalidate the decision.

Capture rationale during implementation, not after. Post-hoc reconstruction omits rejected alternatives and distorts constraint reasoning.

### Assumption and Gap Documentation

Track four categories:

* Tested assumptions are beliefs validated through Method 6 or 7 testing, with evidence references.
* Untested assumptions have been identified but deferred; document why deferral is acceptable for the current prototype.
* Known unknowns are gaps identified during prototyping that require future investigation.
* External dependencies are decisions or resources controlled by other teams, systems, or timelines not yet confirmed.

## Manufacturing-Specific Patterns

### PLC/SCADA Prototyping

Prototypes interact with industrial control systems through read-only data taps or simulation layers. Direct write operations to production PLCs are out of scope.

* Simulation approaches include OPC-UA test servers, PLC simulators (Siemens PLCSIM, Allen-Bradley emulators), and recorded sensor data playback.
* Test integration fidelity with actual communication protocols (Modbus, OPC-UA, EtherNet/IP) against simulated endpoints. Protocol timing and error handling must be realistic even when endpoints are simulated.
* Constraint categories to evaluate include scan cycle timing, network latency tolerance, data format compatibility, and historian integration requirements.

### Digital Twin Prototyping

Four fidelity levels for digital twin prototypes:

1. A static model provides historical data visualization with no live connection.
2. A dynamic model integrates live data streams with real-time updates.
3. A predictive model runs scenario simulations using current data to forecast outcomes.
4. A prescriptive model generates automated response recommendations. This level exceeds Method 7 scope; treat as a Method 9 target.

Identify the minimum sensor coverage for meaningful twin behavior. Document data quality assumptions and compare twin predictions against actual system behavior to calibrate divergence tolerance.

### Safety-Critical Boundaries

* Prototypes do not issue commands to safety-critical systems, including emergency stops, safety interlocks, pressure relief, and fire suppression.
* Prototypes may read safety system status in safety zones but must not interfere with safety PLC logic or certified safety functions.
* In regulated industries (pharmaceuticals, food, energy), prototype testing requires documented risk assessment even for observation-only deployments.
* Prototype hardware placed in safety zones must meet the same ingress protection and electrical safety standards as production equipment.

### Operator Interface Fidelity

* Touch targets require a minimum of 15 mm for bare hands and 20 mm for gloved operation, with no fine-motor gestures.
* Screens must be readable at arm's length under industrial lighting, with high-contrast displays and no glossy screens.
* Interface state must be comprehensible to an incoming operator during shift handoff without training on prototype specifics.
* Audio feedback is unreliable above 80 dB; use visual and haptic feedback patterns instead.
* Interfaces exposed to oil, dust, or moisture need appropriate enclosures. Prototype enclosures can be improvised (sealed bags, ruggedized tablets) but must be tested under actual conditions.
* All DT coaching artifacts are scoped to `.copilot-tracking/dt/{project-slug}/`. Never write DT artifacts directly under `.copilot-tracking/dt/` without a project-slug directory.
