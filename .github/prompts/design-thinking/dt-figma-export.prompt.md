---
description: 'Export Design Thinking artifacts to a collaborative FigJam board or Figma Design file using the official Figma MCP server - Brought to you by microsoft/hve-core'
agent: 'DT Coach'
argument-hint: "project-slug=... [board-title=...] [method=latest] [output-type=figjam]"
tools: ['read_file', 'figma/*']
---

# DT Figma Export

## Overview

Export Design Thinking artifacts from `.copilot-tracking/dt/{project-slug}/` to a FigJam board or Figma Design file using the official `figma` MCP server.
Use this prompt after a team has produced Method 1, 3, 4, 5, or 6 artifacts that would benefit from collaborative visual review.

FigJam boards are the default output type. They provide a collaborative whiteboarding surface for sticky notes, text, shapes, connectors, and diagrams. Figma Design files are available for teams that want structured frames with auto-layout for higher-fidelity visual outputs.

## Inputs

* ${input:project-slug}: (Required) Kebab-case Design Thinking project identifier.
* ${input:board-title}: (Optional) Explicit board or file title. If omitted, derive a concise title from the project context and exported method.
* ${input:method}: (Optional, defaults to `latest`) Method number or `latest` to export the most recent DT method artifacts.
* ${input:output-type}: (Optional, defaults to `figjam`) Output type: `figjam` for a FigJam whiteboard, `design` for a Figma Design file, or `both` for one of each.

## Prerequisites

* The DT project artifacts MUST exist under `.copilot-tracking/dt/{project-slug}/`.
* The `figma` MCP server MUST be configured in your workspace (see `.vscode/mcp.json`).
* The user MUST have a Figma account with a Dev or Full seat on a Professional, Organization, or Enterprise plan for sustained usage. Starter plans are limited to 6 tool calls per month.
* Authentication happens automatically via browser OAuth on first use. No credential files or API keys are required.

## Workflow Steps

1. Resolve Project State:
   Read `.copilot-tracking/dt/{project-slug}/coaching-state.md` and confirm the project exists. If it does not, stop and explain how to start or resume a DT project first.

2. Select Export Scope:
   Determine which method artifacts to export based on `${input:method}`.
   If `${input:method}` is `latest`, infer the latest completed or active method from the coaching state and recent artifacts.
   Prefer explicit artifact files referenced in the coaching state over directory guessing.

3. Validate Figma Availability:
   Call `whoami` to confirm the Figma MCP server is connected and the user is authenticated.
   If the `figma` MCP server or tools are unavailable, stop and provide the setup path:
   Add `{"figma": {"type": "http", "url": "https://mcp.figma.com/mcp"}}` to `.vscode/mcp.json` under `servers`, then restart VS Code.

4. Create the Destination File:
   Use `create_new_file` to create a new FigJam file (for `figjam` output) or a new Figma Design file (for `design` output) or both (for `both` output).
   Use `${input:board-title}` when provided; otherwise derive a clear title from project and method context.
   If the user specifies an existing Figma URL instead of a title, use `get_figjam` or `get_metadata` to read the existing file before modifying it.

5. Build FigJam Export Layout (when output-type is `figjam` or `both`):
   Use `use_figma` to create sections, sticky notes, text, shapes, and connectors on the FigJam board.
   Translate artifact content into a left-to-right section layout with grouping areas and labeled sticky notes.

   **Section structure:**
   * Header section: Project name, method name, date, and current status.
   * Theme/category sections: One section per theme or category, arranged left to right.
   * Footer section: Summary, open questions, or how-might-we prompts.

   **Sticky note conventions:**
   * Yellow stickies: Evidence, facts, and observations.
   * Blue stickies: Implications, insights, and interpretations.
   * Green stickies: How-might-we questions and open questions.
   * Pink stickies: Decisions and validation targets.
   * Orange stickies: Constraints and risks.

   Keep sticky content concise: 1-3 short sentences per sticky.

   **Diagram generation:**
   Where structured relationships exist in the artifacts, use `generate_diagram` to create Mermaid-based diagrams:
   * Method 1: Stakeholder relationship flowchart showing influence and impact.
   * Method 3: Theme-to-evidence cluster diagram showing how evidence supports themes.
   * Method 8: User testing flow diagrams showing test scenarios and outcomes.

6. Build Figma Design Export Layout (when output-type is `design` or `both`):
   Use `use_figma` to create structured frames with auto-layout in a Figma Design file.

   **Frame structure:**
   * Main frame: Named after the project and method, using auto-layout (vertical, 40px gap).
   * Header frame: Project title, method name, date, status as text layers.
   * Content frames: One frame per theme or category with auto-layout (vertical, 20px gap).
   * Card components: Each artifact item as a card frame (rounded corners, padding, fill).

   **Card conventions:**
   * Evidence cards: Light yellow background (#FFF9C4), dark text.
   * Insight cards: Light blue background (#BBDEFB), dark text.
   * Question cards: Light green background (#C8E6C9), dark text.
   * Decision cards: Light pink background (#F8BBD0), dark text.
   * Constraint cards: Light orange background (#FFE0B2), dark text.

   Use consistent typography: title text at 24px, body text at 16px, labels at 12px.

7. Apply Method-Specific Layout:
   For Method 1, export request framing, stakeholder map, constraints, and open questions. Generate a stakeholder relationship diagram.
   For Method 2, export research findings, personas, and assumption logs. When persona artifacts are present, use the **Persona Card** template below.
   For Method 3, export synthesis themes, evidence clusters, and how-might-we prompts. Generate a theme-evidence cluster diagram.
   For Method 4, export idea clusters and convergence candidates. Arrange ideas by category in columns.
   For Method 5, export concepts, evaluation notes, and stakeholder reactions. Create concept comparison cards.
   For Method 6, export prototype plan, build decisions, and testing hypotheses. Create a hypothesis tracking board.
   If artifacts span multiple methods, group by method first and then by theme.

## Exercise Templates

The following structured templates define precise FigJam layouts for specific DT exercises.
When artifacts match a template type, use the template layout instead of the generic section/sticky approach.
Each template specifies sections, rows, sticky colors, and spatial arrangement.

### Persona Card (Method 2)

Use this template when exporting persona artifacts from Design Research.
Create one Persona Card per persona found in the project artifacts.
Follow the reference implementation EXACTLY. Do not improvise layout, colors, spacing, or structure.

**Reference layout:**

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

**Reference implementation (Figma Plugin API):**

The following code is the EXACT construction pattern to follow. Substitute persona data for the placeholder arrays.
Do NOT deviate from the layout constants, color values, or positioning logic.

All elements use `createShapeWithText` (FigJam shapes), NOT `createSticky`.
Headings sit ABOVE their card rows, not in a left column.
The intro text block combines name, role, and description in a single shape with mixed font ranges.

```javascript
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

**Strict rules:**

1. **One section per persona.** Section name = `PERSONA - {ROLE NAME}` (uppercase). All shapes go inside this section.
2. **Row order is fixed:** Primary Tools, Other Tools, Responsibilities, Behavioural Traits, Desires, Goals, Needs, Hacks and Workarounds, Key Findings. Do not reorder.
3. **Color is fixed:** All card shapes use `#FFE0C2`. Do not substitute or vary by category.
4. **Use shapes, not stickies.** All elements use `createShapeWithText` with `ROUNDED_RECTANGLE` (cards) or `SQUARE` (headings/intro). Never use `createSticky`.
5. **Headings above rows.** Each category heading sits above its card grid as a transparent `SQUARE` shape, not in a left column.
6. **Intro layout:** Name, role, and description are a single `SQUARE` shape with mixed font ranges positioned to the left. The avatar ellipse is positioned to the right.
7. **Grid coordinates are fixed:** Use the constants from the reference code. Do not freestyle positioning.
8. **Wrapping:** Rows with more than 5 items wrap at column 6 to a new line within the same category.
9. **Omit empty rows:** If a persona has no data for a category, skip that row entirely. Do not create empty rows.
10. **Multiple personas:** Arrange persona sections left to right with 80px horizontal gaps using the `offsetX` parameter.

**Data mapping:**

Pull persona data from artifact files under `.copilot-tracking/dt/{project-slug}/`. Map fields:

| Artifact field | Template row | Notes |
|---|---|---|
| `name`, first heading | Intro name (40pt bold) | Display name of the persona |
| `role`, `title`, subheading | Intro role (22pt bold) | Job title or role label |
| `description`, body text | Intro body (14pt regular) | Paragraphs separated by `\n\n` |
| `tools`, `primary_tools` | Primary Tools | Each item: tool name + parenthetical use |
| `other_tools`, `secondary_tools` | Other Tools | Each item: tool name + parenthetical use |
| `responsibilities`, `duties` | Responsibilities | Each item: 1--2 sentence description |
| `traits`, `behavioural_traits` | Behavioural Traits | Each item: trait + brief qualifier |
| `desires` | What do they desire in their role? | Each item: desired outcome statement |
| `goals`, `motivations` | What kinds of goals drive them? | Each item: goal or motivation statement |
| `needs` | Needs | Each item: need statement |
| `hacks`, `workarounds` | Hacks and Workarounds | Each item: current workaround description |
| `findings`, `key_findings` | Key Findings | Each item: research finding statement |

If a field is missing from the artifact, omit that row. Do not invent placeholder data.

8. Report Results:
   Summarize the file title, file URL (provided by `create_new_file` or `use_figma`), output type, and counts of sections, stickies, text elements, and diagrams created.
   Call out any skipped or failed items with actionable reasons.

## Success Criteria

* [ ] DT artifacts were read from `.copilot-tracking/dt/{project-slug}/`.
* [ ] The `figma` MCP server was available and used successfully.
* [ ] A new or updated FigJam board or Figma Design file contains readable sections aligned to the DT artifact structure.
* [ ] The user received the file URL and a concise export summary.

## Examples

```text
/dt-figma-export project-slug=factory-floor-maintenance
```

```text
/dt-figma-export project-slug=customer-support-ai board-title="Customer Support AI - Stakeholder Map" method=1
```

```text
/dt-figma-export project-slug=warehouse-onboarding method=3 output-type=both
```

```text
/dt-figma-export project-slug=incident-response output-type=design
```

## Error Handling

* If the DT project directory or coaching state is missing, stop and direct the user to create or resume the project before export.
* If the `figma` MCP server is not configured, stop and provide the setup instructions rather than attempting a partial export.
* If `whoami` indicates a Starter plan, warn the user about the 6-call monthly limit and suggest batching exports.
* If artifacts are incomplete for the requested method, explain the gap and ask whether to export the available subset or return to coaching.
* If file creation or widget placement fails, report exactly which sections or elements failed and preserve the successfully created content.

## Rate Limits

The Figma MCP server applies rate limits based on your Figma plan:

* **Starter plan or View/Collab seats**: Up to 6 tool calls per month. DT export will likely exhaust this in a single session.
* **Dev or Full seats on Professional/Organization/Enterprise**: Per-minute rate limits matching Figma REST API Tier 1.

For best results, ensure team members have Dev or Full seats on a paid Figma plan.

## Beta Notice

The `use_figma` write tool is currently in beta and free during the beta period. Figma has indicated it will eventually become a usage-based paid feature. The read-only tools (`get_figjam`, `get_screenshot`, `generate_diagram`) are not affected by this and will continue to work.

---

Brought to you by microsoft/hve-core
