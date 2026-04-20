<!-- markdownlint-disable-file -->
# Customer Card Canonical-to-Visual Mapping Spec

Defines how each canonical artifact type maps to PPTX render fields.
This spec is the contract `generate_cards.py` implements and `build-cards.ps1` invokes.

## Canonical Source Layout

```
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

Canonical files are accepted in either of these equivalent formats:

Format A (frontmatter title + explicit summary heading):

```markdown
---                            ← YAML frontmatter
title: <string>
---

## Customer-friendly summary   ← Customer card body text
<paragraph>

## Internal metadata           ← Markdown table
| Artifact type | <Value>     |
| Source path   | <rel/path>  |
| Last updated  | YYYY-MM-DD  |
...
```

Format B (header + summary block + metadata table):

```markdown
## <Artifact Header>

<summary paragraph>

### Internal Metadata
| Property | Value |
|----------|-------|
| Source artifact type | <Value> |
| Source file path | <rel/path> |
... 
```

The renderer must map both metadata naming variants:

* `Artifact type` or `Source artifact type`
* `Source path` or `Source file path`
* `Last updated` (optional; defaults to current date when missing)

Scenario, Use Case, and Persona files additionally contain type-specific sections extracted into structured customer cards.

---

## Render Fields per Card Type

### Common elements (all card types)

| Render field      | Source                          | PPTX element              | Position (inches)                              |
|-------------------|---------------------------------|---------------------------|------------------------------------------------|
| Background        | Fixed                           | Slide fill `#0F1117`      | Full slide                                     |
| Card frame        | Fixed                           | Rectangle `#1A1D27`       | left=0.25, top=0.25, w=12.833, h=7.0           |
| Accent bar        | Fixed (type color)              | Rectangle, h=0.08         | left=0.25, top=0.25, w=12.833 (top of frame)   |
| Type badge        | `Artifact type` metadata        | Rounded rect + text, 9pt  | left=0.55, top=0.55, w=2.5, h=0.36             |
| Title             | Frontmatter `title`             | Textbox, 28pt bold white  | left=0.55, top=1.10, w=11.8, h=1.35            |
| Divider           | Fixed (type color)              | Rectangle, h=0.02         | left=0.55, top=2.58, w=11.8                    |
| Footer: source    | `Source path` metadata          | Textbox, 9pt muted        | left=0.55, top=6.88, w=9.5, h=0.25             |
| Footer: date      | `Last updated` metadata         | Textbox, 9pt muted right  | left=11.0, top=6.88, w=2.1, h=0.25             |
| Speaker notes     | Artifact type + source path     | PPTX notes field          | —                                              |

### Vision Statement

| Render field | Source                            | Notes                     |
|--------------|-----------------------------------|---------------------------|
| Type badge   | "VISION STATEMENT"                | Accent `#0078D4` (blue)   |
| Title        | Frontmatter `title`               | Max 90 chars              |
| Body         | `## Vision Statement`             | Full width body text      |
| Image slot   | None                              | —                         |
| Extra fields | `### Why This Matters`            | Labeled secondary section |

Body area: left=0.55, top=2.75, w=11.8, h=3.85

### Problem Statement

| Render field | Source                            | Notes                     |
|--------------|-----------------------------------|---------------------------|
| Type badge   | "PROBLEM STATEMENT"               | Accent `#D83B01` (red)    |
| Title        | Frontmatter `title`               | Max 90 chars              |
| Body         | `## Problem Statement`            | Full width body text      |
| Image slot   | None                              | —                         |
| Extra fields | None                              | —                         |

Body area: left=0.55, top=2.75, w=11.8, h=3.85

### Scenario

Scenario cards render only the approved sections. All other canonical scenario sections are ignored by the visual renderer.

Required canonical sections, in order:

1. `### Description`
2. `### Scenario Narrative`
3. `### How Might We`

Scenario layout:

* Single slide
* Full-width `Description` section above the lower grid
* Lower left column: `Scenario Narrative`
* Lower right column: `How Might We`
* All three sections render as labeled shrink-to-fit text blocks

The `How Might We` section should capture:

* The business value being pursued
* Opportunities that become possible if the scenario succeeds
* Who benefits from the scenario
* What those benefits are

### Use Case

Use case cards render only the approved sections and preserve the required order across one or more pages.

Required canonical sections, in order:

1. `### Use Case Description`
2. `### Business Value`
3. `### Use Case Overview`
4. `### Primary User`
5. `### Secondary User`
6. `### Preconditions`
7. `### Steps`
8. `### Data Requirements`
9. `### Equipment Requirements`
10. `### Operating Environment`
11. `### Success Criteria`
12. `### Pain Points`
13. `### Evidence`

Use case layout:

* Multi-page, 2-column by 2-row grid
* Up to 4 sections per slide
* Sections flow in the required order
* Only these sections are rendered

### Persona

| Render field | Source                                     | Notes                                    |
|--------------|--------------------------------------------|------------------------------------------|
| Type badge   | "PERSONA"                                  | Accent `#5C2D91` (purple)               |
| Title        | Frontmatter `title`                        | Max 90 chars                             |
| Body         | `### Description`                          | Used as the slide's customer summary     |
| Image slot   | Placeholder rectangle                      | left=9.1, top=2.75, w=3.7, h=3.4       |
| Goal         | `### User Goal` section                    | Extra field 1 below body               |
| Needs        | First bullet of `### User Needs` section   | Extra field 2 below body               |

Extra field area: Goal at top=5.55, Needs at top=6.05; w=7.9, h=0.38 each.

---

## Accent Color Palette

| Artifact type      | Hex       | Role                        |
|--------------------|-----------|-----------------------------|
| Vision Statement   | `#0078D4` | Microsoft blue — aspiration |
| Problem Statement  | `#D83B01` | Alert red — tension/need    |
| Scenario           | `#107C10` | Action green — user journey |
| Persona            | `#5C2D91` | Purple — identity           |

---

## Narrative Ordering

Cards are emitted in this sequence, matching the DT discovery flow:

1. Vision Statement
2. Problem Statement
3. Scenarios (alphabetical by filename)
4. Use Cases (alphabetical by filename)
5. Personas (alphabetical by filename)

---

## Text Handling Rules

Customer-card rendering preserves canonical content without truncation.

* Textboxes use shrink-to-fit behavior when content exceeds available space.
* Markdown list structure is preserved in rendered text blocks.
* Newlines are normalized for layout while keeping section semantics intact.

---

## Output Structure

The generator writes to `render/content/`:

```
render/content/
├── global/
│   └── style.yaml
├── slide-001/
│   └── content.yaml    ← Vision Statement
├── slide-002/
│   └── content.yaml    ← Problem Statement
├── slide-003/
│   └── content.yaml    ← Scenario: monthly-utility-bill-retrieval-and-allocation
├── slide-004/
│   └── content.yaml    ← Use Case: monthly-utility-distribution (Part 1)
└── slide-005/
    └── content.yaml    ← Persona: team-lead-async-share-author
```

The PPTX lands in `render/output/`:

```
render/output/
└── customer-cards.pptx
```
