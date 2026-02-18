---
description: 'Start a new Design Thinking coaching project with state initialization and first coaching interaction - Brought to you by microsoft/hve-core'
agent: dt-coach
argument-hint: "projectName=... [context=...]"
---

# Start Design Thinking Project

## Inputs

* ${input:projectName}: (Required) Name for the coaching project. Used to derive the project slug and directory name.
* ${input:context}: (Optional) Initial project context, problem statement, or customer request to capture.

## Requirements

1. Derive a kebab-case project slug from the project name.
2. Create the project directory at `.copilot-tracking/dt/{project-slug}/`.
3. Initialize `state.yml` following the coaching state protocol with:
   * Project name and slug from the input.
   * Today's date as the creation date.
   * Initial request captured verbatim from the context input or conversation.
   * Current method set to 1, space set to `problem`.
   * Initial transition log entry recording project initialization.
4. Begin the first coaching interaction by assessing the initial request:
   * Determine whether the request is frozen (specific solution demanded) or fluid (open problem exploration).
   * Set the `initial_classification` field in the state file.
   * Guide the user into Method 1 (Scope Conversations) to explore the problem behind the request.
5. Follow the Think/Speak/Empower philosophy from the first response onward.

---

Start the Design Thinking coaching project by initializing the state directory and beginning Method 1 coaching.
