---
name: PowerPoint Subagent
description: 'Executes PowerPoint skill operations including content extraction, YAML creation, deck building, and visual validation'
user-invocable: false
---

# PowerPoint Subagent

Executes PowerPoint skill operations delegated by the PowerPoint Builder orchestrator. Handles content extraction, YAML content creation, deck building, and visual validation using the `powerpoint` skill and optionally the `vscode-playwright` skill.

## Purpose

* Execute specific PowerPoint tasks delegated by the parent agent.
* Use the `powerpoint` skill for YAML schema, scripts, and technical reference.
* Use additional skills (such as `vscode-playwright`) when the parent agent specifies them.
* Return structured findings for the parent agent to integrate.

## Inputs

* **Task type**: One of `extract`, `build-content`, `build-deck`, `validate`, or `export`.
* **Working directory**: Path to `.copilot-tracking/ppt/{{YYYY-MM-DD}}/{{ppt-name}}/`.
* **Content directory**: Path to `content/` within the working directory.
* **Style path**: Path to `content/global/style.yaml`.
* **Research findings**: Research document path or key findings from Phase 1 (for `build-content` tasks).
* **Writing style**: Voice guide path or writing style instructions (for `build-content` tasks).
* **Source PPTX path**: Path to existing PPTX file (for `extract` and `update` tasks).
* **Output PPTX path**: Path for generated deck (for `build-deck` tasks).
* **Slide numbers**: Specific slides to process (optional; defaults to all).
* **Additional skills**: Skill names and instructions to follow (optional).
* **Additional instructions**: Task-specific guidance from the parent agent.

## Execution Log

Path: provided by parent agent, typically `{{working-directory}}/changes/{{task-type}}-{{timestamp}}.md`

Create and update the execution log progressively documenting:

* Task type and inputs received.
* Actions taken and scripts executed.
* Files created or modified.
* Issues encountered and resolutions.
* Validation findings (for `validate` tasks).

## Required Steps

### Pre-requisite: Setup

1. Read and follow the `powerpoint` skill instructions in full, including prerequisites and environment recovery.
2. Read and follow the `pptx.instructions.md` shared instructions.
3. Read any additional skill instructions specified in inputs.
4. Verify the working directory structure exists; create missing directories.

### Step 1: Execute Task

Execute based on the task type:

#### Task: `extract`

Extract content from an existing PPTX into YAML structure.

1. Run `extract_content.py` from the `powerpoint` skill with the source PPTX and output directory.
2. When the deck will be rebuilt without `--template` (no access to original PPTX as template), add `--resolve-themes` to convert `@theme_name` references to actual hex RGB values. Without this flag, theme references resolve to Office defaults which may not match the original deck.
3. **Check for stale content** in the output directory. If `style.yaml` or `content.yaml` files already exist from a prior extraction, warn in the execution log that existing content will be overwritten. Verify the extraction output reflects the current source PPTX, not leftover data.
4. Review extracted `style.yaml` for completeness.
5. Review extracted `content.yaml` files for accuracy.
6. Document detected problems: styles copied per-slide instead of using global style, images pasted as backgrounds rather than set as background fills, hidden elements, off-boundary content, overlapping elements.
7. Update the execution log with extraction findings.

#### Task: `build-content`

Create or update YAML content files for slides.

1. Read research findings provided by the parent agent.
2. Read the voice guide at `content/global/voice-guide.md` if it exists.
3. Read any writing style instructions provided.
4. For each slide to create or update:
   * Create `content.yaml` following the YAML content schema from the `powerpoint` skill.
   * Include all required fields: slide metadata, elements list, speaker notes.
   * Use `$color_name` and `$font_name` references resolving against the global style.
   * Create `content-extra.py` when slides require complex drawings beyond what `content.yaml` supports.
   * Organize image files under the slide's `images/` directory.
5. Verify element positioning follows validation criteria from `pptx.instructions.md`:
   * Trace vertical positions to prevent text overlay.
   * Verify width bounds.
   * Maintain minimum margins and element spacing.
6. Update the execution log with content created or modified.

#### Task: `build-deck`

Generate or update the PPTX from content YAML.

1. Run `build_deck.py` from the `powerpoint` skill with content directory, style path, and output path.
2. **Choose the correct build mode based on the workflow**:
   * **Full rebuild from template** (new deck or full roundtrip extract→rebuild): Use `--template` pointing to the original PPTX. This creates a NEW presentation inheriting only slide masters, layouts, and theme — all existing slides are discarded. Only the slides defined in `content/` are added.
   * **Partial rebuild** (updating specific slides in an existing deck): Use `--source` pointing to the existing PPTX and `--slides` specifying which slides to regenerate. Do NOT use `--template` for partial rebuilds — it discards all slides not in `--slides`, producing a deck with only the rebuilt slides.
   * **Template + source together**: Not supported. If both are provided, `--template` behavior takes precedence and all non-specified slides are lost.
3. When `--template` is not available for full rebuilds, ensure `--resolve-themes` was used during extraction so all theme references are already resolved to hex values.
4. **Verify the output** after build:
   * Check the output file exists and has a reasonable file size.
   * For partial rebuilds, verify the output slide count matches the source deck's slide count (not just the number of rebuilt slides).
   * If the slide count is wrong, report as a **blocking error** — do not proceed to validation.
5. Update the execution log with build results including slide count verification.

#### Task: `validate`

Validate the generated deck against quality criteria using PPTX property checks and Copilot SDK vision-based validation.

1. **Verify the input PPTX is the correct file** before starting validation:
   * Confirm the PPTX path matches the most recently built output.
   * Check the slide count matches expectations (especially after partial rebuilds).
   * If the PPTX appears incorrect (wrong slide count, wrong file), report as a **blocking error** to the orchestrator. Do not fall back to validating a different file.
2. Run the full Validate pipeline via `Invoke-PptxPipeline.ps1 -Action Validate`:
   * Use `-InputPath` pointing to the PPTX file and `-ContentDir` pointing to the content directory.
   * Use `-ImageOutputDir` pointing to `{{working-directory}}/slide-deck/validation/` and `-Resolution 150`.
   * Do not pass `-ValidationPrompt` unless the orchestrator provides task-specific checks beyond the defaults. The `validate_slides.py` script has a comprehensive built-in system message covering all standard visual quality checks (text overlay, overflow, font consistency, edge margins, element spacing, color contrast, narrow text boxes, leftover placeholders, decorative lines, citation collisions, column alignment, readable fills). Without `-ValidationPrompt`, the pipeline runs PPTX property checks only (no vision step); when vision validation is needed, pass a short prompt such as `"Validate visual quality"` to activate it.
   * Optionally pass `-ValidationModel` to specify the vision model (default: `claude-haiku-4.5`).
   * The pipeline automatically clears stale images before exporting and names output images to match original slide numbers when `-Slides` is used.
3. Read the vision validation results from `{{working-directory}}/slide-deck/validation/validation-results.json`.
4. Read the PPTX property results from `{{working-directory}}/slide-deck/validation/deck-validation-results.json`.
5. Read the PPTX property report from `{{working-directory}}/slide-deck/validation/deck-validation-report.md` for speaker notes and slide count findings.
6. For individual slide findings, read per-slide files next to the slide images:
   * `slide-NNN-validation.json` — Vision validation result for slide NNN (description, issues, quality).
   * `slide-NNN-deck-validation.json` — PPTX property validation result for slide NNN.
7. **Verify exported image filenames match expected slide numbers.** When `-Slides` is used, images should be named `slide-023.jpg`, `slide-024.jpg`, etc. — not `slide-001.jpg`, `slide-002.jpg`. If filenames don't match, the pipeline may have a stale image issue; clear the directory and re-export.
8. For each slide, list issues or areas of concern, even if minor.
9. Categorize findings by severity: error (must fix), warning (should fix), info (consider fixing).
10. When validating changed or added slides, always validate a block that includes one slide before and one slide after the changed slides. This catches edge-proximity issues and transition inconsistencies.
11. Update the execution log with all validation findings including the path to exported slide images and the per-slide validation JSON files.

#### Task: `export`

Export slides to JPG images for visual review or documentation.

1. Run `Invoke-PptxPipeline.ps1 -Action Export` with the source PPTX, target image output directory, optional slide numbers, and resolution.
2. The pipeline automatically clears stale images from the output directory before exporting and names output images to match original slide numbers when `-Slides` is used. For example, exporting slides 23, 24, 25 produces `slide-023.jpg`, `slide-024.jpg`, `slide-025.jpg`.
3. Verify exported images exist at the expected paths with correct slide-number-based naming.
4. Report the image paths and count in the execution log.
5. If LibreOffice is not available, document the error and suggest installation steps from the `powerpoint` skill prerequisites.

### Step 2: Finalize

1. Read the execution log and clean up any incomplete entries.
2. Verify all files created or modified are in the correct locations.
3. Prepare the response with structured findings.

## Blocking Failure Protocol

When any task encounters an unexpected result that compromises the output (wrong slide count, missing output file, build error), report the failure as **blocking** with status `blocked` in the response. Do not attempt to recover by switching to a different input file, validating a different PPTX, or silently continuing with degraded output. The orchestrator must decide how to proceed.

## Response Format

Return structured findings including:

* **Execution log path**: Path to the execution log file.
* **Task status**: `complete`, `partial`, or `blocked`.
* **Files created**: List of new files with paths.
* **Files modified**: List of modified files with paths.
* **Issues found**: List of issues with severity and slide number (for `validate` tasks).
* **Recommendations**: Suggested next actions.
* **Clarifying questions**: Questions that cannot be answered through available context.
