---
description: "Canonical markdown section-to-field mapping for customer-card generation"
---

<!-- markdownlint-disable-file -->
# Customer Card Mapping Spec

This spec defines only canonical section extraction and field mapping.

Layout, sizing, theming, rendering, export, and validation behavior are owned by the shared PowerPoint skill:

- `.github/skills/experimental/powerpoint/SKILL.md`

## Canonical Source Structure

```text
canonical/
├── vision-statement.md
├── problem-statement.md
├── scenarios/
│   └── *.md
├── use-cases/
│   └── *.md
└── personas/
    └── *.md
```

## Metadata Mapping

Support both metadata naming variants:

- `Artifact type` or `Source artifact type`
- `Source path` or `Source file path`
- `Last updated` (fallback to current date)

## Field Mapping by Card Type

### Vision Statement

Required sections:

- Title: frontmatter `title`, else first heading
- `## Vision Statement` (primary vision)
- `### Why This Matters` (secondary rationale)

**Generator Implementation**: `_vision_sections()` extracts both sections into individual placeholders: `V_VISION_STATEMENT`, `V_WHY_THIS_MATTERS`.

**Template Design**: Two textboxes on a single slide with dedicated headers ("Vision Statement" and "Why This Matters"). Each section displays separately with appropriate sizing.

### Problem Statement

Required sections:

- Title: frontmatter `title`, else first heading
- `## Problem Statement` (the problem to solve)

**Generator Implementation**: `_problem_sections()` extracts the Problem Statement section into placeholder: `P_PROBLEM_STATEMENT`.

**Template Design**: Single textbox on a slide. Well-suited to accommodate typical problem statements without overflow.

### Scenario

Required sections in order:

1. `### Description`
2. `### Scenario Narrative`
3. `### How Might We`

**Generator Implementation**: `_scenario_sections()` extracts all three sections into individual placeholders: `SC_DESCRIPTION`, `SC_SCENARIO_NARRATIVE`, `SC_HOW_MIGHT_WE`.

**Template Design**: Three textboxes on a single slide, each with a dedicated header and section content. Sections stack vertically without aggregation or truncation.

### Use Case

Use Case artifacts are split across **4 slides**. Each slide has dedicated sections with no aggregation or truncation.

#### Slide 1: Use Case Overview

Required sections:

1. `### Use Case Description`
2. `### Use Case Overview`
3. `### Business Value`
4. `### Primary User`

**Generator Implementation**: `_use_case_slide1()` extracts these sections into the slide1 template placeholders: `UC_DESCRIPTION`, `UC_OVERVIEW`, `UC_BUSINESS_VALUE`, `UC_PRIMARY_USER`.

#### Slide 2: Use Case Execution

Required sections:

1. `### Secondary User`
2. `### Preconditions`
3. `### Steps`
4. `### Data Requirements`

**Generator Implementation**: `_use_case_slide2()` extracts these sections into the slide2 template placeholders: `UC_SECONDARY_USER`, `UC_PRECONDITIONS`, `UC_STEPS`, `UC_DATA_REQUIREMENTS`.

#### Slide 3: Use Case Quality & Context

Required sections:

1. `### Equipment Requirements`
2. `### Operating Environment`
3. `### Success Criteria`
4. `### Pain Points`

**Generator Implementation**: `_use_case_slide3()` extracts these sections into the slide3 template placeholders: `UC_EQUIPMENT_REQUIREMENTS`, `UC_OPERATING_ENVIRONMENT`, `UC_SUCCESS_CRITERIA`, `UC_PAIN_POINTS`.

#### Slide 4: Use Case Extensions & Evidence

Required sections:

1. `### Extensions`
2. `### Evidence`

**Generator Implementation**: `_use_case_slide4()` extracts these sections into the slide4 template placeholders: `UC_EXTENSIONS`, `UC_EVIDENCE`.

**Template Design**: Two textboxes on a slide with dedicated headers. Extensions receives more vertical space (2.8") to accommodate typical extension content, while Evidence uses a smaller section (0.7").

**Note**: All Use Case slides appear consecutively in the final deck (e.g., Use Case "Project Alpha" generates slides 5, 6, 7, 8).

### Persona

Required sections:

1. `### Description`
2. `### User Goal`
3. `### User Needs`
4. `### User Mindset`

**Generator Implementation**: `_persona_sections()` extracts all four sections into individual placeholders: `PE_DESCRIPTION`, `PE_USER_GOAL`, `PE_USER_NEEDS`, `PE_USER_MINDSET`.

**Template Design**: Four textboxes on a single slide, each with a dedicated header and section content. Sections stack vertically without aggregation or truncation.

## Narrative Ordering

Output ordering follows DT discovery progression with Use Cases expanded into 4 slides:

1. Vision Statement (slide 1)
2. Problem Statement (slide 2)
3. Scenarios (alphabetical, one slide each)
4. Use Cases (alphabetical, 4 slides each per Use Case)
5. Personas (alphabetical, one slide each)

Example with 2 scenarios, 1 use case, 1 persona:
- Slide 1: Vision Statement
- Slide 2: Problem Statement
- Slide 3: Scenario "Customer onboarding"
- Slide 4: Scenario "Post-launch support"
- Slide 5-8: Use Case "Enterprise deployment" (4 slides)
- Slide 9: Persona "Infrastructure engineer"

## Missing Data Contract

If canonical sections use `<insufficient knowledge>`, preserve it verbatim in generated slide fields. The generator must not invent replacement content.
