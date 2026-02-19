---
description: 'Quality constraints, fidelity rules, and output standards for Design Thinking coaching across all nine methods'
applyTo: '**/.copilot-tracking/dt/**'
---

# DT Quality Constraints

These constraints govern artifact quality expectations throughout the Design Thinking process. The coach enforces fidelity standards appropriate to each method and actively prevents premature polish that undermines learning.

## Universal Quality Rules

These rules apply to every method regardless of space or fidelity level.

* Multi-source validation: no conclusion rests on a single source, interview, or data point.
* Real-world environment testing: lab conditions and ideal environments produce misleading results. Test where users actually work.
* Evidence over opinion: require quotes, observations, metrics, and data points. Surface-level feedback ("Do you like it?") provides no actionable insight.
* Constraint-driven design: physical, environmental, workflow, and organizational constraints are creative catalysts, not obstacles. Apply them during ideation, not after.
* Assumption testing: every method tests, validates, or challenges specific assumptions from prior methods.
* Anti-polish stance: fidelity stays appropriate to the current method. Premature polish invites surface-level feedback and slows iteration.

## Quality by Space

### Problem Space (Methods 1-3)

Quality in the Problem Space means completeness and honesty of understanding.

#### Problem fidelity level

Rough and exploratory. Output is understanding, not deliverables. Solution discussions are premature in this space.

#### Exit gate

Method 3 synthesis validation provides the formal quality checkpoint before entering the Solution Space. The five validation dimensions are Research Fidelity, Stakeholder Completeness, Pattern Robustness, Actionability, and Team Alignment. Each dimension receives a status of Pass, Needs Improvement, or Requires Rework.

#### Problem anti-patterns

Forcing themes that do not genuinely exist in the data, relying on a single source for conclusions, jumping to solutions before the problem is understood.

### Solution Space (Methods 4-6)

Quality in the Solution Space means creative diversity and learning speed.

#### Solution fidelity level

Intentionally at its lowest. Stick figures, paper prototypes, and cardboard mock-ups are the expected output format. The goal is quantity and variety of ideas with rapid constraint discovery.

#### Solution core principle

Treat instant failure as instant win. A failed prototype that reveals a constraint in minutes saves weeks of rework later.

#### Solution anti-patterns

Premature convergence on the first decent idea, polished prototypes that invite surface-level aesthetic feedback, testing in artificial or controlled environments only.

### Implementation Space (Methods 7-9)

Quality in the Implementation Space means technical proof, user validation depth, and measurable business value.

#### Implementation fidelity level

Functionally rigorous but still not visually polished. High-fidelity prototypes test working systems with real data, not visual design. Multiple implementation variants enable systematic comparison.

#### Implementation core principle

Systematic validation through quantitative metrics (task completion, error rates, efficiency) alongside qualitative feedback extracted through progressive questioning.

#### Implementation anti-patterns

Over-polished interfaces that distract from functional validation, testing a single implementation path without alternatives, running tests only under ideal conditions.

## Method-Specific Quality Frameworks

Each method enforces a quality framework suited to its purpose.

### Method 1: Scope Conversations

* Classify constraints as frozen (fixed, non-negotiable) or fluid (malleable, open to change) before proceeding.
* Success indicator: the customer shares context they had not originally planned to discuss. The initial request evolves or becomes more nuanced.
* Document the original request alongside the discovered problem space. The gap between them reveals understanding depth.

### Method 2: Design Research

* Assign insight confidence levels: High (multiple sources confirm), Medium (good evidence but limited), Low (requires additional validation).
* Identify research gaps explicitly. Gaps left unacknowledged propagate into flawed synthesis.
* Insights that surprise stakeholders indicate genuine discovery. Insights that confirm initial assumptions suggest confirmation bias.

### Method 3: Input Synthesis

* Seven red flags signal synthesis failure: Single Source Dependency, Stakeholder Blind Spots, Pattern Forcing, Solution Bias, Jargon Overload, Scope Creep, and Premature Convergence.
* Effective synthesis demonstrates multi-source validation, complete stakeholder representation, actionable insights, robust patterns, and preserved context.
* Test themes with the question: would original research participants recognize themselves in this synthesis?

### Method 4: Brainstorming

* Generate a minimum of 15 ideas before evaluating any. Diversity target: ideas spanning 4-6 different solution categories.
* Convergence target: 3-5 clear, distinct themes. Fewer than 3 suggests premature convergence. More than 5 suggests insufficient analysis.
* Themes must span different solution approaches with clear rationale for prioritization.

### Method 5: User Concepts

* 30-second comprehension test: every concept must be understandable in 30 seconds or less.
* 15-second napkin sketch standard: visual representations use stick figures, basic shapes, and minimal detail. Hand-drawn aesthetic preferred.
* Concepts produce a YAML artifact (`concepts.yml`) with `name`, `description`, `file` (kebab-case .png), and `prompt` fields.
* Validation follows Silent Review, Understanding Check, Gap Identification, and Resonance Assessment sequence.

### Method 6: Lo-Fi Prototypes

* Build constraint: minutes to hours, not days. If it takes longer, the prototype is too polished.
* Each prototype tests one core assumption clearly. Testing multiple assumptions simultaneously produces ambiguous results.
* Materials: paper, cardboard, simple physical objects. Paper-based workflows and manual simulations.
* Ask "Walk me through exactly how you would use this" and "What would prevent you from using this?" Avoid surface-level questions like "What do you think?" or "Do you like it?"

### Method 7: Hi-Fi Prototypes

* Functional core only: working systems with real data, not visual design.
* Multiple implementation approaches (minimum 2-3) enable controlled variable testing with single-difference focus.
* Four metric categories: Performance (response time, throughput), User Effectiveness (task completion, errors), Integration (system compatibility), and Technical (resource usage, reliability).
* Stripped-down standard: still scrappy, but now about technical proof rather than physical proof.

### Method 8: User Testing

* Leap Enabling questions produce insight. Leap Killing questions produce empty validation.
* Leap Killing: "Do you like this feature?" produces "Yes" with no actionable insight.
* Leap Enabling: "Walk me through what happened when you used the voice system" produces specific observations that reveal underlying constraints.
* Progressive questioning: always ask "why?" at least twice to move from surface reaction to implementation insight.
* Conduct testing in actual usage environments with authentic limitations.

### Method 9: Iteration at Scale

* Prioritize high-impact, low-risk changes first. Iterative enhancement, not fundamental redesign.
* User Advocacy framework: prevent experience degradation, manage complexity, preserve working workflows, maintain trust.
* Phased rollouts with rollback capability. A/B testing for systematic comparison.
* Review cadence: weekly perspective checks, monthly comprehensive reviews, quarterly strategic assessments, annual user research validation.
* Connect usage patterns to measurable business outcomes. Metrics without business value context are noise.
