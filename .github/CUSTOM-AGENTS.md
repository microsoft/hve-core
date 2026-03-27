---
title: GitHub Copilot Custom Agents
description: Specialized AI agents for planning, research, prompt engineering, documentation, and code review workflows
author: HVE Core Team
ms.date: 2026-03-22
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

| Agent                            | Purpose                                                                      | Key Constraint                                        |
|----------------------------------|------------------------------------------------------------------------------|-------------------------------------------------------|
| **adr-creation**                 | Interactive ADR coaching with guided discovery                               | Socratic coaching approach                            |
| **brd-builder**                  | Creates Business Requirements Documents with reference integration           | Solution-agnostic requirements focus                  |
| **doc-ops**                      | Documentation operations and maintenance                                     | Does not modify source code                           |
| **meeting-analyst**              | Analyzes meeting transcripts to extract product requirements via work-iq-mcp | Experimental; requires work-iq-mcp EULA; transcripts may contain PII and confidential data, analysis files are unencrypted on disk |
| **prd-builder**                  | Creates Product Requirements Documents through guided Q&A                    | Iterative questioning; state-tracked sessions         |
| **product-manager-advisor**      | Requirements discovery, story quality, and prioritization guidance           | Principles over format; delegates to prd/brd builders |
| **security-planner**             | STRIDE-based security model analysis with standards mapping and backlog handoff | Six-phase conversational workflow; experimental       |
| **sssc-planner**                 | Supply chain security assessment with 6-phase workflow against OpenSSF Scorecard, SLSA, Sigstore, and SBOM | Six-phase conversational workflow; experimental       |
| **rai-planner**                  | Responsible AI assessment with 6-phase workflow against MS RAI Standard v2 and NIST AI RMF | Six-phase conversational workflow; experimental       |
| **system-architecture-reviewer** | Reviews system designs for trade-offs and ADR alignment                      | Scoped review; delegates security concerns            |
| **ux-ui-designer**               | JTBD analysis, user journey mapping, and accessibility requirements          | Research artifacts only; visual design in Figma       |

### Utility Agents

| Agent      | Purpose                                    | Key Constraint                        |
|------------|--------------------------------------------|---------------------------------------|
| **memory** | Persists repository facts for future tasks | Stores only durable, actionable facts |

### Code and Review Agents

| Agent                 | Purpose                                                          | Key Constraint                          |
|-----------------------|------------------------------------------------------------------|-----------------------------------------|
| **pr-review**         | 4-phase PR review with tracking artifacts                        | Review-only; never modifies code        |
| **prompt-builder**    | Engineers and validates instruction/prompt files                 | Dual-persona system with auto-testing   |
| **security-reviewer** | OWASP vulnerability assessment with subagent-driven verification | Delegates all reference reading to subagents |

### Generator Agents

| Agent                       | Purpose                                            | Key Constraint                       |
|-----------------------------|----------------------------------------------------|--------------------------------------|
| **gen-jupyter-notebook**    | Creates structured EDA notebooks from data sources | Requires data dictionaries           |
| **gen-streamlit-dashboard** | Develops multi-page Streamlit dashboards           | Uses Context7 for documentation      |
| **gen-data-spec**           | Generates data dictionaries and profiles           | Produces JSON and markdown artifacts |
| **arch-diagram-builder**    | Builds ASCII block diagrams from Azure IaC         | Parses Terraform, Bicep, ARM scripts |

### Platform Integration Agents

| Agent                    | Purpose                                                    | Key Constraint                                  |
|--------------------------|------------------------------------------------------------|-------------------------------------------------|
| **github-backlog-manager** | Consolidated GitHub backlog management with community interaction | Uses MCP GitHub tools                           |
| **jira-backlog-manager** | Consolidated Jira backlog management with workflow dispatch and handoff tracking | Uses Jira skill planning workflows              |
| **ado-prd-to-wit**       | Analyzes PRDs and plans Azure DevOps work item hierarchies | Planning-only; does not create work items       |
| **jira-prd-to-wit**      | Analyzes PRDs and plans Jira issue hierarchies             | Planning-only; does not mutate Jira             |

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

**Critical:** Asks questions and reviews existing artifacts (ADRs, PRDs, plans) before making assumptions. Scopes reviews to 2-3 relevant framework areas based on gathered context. Delegates security-specific reviews to `security-planner` and detailed ADR coaching to `adr-creation`. Uses `docs/templates/adr-template-solutions.md` for ADR structure.

### doc-ops

**Creates:** Documentation updates and maintenance artifacts:

* `.copilot-tracking/doc-ops/{{YYYY-MM-DD}}-session.md` (session tracking for documentation operations)

**Workflow:**

* Review existing documentation for accuracy and completeness
* Identify gaps, inconsistencies, or outdated content
* Apply structured documentation updates aligned with repository standards

**Critical:** Operates strictly on documentation files and does not modify application or source code

### meeting-analyst

**Creates:** Transcript analysis documents and session state:

* `.copilot-tracking/prd-sessions/<kebab-case-name>-transcript-analysis.md` (structured requirements extracted from meeting transcripts)
* `.copilot-tracking/prd-sessions/<kebab-case-name>-transcript.state.json` (session state for resume capability)

**Workflow:** Discover → Extract → Synthesize → Handoff

**Critical:** Experimental. Requires the `workiq` MCP server in `.vscode/mcp.json` (not included in the installer skill or curated MCP documentation; see [official documentation](https://learn.microsoft.com/microsoft-365-copilot/extensibility/workiq-overview#install-in-vs-code) for setup). Requires `mcp_workiq_accept_eula` call before querying. Uses `mcp_workiq_ask_work_iq` for Microsoft 365 meeting data. Query budget of approximately 30 per session. Hands off to **prd-builder** for PRD creation.

**Data Sensitivity Warning:** Meeting transcripts retrieved by this agent may contain PII, customer confidential information, and proprietary business data. Analysis files and state files are written to `.copilot-tracking/prd-sessions/` which is gitignored by default when following HVE Core setup guidance, but the files exist **unencrypted on disk**.
Users are responsible for verifying their repository's `.gitignore` configuration, complying with their organization's data handling policies, and deleting both the `<name>-transcript-analysis.md` and `<name>-transcript.state.json` files after the PRD handoff is complete. The agent will prompt for deletion at handoff completion, but deletion is the user's responsibility.

### memory

**Creates:** Repository memory records and session context:

* `.copilot-tracking/memory/{{YYYY-MM-DD}}/{{short-description}}-memory.md` (session continuity context)
* `.copilot-tracking/memory/{{YYYY-MM-DD}}/{{short-description}}-artifacts/` (optional companion files)
* `/memories/repo/<descriptive-name>.jsonl` (durable repository facts for future tasks)

**Workflow:** Identify actionable repository fact → Validate durability → Store with context → Available for future tasks

**Critical:** Stores only durable, reusable facts. Does not store transient discussion, personal preferences, or speculative information.

### security-planner

**Creates:** Security plans and backlog handoff artifacts under `.copilot-tracking/security-plans/{project-slug}/`:

* `state.json` (session state for resume capability)
* `security-plan-{project-slug}.md` (security plan with STRIDE analysis, standards mapping, and operational bucket classification)
* Backlog items in ADO (`WI-SEC-{NNN}`) or GitHub (`{{SEC-TEMP-N}}`) format

**Workflow:** Six sequential phases: Scoping → Bucket Analysis → Standards Mapping → Security Model Analysis → Backlog Generation → Review and Handoff

**Entry Modes:** Two modes converge at Phase 2. Capture mode starts from scratch with an interview. From-PRD mode pre-populates from existing PRD/BRD artifacts.

**Critical:** Uses STRIDE methodology per operational bucket. Maps controls to OWASP Top 10, NIST 800-53, and CIS v8 frameworks. Detects AI/ML components during scoping and recommends RAI Planner dispatch when AI elements are present. Works iteratively with 3-5 questions per turn using emoji checklists to track progress. No blueprint infrastructure requirement. Maturity: experimental.

### rai-planner

**Creates:** Ten artifacts across 6 phases under `.copilot-tracking/rai-plans/{project-slug}/`:

* `state.json` (session state for resume capability)
* `system-definition-pack.md`, `stakeholder-impact-map.md` (Phase 1: AI System Scoping)
* `sensitive-uses-screening.md`, `use-misuse-inventory.md` (Phase 2: Sensitive Uses Assessment)
* `rai-standards-mapping.md` (Phase 3: RAI Standards Mapping)
* `rai-security-model-addendum.md` (Phase 4: RAI Security Model Analysis)
* `control-surface-catalog.md`, `evidence-register.md`, `rai-tradeoffs.md` (Phase 5: RAI Impact Assessment)
* `rai-scorecard.md` and backlog items (Phase 6: Review and Handoff)

**Workflow:** Six sequential phases mapped to NIST AI RMF functions: AI System Scoping (Govern + Map) → Sensitive Uses Assessment (Map) → RAI Standards Mapping (Govern + Measure) → RAI Security Model Analysis (Measure) → RAI Impact Assessment (Manage) → Review and Handoff (Manage)

**Entry Modes:** Three modes converge at Phase 2. Capture mode uses exploration-first interviewing adapted from Design Thinking research methods. From-PRD mode seeds the assessment from PRD artifacts. From-security-plan mode continues from a completed Security Planner session, inheriting AI component data and threat ID sequences.

**Critical:** Evaluates AI systems against Microsoft RAI Standard v2 and NIST AI RMF 1.0. Screens for sensitive uses and restricted uses requiring escalation. Applies AI-specific threat analysis using `RAI-T-{CATEGORY}-{NNN}` format across data poisoning, model evasion, prompt injection, and bias amplification. Seven instruction files provide domain guidance. Works iteratively with up to 7 questions per turn. Maturity: experimental.

### sssc-planner

**Creates:** Assessment artifacts under `.copilot-tracking/sssc-plans/{project-slug}/`:

* `state.json` (session state for resume capability)
* `sssc-plan-{project-slug}.md` (supply chain security assessment with standards mapping and gap analysis)
* Backlog items in ADO or GitHub format for remediation tracking

**Workflow:** Six sequential phases: Scoping → Supply Chain Assessment → Standards Mapping → Gap Analysis → Backlog Generation → Review and Handoff

**Entry Modes:** Four modes converge at Phase 2. Capture mode starts from scratch with an interview. From-PRD mode pre-populates from PRD artifacts. From-BRD mode seeds from BRD artifacts. From-security-plan mode continues from a completed Security Planner session.

**Critical:** Assesses against OpenSSF Scorecard (20 checks), SLSA Build levels (L0-L3), Best Practices Badge tiers, Sigstore keyless signing maturity, and SBOM compliance. Works iteratively with 3-5 questions per turn with confirmation before phase advancement. Maturity: experimental.

### security-reviewer

**Creates:** OWASP vulnerability assessment reports:

* `.copilot-tracking/security/{{YYYY-MM-DD}}/security-report-{{NNN}}.md` (audit mode report)
* `.copilot-tracking/security/{{YYYY-MM-DD}}/security-report-diff-{{NNN}}.md` (diff mode report)
* `.copilot-tracking/security/{{YYYY-MM-DD}}/plan-risk-assessment-{{NNN}}.md` (plan mode report)

**Workflow:** Setup → Profile Codebase → Assess Applicable Skills → Verify Findings → Generate Report → Compute Summary

**Modes:**

* `audit` (default): Full codebase scan against applicable OWASP skills
* `diff`: Scoped scan of changed files relative to the default branch
* `plan`: Pre-implementation risk assessment of a plan document (skips verification)

**Subagents:** Codebase Profiler, Skill Assessor, Finding Deep Verifier, Report Generator

**Critical:** Orchestrator-only pattern. Delegates codebase profiling, skill assessment, adversarial finding verification, and report generation to specialized subagents. Uses OWASP skills (`owasp-agentic`, `owasp-llm`, `owasp-top-10`, `owasp-ml`) for vulnerability references. Supports incremental comparison with prior scan reports.

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

### jira-backlog-manager

**Creates:** Backlog management artifacts under `.copilot-tracking/jira-issues/`

**Workflow:** Intent Classification → Workflow Dispatch → Summary and Handoff

**Critical:** Uses the Jira skill command surface. Supports discovery, triage, execution, and single-issue workflows while preserving planning files and autonomy gates.

### ado-prd-to-wit

**Creates:** Work item planning files:

* `.copilot-tracking/workitems/prds/<artifact-normalized-name>/planning-log.md` (session activity and decisions)
* `.copilot-tracking/workitems/prds/<artifact-normalized-name>/artifact-analysis.md` (PRD parsing and extraction)
* `.copilot-tracking/workitems/prds/<artifact-normalized-name>/work-items.md` (Epic/Feature/Story hierarchy)
* `.copilot-tracking/workitems/prds/<artifact-normalized-name>/handoff.md` (final handoff for ADO creation)

**Workflow:** Analyze PRD → Discover Codebase → Discover Related Work Items → Refine → Finalize Handoff

**Critical:** Planning-only. Uses ADO MCP tools for work item discovery. Supports Epics, Features, and User Stories.

### jira-prd-to-wit

**Creates:** Work item planning files:

* `.copilot-tracking/jira-issues/prds/<artifact-normalized-name>/planning-log.md` (session activity and decisions)
* `.copilot-tracking/jira-issues/prds/<artifact-normalized-name>/artifact-analysis.md` (PRD parsing and extraction)
* `.copilot-tracking/jira-issues/prds/<artifact-normalized-name>/issues-plan.md` (planned Jira issue hierarchy and field mappings)
* `.copilot-tracking/jira-issues/prds/<artifact-normalized-name>/handoff.md` (final handoff for Jira execution)

**Workflow:** Analyze PRD → Discover Codebase → Discover Related Jira Issues → Refine → Finalize Handoff

**Critical:** Planning-only. Validates Jira issue types and required fields before finalizing plans. Does not call Jira mutation commands.

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
* **No Implementation:** Task planner and researcher never implement actual project code. They create planning artifacts only
* **Subagent Requirements:** Several agents require a subagent tool enabled in Copilot settings

## Tips

* Be specific in your requests for better results
* Provide context about what you're working on
* Review generated outputs before using
* Chain agents together for complex tasks
* Use the RPI workflow (Researcher → Planner → Implementor) for substantial features

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
