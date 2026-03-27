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
   For Method 3, export synthesis themes, evidence clusters, and how-might-we prompts. Generate a theme-evidence cluster diagram.
   For Method 4, export idea clusters and convergence candidates. Arrange ideas by category in columns.
   For Method 5, export concepts, evaluation notes, and stakeholder reactions. Create concept comparison cards.
   For Method 6, export prototype plan, build decisions, and testing hypotheses. Create a hypothesis tracking board.
   If artifacts span multiple methods, group by method first and then by theme.

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
