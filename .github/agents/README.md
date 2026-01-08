---
title: GitHub Copilot Agents
description: Specialized AI agents for planning, research, prompt engineering, and PR reviews
author: HVE Core Team
ms.date: 2026-01-08
ms.topic: guide
keywords:
  - copilot
  - agents
  - ai assistants
  - task planning
  - code review
estimated_reading_time: 4
---

Specialized GitHub Copilot agents for common development workflows. Each agent is optimized for specific tasks with custom instructions and context.

## Quick Start

1. Open GitHub Copilot Chat view (Ctrl+Alt+I)
2. Select the desired agent from the **agent picker dropdown** at the top of the chat panel
3. Enter your request and press Enter

**Example:**

* Select "task-planner" from dropdown
* Type: "Create a plan to add Docker SHA validation"
* Press Enter

**Requirements:** GitHub Copilot subscription, VS Code with Copilot extension, proper workspace configuration (see [Getting Started](../../docs/getting-started/README.md))

## Available Agents

Select from the **agent picker dropdown** in the Chat view:

| Agent Name                     | Purpose                                                         | Key Constraint                                 |
| ------------------------------ | --------------------------------------------------------------- | ---------------------------------------------- |
| **hve-core-installer**         | Automated HVE-Core installation with multiple methods           | Installation-only; environment detection       |
| **rpi-agent**                  | Autonomous agent with subagent delegation for complex tasks     | Requires `runSubagent` tool enabled            |
| **task-planner**               | Creates 3-file plan sets (plan, details, prompt)                | Requires research first; never implements code |
| **task-researcher**            | Produces research documents with evidence-based recommendations | Research-only; never plans or implements       |
| **task-implementor**           | Implements task plans with progressive tracking                 | Requires plan files; creates change records    |
| **prompt-builder**             | Engineers and validates instruction/prompt files                | Dual-persona system with auto-testing          |
| **pr-review**                  | 4-phase PR review with tracking artifacts                       | Review-only; never modifies code               |
| **adr-creation**               | Creates Architecture Decision Records                           | ADR template compliance; structured format     |
| **ado-prd-to-wit**             | Analyzes PRDs and plans Azure DevOps work items                 | Planning-only; creates work item hierarchies   |
| **arch-diagram-builder**       | Builds high-quality ASCII-art architecture diagrams             | Diagram generation from IaC/deployment scripts |
| **brd-builder**                | Business Requirements Document creation                         | Guided Q&A; reference integration              |
| **prd-builder**                | Product Requirements Document creation                          | Guided Q&A; reference integration              |
| **github-issue-manager**       | Interactive GitHub issue management workflows                   | Issue filing, navigation, search               |
| **gen-data-spec**              | Generates data dictionaries and profiles                        | Guided discovery; machine-readable output      |
| **gen-jupyter-notebook**       | Jupyter notebook generation                                     | Python notebook creation                       |
| **gen-streamlit-dashboard**    | Multi-page Streamlit dashboard development                      | Python Streamlit apps                          |
| **test-streamlit-dashboard**   | Streamlit dashboard testing with Playwright                     | Testing framework; issue tracking              |
| **security-plan-creator**      | Comprehensive cloud security plan creation                      | Security architecture; cloud platforms         |

## Core Agent Details

### hve-core-installer

**Creates:** Installation artifacts and workspace configurations

**Workflow:** Environment detection → Method selection → Installation execution → Validation
**Critical:** Two-persona system (Installer + Validator); supports 6 installation methods; handles local, devcontainer, and Codespaces environments

### rpi-agent

**Creates:** Subagent research artifacts when needed:

* `.copilot-tracking/subagent/YYYYMMDD/topic-research.md`

**Workflow:** Understand → Implement → Verify → Continue or Complete
**Critical:** Requires `runSubagent` tool enabled; delegates MCP tools, heavy terminal commands, and complex research to subagents; autonomous execution with loop guard

### task-planner

**Creates:** Three interconnected files per task:

* Plan checklist: `.copilot-tracking/plans/YYYYMMDD-task-plan.instructions.md`
* Implementation details: `.copilot-tracking/details/YYYYMMDD-task-details.md`
* Implementation prompt: `.copilot-tracking/prompts/implement-task.prompt.md`

**Workflow:** Validates research → Creates plan files → User implements separately
**Critical:** Automatically calls task-researcher if research missing; treats ALL user input as planning requests (never implements actual code)

### task-researcher

**Creates:** Single authoritative research document:

* `.copilot-tracking/research/YYYYMMDD-topic-research.md`
* Subagent files: `.copilot-tracking/research/YYYYMMDD-topic-subagent/task-research.md`

**Workflow:** Deep tool-based research → Document findings → Consolidate to ONE approach → Hand off to planner
**Critical:** Research-only specialist; uses `runSubagent` tool; continuously refines document; never plans or implements

### task-implementor

**Creates:** Change tracking and implementation logs:

* `.copilot-tracking/changes/YYYYMMDD-change-log.md`

**Workflow:** Load plan → Progressive implementation → Track changes → Verify completion
**Critical:** Requires task plan files; creates change records; never modifies without plan

### prompt-builder

**Creates:** Instruction files AND prompt files:

* `.github/instructions/*.instructions.md`
* `.copilot-tracking/prompts/*.prompt.md`

**Workflow:** Research sources → Draft → Auto-validate with Prompt Tester → Iterate (up to 3 cycles)
**Critical:** Dual-persona system; uses XML-style blocks (`<!-- <example-*> -->`); links to authoritative sources; minimal inline examples

### pr-review

**Creates:** Review tracking files in normalized branch folders:

* `.copilot-tracking/pr/review/{normalized-branch}/in-progress-review.md`
* `.copilot-tracking/pr/review/{normalized-branch}/pr-reference.xml`
* `.copilot-tracking/pr/review/{normalized-branch}/handoff.md`
* `.copilot-tracking/pr/review/{normalized-branch}/hunk-*.txt`

**Workflow:** 4 phases (Initialize → Analyze → Collaborative Review → Finalize)
**Critical:** Review-only; never modifies code; evaluates 8 dimensions (functional correctness, design, idioms, reusability, performance, reliability, security, documentation)

## Common Workflows

**Installing HVE-Core:**

1. Select **hve-core-installer** from agent picker
2. Follow guided installation with environment detection
3. Choose from 6 installation methods
4. Agent validates installation success

**Autonomous Task Completion:**

1. Select **rpi-agent** from agent picker
2. Provide your request
3. Agent autonomously researches, implements, and verifies
4. Review results; agent continues if more work remains
5. Requires `runSubagent` tool enabled in settings

**Planning a Feature:**

1. Select **task-researcher** from agent picker
2. Create research document with findings
3. Review research, provide decisions on approach
4. Clear context or start new chat
5. Select **task-planner** from agent picker
6. Generate 3-file plan set (attach research doc)
7. Use implementation prompt to execute (separate step)

**Implementing a Plan:**

1. Select **task-implementor** from agent picker
2. Point to plan files in `.copilot-tracking/plans/` and `.copilot-tracking/details/`
3. Agent implements with progressive tracking
4. Review change logs in `.copilot-tracking/changes/`

**Code Review:**

1. Select **pr-review** from agent picker
2. Automatically runs 4-phase protocol
3. Collaborate during Phase 3 (review items)
4. Receive `handoff.md` with final PR comments

**Creating Instructions:**

1. Select **prompt-builder** from agent picker
2. Draft instruction file with conventions
3. Auto-validates with Prompt Tester persona
4. Iterates up to 3 times for quality
5. Delivered to `.github/instructions/`

**Creating Documentation:**

1. Select **adr-creation** for Architecture Decision Records
2. Select **brd-builder** for Business Requirements
3. Select **prd-builder** for Product Requirements
4. Follow guided Q&A workflows

**Azure DevOps Work Items:**

1. Select **ado-prd-to-wit** from agent picker
2. Provide PRD artifacts, files, or URLs
3. Agent analyzes and plans work item hierarchies
4. Review planning files before work item creation

## Important Notes

* **Linting Exemption:** Files in `.copilot-tracking/**` are exempt from repository linting rules
* **Agent Switching:** User must manually switch between agents (e.g., from researcher to planner)
* **Research First:** Task planner requires completed research; will automatically invoke researcher if missing
* **No Implementation:** Task planner and researcher never implement actual project code—only create planning artifacts
* **Agent Files:** All agents are defined in `.agent.md` files in this directory

## Tips

* Be specific in your requests for better results
* Provide context about what you're working on
* Review generated outputs before using
* Chain agents together for complex tasks
* Use agent handoffs (available in some agents like rpi-agent) for smooth transitions

## Migration from Chat Modes

If you previously used chat modes (`.chatmode.md` files), those have been migrated to agents (`.agent.md` files). The functionality remains the same, but the format now follows VS Code's standard agent specification.

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
