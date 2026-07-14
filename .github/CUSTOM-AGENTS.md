---
title: GitHub Copilot Custom Agents
description: Specialized AI agents for planning, research, prompt engineering, documentation, and code review workflows
author: HVE Core Team
ms.date: 2026-07-13
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

The RPI lifecycle keeps Research, Plan, Implement, Review, and Follow-up distinct for complex development tasks. It begins with research readiness: supplied or completed evidence is reused when adequate, and research runs only for a demonstrated requirements, acceptance, dependency, material-risk, complexity, uncertainty, or decision-critical gap.

`RPI Agent` is a user-selected lifecycle wrapper that activates the matching RPI skills. `/rpi-quick` is a skill-based full-flow entry point. They are alternative entry surfaces for the same phase skills, not autonomous dispatchers of specialized task workers. Use `/rpi-research`, `/rpi-plan`, `/rpi-implement`, and `/rpi-review` when you need a direct phase entry point. See the [RPI Documentation](../docs/rpi/README.md) for both surfaces.

| Agent                | Purpose                                                                                               | Key Constraint                                                                    |
|----------------------|-------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------|
| **RPI Agent**        | User-selected lifecycle wrapper that activates matching RPI skills                                   | Uses research readiness and has no fixed specialized task-worker roster           |
| **task-researcher**  | Produces research evidence and recommendations for a demonstrated readiness gap                      | Research-only; never plans or implements                                          |
| **task-planner**     | Produces a dated plan and matching phase-details artifact, then records independent critique          | Uses supplied or complete evidence; activates research only for a demonstrated readiness gap |
| **task-implementor** | Directly executes approved `Pxx` or `Pxx-Txx` work and records change evidence                        | Significant divergence requires a fresh critique before affected dependent work resumes |
| **task-reviewer**    | Reconciles plan, details, critique, amendments, changes, and validation evidence                      | Review-only; separates execution status from outcome and routes open work         |
| **task-challenger**  | Adversarial questioning agent that interrogates completed implementations with What/Why/How questions | Experimental; no suggestions, hints, or leading questions                         |

### Documentation and Planning Agents

| Agent                            | Purpose                                                                                                                  | Key Constraint                                                                                                                     |
|----------------------------------|--------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------|
| **adr-creation**                 | Interactive ADR coaching with guided discovery                                                                           | Socratic coaching approach                                                                                                         |
| **brd-builder**                  | Creates Business Requirements Documents with reference integration                                                       | Solution-agnostic requirements focus                                                                                               |
| **documentation**                | Documentation audit, drift, authoring, and validation workflow                                                           | Uses the shared documentation skill and escalates formal assessments to planner agents                                             |
| **meeting-analyst**              | Analyzes meeting transcripts to extract product requirements via work-iq-mcp                                             | Experimental; requires work-iq-mcp EULA; transcripts may contain PII and confidential data, analysis files are unencrypted on disk |
| **prd-builder**                  | Creates Product Requirements Documents through guided Q&A                                                                | Iterative questioning; state-tracked sessions                                                                                      |
| **product-manager-advisor**      | Requirements discovery, story quality, and prioritization guidance                                                       | Principles over format; delegates to prd/brd builders                                                                              |
| **security-planner**             | STRIDE-based security model analysis with standards mapping and backlog handoff                                          | Six-phase conversational workflow; experimental                                                                                    |
| **sssc-planner**                 | Supply chain security assessment with 6-phase workflow against OpenSSF Scorecard, SLSA, Sigstore, and SBOM               | Six-phase conversational workflow; experimental                                                                                    |
| **rai-planner**                  | Responsible AI assessment with 6-phase workflow against Microsoft Responsible AI Impact Assessment Guide and NIST AI RMF | Six-phase conversational workflow; experimental                                                                                    |
| **system-architecture-reviewer** | Reviews system designs for trade-offs and ADR alignment                                                                  | Scoped review; delegates security concerns                                                                                         |
| **ux-ui-designer**               | JTBD analysis, user journey mapping, and accessibility requirements                                                      | Research artifacts only; visual design in Figma                                                                                    |

### Utility Agents

| Agent      | Purpose                                    | Key Constraint                        |
|------------|--------------------------------------------|---------------------------------------|
| **memory** | Persists repository facts for future tasks | Stores only durable, actionable facts |

### Code and Review Agents

| Agent                 | Purpose                                                                | Key Constraint                                                |
|-----------------------|------------------------------------------------------------------------|---------------------------------------------------------------|
| **prompt-builder**    | Compatibility entry point for HVE Builder artifact lifecycle work      | Routes to one author-review-test-validation implementation    |
| **security-reviewer** | OWASP vulnerability assessment with subagent-driven verification       | Delegates all reference reading to subagents                  |
| **code-review**       | Human-gated review orchestrator dispatching five perspective subagents | Operator confirms scope, perspectives, and depth; review-only |

### Generator Agents

| Agent                       | Purpose                                            | Key Constraint                       |
|-----------------------------|----------------------------------------------------|--------------------------------------|
| **gen-jupyter-notebook**    | Creates structured EDA notebooks from data sources | Requires data dictionaries           |
| **gen-streamlit-dashboard** | Develops multi-page Streamlit dashboards           | Uses Context7 for documentation      |
| **gen-data-spec**           | Generates data dictionaries and profiles           | Produces JSON and markdown artifacts |

### Platform Integration Agents

| Agent                      | Purpose                                                                          | Key Constraint                            |
|----------------------------|----------------------------------------------------------------------------------|-------------------------------------------|
| **github-backlog-manager** | Consolidated GitHub backlog management with community interaction                | Uses MCP GitHub tools                     |
| **jira-backlog-manager**   | Consolidated Jira backlog management with workflow dispatch and handoff tracking | Uses Jira skill planning workflows        |
| **ado-prd-to-wit**         | Analyzes PRDs and plans Azure DevOps work item hierarchies                       | Planning-only; does not create work items |
| **jira-prd-to-wit**        | Analyzes PRDs and plans Jira issue hierarchies                                   | Planning-only; does not mutate Jira       |

### Testing Agents

| Agent                        | Purpose                                     | Key Constraint                         |
|------------------------------|---------------------------------------------|----------------------------------------|
| **test-streamlit-dashboard** | Automated Streamlit testing with Playwright | Requires running Streamlit application |

## Agent Details

### RPI Agent

**Activates:** The matching RPI skills for the applicable lifecycle concepts:

* `rpi-research` only when research readiness identifies a demonstrated gap
* `rpi-plan` for the parent-owned plan, phase details, and independent critique
* `rpi-implement` for direct execution and change evidence
* `rpi-review` for one evidence-reconciliation record and outcome routing

**Workflow:** Research readiness → Plan → Implement → Review → Follow-up. Research can be reused or satisfied-and-skipped when the evidence set is adequate. Follow-up routes defects to implementation, decisions to planning, evidence gaps to research, and residual work to a distinct next item.

**Artifacts:** When a stage needs a durable record, the lifecycle uses one stable task ID and these marker-addressed paths:

* `.copilot-tracking/research/{{YYYY-MM-DD}}/{{task_slug}}-research.md`
* `.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md`
* `.copilot-tracking/details/{{YYYY-MM-DD}}/{{task_slug}}-phase-details.md`
* `.copilot-tracking/reviews/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan-critique.md`
* `.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md`
* `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/{{task_slug}}-review.md`

**Critical:** `RPI Agent` is a user-selected lifecycle wrapper, not an autonomous loop or a dispatcher for named specialized task workers. It may use generic bounded delegation only when it materially improves an isolated activity. Navigate durable artifacts with the task ID, `Pxx`, `Pxx-Txx`, headings, and `<!-- rpi:... -->` markers.

### task-researcher

**Creates:** Single authoritative research document:

* `.copilot-tracking/research/{{YYYY-MM-DD}}/{{task_slug}}-research.md` (primary research with evidence-based recommendations)
* `.copilot-tracking/research/subagents/{{YYYY-MM-DD}}/{{task_slug}}-subagent-research.md` (subagent research outputs when delegating)

**Workflow:** Deep tool-based research → Document findings → Consolidate to one approach → Hand off to planner

**Critical:** Research-only specialist. Uses subagent tools. Continuously refines document. Never plans or implements.

### task-planner

**Creates:** Planning records per task:

* `.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md` (implementation plan with checklist items)
* `.copilot-tracking/details/{{YYYY-MM-DD}}/{{task_slug}}-phase-details.md` (evidence-based phase and task details)
* `.copilot-tracking/reviews/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan-critique.md` (independent plan critique)

**Workflow:** Assess supplied evidence → Create plan and phase details → Record critique disposition → Hand off for implementation

**Critical:** Uses supplied or complete evidence and activates research only for a demonstrated readiness gap. The plan and details use `Pxx` and `Pxx-Txx` IDs with stable markers. Never implements actual code.

### task-implementor

**Creates:** Change evidence:

* `.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md` (changes, divergences, validation, and handoff evidence)

**Workflow:** Resolve plan and phase details by marker → Implement approved work directly → Record changes and validation → Hand off for review

**Critical:** Checks off completed `Pxx` and `Pxx-Txx` work only after evidence exists. Uses `CHG-xxx` entries for material changes. A significant `DIV-xxx` links to an `AM-xxx` amendment and matching phase-detail update, then requires a fresh critique before affected dependent work resumes.

### task-reviewer

**Creates:** Review records:

* `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/{{task_slug}}-review.md` (evidence reconciliation, findings, outcome, and routing)

**Workflow:** Reconcile plan, phase details, critique, amendments, changes, and validation evidence → Record findings → Route each open item

**Critical:** Review-only specialist. Produces severity-graded `RV-xxx` findings and keeps execution status (`Complete`, `Partial`, or `Blocked`) distinct from the review outcome and next-owner routing.

**Documentation:** See [Task Reviewer Guide](../docs/rpi/task-reviewer.md) for detailed usage.

### prompt-builder

**Creates:** Instruction files and prompt files:

* `.github/instructions/{collection-id}/*.instructions.md` (coding guidelines and conventions, by convention)
* `.github/prompts/{collection-id}/*.prompt.md` (reusable workflow prompts, by convention)
* `.copilot-tracking/hve-builder/{{YYYY-MM-DD}}/*-review-*.md` (independent static review evidence)
* `.copilot-tracking/hve-builder/{{YYYY-MM-DD}}/*-behavior-report-*.md` (fidelity-labeled behavior evidence)

**Workflow:** Route mode and write boundary → Author → Fresh-context review → Behavior test → Host validation

**Critical:** Compatibility surface only. The `hve-builder` skill owns the lifecycle, stage gates, Terra/Luna worker models, and final outcome.

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

* `docs/project-planning/<kebab-case-name>.md` (PRD document with requirements)
* `.copilot-tracking/prd-sessions/<kebab-case-name>.state.json` (session state for resume capability)

**Workflow:** Assess → Discover → Create → Build → Integrate → Validate → Finalize

**Critical:** Iterative questioning with refinement checklists. Maintains session state for continuity. Integrates user-provided references automatically.

### brd-builder

**Creates:** Business requirements documents with session state:

* `docs/project-planning/<kebab-case-name>-brd.md` (BRD document with business objectives)
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

### documentation

**Creates:** Documentation workflow session tracking and documentation updates:

* `.copilot-tracking/documentation/{{YYYY-MM-DD}}-session.md` (session tracking for the Documentation workflow)

**Workflow:**

* Review existing documentation for scope, accuracy, and completeness
* Identify drift, gaps, or outdated content in the requested area
* Author or validate documentation updates using the shared documentation skill

**Critical:** Uses the Documentation workflow as the canonical entry point for documentation work. It stays focused on documentation artifacts and routes formal accessibility, RAI, and security assessments to the matching planner agents.

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

**Creates:** Nine artifacts across 6 phases under `.copilot-tracking/rai-plans/{project-slug}/`:

* `state.json` (session state for resume capability)
* `system-definition-pack.md`, `stakeholder-impact-map.md` (Phase 1: AI System Scoping)
* Risk classification screening output (Phase 2: Risk Classification)
* `rai-standards-mapping.md` (Phase 3: RAI Standards Mapping)
* `rai-threat-addendum.md` (Phase 4: RAI Security Model Analysis)
* `control-surface-catalog.md`, `evidence-register.md`, `rai-tradeoffs.md` (Phase 5: RAI Impact Assessment)
* `rai-review-summary.md` and backlog items (Phase 6: Review and Handoff)

**Workflow:** Six sequential phases mapped to NIST AI RMF functions: AI System Scoping (Govern + Map) → Risk Classification (Govern) → RAI Standards Mapping (Govern + Measure) → RAI Security Model Analysis (Measure) → RAI Impact Assessment (Manage) → Review and Handoff (Manage)

**Entry Modes:** Three modes converge at Phase 2. Capture mode uses exploration-first interviewing adapted from Design Thinking research methods. From-PRD mode seeds the assessment from PRD artifacts. From-security-plan mode continues from a completed Security Planner session, inheriting AI component data and threat ID sequences.

**Critical:** Evaluates AI systems against the Microsoft Responsible AI Impact Assessment Guide and NIST AI RMF 1.0. Applies AI-specific threat analysis using dual threat ID convention (`T-RAI-{NNN}` sequential IDs and `T-{BUCKET}-AI-{NNN}` cross-references) across data poisoning, model evasion, prompt injection, and bias amplification. Seven instruction files provide domain guidance. Works iteratively with up to 7 questions per turn. Maturity: experimental.

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

**Critical:** Orchestrator-only pattern. Delegates codebase profiling, skill assessment, adversarial finding verification, and report generation to specialized subagents. Uses OWASP skills (`owasp-agentic`, `owasp-llm`, `owasp-top-10`, `owasp-mcp`, `owasp-infrastructure`, `owasp-cicd`) and the `secure-by-design` skill for vulnerability and design principle references. Supports incremental comparison with prior scan reports.

### code-review

**Creates:** Merged review artifacts in a normalized branch folder:

* `.copilot-tracking/reviews/code-reviews/<sanitized-branch>/review.md` (merged review document, per the shared persistence protocol in `review-artifacts.instructions.md`)
* `.copilot-tracking/reviews/code-reviews/<sanitized-branch>/metadata.json` (review metadata record)

**Workflow:** Context Bootstrap → Human Scope Confirmation → Perspective + Depth Selection → Prepare Dispatch State → Dispatch Selected Perspectives → Merge and Persist

**Critical:** Human-gated orchestrator invoked from the agent picker. After computing the diff via the `pr-reference` skill, it confirms scope with the operator, then lets the operator choose any combination of five perspectives (`functional`, `standards`, `accessibility`, `security`, `pr`) or `full` to run all five, plus a depth tier (`basic`, `standard`, or `comprehensive`) applied independently of perspective.
It dispatches thin perspective subagents under `.github/agents/coding-standards/subagents/`, shares the computed diff to avoid duplicate git operations, and merges every report into a single output. Review-only; never modifies code. Maturity: experimental.

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

### Coordinating an RPI Lifecycle

1. Select **RPI Agent** from the agent picker, or use `/rpi-quick` for the skill-based full-flow entry point.
2. Provide the task, acceptance criteria, decisions, dependencies, and any completed research.
3. Assess research readiness before activating `rpi-research`; reuse adequate evidence instead of repeating research.
4. Continue through the applicable phase skills and resume from the durable artifact set when a long lifecycle needs a fresh context.

### Planning a Feature

1. Gather task context, decisions, acceptance criteria, and any completed research
2. Use **task-researcher** when a demonstrated planning-readiness gap remains
3. Clear context or start new chat
4. Select **task-planner** from agent picker and attach the available evidence
5. Generate a plan, matching phase-details artifact, and independent critique
6. Use `/task-implement` to execute the plan (automatically switches to **task-implementor**)

### Code Review

1. Select **code-review** from agent picker
2. Confirm the change scope when prompted
3. Choose perspectives (`functional`, `standards`, `accessibility`, `security`, `pr`, or `full`) and a depth tier
4. Receive a merged `review.md` under `.copilot-tracking/reviews/code-reviews/<branch>/`

### Creating Instructions

1. Select **prompt-builder** from agent picker
2. Provide the target path, reference context, and requirements
3. HVE Builder resolves the create or improve mode and source-write boundary
4. HVE Builder authors, independently reviews, behavior-tests, and validates the artifact
5. Review the overall outcome and evidence links before merging

### Creating Documentation

1. Select **prd-builder** or **brd-builder** from agent picker
2. Answer guided questions about the product or business initiative
3. Provide references and supporting materials
4. Review and refine iteratively
5. Finalize when quality gates pass

## Important Notes

* **Linting Exemption:** Files in `.copilot-tracking/**` are exempt from repository linting rules
* **Agent Switching:** Clear context or start a new chat when switching between specialized agents
* **Evidence Readiness:** Task Planner uses supplied or complete evidence and activates research only for a demonstrated readiness gap
* **No Implementation:** Task planner and researcher never implement actual project code. They create planning artifacts only
* **RPI entry surfaces:** `RPI Agent` and `/rpi-quick` activate the same phase skills; neither requires a fixed specialized task-worker roster

## Tips

* Be specific in your requests for better results
* Provide context about what you're working on
* Review generated outputs before using
* Use the RPI lifecycle when research readiness identifies a gap or the task needs durable planning, implementation evidence, review, or follow-up routing
* Resume long-lived work from the stable task ID and dated RPI artifacts instead of relying on conversation history

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
