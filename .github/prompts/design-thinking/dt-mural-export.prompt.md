---
description: 'Export Design Thinking artifacts to a collaborative Mural board using an optional MCP server - Brought to you by microsoft/hve-core'
agent: 'agent'
argument-hint: "project-slug=... [board-title=...] [method=latest]"
tools: ['read_file', 'mural/*']
---

# DT Mural Export

## Overview

Export Design Thinking artifacts from `.copilot-tracking/dt/{project-slug}/` to a Mural board using an optional `mural` MCP server.
Use this prompt after a team has produced Method 1, 3, 4, 5, or 6 artifacts that would benefit from collaborative board review.

## Inputs

* ${input:project-slug}: (Required) Kebab-case Design Thinking project identifier.
* ${input:board-title:}: (Optional) Explicit board title. If omitted, derive a concise title from the project context and exported method.
* ${input:method:latest}: (Optional, defaults to `latest`) Method number or `latest` to export the most recent DT method artifacts.

## Prerequisites

* The DT project artifacts MUST exist under `.copilot-tracking/dt/{project-slug}/`.
* The `mural` MCP server MUST be configured in your workspace before attempting export.
* Repository-clone users SHOULD run `npm run mcp:setup:mural` and add the Mural server entry documented in `docs/getting-started/mcp-configuration.md`.
* Extension-only users MAY follow the same setup manually without cloning the repository scripts.

## Workflow Steps

1. Resolve Project State:
   Read `.copilot-tracking/dt/{project-slug}/coaching-state.md` and confirm the project exists. If it does not, stop and explain how to start or resume a DT project first.
2. Select Export Scope:
   Determine which method artifacts to export based on `${input:method}`.
   If `${input:method}` is `latest`, infer the latest completed or active method from the coaching state and recent artifacts.
   Prefer explicit artifact files referenced in the coaching state over directory guessing.
3. Validate MCP Availability:
   Attempt a lightweight Mural discovery flow by listing workspaces or rooms.
   If the `mural` MCP server or tools are unavailable, stop and provide the setup path:
   `docs/getting-started/mcp-configuration.md`, `docs/design-thinking/mural-export.md`, and `npm run mcp:setup:mural` for repository-clone users.
4. Confirm Destination:
   Ask the user to choose the target workspace and room if they are not already clear from context.
   Ask whether to create a new board or update an existing one.
   If creating a new board, use `${input:board-title}` when provided; otherwise derive a clear title from project and method context.
5. Build Export Layout:
   Translate artifact content into left-to-right columns with grouping areas, labels, and sticky notes.
   Use rectangle stickies for facts, insights, constraints, and evidence.
   Use circle stickies for open questions, decisions, and validation targets.
   Keep sticky content concise: 1-3 short sentences per sticky.

   ### Layout Defaults

   Use these sizing and spacing defaults. All values are in Mural coordinate units.

   **Areas:**
   * Header area: full board width, 350 tall, positioned at top.
   * Theme columns: 680 wide each, 1200 tall, spaced with 30-unit gaps between columns.
   * Footer area (HMW or summary): full board width, 400 tall, below theme columns with a 80-unit gap.

   **Text boxes:**
   * Board title: 700 wide, 80 tall, top-left of header area.
   * Subtitle (method, date, status): 1000 wide, 50 tall, below title.
   * Context summary: 800 wide, 160 tall, top-right of header area.
   * Theme descriptions: column width minus 40 padding, 100 tall, positioned 120 units below the top of their area to clear the area title.

   **Sticky notes:**
   * Evidence stickies: 310 wide, 180 tall, arranged in a 2-column grid within each theme column with 20-unit gaps. Position the first row 250 units below the area top, second row 200 units below the first.
   * Implication stickies: column width minus 40 padding, 150 tall, positioned below evidence rows with a 40-unit gap.
   * Circle stickies (HMW, open questions): 250 wide, 250 tall, evenly spaced horizontally within the footer area.

   ### Color Scheme

   Apply these colors using 8-character RGBA hex values.

   **Area backgrounds (distinct pastel per section):**
   * Header / Project Context: `#E3F2FDFF` (light blue)
   * Theme column 1: `#E8EAF6FF` (lavender)
   * Theme column 2: `#E0F2F1FF` (light teal)
   * Theme column 3: `#FFF3E0FF` (light orange)
   * Theme column 4: `#FCE4ECFF` (light pink)
   * For additional columns, cycle through: `#F1F8E9FF` (light green), `#FFF8E1FF` (light amber), `#E0F7FAFF` (light cyan).
   * Footer / HMW area: `#F3E5F5FF` (light purple)

   **Sticky note backgrounds (by content type):**
   * Evidence and facts: `#FCFE7DFF` (yellow, the default)
   * Implications and insights: `#80D2FCFF` (blue)
   * HMW questions and open questions: `#8FD14FFF` (green)
   * Decisions and validation targets: `#F36DFFFF` (purple)
   * Constraints and risks: `#FF9D48FF` (orange)

6. Apply Method-Specific Layout:
   For Method 1, export request framing, stakeholder map, constraints, and open questions.
   For Method 3, export synthesis themes, evidence clusters, and how-might-we prompts.
   For Method 4, export idea clusters and convergence candidates.
   For Method 5, export concepts, evaluation notes, and stakeholder reactions.
   For Method 6, export prototype plan, build decisions, and testing hypotheses.
   If artifacts span multiple methods, group by method first and then by theme.
7. Create or Update the Board:
   Use batch Mural tool calls where possible.
   Create areas and text boxes first when section structure matters for readability, then add sticky notes.
   If updating an existing board, avoid duplicating already-confirmed sections unless the user explicitly wants a fresh export.
8. Report Results:
   Summarize the board title, board URL, and counts of areas, text boxes, and sticky notes created or updated.
   Call out any skipped or failed items with actionable reasons.

## Success Criteria

* [ ] DT artifacts were read from `.copilot-tracking/dt/{project-slug}/`.
* [ ] The `mural` MCP server was available and used successfully.
* [ ] A new or updated board contains readable sections aligned to the DT artifact structure.
* [ ] The user received the board URL and a concise export summary.

## Examples

```text
/dt-mural-export project-slug=factory-floor-maintenance
```

```text
/dt-mural-export project-slug=customer-support-ai board-title="Customer Support AI Assistant - Stakeholder Map" method=1
```

```text
/dt-mural-export project-slug=warehouse-onboarding method=3
```

## Error Handling

* If the DT project directory or coaching state is missing, stop and direct the user to create or resume the project before export.
* If the `mural` MCP server is not configured, stop and provide the setup path rather than attempting a partial export.
* If artifacts are incomplete for the requested method, explain the gap and ask whether to export the available subset or return to coaching.
* If board creation succeeds only partially, report exactly which sections or widgets failed and preserve the successfully created content.

---

Brought to you by microsoft/hve-core