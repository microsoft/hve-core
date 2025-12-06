---
applyTo: 'learning/training-labs/**/*.md'
description: 'Required instructions for training lab hub content including lab YAML requirements, phase table structure, and deliverables pattern'
---

# Training Lab Content Standards

This file provides instructions for creating and maintaining training lab hub content. Training labs are comprehensive multi-phase learning experiences that integrate multiple concepts and technologies.

**For kata content standards**, see `kata-content.instructions.md` (inherits: No Company Names Policy, AI Coaching Integration, Standard Footer format).

**For learning path content**, see `learning-path-content.instructions.md`.

## Overview

Training labs provide immersive, multi-phase learning experiences:

- **Comprehensive scenarios**: Real-world challenges without company names
- **Multi-phase structure**: 3-5 phases with clear progression
- **Hands-on deliverables**: Concrete outputs demonstrating mastery
- **Integration focus**: Combines multiple katas and concepts

## Training Lab Hub YAML Requirements

Training lab hub markdown files require specific YAML frontmatter:

```yaml
---
title: "[Lab Name]"
description: "Brief description of lab objectives"
ms.topic: tutorial
ms.date: MM/DD/YYYY
ms.author: github-username
author: Full Name
lab_id: lab-unique-identifier
difficulty: 3                              # Integer 1-5
estimated_total_time_minutes: 180          # Sum of all phase times
phases: 4                                  # Number of lab phases
phase_structure:
  - phase: 1
    title: "Phase 1 Title"
    estimated_minutes: 45
  - phase: 2
    title: "Phase 2 Title"
    estimated_minutes: 45
  - phase: 3
    title: "Phase 3 Title"
    estimated_minutes: 45
  - phase: 4
    title: "Phase 4 Title"
    estimated_minutes: 45
related_katas:                             # Array of kata IDs covered
  - kata-id-1
  - kata-id-2
  - kata-id-3
learning_objectives:
  - "Objective 1"
  - "Objective 2"
  - "Objective 3"
technologies:
  - "Technology 1"
  - "Technology 2"
prerequisites:
  - "Prerequisite 1"
  - "Prerequisite 2"
---
```

## Training Lab Hub Content Structure

Training lab hubs organize multi-phase experiences with clear structure:

<!-- <lab-hub-structure> -->
```markdown
# [Lab Name]

Brief introduction explaining the lab's purpose, complexity, and expected outcomes.

## Lab Overview

2-3 paragraphs describing:
- Comprehensive scenario (role + industry + technical context, NO company names)
- Why this lab integrates multiple concepts
- Real-world application of the combined skills

## Prerequisites

### Required Knowledge
- Concept 1 (link to kata if applicable)
- Concept 2 (link to kata if applicable)

### Required Tools
- Tool 1 (with version)
- Tool 2 (with version)
- Azure subscription

### Recommended Preparation
Complete these katas before starting:
- [Kata 1](../katas/category/kata-1.md)
- [Kata 2](../katas/category/kata-2.md)

## Learning Objectives

By completing this lab, you will be able to:
1. Objective 1
2. Objective 2
3. Objective 3

## Lab Phases

| Phase | Title                                   | Duration | Focus                       |
|-------|-----------------------------------------|----------|-----------------------------|
| 1     | [Phase 1 Title](#phase-1-phase-1-title) | 45 min   | Foundation setup            |
| 2     | [Phase 2 Title](#phase-2-phase-2-title) | 45 min   | Integration                 |
| 3     | [Phase 3 Title](#phase-3-phase-3-title) | 45 min   | Advanced configuration      |
| 4     | [Phase 4 Title](#phase-4-phase-4-title) | 45 min   | Validation and optimization |

## Phase 1: [Phase Title]

[AI coaching HTML comment]

### Scenario Context

You're a [role] at a [industry type] organization working on [technical context without company name]. In this phase, you'll [specific objectives].

### Objectives

- Objective 1
- Objective 2
- Objective 3

### Steps

1. Step 1 with detailed instructions
2. Step 2 with detailed instructions
3. Step 3 with detailed instructions

### Deliverables

- [ ] Deliverable 1
- [ ] Deliverable 2
- [ ] Deliverable 3

### Validation

Verify your phase 1 completion:

\```bash
# Validation command 1
kubectl get pods

# Validation command 2
az iot ops check
\```

Expected output: [Description of successful state]

## Phase 2: [Phase Title]

[AI coaching HTML comment]

### Scenario Context

Building on Phase 1, you'll now [next objectives].

### Objectives

- Objective 1
- Objective 2
- Objective 3

### Steps

1. Step 1 with detailed instructions
2. Step 2 with detailed instructions
3. Step 3 with detailed instructions

### Deliverables

- [ ] Deliverable 1
- [ ] Deliverable 2
- [ ] Deliverable 3

### Validation

Verify your phase 2 completion:

\```bash
# Validation commands
\```

Expected output: [Description of successful state]

## Phase 3: [Phase Title]

[Continue pattern for remaining phases]

## Lab Completion

### Final Deliverables

You should now have:
- [ ] Deliverable 1 from all phases
- [ ] Deliverable 2 from all phases
- [ ] Deliverable 3 from all phases

### Validation Checklist

- [ ] All phases completed successfully
- [ ] All deliverables produced
- [ ] System performs as expected under test scenarios

### Cleanup (Optional)

If you want to remove resources:

\```bash
# Cleanup commands
az group delete --name resource-group-name --yes
\```

## What's Next

After completing this lab, consider:
- [Advanced Lab](./advanced-lab-hub.md) - Builds on these skills
- [Related Learning Path](../paths/related-path.md) - Structured kata sequence
- Additional challenges: [Description of extension activities]

## Resources

- [Official Documentation](https://learn.microsoft.com)
- [Related Katas](../katas/README.md)
- [Community Discussion](https://github.com/your-org/your-repo/discussions)

[Standard Footer - see below]
```
<!-- </lab-hub-structure> -->

## Phase Table Structure

The lab phases table provides a quick reference for the entire lab structure:

### Table Requirements

1. **Columns**: Phase number, Title (with anchor link), Duration, Focus
2. **Anchor links**: Link to corresponding phase H2 headers
3. **Duration format**: Minutes (e.g., "45 min")
4. **Focus**: One-sentence description of phase purpose

### Anchor Link Format

```markdown
[Phase Title](#phase-1-phase-title)
```

- Lowercase all text
- Replace spaces with hyphens
- Include phase number prefix

## Deliverables Pattern

Each phase MUST include a deliverables checklist:

### Format

```markdown
### Deliverables

- [ ] Deliverable 1 description
- [ ] Deliverable 2 description
- [ ] Deliverable 3 description
```

### Purpose

- **Concrete outcomes**: Learners produce tangible artifacts
- **Progress tracking**: Checkboxes indicate completion
- **Assessment alignment**: Deliverables map to learning objectives

### Best Practices

- **Specific**: "Kubernetes YAML file with service configuration" not "Configuration file"
- **Measurable**: "Service responds to health check at /health endpoint" not "Service works"
- **Relevant**: Directly supports learning objectives

## Standard Footer

ALL training lab content MUST include the standard AI-generated attribution footer:

```markdown
---

*This learning content was generated with assistance from AI tools and reviewed by subject matter experts to ensure technical accuracy and pedagogical effectiveness.*
```

### Footer Rules

- **Position**: After all content sections
- **Separator**: Horizontal rule (`---`) above footer text
- **Format**: Italicized paragraph
- **Required**: No exceptions

## Validation Checklist

### Training Lab Hub Content

- [ ] 🔴 **CRITICAL**: All required YAML fields present
- [ ] 🔴 **CRITICAL**: Phase table with anchor links included
- [ ] 🔴 **CRITICAL**: Each phase has deliverables checklist
- [ ] 🔴 **CRITICAL**: Standard footer present
- [ ] 🔴 **CRITICAL**: NO company names used in scenarios or examples
- [ ] 🟠 **HIGH**: AI coaching HTML comments in each phase
- [ ] 🟠 **HIGH**: Phase count matches YAML `phases` field
- [ ] 🟠 **HIGH**: Each phase includes: scenario context, objectives, steps, deliverables, validation
- [ ] 🟠 **HIGH**: Related katas clearly identified and linked
- [ ] 🟡 **MEDIUM**: Prerequisites comprehensive and linked where applicable
- [ ] 🟡 **MEDIUM**: Final deliverables section summarizes all phase outputs
- [ ] 🟡 **MEDIUM**: Cleanup instructions provided
- [ ] **LOW**: All kata links are valid
- [ ] **LOW**: Estimated total time matches sum of phase times

## References

1. **Kata Content Standards**: `kata-content.instructions.md` - Inherits No Company Names Policy, AI Coaching Integration, Standard Footer format
2. **Example Training Lab**: `learning/training-labs/example-lab-hub.md` - Reference implementation
3. **Related Katas**: `learning/katas/README.md` - Overview of katas that can be integrated into labs
4. **Learning Paths**: See `learning-path-content.instructions.md` for structured kata sequences

---

*These instructions were developed to ensure consistency, quality, and comprehensive learning experiences across all training lab content.*
