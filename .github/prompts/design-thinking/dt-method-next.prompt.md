---
description: 'Assess DT project state and recommend next method with sequencing validation - Brought to you by microsoft/hve-core'
agent: dt-coach
argument-hint: "[project-slug=...]"
---

# DT Method Next

## Inputs

* ${input:project-slug}: (Optional) Project slug identifying the DT project directory. If omitted, inferred from open files under `.copilot-tracking/dt/` or from conversation context.

## Requirements

* All DT coaching artifacts are scoped to `.copilot-tracking/dt/{project-slug}/`. Never write DT artifacts directly under `.copilot-tracking/dt/` without a project-slug directory.

### 1. Locate Project Directory

**Goal:** Find the coaching state file for the specified or inferred project.

* Derive project-slug from input, open files, or conversation context
* Look for coaching state at `.copilot-tracking/dt/{project-slug}/coaching-state.md`
* If not found and multiple projects exist, list available projects with last session dates and ask user to select
* **Edge case — No project found:** If no DT project exists, respond: "No Design Thinking project found. Start a new project by running `/dt-start-project project-slug='...'` with your project slug."

### 2. Read and Assess Current State

**Goal:** Extract current method, space, completion status, and progress indicators.

* Read the coaching state YAML frontmatter:
  * `current.method` (1-9): active method number
  * `current.space` (problem|solution|implementation): derived from method number
  * `current.phase`: free-text step within current method
  * `methods_completed`: array of completed method numbers
  * `transition_log`: history of method changes with rationales
  * `session_log`: recent session summaries
  * `artifacts`: list of generated artifacts with paths
* Scan the project directory for artifact subdirectories matching `method-{NN}-*/` patterns
* Assess method completeness by comparing artifacts against exit signals from `.github/instructions/design-thinking/dt-method-sequencing.instructions.md`

### 3. Determine Next Method Recommendation

**Goal:** Suggest appropriate next method based on state analysis and sequencing rules.

Apply progression logic:

* **Forward progression (primary path):**
  * If current method has artifacts and exit signals met → suggest method + 1
  * At space boundaries (3→4, 6→7): verify readiness signals before suggesting transition
  
* **Backward iteration (secondary path):**
  * If current method reveals gaps in prior work → suggest returning to earlier method with rationale
  * Common patterns: prototype issues → Method 2/3, brainstorming failure → Method 3, concept misalignment → Method 1
  
* **Lateral transitions:**
  * If all 9 methods complete → suggest iteration on Method 9 or handoff to RPI workflow
  * If user requests skipping methods → explain sequencing rationale and offer to proceed with caution

* **Edge case — All complete:** If `methods_completed` includes 1-9, respond: "All 9 Design Thinking methods are complete. You can iterate on Method 9 for optimization, or hand off to RPI workflow for implementation planning. What would you like to focus on?"

* **Edge case — Iteration loop detected:** If the same method or method pair appears 3+ times in the last 6 `transition_log` entries, acknowledge the iteration explicitly: "I notice you've returned to Method [N] multiple times. This suggests [observation about missing foundation]. Would you like to revisit the underlying challenge or continue refining Method [N]?"

### 4. Output Format and Recommendation

**Goal:** Present project status summary with clear next steps.

Provide a concise summary including:

* **Project:** Display name and slug
* **Current Method:** Number, name, and phase description
* **Progress:** Count of completed methods out of 9
* **Recent Work:** Summary from last session log entry
* **Key Artifacts:** Highlight 2-3 critical artifacts from current method directory

Then present recommendation:

* **Suggested Next Method:** Number and name with rationale tied to exit signals or discovered gaps
* **Transition Type:** Forward progression, backward iteration, or lateral handoff
* **Readiness Check:** For space boundary transitions, validate these signals:
  * 3→4 (Problem→Solution): Themes validated across sources, team alignment confirmed, HMW questions formulated
  * 6→7 (Solution→Implementation): Lo-fi prototypes tested with real users, core assumptions validated, concepts narrowed to 1-2 directions
* **User Choice:** "Does this direction make sense, or would you prefer to target a different method?"

### 5. Delegate to DT Coach

After presenting the recommendation, wait for user confirmation of the suggested method or their choice of a different method. Once confirmed, transition coaching into the target method by:

* Updating `coaching-state.md` with new `current.method` value
* Adding transition log entry with rationale and date
* Loading the target method instruction file for method-specific knowledge
* Beginning active coaching at the appropriate phase within the target method

---

Assess the Design Thinking project state and recommend the next method to pursue based on completion indicators and sequencing rules.
