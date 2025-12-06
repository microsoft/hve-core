---
applyTo: '../../learning/katas/**/README.md'
description: 'Required instructions for kata category README files including structure, scaffolding levels, kata listings, and integration documentation'
---

# Kata Category README Standards

This file provides comprehensive instructions for creating and maintaining kata category README files that serve as landing pages for kata collections.

Category README files organize related katas, document learning progressions, and integrate with learning paths and training labs.

For individual kata content, see `kata-content.instructions.md`.
For learning path content, see `learning-path-content.instructions.md`.
For training lab content, see `training-lab-content.instructions.md`.

## Content Type and ms.topic Mapping

Use the following `ms.topic` value in YAML frontmatter for category README files:

| Content Type         | ms.topic Value  | Description                                                        |
|----------------------|-----------------|--------------------------------------------------------------------|
| Kata Category README | `kata-category` | Overview page organizing related katas by category                 |
| Individual Kata      | `how-to-guide`  | Step-by-step technical exercises with specific learning objectives |
| Learning Path        | `learning-path` | Curated sequence of katas with progressive difficulty              |
| Training Lab Hub     | `tutorial`      | Multi-phase learning experience with comprehensive objectives      |

## **HIGHEST PRIORITY**

1. **NO COMPANY NAMES**: MUST NOT use any company names (real, fictitious, example, or sample) in any section, descriptions, or scenarios. Use role + industry + technical context only.
2. **Standard Footer**: MUST include standard Copilot attribution footer at end of all category README files.
3. **Core Sections**: MUST include all required sections (minimum 10) appropriate for the category.
4. **Kata Listings**: MUST list all katas with descriptions, difficulty ratings, time estimates, and prerequisites.
5. **Comparison Matrix**: MUST include tabular comparison of all katas with key attributes.

## Kata Category README Structure

Each category (folder) under `../../learning/katas/` MUST have a `README.md` file that serves as the category landing page.

### Purpose

- **Category Overview**: Explain the category theme and learning progression
- **Kata Organization**: List all katas with descriptions, difficulty, and time estimates
- **Prerequisites**: Define category-level prerequisites
- **Learning Path Integration**: Show how katas build upon each other

### Scaffolding Level Definitions

These levels correspond to the YAML field `scaffolding_level` in individual katas and should be documented in category READMEs:

Category READMEs should indicate scaffolding approach for each kata:

- **Heavy**: Step-by-step instructions with code samples and detailed explanations
- **Medium-Heavy**: Detailed guidance with some code provided, expects learners to adapt
- **Light**: High-level objectives and structure, minimal code examples
- **Minimal**: Problem statement only, learners implement independently with reference links

### Complexity Rating Scale

Use these ratings when documenting kata difficulty (matches individual kata `kata_difficulty` field):

| Rating | Label      | Description            | Characteristics                                                                |
|--------|------------|------------------------|--------------------------------------------------------------------------------|
| 1      | Foundation | Starting point         | Minimal prerequisites, single technology, foundational skills                  |
| 2      | Skill      | Building competency    | 1-2 prerequisites, limited integration, some decision-making                   |
| 3      | Advanced   | Integration challenges | Moderate problem-solving, 2-3 technologies, integration patterns               |
| 4      | Expert     | Complex scenarios      | Deep expertise required, 3+ technologies, architectural decisions              |
| 5      | Legendary  | Mastery-level          | Extensive prerequisites, multi-system orchestration, production considerations |

### Standard Section Structure

Category README files MUST include these core sections (minimum 10, typically 12-15 depending on category complexity):

<!-- <kata-category-readme-pattern> -->
```markdown
---
title: "[Category Name] - Learning Katas"
description: "Category overview and kata collection"
ms.topic: kata-category
ms.date: MM/DD/YYYY
---

# [Category Name]

Brief description of what this category covers and why it matters.

## Category Overview

2-3 paragraphs explaining:
- Category theme and scope
- Key technologies covered
- Progressive learning approach
- Real-world applications

## Prerequisites

### Required Knowledge

- Concept 1
- Concept 2
- Concept 3

### Required Tools

- Tool 1 (with version)
- Tool 2 (with version)
- Azure subscription

### Recommended Preparation

- [Link to prerequisite kata 1](../../other-category/kata-1.md)
- [Link to prerequisite kata 2](../../other-category/kata-2.md)

## Learning Path

Visual representation or description of kata progression:

```text
[Kata 1: Basics] → [Kata 2: Intermediate] → [Kata 3: Advanced]
       ↓                     ↓                      ↓
  Foundation          Integration            Production-Ready
```

## Category Katas

### [Kata 1 Title](./kata-1-id.md)

**Difficulty**: ⭐ (1/5) | **Time**: 20 minutes

Brief description of what this kata teaches.

**You'll Learn**:

- Key skill 1
- Key skill 2
- Key skill 3

**Prerequisites**: None

---

### [Kata 2 Title](./kata-2-id.md)

**Difficulty**: ⭐⭐ (2/5) | **Time**: 30 minutes

Brief description of what this kata teaches.

**You'll Learn**:

- Key skill 1
- Key skill 2
- Key skill 3

**Prerequisites**: [Kata 1](./kata-1-id.md)

---

### [Kata 3 Title](./kata-3-id.md)

**Difficulty**: ⭐⭐⭐ (3/5) | **Time**: 45 minutes

Brief description of what this kata teaches.

**You'll Learn**:

- Key skill 1
- Key skill 2
- Key skill 3

**Prerequisites**: [Kata 2](./kata-2-id.md)

## Kata Comparison Matrix

| Kata                     | Difficulty | Time   | Technologies   | Scaffolding  | Prerequisites |
|--------------------------|------------|--------|----------------|--------------|---------------|
| [Kata 1](./kata-1-id.md) | ⭐ (1/5)    | 20 min | Tech A, Tech B | Heavy        | None          |
| [Kata 2](./kata-2-id.md) | ⭐⭐ (2/5)   | 30 min | Tech B, Tech C | Medium-Heavy | Kata 1        |
| [Kata 3](./kata-3-id.md) | ⭐⭐⭐ (3/5)  | 45 min | Tech C, Tech D | Light        | Kata 2        |

## Suggested Learning Sequences

### For Beginners

1. [Kata 1](./kata-1-id.md) - Foundation
2. [Kata 2](./kata-2-id.md) - Building on basics

### For Intermediate Learners

1. [Kata 2](./kata-2-id.md) - Skip basics if familiar
2. [Kata 3](./kata-3-id.md) - Advanced patterns

## Real-World Applications

Describe practical scenarios where these skills apply:

- Industry context 1
- Industry context 2
- Industry context 3

## Common Challenges and Solutions

### Challenge 1: [Description]

**Solution**: Explanation and reference to relevant kata

### Challenge 2: [Description]

**Solution**: Explanation and reference to relevant kata

## Integration with Learning Paths

This category integrates with the following learning paths:

- [Learning Path 1](../../paths/path-1.md) - Uses Katas 1-2
- [Learning Path 2](../../paths/path-2.md) - Uses Kata 3

## Hands-On Labs

Related comprehensive labs:

- [Lab 1](../../training-labs/lab-1-hub.md) - Multi-phase experience using all category katas

## Additional Resources

### Official Documentation

- [Azure IoT Operations Docs](https://learn.microsoft.com/azure/iot-operations)
- [Kubernetes Docs](https://kubernetes.io/docs)

### Community Resources

- [GitHub Repository](https://github.com/your-org/your-repo)
- [Discussion Forum](https://github.com/your-org/your-repo/discussions)

### Related Categories

- [Category 1](../../category-1/README.md) - Foundational concepts
- [Category 2](../../category-2/README.md) - Advanced topics

## Feedback and Contributions

We welcome feedback and contributions! Please:

- Report issues or suggest improvements via [GitHub Issues](https://github.com/your-org/your-repo/issues)
- Contribute new katas following our [contribution guidelines](../../contributing.md)

## Version History

| Version | Date       | Changes                   |
|---------|------------|---------------------------|
| 1.0.0   | MM/DD/YYYY | Initial category creation |

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
```

<!-- </kata-category-readme-pattern> -->

### Category README Requirements

1. **YAML Frontmatter**: Include `ms.topic: kata-category` and comprehensive metadata
2. **Core Sections**: Include all sections appropriate for your category (minimum 10 sections)
3. **Kata Listings**: Each kata must have description, difficulty, time, prerequisites
4. **Comparison Matrix**: Tabular view of all katas with key attributes
5. **Scaffolding Indicators**: Show scaffolding level for each kata
6. **Learning Sequences**: Provide recommended paths for different skill levels
7. **Integration Points**: Reference learning paths and labs that use these katas
8. **Standard Footer**: Include standard Copilot attribution footer

## No Company Names Policy

### **CRITICAL REQUIREMENT**

**MUST NOT use any company names** in category README content:

- ❌ Real company names (Microsoft, Amazon, Google, etc.)
- ❌ Fictitious company names (Contoso, Fabrikam, Northwind, etc.)
- ❌ Example company names (Acme, Example Corp, Sample Industries, etc.)
- ❌ Sample company names (Demo Company, Test Corp, etc.)

### Approved Format

Use **role + industry + technical context** instead:

✅ **Good Examples:**

- "Platform engineers at manufacturing companies implementing AI..."
- "DevOps teams in retail organizations deploying IoT sensors..."
- "Solutions architects for logistics providers configuring..."

❌ **Bad Examples:**

- "Contoso Manufacturing engineers deploying..."
- "Fabrikam Retail teams implementing..."
- "Northwind Logistics architects configuring..."

### Rationale

- **Focus on Learning**: Company names distract from technical content
- **Universal Applicability**: Role-based descriptions apply to any organization
- **Reduces Maintenance**: No need to track approved/deprecated company names
- **Improves Clarity**: Direct technical context without fictional narrative overhead

## Standard Footer

ALL category README files MUST include this footer:

<!-- <learning-content-footer> -->
```markdown
---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
```
<!-- </learning-content-footer> -->

### Footer Placement

- **Position**: After all content sections, before any metadata blocks
- **Separator**: Horizontal rule (`---`) above footer text
- **Format**: Italicized paragraph with markdownlint disable/enable comments
- **Required**: No exceptions, all category README files must include this footer

## Validation Checklist

**Priority Guide**: Focus on 🔴 CRITICAL items first, then 🟠 HIGH, then 🟡 MEDIUM. LOW items can be deferred but should not be ignored.

### Category README Files

- [ ] 🔴 **CRITICAL**: All core sections present (minimum 10)
- [ ] 🔴 **CRITICAL**: Standard Copilot footer present
- [ ] 🔴 **CRITICAL**: NO company names used in any section
- [ ] 🔴 **CRITICAL**: `ms.topic: kata-category` in YAML frontmatter
- [ ] 🟠 **HIGH**: Each kata listed with description, difficulty, time, prerequisites
- [ ] 🟠 **HIGH**: Comparison matrix complete with all katas
- [ ] 🟠 **HIGH**: Scaffolding levels indicated for each kata
- [ ] 🟡 **MEDIUM**: Learning sequences provided for different skill levels
- [ ] 🟡 **MEDIUM**: Integration with learning paths documented
- [ ] 🟡 **MEDIUM**: Real-world applications described (without company names)
- [ ] **LOW**: Version history maintained
- [ ] **LOW**: Links to external resources are valid

## References

### Project Files

1. **Category README Example**: `../../learning/katas/prompt-engineering/README.md` - Real category page with all sections
2. **Root Katas README**: `../../learning/katas/README.md` - Overview of all kata categories
3. **Validation Script**: `../../scripts/kata-validation/Validate-Katas.ps1` - Automated category structure validation
4. **Individual Kata Instructions**: `kata-content.instructions.md` - Instructions for individual katas (not category READMEs)

### Related Instruction Files

1. **Kata Content**: `kata-content.instructions.md` - Individual kata requirements and standards
2. **Learning Path Integration**: `learning-path-content.instructions.md` - Path-specific requirements
3. **Training Lab Integration**: `training-lab-content.instructions.md` - Lab-specific requirements
4. **Markdown Standards**: `markdown.instructions.md` - General markdown formatting rules
5. **Commit Messages**: `commit-message.instructions.md` - Conventional commit format for category changes

### External Documentation

1. **Microsoft Learn Metadata**: [Metadata documentation](https://learn.microsoft.com/contribute/metadata) - Official field definitions
