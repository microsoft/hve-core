---
description: 'Method 3 Input Synthesis coaching knowledge: pattern recognition, theme development, synthesis validation, and Problem-to-Solution Space transition readiness'
applyTo: '**/.copilot-tracking/dt/**/method-03*'
---

# DT Method 03: Input Synthesis

Input synthesis aggregates research inputs (interviews, surveys, reports, observations) to find patterns, themes, and insights that form a complete picture of the problem. Without proper synthesis, teams move to brainstorming with fragmented understanding instead of unified problem clarity.

## Purpose

Transform fragmented research data from diverse sources into unified problem understanding that sets clear direction for solution development.

## Sub-Method Phases

### Phase 1: Synthesis Planning

Organize all Method 2 research outputs and establish the synthesis strategy. Determine data source availability, identify coverage gaps, and define the analysis approach.

Exit criteria: an input inventory exists cataloging all Method 2 artifacts with source type, coverage assessment, and a defined synthesis approach.

### Phase 2: Synthesis Execution

Perform systematic pattern recognition across organized inputs. Identify cross-source themes, validate patterns through multiple perspectives, and develop unified insights.

Exit criteria: affinity clusters and insight statements exist with each theme supported by evidence from multiple independent sources.

### Phase 3: Synthesis Documentation

Formalize validated patterns into structured problem definitions, insight statements, and how-might-we questions. Run synthesis validation across all five dimensions before declaring transition readiness.

Exit criteria: problem definition and how-might-we artifacts exist, five-dimension validation shows strength across all dimensions, and the team confirms shared problem understanding.

## Coaching Hats

Two specialized hats activate based on conversation context. See dt-method-03-deep.instructions.md for detailed hat guidance, activation triggers, coaching focus areas, and Human-AI Collaboration patterns.

| Hat             | Role                                                                       | Activation                                                        |
|-----------------|----------------------------------------------------------------------------|-------------------------------------------------------------------|
| Pattern Analyst | Data organization, cross-source theme discovery, evidence-based validation | Raw data shared, clustering needed, contradictions detected       |
| Insight Framer  | Problem articulation, HMW questions, transition readiness assessment       | Patterns validated, problem framing needed, transition discussion |

## Pattern Recognition Framework

### Data Source Integration

* Combine input sources: worker interviews revealing capability constraints, observational data showing environmental factors, performance reports quantifying impact metrics
* Look for themes that emerge when different data sources confirm and reinforce each other

### Theme Development

* Individual insight: a specific observation or quote from one source
* Supporting evidence: confirmation from additional sources and perspectives
* Unified theme: the pattern connecting all perspectives into a coherent problem statement
* Actionable direction: framing that guides solution development without prescribing specific solutions

## Systematic Synthesis Process

### Input Organization

* Stakeholder inputs: interview transcripts, conversation notes, survey responses, stakeholder mapping
* Observational data: workflow documentation, process mapping, environmental constraint analysis
* Quantitative data: performance metrics, operational analytics, resource utilization

### Pattern Recognition

* Validate patterns through different stakeholder perspectives
* Connect qualitative observations with quantitative metrics
* Require multiple independent sources to support each theme before considering it robust

### Unified Insight Development

* Prioritize themes based on stakeholder impact and solution potential
* Frame insights as actionable direction without prescribing specific solutions
* Validate synthesis against original research data for accuracy

## Synthesis Validation

Before transitioning to brainstorming, evaluate synthesis quality across five dimensions.

* Research fidelity: synthesis accurately reflects collected evidence rather than assumptions
* Stakeholder completeness: themes include the full range of relevant stakeholder groups
* Pattern robustness: patterns appear across multiple data points, not from isolated anecdotes
* Actionability: outputs translate into clear problem statements that can guide solution work
* Team alignment: the team shares common understanding and agrees synthesis reflects their learning

When validation reveals weaknesses: return to data sources for low fidelity, refine statements for weak actionability, conduct targeted research for completeness gaps, abandon themes for insufficient robustness.

## Coaching Patterns

* Every major theme requires evidence from multiple research sources
* Include all key user groups; silent stakeholders often reveal critical constraints
* Maintain domain-specific nuances while identifying universal patterns
* Do not force themes that evidence does not genuinely support

## Quality Rules

* Seven red flags signal synthesis failure: Single Source Dependency, Stakeholder Blind Spots, Pattern Forcing, Solution Bias, Jargon Overload, Scope Creep, and Premature Convergence
* Effective synthesis demonstrates multi-source validation, complete stakeholder representation, actionable insights, robust patterns, and preserved context
* Test themes with the question: would original research participants recognize themselves in this synthesis?

## Synthesis Goals

### Accomplish

* Multi-source pattern recognition across different research data types
* Stakeholder perspective integration across all key user groups
* Environmental context preservation including domain-specific constraints
* Solution-ready problem statements without prescribing solutions

### Avoid

* Theme forcing where evidence does not support connections
* Single source over-reliance
* Premature solution jumping before completing synthesis
* Context loss in pursuit of generic patterns

## Success Indicators

### During Synthesis

* All research inputs systematically analyzed without data loss
* Themes supported by multiple independent data sources
* Environmental and contextual factors preserved
* Team members demonstrate shared understanding

### After Synthesis

* Unified problem statements with stakeholder consensus
* Validated themes supported by comprehensive evidence
* Solution focus areas identified without premature solution prescription
* Team alignment on problem understanding and design direction

## Input from Method 2

* User interview findings with direct quotes and observations
* Environmental constraint documentation
* Workflow integration requirements
* Unmet need patterns across user groups

## Output to Method 4

* Clear problem focus areas with validated themes for solution development
* Design constraints from environmental and contextual factors
* Stakeholder priorities and specific needs for solution targeting
* Success criteria based on synthesized problem understanding

## Artifacts

Method 3 artifacts at `.copilot-tracking/dt/{project-slug}/method-03-synthesis/`:

* `affinity-clusters.md`: labeled clusters with representative evidence and tensions
* `insight-statements.md`: synthesized insights explaining why patterns matter, with supporting sources and design implications
* `problem-definition.md`: unified problem framing with scope, stakeholders, constraints, and success signals
* `how-might-we-questions.md`: HMW questions bridging from problem understanding to ideation, with related insights and constraints

## Problem-to-Solution Space Transition

Method 3 sits at the boundary between Problem Space and Solution Space. This is the most critical transition. Moving to solutions without validated problem understanding produces solutions to the wrong problem.

Transition readiness signals:

* Synthesis validation shows strength across all five dimensions with remaining gaps explicitly acknowledged
* The team can articulate the discovered problem in terms that differ meaningfully from the original request
* Multiple stakeholder perspectives are represented in the synthesis themes
* Environmental and workflow constraints are documented, not just functional requirements

Next-step pathways:

* Proceed to Method 4 when synthesis artifacts are complete and stable
* Hand off to the RPI workflow via `dt-handoff-problem-space.prompt.md` when the team wants a Researcher/Planner/Implementor to continue from validated problem understanding
* Return to Methods 1-2 when synthesis exposes research gaps, conflicting narratives, or missing constraints
