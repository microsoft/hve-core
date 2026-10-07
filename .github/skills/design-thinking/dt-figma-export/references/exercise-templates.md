---
title: 'DT Figma Export Exercise Templates'
description: FigJam layouts, reference Figma Plugin API code, and data mappings for the Project Details card and Persona Card exercises.
---

The following structured templates define precise FigJam layouts for specific DT exercises.
When artifacts match a template type, use the template layout instead of the generic section/sticky approach.
Each template specifies sections, rows, sticky colors, and spatial arrangement.

Universal components appear first and apply to every board. Exercise-specific templates follow.

## Universal: Project Details Card

Place this component at the top-left of every FigJam board before any exercise-specific content.
It provides engagement context so all board viewers know the project scope at a glance.
Create it once per board. All exercise sections are positioned below or to the right of it.

Reference layout:

```text
+============================================================+
| PROJECT DETAILS                        (section, blue fill) |
+============================================================+
|  +------------------------------------------------------+  |
|  | Customer: {customer name}                             |  |
|  +------------------------------------------------------+  |
|  +------------------------------------------------------+  |
|  | Project: {project name}                               |  |
|  +------------------------------------------------------+  |
|  +------------------------------------------------------+  |
|  | Sprint: {milestone / sprint info}                     |  |
|  +------------------------------------------------------+  |
|  +------------------------------------------------------+  |
|  | Workstream: {workstream description}                  |  |
|  +------------------------------------------------------+  |
|  +------------------------------------------------------+  |
|  | Prototype: {link to prototype or video}               |  |
|  +------------------------------------------------------+  |
+============================================================+
```

Reference implementation (Figma Plugin API):

The following code is the exact construction pattern to follow. Substitute actual project data for the placeholder values.
Do not deviate from the layout constants, color values, or positioning logic.

All elements use `createShapeWithText` (FigJam shapes) inside a `createSection` with a blue fill.
Each field row uses mixed font ranges: bold label, regular value.

```javascript
// ── LOAD FONTS (required before any text operations) ──
await figma.loadFontAsync({family: "Inter", style: "Regular"});
await figma.loadFontAsync({family: "Inter", style: "Bold"});

// ── PROJECT DETAILS CONSTANTS (do not change) ──
const DET_PAD   = 40;    // internal padding
const ROW_W     = 1000;  // field row width
const ROW_H     = 52;    // field row height
const ROW_GAP   = 16;    // gap between rows
const DET_W     = ROW_W + 2 * DET_PAD; // 1080
const CORNER_R  = 16;    // outer corner radius

// ── COLORS (do not change) ──
const BG_BLUE  = {r: 0x00/255, g: 0x78/255, b: 0xD4/255}; // #0078D4
const ROW_BLUE = {r: 0x21/255, g: 0x96/255, b: 0xF3/255}; // #2196F3
const WHITE    = {r: 1, g: 1, b: 1};

// ── BUILDER FUNCTION ──
// fields = [{label: "Customer", value: "{Customer name}"}, ...]
function buildProjectDetails(fields, x, y) {
  const DET_H = 2 * DET_PAD + fields.length * ROW_H
              + (fields.length - 1) * ROW_GAP;

  const section = figma.createSection();
  section.name = "PROJECT DETAILS";
  section.fills = [{type: 'SOLID', color: BG_BLUE}];

  let rowY = DET_PAD;
  for (const field of fields) {
    const row = figma.createShapeWithText();
    row.shapeType = "ROUNDED_RECTANGLE";
    row.resize(ROW_W, ROW_H);
    row.x = DET_PAD;
    row.y = rowY;
    row.cornerRadius = 6;
    row.fills = [{type: 'SOLID', color: ROW_BLUE}];
    row.strokes = [];

    const lbl = field.label + ": ";
    row.text.characters = lbl + field.value;
    row.text.fontName = {family: "Inter", style: "Regular"};
    row.text.fontSize = 18;
    row.text.fills = [{type: 'SOLID', color: WHITE}];
    row.text.textAlignHorizontal = "LEFT";
    row.text.setRangeFontName(0, lbl.length,
      {family: "Inter", style: "Bold"});

    section.appendChild(row);
    rowY += ROW_H + ROW_GAP;
  }

  section.resizeWithoutConstraints(DET_W, DET_H);
  section.x = x;
  section.y = y;
  figma.currentPage.appendChild(section);
  return section;
}

// ── USAGE ──
// Place at (0, 0). Exercise templates go below at y = details.height + 80.
// const details = buildProjectDetails([
//   {label: "Customer",    value: "{Customer name}"},
//   {label: "Project",     value: "{Project name}"},
//   {label: "Sprint",      value: "{Milestone / Sprint}"},
//   {label: "Workstream",  value: "{Workstream description}"},
//   {label: "Prototype",   value: "{Link to prototype or video}"},
// ], 0, 0);
```

Rules:

1. Build the Project Details card before any exercise template on the board and position it at (0, 0).
2. Create only one Project Details card per FigJam file, regardless of how many exercise templates follow.
3. Use `createSection` with a `#0078D4` fill, not a standalone shape, so all field rows stay grouped and movable.
4. Keep the field order fixed: Customer, Project, Sprint, Workstream, Prototype.
5. Keep the colors fixed: section fill `#0078D4`, row fill `#2196F3`, and white text.
6. Use bold for each row's label portion and regular for its value, applying `setRangeFontName` to the label substring.
7. Start every exercise section at `y = detailsSection.height + 80` or greater to avoid overlap.
8. Skip any project detail field that has no data rather than creating a placeholder row.

Data mapping:

Pull project details from `.copilot-tracking/dt/{project-slug}/coaching-state.md` and any associated metadata. Map fields:

| Source                               | Field Label | Notes                                           |
|--------------------------------------|-------------|-------------------------------------------------|
| `customer`, `client`, `organization` | Customer    | Customer or client organization name            |
| `project`, `engagement`, `title`     | Project     | Project or engagement name                      |
| `sprint`, `milestone`, `iteration`   | Sprint      | Current sprint or milestone label               |
| `workstream`, `stream`, `track`      | Workstream  | Active workstream or focus area                 |
| `prototype_url`, `demo_url`, `video` | Prototype   | URL or descriptive label for prototype or video |

If the coaching state does not contain a field, check the project README or ask the user. Never invent placeholder values.

## Persona Card (Method 2)

Use this template when exporting persona artifacts from Design Research.
Create one Persona Card per persona found in the project artifacts.
Follow the reference implementation exactly. Do not improvise layout, colors, spacing, or structure.

Reference layout:

```text
+============================================================================+
| PERSONA - {ROLE NAME}                                    (section title)   |
+============================================================================+
|                                                                            |
| [Name]          (40pt bold)                        [👤 Portrait]           |
| [Role]          (22pt bold)                         248px ellipse          |
| [Description paragraphs]                            peach fill             |
|                  (14pt regular, grey)               gold stroke            |
|                                                                            |
+----------------------------------------------------------------------------+
| **Primary Tools**              (heading above cards, 13pt bold)            |
| [Tool 1]  [Tool 2]  [Tool 3]  [Tool 4]  [Tool 5]                         |
|  233x135   233x135   233x135   233x135   233x135   #FFE0C2 fill           |
+----------------------------------------------------------------------------+
| **Other Tools**                                                            |
| [Tool 1]  [Tool 2]                                                         |
+----------------------------------------------------------------------------+
| **Responsibilities**                                                       |
| [Resp 1]  [Resp 2]  [Resp 3]  [Resp 4]  [Resp 5]   (row 1)               |
| [Resp 6]  [Resp 7]  [Resp 8]  [Resp 9]              (row 2, wraps)        |
+----------------------------------------------------------------------------+
| **Behavioural Traits**                                                     |
| [Trait 1] [Trait 2] [Trait 3] [Trait 4] [Trait 5]                          |
| [Trait 6]                                                                  |
+----------------------------------------------------------------------------+
| **What do they desire in their role?**                                     |
| [Desire 1] [Desire 2] [Desire 3] [Desire 4] [Desire 5]                   |
+----------------------------------------------------------------------------+
| **What kinds of goals drive them?**                                        |
| [Goal 1] [Goal 2] [Goal 3] [Goal 4] [Goal 5]                             |
+----------------------------------------------------------------------------+
| **Needs**                                                                  |
| [Need 1] [Need 2] [Need 3] [Need 4] [Need 5]                             |
+----------------------------------------------------------------------------+
| **Hacks and Workarounds**                                                  |
| [Hack 1] [Hack 2] [Hack 3] [Hack 4] [Hack 5]                             |
+----------------------------------------------------------------------------+
| **Key Findings**                                                           |
| [Finding 1] [Finding 2] [Finding 3] [Finding 4] [Finding 5]               |
+============================================================================+
```

Reference implementation (Figma Plugin API):

The following code is the exact construction pattern to follow. Substitute persona data for the placeholder arrays.
Do not deviate from the layout constants, color values, or positioning logic.

All elements use `createShapeWithText` (FigJam shapes), not `createSticky`.
Headings sit above their card rows, not in a left column.
The intro text block combines name, role, and description in a single shape with mixed font ranges.

```javascript
// ── LOAD FONTS (required before any text operations) ──
await figma.loadFontAsync({family: "Inter", style: "Regular"});
await figma.loadFontAsync({family: "Inter", style: "Bold"});

// ── LAYOUT CONSTANTS (do not change) ──
const CELL_W      = 233;   // card width
const CELL_H      = 135;   // card height
const GAP         = 8;     // consistent gap between all elements
const COLS        = 5;     // max cards per row before wrapping
const GRID_W      = COLS * CELL_W + (COLS - 1) * GAP;
const AVATAR_SIZE = 248;   // portrait circle diameter
const LEFT_PAD    = 20;    // left padding from section edge
const INTRO_X     = LEFT_PAD + AVATAR_SIZE + 32;
const INTRO_W     = 667;   // intro text block width
const HEADING_GAP = 6;     // gap between heading and its cards
const ROW_GAP     = 16;    // gap between last card row and next heading

// ── COLORS (do not change) ──
const CARD_COLOR = {r: 0xFF/255, g: 0xE0/255, b: 0xC2/255}; // #FFE0C2
const PEACH_BG   = {r: 249/255, g: 228/255, b: 200/255};    // avatar fill
const DARK       = {r: 0.15, g: 0.15, b: 0.15};             // heading + card text
const GRAY       = {r: 0.3, g: 0.3, b: 0.3};                // body text

// ── REUSABLE BUILDER FUNCTION ──
// Call once per persona. offsetX positions multiple cards side by side.
function buildPersona(personaName, roleTitle, bodyText, rows, offsetX) {
  const section = figma.createSection();
  section.name = "PERSONA - " + roleTitle.toUpperCase();

  // ── INTRO TEXT (left side, single shape with mixed fonts) ──
  const intro = figma.createShapeWithText();
  intro.shapeType = "SQUARE";
  intro.resize(INTRO_W, 450);
  intro.x = LEFT_PAD; intro.y = 20;
  intro.fills = [];
  intro.strokes = [];
  intro.text.textAlignHorizontal = "LEFT";
  intro.text.fontName = {family: "Inter", style: "Regular"};
  intro.text.fontSize = 14;
  intro.text.fills = [{type: 'SOLID', color: GRAY}];

  const fullText = personaName + "\n" + roleTitle + "\n\n" + bodyText;
  intro.text.characters = fullText;

  // Apply font ranges: name=40pt bold, role=22pt bold, body=14pt regular
  const nameEnd = personaName.length;
  const roleStart = nameEnd + 1;
  const roleEnd = roleStart + roleTitle.length;
  intro.text.setRangeFontName(0, nameEnd, {family: "Inter", style: "Bold"});
  intro.text.setRangeFontSize(0, nameEnd, 40);
  intro.text.setRangeFills(0, nameEnd, [{type: 'SOLID', color: DARK}]);
  intro.text.setRangeFontName(roleStart, roleEnd, {family: "Inter", style: "Bold"});
  intro.text.setRangeFontSize(roleStart, roleEnd, 22);
  intro.text.setRangeFills(roleStart, roleEnd, [{type: 'SOLID', color: DARK}]);
  section.appendChild(intro);

  // ── AVATAR (right side) ──
  const avatar = figma.createShapeWithText();
  avatar.shapeType = "ELLIPSE";
  avatar.resize(AVATAR_SIZE, AVATAR_SIZE);
  avatar.x = LEFT_PAD + GRID_W - AVATAR_SIZE;
  avatar.y = 20;
  avatar.fills = [{type: 'SOLID', color: PEACH_BG}];
  avatar.strokes = [{type: 'SOLID', color: {r: 200/255, g: 160/255, b: 80/255}}];
  avatar.strokeWeight = 4;
  avatar.text.characters = "Portrait";
  section.appendChild(avatar);

  // ── CATEGORY ROWS (heading above cards) ──
  let y = 500;

  for (const row of rows) {
    // Heading shape (transparent, left-aligned, bold)
    const heading = figma.createShapeWithText();
    heading.shapeType = "SQUARE";
    heading.resize(300, 30);
    heading.x = LEFT_PAD;
    heading.y = y;
    heading.fills = [];
    heading.strokes = [];
    heading.text.fontName = {family: "Inter", style: "Bold"};
    heading.text.fontSize = 13;
    heading.text.characters = row.label;
    heading.text.fills = [{type: 'SOLID', color: DARK}];
    heading.text.textAlignHorizontal = "LEFT";
    section.appendChild(heading);

    y += 30 + HEADING_GAP;

    // Card grid (ROUNDED_RECTANGLE shapes, 8px corner radius)
    const numCellRows = Math.ceil(row.items.length / COLS);
    for (let i = 0; i < row.items.length; i++) {
      const col = i % COLS;
      const cellRow = Math.floor(i / COLS);
      const card = figma.createShapeWithText();
      card.shapeType = "ROUNDED_RECTANGLE";
      card.resize(CELL_W, CELL_H);
      card.x = LEFT_PAD + col * (CELL_W + GAP);
      card.y = y + cellRow * (CELL_H + GAP);
      card.cornerRadius = 8;
      card.fills = [{type: 'SOLID', color: CARD_COLOR}];
      card.strokes = [];
      card.text.fontName = {family: "Inter", style: "Regular"};
      card.text.fontSize = 12;
      card.text.characters = row.items[i];
      card.text.fills = [{type: 'SOLID', color: DARK}];
      section.appendChild(card);
    }

    y += numCellRows * CELL_H + (numCellRows - 1) * GAP + ROW_GAP;
  }

  section.resizeWithoutConstraints(LEFT_PAD + GRID_W + LEFT_PAD, y + 40);
  section.x = offsetX;
  figma.currentPage.appendChild(section);
  return section;
}

// ── USAGE ──
// Call buildPersona once per persona. Arrange side by side:
// const p1 = buildPersona("Sam", "Case Worker", bodyText, rows, 0);
// const p2 = buildPersona("Alex", "Field Auditor", bodyText2, rows2, p1.width + 80);
```

Rules:

1. Create one section per persona named `PERSONA - {ROLE NAME}` in uppercase, and place all of its shapes inside that section.
2. Keep the row order fixed: Primary Tools, Other Tools, Responsibilities, Behavioural Traits, Desires, Goals, Needs, Hacks and Workarounds, Key Findings.
3. Fill every card shape with `#FFE0C2`; do not vary the color by category.
4. Build every element with `createShapeWithText`, using `ROUNDED_RECTANGLE` for cards and `SQUARE` for headings and the intro; never use `createSticky`.
5. Place each category heading above its card grid as a transparent `SQUARE` shape, not in a left column.
6. Combine the name, role, and description in a single left-hand `SQUARE` shape with mixed font ranges, and position the avatar ellipse to the right.
7. Use the constants from the reference code for grid coordinates rather than freestyle positioning.
8. Wrap rows with more than five items at column six onto a new line within the same category.
9. Skip any category with no persona data rather than creating an empty row.
10. Arrange multiple persona sections left to right with 80px horizontal gaps using the `offsetX` parameter.

Data mapping:

Pull persona data from artifact files under `.copilot-tracking/dt/{project-slug}/`. Map fields:

| Artifact field                   | Template row                       | Notes                                     |
|----------------------------------|------------------------------------|-------------------------------------------|
| `name`, first heading            | Intro name (40pt bold)             | Display name of the persona               |
| `role`, `title`, subheading      | Intro role (22pt bold)             | Job title or role label                   |
| `description`, body text         | Intro body (14pt regular)          | Paragraphs separated by `\n\n`            |
| `tools`, `primary_tools`         | Primary Tools                      | Each item: tool name + parenthetical use  |
| `other_tools`, `secondary_tools` | Other Tools                        | Each item: tool name + parenthetical use  |
| `responsibilities`, `duties`     | Responsibilities                   | Each item: 1--2 sentence description      |
| `traits`, `behavioural_traits`   | Behavioural Traits                 | Each item: trait + brief qualifier        |
| `desires`                        | What do they desire in their role? | Each item: desired outcome statement      |
| `goals`, `motivations`           | What kinds of goals drive them?    | Each item: goal or motivation statement   |
| `needs`                          | Needs                              | Each item: need statement                 |
| `hacks`, `workarounds`           | Hacks and Workarounds              | Each item: current workaround description |
| `findings`, `key_findings`       | Key Findings                       | Each item: research finding statement     |

If a field is missing from the artifact, omit that row. Do not invent placeholder data.
