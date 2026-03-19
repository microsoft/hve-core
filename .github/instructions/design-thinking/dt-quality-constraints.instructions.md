---
description: 'Quality constraints, fidelity rules, and output standards for Design Thinking coaching across all nine methods'
applyTo: '**/.copilot-tracking/dt/**'
---

# DT Quality Constraints

These constraints govern artifact quality expectations throughout the Design Thinking process. The coach enforces fidelity standards appropriate to each method and actively prevents premature polish that undermines learning.

## Universal Quality Rules

* Multi-source validation: no conclusion rests on a single source, interview, or data point
* Real-world environment testing: test where users actually work, not in lab conditions
* Evidence over opinion: require quotes, observations, metrics. Surface-level feedback ("Do you like it?") provides no actionable insight.
* Constraint-driven design: physical, environmental, workflow, and organizational constraints are creative catalysts, not obstacles
* Assumption testing: every method tests, validates, or challenges specific assumptions from prior methods
* Anti-polish stance: fidelity stays appropriate to the current method. Premature polish invites surface-level feedback and slows iteration.

### Too Nice Prototype Tension

Teams investing effort in polish feel ownership, making redirection to lower fidelity difficult. Polished artifacts invite approval feedback instead of critical feedback; rougher versions surface honest reactions. Watch for this tension across all spaces: over-researched synthesis (Problem), polished prototypes (Solution), and over-engineered builds (Implementation).

## Quality Enforcement Approach

The coach uses Think/Speak/Empower to enforce quality without rule citations:

* Internally assess which quality rules apply and what fidelity level the current method requires
* Surface quality observations as coaching insights. Describe observed behavior and ask what a different approach would reveal, rather than naming the violated rule.
* Offer the team choices about addressing quality gaps rather than prescribing corrections
* All DT coaching artifacts are scoped to `.copilot-tracking/dt/{project-slug}/`. Never write DT artifacts directly under `.copilot-tracking/dt/` without a project-slug directory.

## Quality by Space

### Problem Space (Methods 1-3)

Rough and exploratory. Output is understanding, not deliverables. Solution discussions are premature.

Exit gate: Method 3 synthesis validation across five dimensions (Research Fidelity, Stakeholder Completeness, Pattern Robustness, Actionability, Team Alignment).

Anti-patterns: forcing themes not supported by data, single-source conclusions, jumping to solutions before the problem is understood.

### Solution Space (Methods 4-6)

Fidelity at its lowest. Stick figures, paper prototypes, cardboard mock-ups. Goal: quantity and variety of ideas with rapid constraint discovery.

Core principle: instant failure is instant win. A failed prototype revealing a constraint in minutes saves weeks of rework.

Anti-patterns: premature convergence on the first decent idea, polished prototypes inviting aesthetic feedback, testing only in controlled environments.

### Implementation Space (Methods 7-9)

Functionally rigorous but not visually polished. High-fidelity prototypes test working systems with real data, not visual design.

Core principle: systematic validation through quantitative metrics (task completion, error rates, efficiency) alongside qualitative feedback via progressive questioning.

Anti-patterns: over-polished interfaces, testing a single implementation path, running tests only under ideal conditions.
