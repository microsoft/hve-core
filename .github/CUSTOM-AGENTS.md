---
title: GitHub Copilot Custom Agents
description: Specialized AI agents for planning, research, prompt engineering, documentation, and code review workflows
author: HVE Core Team
ms.date: 2026-01-18
ms.topic: guide
keywords:
  - copilot
  - custom agents
  - ai assistants
  - task planning
  - code review
estimated_reading_time: 6
---

Specialized GitHub Copilot behaviors for common development workflows. Each custom agent is optimized for specific tasks with custom instructions and context.

## Quick Start

1. Open GitHub Copilot Chat view (Ctrl+Alt+I or Cmd+Alt+I)
2. Click the **agent picker dropdown** at the top of the chat panel
3. Select the desired agent from the list
4. Enter your request and press Enter

**Example:**

* Select "task-planner" from the dropdown
* Type: "Create a plan to add Docker SHA validation"
* Press Enter

**Requirements:** GitHub Copilot subscription, VS Code with Copilot extension, proper workspace configuration (see [Getting Started](../docs/getting-started/README.md))

## Available Agents

Select from the **agent picker dropdown** in the Chat view:

### RPI Workflow Agents

The Research-Plan-Implement (RPI) workflow provides a structured approach to complex development tasks.

| Agent                | Purpose                                                           | Key Constraint                                 |
|----------------------|-------------------------------------------------------------------|------------------------------------------------|
| **rpi-agent**        | Autonomous agent with subagent delegation for complex tasks       | Requires a subagent tool enabled               |
| **task-researcher**  | Produces research documents with evidence-based recommendations   | Research-only; never plans or implements       |
| **task-planner**     | Creates 3-file plan sets (plan, details, prompt)                  | Requires research first; never implements code |
| **task-implementor** | Executes implementation plans with subagent delegation            | Requires completed plan files                  |
| **task-reviewer**    | Validates implementation against research and plan specifications | Requires research/plan artifacts               |

### Documentation and Planning Agents

| Agent                            | Purpose                                                            | Key Constraint                                        |
|----------------------------------|--------------------------------------------------------------------|-------------------------------------------------------|
| **adr-creation**                 | Interactive ADR coaching with guided discovery                     | Socratic coaching approach                            |
| **brd-builder**                  | Creates Business Requirements Documents with reference integration | Solution-agnostic requirements focus                  |
| **doc-ops**                      | Documentation operations and maintenance                           | Does not modify source code                           |
| **prd-builder**                  | Creates Product Requirements Documents through guided Q&A          | Iterative questioning; state-tracked sessions         |
| **product-manager-advisor**      | Requirements discovery, story quality, and prioritization guidance  | Principles over format; delegates to prd/brd builders |
| **security-plan-creator**        | Creates comprehensive cloud security plans from blueprints         | Blueprint-driven threat modeling                      |
| **system-architecture-reviewer** | Reviews system designs for trade-offs and ADR alignment             | Scoped review; delegates security concerns            |
| **ux-ui-designer**               | JTBD analysis, user journey mapping, and accessibility requirements | Research artifacts only; visual design in Figma       |

### Utility Agents

| Agent      | Purpose                                    | Key Constraint                        |
|------------|--------------------------------------------|---------------------------------------|
| **memory** | Persists repository facts for future tasks | Stores only durable, actionable facts |

### Code and Review Agents

| Agent              | Purpose                                          | Key Constraint                        |
|--------------------|--------------------------------------------------|---------------------------------------|
| **pr-review**      | 4-phase PR review with tracking artifacts        | Review-only; never modifies code      |
| **prompt-builder** | Engineers and validates instruction/prompt files | Dual-persona system with auto-testing |

### Generator Agents

| Agent                       | Purpose                                            | Key Constraint                       |
|-----------------------------|----------------------------------------------------|--------------------------------------|
| **gen-jupyter-notebook**    | Creates structured EDA notebooks from data sources | Requires data dictionaries           |
| **gen-streamlit-dashboard** | Develops multi-page Streamlit dashboards           | Uses Context7 for documentation      |
| **gen-data-spec**           | Generates data dictionaries and profiles           | Produces JSON and markdown artifacts |
| **arch-diagram-builder**    | Builds ASCII block diagrams from Azure IaC         | Parses Terraform, Bicep, ARM scripts |

### Platform Integration Agents

| Agent                    | Purpose                                                    | Key Constraint                            |
|--------------------------|------------------------------------------------------------|-------------------------------------------|
| **github-backlog-manager** | Consolidated GitHub backlog management with community interaction | Uses MCP GitHub tools                     |
| **ado-prd-to-wit**       | Analyzes PRDs and plans Azure DevOps work item hierarchies | Planning-only; does not create work items |
| **hve-core-installer**   | Decision-driven HVE-Core installation with 6 methods       | Environment detection and validation      |

### Testing Agents

| Agent                        | Purpose                                     | Key Constraint                         |
|------------------------------|---------------------------------------------|----------------------------------------|
| **test-streamlit-dashboard** | Automated Streamlit testing with Playwright | Requires running Streamlit application |

## Agent Details

### rpi-agent

**Creates:** Subagent research artifacts when needed:

* `.copilot-tracking/subagent/YYYY-MM-DD/topic-research.md`

**Workflow:** Understand → Implement → Verify → Continue or Complete

**Critical:** Requires a subagent tool enabled. Delegates MCP tools, heavy terminal commands, and complex research to subagents. Provides autonomous execution with loop guard for detecting stuck states.

### task-researcher

**Creates:** Single authoritative research document:

* `.copilot-tracking/research/{{YYYY-MM-DD}}-topic-research.md` (primary research with evidence-based recommendations)
* `.copilot-tracking/subagent/{{YYYY-MM-DD}}/task-research.md` (subagent research outputs when delegating)

**Workflow:** Deep tool-based research → Document findings → Consolidate to one approach → Hand off to planner

**Critical:** Research-only specialist. Uses subagent tools. Continuously refines document. Never plans or implements.

### task-planner

**Creates:** Two interconnected files per task:

* `.copilot-tracking/plans/{{YYYY-MM-DD}}-task-plan.instructions.md` (implementation plan with checklist items)
* `.copilot-tracking/details/{{YYYY-MM-DD}}-task-details.md` (step-by-step execution details)

**Workflow:** Validates research → Creates plan files → User implements separately

**Critical:** Automatically calls task-researcher if research is missing. Treats all user input as planning requests. Never implements actual code.

### task-implementor

**Creates:** Change tracking logs:

* `.copilot-tracking/changes/{{YYYY-MM-DD}}-task-changes.md` (chronological log with Added/Modified/Removed sections)

**Workflow:** Analyze plan → Run subagents per phase → Track progress → Validate

**Critical:** Requires completed plan files. Uses subagent architecture for parallel phase execution. Updates tracking artifacts after each phase.

### task-reviewer

**Creates:** Review validation logs:

* `.copilot-tracking/reviews/{{YYYY-MM-DD}}-{{topic}}-review.md` (findings with severity levels and follow-up work)

**Workflow:** Locate artifacts → Extract checklist → Validate items → Run commands → Document findings

**Critical:** Review-only specialist. Validates against documentation, not assumptions. Produces findings with severity levels (Critical, Major, Minor).

**Documentation:** See [Task Reviewer Guide](../docs/rpi/task-reviewer.md) for detailed usage.

### prompt-builder

**Creates:** Instruction files and prompt files:

* `.github/instructions/{collection-id}/*.instructions.md` (coding guidelines and conventions, by convention)
* `.github/prompts/{collection-id}/*.prompt.md` (reusable workflow prompts, by convention)
* `.copilot-tracking/sandbox/{{YYYY-MM-DD}}-{{prompt-name}}-{{run-number}}/execution-log.md` (test execution trace)
* `.copilot-tracking/sandbox/{{YYYY-MM-DD}}-{{prompt-name}}-{{run-number}}/evaluation-log.md` (quality validation results)

**Workflow:** Research sources → Draft → Auto-validate with Prompt Tester → Iterate (up to 3 cycles)

**Critical:** Dual-persona system with execution and evaluation subagents. Uses sandbox environment for testing. Links to authoritative sources.

### pr-review

**Creates:** Review tracking files in normalized branch folders:

* `.copilot-tracking/pr/review/{normalized-branch}/in-progress-review.md` (living review document with findings)
* `.copilot-tracking/pr/review/{normalized-branch}/pr-reference.xml` (PR metadata and diff summary, generated via the `pr-reference` skill)
* `.copilot-tracking/pr/review/{normalized-branch}/handoff.md` (finalized comments for PR submission)

**Workflow:** 4 phases (Initialize → Analyze → Collaborative Review → Finalize)

**Critical:** Review-only. Never modifies code. Evaluates 8 dimensions: functional correctness, design, idioms, reusability, performance, reliability, security, documentation.

### product-manager-advisor

**Purpose:** Requirements discovery, story quality assurance, and prioritization guidance.

**Workflow:** Discovery → Story Quality → Prioritization → Validation → Handoff

**Handoffs:** Delegates to `prd-builder` for full PRDs, `brd-builder` for business requirements, `ux-ui-designer` for journey mapping, and `task-researcher` for deep research.

**Critical:** Focuses on quality principles rather than prescribing issue formats. Guides teams to leverage platform-native templates (GitHub issue forms, Azure DevOps work item templates). Differentiates from `prd-builder` by focusing on the requirements discovery gate rather than document authoring.

### ux-ui-designer

**Purpose:** UX research artifacts including Jobs-to-be-Done analysis, user journey mapping, and accessibility requirements.

**Creates:** Research documentation using the [user journey template](../docs/templates/user-journey-template.md):

* JTBD analysis documenting user goals and current solution gaps
* Journey maps tracing user behavior, emotions, and pain points across stages
* Accessibility requirements integrated into journey stages
* Design handoff sections with flow descriptions and principles

**Handoffs:** Delegates to `product-manager-advisor` for business alignment and `task-researcher` for technical feasibility.

**Critical:** Research-only. Does not generate UI designs or visual mockups. Produces artifacts that designers translate into Figma flows. Treats accessibility as a foundational constraint.

### prd-builder

**Creates:** Product requirements documents with session state:

* `docs/prds/<kebab-case-name>.md` (PRD document with requirements)
* `.copilot-tracking/prd-sessions/<kebab-case-name>.state.json` (session state for resume capability)

**Workflow:** Assess → Discover → Create → Build → Integrate → Validate → Finalize

**Critical:** Iterative questioning with refinement checklists. Maintains session state for continuity. Integrates user-provided references automatically.

### brd-builder

**Creates:** Business requirements documents with session state:

* `docs/brds/<kebab-case-name>-brd.md` (BRD document with business objectives)
* `.copilot-tracking/brd-sessions/<kebab-case-name>.state.json` (session state for resume capability)

**Workflow:** Assess → Discover → Create → Elicit → Integrate → Validate → Finalize

**Critical:** Solution-agnostic requirements focus. Links every requirement to business objectives. Supports session resume after context summarization.

### adr-creation

**Creates:** Architecture Decision Records:

* `.copilot-tracking/adrs/{{topic-name}}-draft.md` (working draft)
* `docs/decisions/YYYY-MM-DD-{{topic}}.md` (final location)

**Workflow:** Discovery → Research → Analysis → Documentation

**Critical:** Uses Socratic coaching methods. Guides users through decision-making process. Adapts coaching style to experience level.

### system-architecture-reviewer

**Creates:** Architecture review findings and ADRs:

* `docs/decisions/YYYY-MM-DD-short-title.md` (architecture decision records)

**Workflow:** Context Discovery → Review Scoping → Well-Architected Evaluation → Trade-Off Analysis → ADR Documentation → Escalation Review

**Critical:** Asks questions and reviews existing artifacts (ADRs, PRDs, plans) before making assumptions. Scopes reviews to 2-3 relevant framework areas based on gathered context. Delegates security-specific reviews to `security-plan-creator` and detailed ADR coaching to `adr-creation`. Uses `docs/templates/adr-template-solutions.md` for ADR structure.

### doc-ops

**Creates:** Documentation updates and maintenance artifacts:

* `.copilot-tracking/doc-ops/{{YYYY-MM-DD}}-session.md` (session tracking for documentation operations)

**Workflow:**

* Review existing documentation for accuracy and completeness
* Identify gaps, inconsistencies, or outdated content
* Apply structured documentation updates aligned with repository standards

**Critical:** Operates strictly on documentation files and does not modify application or source code

### memory

**Creates:** Repository memory records and session context:

* `.copilot-tracking/memory/{{YYYY-MM-DD}}/{{short-description}}-memory.md` (session continuity context)
* `.copilot-tracking/memory/{{YYYY-MM-DD}}/{{short-description}}-artifacts/` (optional companion files)
* `/memories/repo/<descriptive-name>.jsonl` (durable repository facts for future tasks)

**Workflow:** Identify actionable repository fact → Validate durability → Store with context → Available for future tasks

**Critical:** Stores only durable, reusable facts. Does not store transient discussion, personal preferences, or speculative information.

### security-plan-creator

**Creates:** Security plans and implementation artifacts:

* `.copilot-tracking/plans/security-plan-{blueprint-name}.plan.md` (planning artifacts and threat analysis)
* `security-plan-outputs/security-plan-{blueprint-name}.md` (final security plan document)

**Workflow:** Blueprint Selection → Architecture Analysis → Threat Assessment → Plan Generation → Validation

**Critical:** Requires blueprint infrastructure (Terraform or Bicep). Maps threats to specific system components. Generates iteratively with user feedback per section.

### gen-jupyter-notebook

**Creates:** Exploratory data analysis notebooks:

* `notebooks/*.ipynb` (EDA notebooks with parameterized data loading)
* `data/processed/*.parquet` (derived datasets with semantic naming)

**Workflow:** Context Gathering → Notebook Generation → Validation

**Critical:** Follows standard section layout with 13 required sections. Uses Plotly Express for interactive visualizations. References existing data dictionaries.

### gen-streamlit-dashboard

**Creates:** Multi-page Streamlit applications:

* `app.py` (main entry point with page navigation)
* `pages/*.py` (summary statistics, univariate/multivariate analysis, time series)
* `requirements.txt` (pinned dependencies)

**Workflow:** Project Setup → Core Dashboard Development → Advanced Features → Refinement

**Critical:** Uses Context7 for current Streamlit documentation. Supports AutoGen chat integration when reference scripts exist.

### gen-data-spec

**Creates:** Data documentation artifacts:

* `outputs/data-dictionary-{{dataset}}-{{YYYY-MM-DD}}.md` (column definitions and semantics)
* `outputs/data-profile-{{dataset}}-{{YYYY-MM-DD}}.json` (statistical profile for downstream tools)
* `outputs/data-objectives-{{dataset}}-{{YYYY-MM-DD}}.json` (analysis goals and constraints)
* `outputs/data-summary-{{dataset}}-{{YYYY-MM-DD}}.md` (human-readable overview)

**Workflow:** Confirm Scope → Discover Data → Sample & Infer Schema → Profile → Clarify → Emit Artifacts

**Critical:** Produces machine-readable profiles for downstream consumption. Follows strict JSON schemas. Minimal clarifying questions.

### arch-diagram-builder

**Creates:** ASCII architecture diagrams in markdown:

* Inline ASCII block diagrams embedded in markdown (pure ASCII for consistent alignment)
* Component legend and relationship key

**Workflow:** Discovery → Parsing → Relationship Mapping → Generation

**Critical:** Parses Terraform, Bicep, ARM, or shell scripts. Uses pure ASCII for consistent alignment. Groups by network boundary.

### github-backlog-manager

**Creates:** Backlog management artifacts under `.copilot-tracking/github-issues/`

**Workflow:** Issue Creation | Backlog Discovery | Triage | Community Interaction

**Critical:** Uses MCP GitHub tools. Follows community interaction guidelines from `community-interaction.instructions.md` for all contributor-facing comments.

### ado-prd-to-wit

**Creates:** Work item planning files:

* `.copilot-tracking/workitems/prds/<artifact-normalized-name>/planning-log.md` (session activity and decisions)
* `.copilot-tracking/workitems/prds/<artifact-normalized-name>/artifact-analysis.md` (PRD parsing and extraction)
* `.copilot-tracking/workitems/prds/<artifact-normalized-name>/work-items.md` (Epic/Feature/Story hierarchy)
* `.copilot-tracking/workitems/prds/<artifact-normalized-name>/handoff.md` (final handoff for ADO creation)

**Workflow:** Analyze PRD → Discover Codebase → Discover Related Work Items → Refine → Finalize Handoff

**Critical:** Planning-only. Uses ADO MCP tools for work item discovery. Supports Epics, Features, and User Stories.

### hve-core-installer

**Creates:** Installation configuration and tracking:

* `.hve-tracking.json` (for agent copy tracking)
* Settings updates in `.vscode/settings.json` (VS Code configuration)
* `.vscode/mcp.json` (MCP server configuration when applicable)

**Workflow:** Environment Detection → Decision Matrix → Installation → Validation → Agent Customization

**Critical:** Supports 6 installation methods plus extension quick install. Detects environment type automatically. Validates installation before reporting success.

### test-streamlit-dashboard

**Creates:** Test reports and issue documentation:

* Test results summary (pass/fail counts by category)
* Issue registry with reproduction steps (severity-categorized findings)
* Performance metrics (page load times, render benchmarks)

**Workflow:** Environment Setup → Functional Testing → Data Validation → Performance Assessment → Issue Reporting

**Critical:** Uses Playwright for browser automation. Requires running Streamlit application. Categorizes issues by severity.

## Common Workflows

### Autonomous Task Completion

1. Select **rpi-agent** from agent picker
2. Provide your request
3. Agent autonomously researches, implements, and verifies
4. Review results; agent continues if more work remains
5. Requires a subagent tool enabled in settings

### Planning a Feature

1. Select **task-researcher** from agent picker and create research document
2. Review research and provide decisions on approach
3. Clear context or start new chat
4. Select **task-planner** from agent picker and attach research doc
5. Generate 3-file plan set
6. Use `/task-implement` to execute the plan (automatically switches to **task-implementor**)

### Code Review

1. Select **pr-review** from agent picker
2. Automatically runs 4-phase protocol
3. Collaborate during Phase 3 (review items)
4. Receive `handoff.md` with final PR comments

### Creating Instructions

1. Select **prompt-builder** from agent picker
2. Draft instruction file with conventions
3. Auto-validates with Prompt Tester persona
4. Iterates up to 3 times for quality
5. Delivered to `.github/instructions/{collection-id}/` by convention

### Creating Documentation

1. Select **prd-builder** or **brd-builder** from agent picker
2. Answer guided questions about the product or business initiative
3. Provide references and supporting materials
4. Review and refine iteratively
5. Finalize when quality gates pass

## Important Notes

* **Linting Exemption:** Files in `.copilot-tracking/**` are exempt from repository linting rules
* **Agent Switching:** Clear context or start a new chat when switching between specialized agents
* **Research First:** Task planner requires completed research; will automatically invoke researcher if missing
* **No Implementation:** Task planner and researcher never implement actual project code—they create planning artifacts only
* **Subagent Requirements:** Several agents require a subagent tool enabled in Copilot settings

## Tips

* Be specific in your requests for better results
* Provide context about what you're working on
* Review generated outputs before using
* Chain agents together for complex tasks
* Use the RPI workflow (Researcher → Planner → Implementor) for substantial features

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
