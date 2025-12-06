---
applyTo: '../../learning/paths/**/*.md'
description: 'Required instructions for learning path content including path YAML requirements, double checkbox navigation pattern, and progressive difficulty ordering'
---

# Learning Path Content Standards

This file provides instructions for creating and maintaining learning path content. Learning paths are curated sequences of katas with progressive difficulty and clear learning objectives.

**For kata content standards**, see `kata-content.instructions.md` (inherits: No Company Names Policy, AI Coaching Integration, Standard Footer format).

**For training lab content**, see `training-lab-content.instructions.md`.

## Overview

Learning paths organize multiple katas into coherent learning journeys:

- **Progressive difficulty**: Katas arranged from foundational to advanced
- **Clear prerequisites**: Each step builds on prior knowledge
- **Measurable outcomes**: Defined skills gained at each milestone
- **Flexible pacing**: Learners can skip familiar content or deep-dive as needed

## Learning Path YAML Requirements

Learning path markdown files require specific YAML frontmatter:

<!-- <learning-path-yaml> -->
```yaml
---
title: "[Learning Path Name]"
description: "Brief description of learning path objectives"
author: Full Name or Team Name
ms.date: MM/DD/YYYY
ms.topic: learning-path
estimated_reading_time: 4                   # Integer hours (not minutes)
difficulty: foundation                      # Values: foundation, skill, expert
keywords:                                   # Array of search keywords
  - keyword1
  - keyword2
  - keyword3
---
```
<!-- </learning-path-yaml> -->

### YAML Field Definitions

- **title**: Learning path display name
- **description**: One-sentence summary of objectives (used in previews)
- **author**: Author name or "HVE Essentials Team"
- **ms.date**: Last update date in MM/DD/YYYY format (US format)
- **ms.topic**: MUST be `learning-path` for all paths
- **estimated_reading_time**: Integer representing total hours (sum of all kata/lab times)
- **difficulty**: Path level - `foundation` (basics), `skill` (intermediate), `expert` (advanced)
- **keywords**: Array of searchable terms for discovery and filtering

**Note**: Learning objectives, prerequisites, and target audience go in the body content, NOT in YAML.

## Learning Path Content Structure

Learning paths use a triple-checkbox pattern with emojis for navigation and progress tracking:

<!-- <learning-path-structure> -->
```markdown
# [Learning Path Name]

**Level**: [Foundation Builder|Skill Developer|Expert Practitioner] • **Duration**: X hours • **Topics**: Topic1, Topic2, Topic3

[2-3 sentence description of what learners will achieve and the skills they'll develop]

**Perfect for**: [Primary audience description with experience level and role context]

**Recommended for**: [Comma-separated list of specific roles: Software Engineers, Data Scientists, Platform Engineers, etc.]

## Learning Journey

### Prerequisites

- [ ] [Prerequisite Path or Kata](../path-to-prerequisite.md) completed
- [ ] Specific technical knowledge or experience required
- [ ] Required tools or access (e.g., Azure subscription)

### Core Learning Path

#### 🎯 [Phase Name] *([Total time in minutes])*

- [ ] 📚 [ ] [Kata or Lab Title](../../katas/category/file.md) <time>[X min]</time> <difficulty>[Difficulty Level]</difficulty>

[1-2 sentence description of what this item teaches and why it's important in the sequence]

#### 🧠 [Next Phase Name] *([Total time in minutes])*

- [ ] 📚 [ ] [Next Kata Title](../../katas/category/file.md) <time>[X min]</time> <difficulty>[Difficulty Level]</difficulty>

[1-2 sentence description building on previous phase]

---

## Next Steps

After completing this path, consider these follow-up options:

- **[Difficulty Level]**: [Path Name](./path-file.md) - Brief description
- **[Difficulty Level]**: [Path Name](./path-file.md) - Brief description
- **[Difficulty Level]**: [Path Name](./path-file.md) - Brief description

---

## Progress Tracking

Your progress is automatically tracked as you complete each kata and lab. Use the 📚 checkbox to add items to your personalized learning path, and watch the ✅ indicator update as you complete activities.

---

[Standard Footer - see below]
```
<!-- </learning-path-structure> -->

## Triple Checkbox Pattern

The triple-checkbox pattern provides interactive progress tracking with visual hierarchy:

### Syntax

```markdown
- [ ] 📚 [ ] [Kata or Lab Title](../../katas/category/file.md) <time>X min</time> <difficulty>Level</difficulty>
```

### Components

1. **First checkbox**: Markdown checkbox for adding to personal learning path
2. **Book emoji** (📚): Visual indicator that this is a learning resource
3. **Second checkbox**: Completion status checkbox (updates when kata completed)
4. **Link with title**: Relative path to kata or lab file
5. **Time tag**: `<time>X min</time>` - Duration in minutes
6. **Difficulty tag**: `<difficulty>Level</difficulty>` - Difficulty description

### Purpose

- **Dual tracking**: Separate checkboxes for "added to plan" vs "completed"
- **Visual hierarchy**: Emoji provides quick visual scanning
- **Interactive state**: JavaScript can update completion checkbox based on actual kata progress
- **Metadata display**: HTML tags provide structured time/difficulty information

### Triple Checkbox Usage Rules

1. **One pattern per kata/lab**: Each learning item gets this full pattern
2. **Relative paths**: Use `../../katas/category/` or `../../training-labs/category/` format
3. **Time in minutes**: Even if displaying hours elsewhere, use minutes in tag
4. **Consistent difficulty**: Match difficulty levels used in kata YAML
5. **Bullet list format**: Each item is a markdown list item with nested checkboxes

## Emoji Conventions

Learning paths use emojis for visual hierarchy and quick navigation:

### Section Emojis

Use emojis to categorize phases within the Core Learning Path:

- **🎯** - Foundational concepts, getting started, basics
- **🧠** - Cognitive skills, reasoning, problem-solving
- **📋** - Planning, organization, management topics
- **🔍** - Analysis, investigation, troubleshooting
- **⚡** - Performance, optimization, efficiency
- **🚀** - Advanced topics, deployment, production
- **🔧** - Tools, configuration, setup
- **🌐** - Networking, connectivity, integration
- **🏗️** - Architecture, design, infrastructure

### Item Type Emoji

- **📚** - Standard indicator for all katas and labs in checkbox pattern

### Emoji Usage Rules

1. Choose emoji that best represents the phase's focus
2. Be consistent with emoji meanings across paths
3. Don't overuse - typically 3-6 phases per path
4. Use the 📚 emoji in every checkbox pattern line

## HTML Tags for Metadata

Learning paths use HTML tags to provide structured metadata:

### Time Tag

```markdown
<time>X min</time>
```

- **Format**: Integer followed by space and "min"
- **Purpose**: Machine-readable duration for aggregation
- **Display**: Shows time commitment for each item

### Difficulty Tag

```markdown
<difficulty>Difficulty Description</difficulty>
```

- **Format**: Human-readable difficulty level
- **Examples**: "Foundation", "Core Skill", "Advanced Skill", "Expert Application", "Real-world Application"
- **Purpose**: Helps learners gauge complexity
- **Consistency**: Should align with difficulty progression

### HTML Tag Usage Rules

1. Both tags required for every checkbox pattern line
2. Tags go after the link, separated by space
3. Use consistent difficulty terminology across the path
4. Time should match kata's actual estimated duration

## Standard Footer

ALL learning path content MUST include the standard AI-generated attribution footer:

```markdown
---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
```

### Footer Rules

- **Position**: After all content sections (typically after "Progress Tracking")
- **Separator**: Horizontal rule (`---`) above footer text
- **Format**: Italicized paragraph with emoji, wrapped in markdownlint directives
- **Markdownlint directives**: Required to prevent MD036 (emphasis used instead of heading) warnings
- **Exact text**: Use the exact wording shown above
- **Required**: No exceptions - all learning paths must have this footer

## Path Hierarchy and Leveling

Learning paths are organized into three difficulty tiers that guide learners through progressive skill development:

### Difficulty Levels

1. **Foundation Builder** (`difficulty: foundation`)
   - **Target**: Professionals new to the topic area
   - **Duration**: Typically 3-5 hours
   - **Kata range**: Difficulty 1-2 katas
   - **Example**: "Edge Computing Fundamentals", "AI Engineering Fundamentals"
   - **Path naming**: `foundation-[topic-name].md`

2. **Skill Developer** (`difficulty: skill`)
   - **Target**: Developers with foundational knowledge seeking deeper expertise
   - **Duration**: Typically 4-6 hours
   - **Kata range**: Difficulty 2-3 katas with some level 4
   - **Example**: "Prompt Engineering Excellence", "Edge-to-Cloud Integration"
   - **Path naming**: `skill-[topic-name].md`

3. **Expert Practitioner** (`difficulty: expert`)
   - **Target**: Advanced professionals implementing production systems
   - **Duration**: Typically 5-8 hours
   - **Kata range**: Difficulty 3-5 katas, includes training labs
   - **Example**: "Platform Systems", "Full-Stack AI Integration"
   - **Path naming**: `expert-[topic-name].md`

### Progressive Path Design

When designing learning paths:

1. **Start accessible**: Begin with foundational concepts even in skill/expert paths
2. **Gradual progression**: Each kata should build naturally on previous ones
3. **Clear dependencies**: Make prerequisite relationships explicit
4. **Milestone markers**: Group related katas into phases with emojis
5. **Exit ramps**: Suggest related paths for learners who want to branch

### Audience Targeting

Every learning path must include audience descriptions:

#### "Perfect for" Pattern

```markdown
**Perfect for**: [Experience level] + [Role context] + [Specific goal]
```

**Examples**:

- "Technical professionals new to edge computing, developers exploring distributed systems, engineers building IoT solutions"
- "Developers experienced with AI tools, technical professionals optimizing AI interactions, engineers building AI-powered applications"

#### "Recommended for" Pattern

```markdown
**Recommended for**: [Role1], [Role2], [Role3], [Role4], [Role5]
```

**Common roles**:

- Software Engineers
- Platform Engineers
- Data Scientists
- Solution Architects
- Systems Administrators
- DevOps Engineers
- Product Owners
- QA Engineers
- UX/UI Designers
- Business Analysts

**Rules**:

1. List 4-6 specific roles (not generic terms)
2. Use title case for role names
3. Order by primary to secondary relevance
4. Separate with commas

## Validation Checklist

### Priority Levels

- 🔴 **CRITICAL**: Must be correct or path is unusable/non-compliant
- 🟠 **HIGH**: Important for quality and user experience
- 🟡 **MEDIUM**: Enhances usability and completeness
- **LOW**: Nice-to-have, improves polish

### Learning Path Content

- [ ] 🔴 **CRITICAL**: All required YAML fields present (title, description, author, ms.date, ms.topic, estimated_reading_time, difficulty, keywords)
- [ ] 🔴 **CRITICAL**: Triple-checkbox pattern applied to all katas/labs with 📚 emoji
- [ ] 🔴 **CRITICAL**: Standard footer present with markdownlint directives and emoji
- [ ] 🔴 **CRITICAL**: NO company names used in descriptions or scenarios
- [ ] 🔴 **CRITICAL**: Difficulty level in YAML matches path tier (foundation/skill/expert)
- [ ] 🟠 **HIGH**: Bold intro line includes level, duration, and topics
- [ ] 🟠 **HIGH**: "Perfect for" and "Recommended for" audience targeting present
- [ ] 🟠 **HIGH**: Kata sequence reflects progressive difficulty within phases
- [ ] 🟠 **HIGH**: Each kata listing includes time tag, difficulty tag, and description
- [ ] 🟠 **HIGH**: Prerequisites section with checkboxes for prior paths or experience
- [ ] 🟠 **HIGH**: Phase emojis used consistently for Core Learning Path sections
- [ ] 🟡 **MEDIUM**: "Next Steps" section suggests 2-4 logical follow-up paths
- [ ] 🟡 **MEDIUM**: "Progress Tracking" explanation section present
- [ ] 🟡 **MEDIUM**: Phase groupings have time estimates in parentheses
- [ ] **LOW**: All kata/lab links are valid and use correct relative paths (../../katas/ or ../../training-labs/)
- [ ] **LOW**: Estimated reading time approximately matches sum of individual kata times
- [ ] **LOW**: Keywords in YAML reflect main topics covered

### Validation Script Usage

Use the PowerShell validation script to check learning path compliance:

```powershell
# Validate learning path alignment for all katas
pwsh ../../scripts/kata-validation/Validate-Katas.ps1 -ValidationTypes Paths

# Validate all aspects of kata and path structure
pwsh ../../scripts/kata-validation/Validate-Katas.ps1 -ValidationTypes All

# Include individual kata files in validation
pwsh ../../scripts/kata-validation/Validate-Katas.ps1 -ValidationTypes Paths -IncludeIndividualKatas
```

The validation script checks:

- Learning path references in kata YAML
- Path naming consistency
- Difficulty level alignment
- Prerequisite chain validation

## References

1. **Kata Content Standards**: `kata-content.instructions.md` - Inherits No Company Names Policy, AI Coaching Integration, Standard Footer format
2. **Training Lab Standards**: `training-lab-content.instructions.md` - Multi-phase lab content requirements
3. **Example Learning Paths**:
   - `../../learning/paths/skill-prompt-engineering-excellence.md` - Skill-level path with triple-checkbox pattern
   - `../../learning/paths/foundation-edge-computing.md` - Foundation-level path example
   - `../../learning/paths/expert-platform-systems.md` - Expert-level path example
4. **Validation Script**: `../../scripts/kata-validation/Validate-Katas.ps1` - PowerShell script for learning path validation
5. **Kata Categories**: `../../learning/katas/README.md` - Overview of available katas for path composition
6. **Learning Paths Overview**: `../../learning/paths/README.md` - Root overview of all learning paths
7. **Learning Path Template**: Note - No template file currently exists in `../../learning/templates/`; refer to real examples above
