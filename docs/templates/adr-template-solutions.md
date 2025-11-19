---
title: ADR Title
description: '[The title should be unique within the library, provide a longer title if needed to differentiate with other ADRs]'
author: Name of author(s)
ms.date: 2025-06-06
ms.topic: architecture
estimated_reading_time: 2
keywords:
  - architecture
  - design
  - implementation
  - workspaces
  - edge
  - solution
  - adr
  - library
---

## Overview

This template provides a structured approach to documenting architectural decisions. Use the YAML drafting guide below to organize your thoughts before writing the full ADR.

## YAML Drafting Guide

Use this comprehensive YAML template to draft your ADR before writing the full documentation:

```yaml
# ADR Drafting Worksheet - Complete this first to organize your thinking
adr:
  title: "[Clear, descriptive title of the decision]"
  description: "[Brief summary of what is being decided]"
  author: "[Your name or team name]"
  date: "[YYYY-MM-DD]"

  context:
    scenario: "[What business scenario or use case is this for?]"
    problem: "[What specific problem are you solving?]"
    background: "[Additional context that readers need to understand]"

    stakeholders:
      primary: "[Who is most affected by this decision?]"
      secondary: "[Who else needs to know about this decision?]"

    constraints:
      technical:
        - "[Platform limitations]"
        - "[Integration requirements]"
        - "[Performance requirements]"
      business:
        - "[Budget constraints]"
        - "[Timeline requirements]"
        - "[Regulatory compliance]"
      organizational:
        - "[Team expertise]"
        - "[Operational capabilities]"
        - "[Strategic direction]"

    success_criteria:
      quantitative:
        - "[Measurable performance target]"
        - "[Cost target]"
        - "[Timeline goal]"
      qualitative:
        - "[Maintainability goal]"
        - "[Security posture]"
        - "[Developer experience]"

  decision:
    summary: "[One clear sentence stating what was decided]"
    rationale: "[Why this decision was made - key reasoning]"
    implementation_approach: "[High-level approach to implementing this decision]"

  decision_drivers:
    - name: "[Driver 1 - e.g., Performance Requirements]"
      description: "[Why this factor influenced the decision]"
      weight: "[High/Medium/Low priority]"
    - name: "[Driver 2 - e.g., Cost Optimization]"
      description: "[Why this factor influenced the decision]"
      weight: "[High/Medium/Low priority]"
    - name: "[Driver 3 - e.g., Team Expertise]"
      description: "[Why this factor influenced the decision]"
      weight: "[High/Medium/Low priority]"

  considered_options:
    - name: "[Option 1 - e.g., Technology A]"
      description: "[Brief description of what this option entails]"

      technical_details:
        - "[Architecture approach]"
        - "[Key components]"
        - "[Integration requirements]"

      pros:
        - "[Specific advantage 1]"
        - "[Specific advantage 2]"
        - "[Quantifiable benefit]"

      cons:
        - "[Specific disadvantage 1]"
        - "[Specific disadvantage 2]"
        - "[Quantifiable limitation]"

      risks:
        - risk: "[Risk description]"
          probability: "[High/Medium/Low]"
          impact: "[High/Medium/Low]"
          mitigation: "[How to address this risk]"

      dependencies:
        - "[External dependency]"
        - "[Internal capability requirement]"
        - "[Timeline dependency]"

      costs:
        initial: "[Implementation cost]"
        ongoing: "[Operational cost]"
        effort: "[Development effort required]"

    - name: "[Option 2 - e.g., Technology B]"
      description: "[Brief description]"
      technical_details: ["[Key technical aspects]"]
      pros: ["[Advantages]"]
      cons: ["[Disadvantages]"]
      risks:
        - risk: "[Risk]"
          probability: "[Level]"
          impact: "[Level]"
          mitigation: "[Mitigation strategy]"
      dependencies: ["[Dependencies]"]
      costs:
        initial: "[Cost]"
        ongoing: "[Cost]"
        effort: "[Effort]"

  comparison_matrix:
    criteria:
      - name: "[Evaluation criteria 1]"
        weight: "[High/Medium/Low]"
        option_1_score: "[Score/Rating]"
        option_2_score: "[Score/Rating]"
      - name: "[Evaluation criteria 2]"
        weight: "[High/Medium/Low]"
        option_1_score: "[Score/Rating]"
        option_2_score: "[Score/Rating]"

  consequences:
    positive:
      - "[Positive outcome 1]"
      - "[Positive outcome 2]"
    negative:
      - "[Negative impact 1]"
      - "[Negative impact 2]"
    neutral:
      - "[Neutral change 1]"
      - "[Neutral change 2]"
    risks:
      - "[Risk that remains after decision]"
      - "[Monitoring requirement]"

  implementation:
    phases:
      - "[Phase 1 description]"
      - "[Phase 2 description]"
    timeline: "[Expected timeline]"
    resources_required: "[Team/budget/tools needed]"
    success_metrics: "[How to measure success]"

  future_considerations:
    monitoring:
      - "[What to watch for]"
      - "[When to re-evaluate]"
    evolution:
      - "[Future technology to consider]"
      - "[Upcoming decisions that may affect this]"
    triggers_for_review:
      - "[Condition that would trigger re-evaluation]"
      - "[Timeline for regular review]"
```

---

## ADR Document Structure

After completing the YAML drafting guide above, use this structure for your final ADR:

### Status

[Mark the most applicable status for tracking purposes]

- [ ] Draft
- [ ] Proposed
- [ ] Accepted
- [ ] Deprecated

### Context

**Scenario Context**: [Describe the business scenario or use case]

**Problem Statement**: [Clearly articulate the problem being solved]

**Constraints and Requirements**: [Document technical, business, and organizational boundaries]

**Success Criteria**: [Define measurable outcomes for success]

### Decision

**Decision Statement**: [Clear, single sentence stating what was decided]

**Decision Rationale**: [Explain the reasoning behind this decision]

**Implementation Approach**: [Outline how this decision will be implemented]

### Decision Drivers (optional)

List the key factors that influenced this decision:

- [Driver 1]
- [Driver 2]
- [Driver 3]

### Considered Options (optional)

**Option Evaluation Framework**: [For each option considered, provide:]

#### Option [Number]: [Option Name]

**Description**: [What this option entails]

**Technical Details**: [Architecture, components, requirements]

**Pros**: [Specific advantages with supporting detail]

**Cons**: [Specific disadvantages with impact assessment]

**Risks and Mitigation**: [Risks with probability, impact, and mitigation strategies]

**Dependencies**: [External dependencies and prerequisites]

**Cost Analysis**: [Implementation and operational costs]

### Comparison Matrix (optional)

| Criteria     | Option 1 | Option 2 | Option 3 | Weight  |
|--------------|----------|----------|----------|---------|
| [Criteria 1] | [Score]  | [Score]  | [Score]  | [H/M/L] |
| [Criteria 2] | [Score]  | [Score]  | [Score]  | [H/M/L] |

### Consequences

**Positive Consequences**: [Benefits and positive outcomes]

**Negative Consequences**: [Risks and negative impacts]

**Neutral Consequences**: [Other changes or considerations]

### Future Considerations (optional)

**Monitoring and Evolution**: [What to watch for and when to re-evaluate]

**Review Triggers**: [Conditions that would require re-evaluation of this decision]

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
