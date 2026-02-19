---
description: 'Deep expertise for Method 7: High-Fidelity Prototypes; fidelity translation, architecture patterns, and specification writing'
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

1. **Paper or cardboard** (Method 6 output): Advance when the hypothesis requires interactive behavior paper cannot provide.
2. **Static digital mockup** (visual layout, no logic): Advance when users need to interact with the system to provide meaningful feedback.
3. **Interactive simulation** (logic present, simulated data): Advance when simulated data masks behaviors the hypothesis depends on.
4. **Functional prototype** (real data, constrained scope): The target state for Method 7. Advance to production only in Method 9.
5. **Production-ready**: Reaching this stage during Method 7 is an anti-pattern; redirect effort to testing preparation.

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

* **Implementation complexity**: effort, skills required, tooling dependencies.
* **Constraint compliance**: alignment with noise, safety, environmental, and workflow constraints from Method 6.
* **Integration risk**: compatibility with existing systems, data format requirements, protocol support.
* **Iteration speed**: time to modify and retest after Method 8 user feedback.
* **Technical debt profile**: nature and volume of shortcuts; whether debt blocks user testing.

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

* **Developers**: architecture decisions, API contracts, data flows, known limitations, build and deployment instructions.
* **Product managers**: feature scope boundaries, trade-off rationale, user impact summary, deferred decisions.
* **Testers (Method 8)**: test boundaries, known failure modes, environment setup requirements, expected vs unexpected behaviors.
* **Future implementors (Method 9)**: scalability assumptions, production gaps, deployment constraints, rebuild-vs-extend guidance.

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

* **Tested assumptions**: beliefs validated through Method 6 or 7 testing, with evidence references.
* **Untested assumptions**: identified but deferred; document why deferral is acceptable for the current prototype.
* **Known unknowns**: gaps identified during prototyping that require future investigation.
* **External dependencies**: decisions or resources controlled by other teams, systems, or timelines not yet confirmed.

## Manufacturing-Specific Patterns

### PLC/SCADA Prototyping

Prototypes interact with industrial control systems through read-only data taps or simulation layers. Direct write operations to production PLCs are out of scope.

* **Simulation approaches**: OPC-UA test servers, PLC simulators (Siemens PLCSIM, Allen-Bradley emulators), recorded sensor data playback.
* **Integration fidelity**: test with actual communication protocols (Modbus, OPC-UA, EtherNet/IP) against simulated endpoints. Protocol timing and error handling must be realistic even when endpoints are simulated.
* **Constraint categories**: scan cycle timing, network latency tolerance, data format compatibility, historian integration requirements.

### Digital Twin Prototyping

Four fidelity levels for digital twin prototypes:

1. **Static model**: historical data visualization, no live connection.
2. **Dynamic model**: live data stream integration with real-time updates.
3. **Predictive model**: scenario simulation using current data to forecast outcomes.
4. **Prescriptive model**: automated response recommendations. This level exceeds Method 7 scope; treat as a Method 9 target.

Identify the minimum sensor coverage for meaningful twin behavior. Document data quality assumptions and compare twin predictions against actual system behavior to calibrate divergence tolerance.

### Safety-Critical Boundaries

* **Hard stop rule**: prototypes do not issue commands to safety-critical systems (emergency stops, safety interlocks, pressure relief, fire suppression).
* **Observation-only in safety zones**: prototypes may read safety system status but must not interfere with safety PLC logic or certified safety functions.
* **Regulatory awareness**: in regulated industries (pharmaceuticals, food, energy), prototype testing requires documented risk assessment even for observation-only deployments.
* **Physical proximity**: prototype hardware placed in safety zones must meet the same ingress protection and electrical safety standards as production equipment.

### Operator Interface Fidelity

* **Glove-friendly interaction**: touch targets minimum 15 mm for bare hands, 20 mm for gloved operation. No fine-motor gestures.
* **Visibility constraints**: screen readability at arm's length under industrial lighting. High-contrast requirements; no glossy screens.
* **Shift handoff**: interface state must be comprehensible to an incoming operator without training on prototype specifics.
* **Noise environment**: audio feedback is unreliable above 80 dB. Visual and haptic feedback patterns are required.
* **Dirty environment**: interfaces exposed to oil, dust, or moisture need appropriate enclosures. Prototype enclosures can be improvised (sealed bags, ruggedized tablets) but must be tested under actual conditions.
