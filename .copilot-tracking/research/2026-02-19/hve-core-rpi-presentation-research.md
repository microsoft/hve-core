<!-- markdownlint-disable-file -->
# Task Research: HVE-Core and RPI Presentation

Comprehensive research for a mixed-audience presentation covering HVE-Core's purpose, the RPI framework, enterprise pain points addressed, metrics, and reusable visual assets.

## Task Implementation Requests

* Explain what HVE-Core is and the problems it solves
* Detail the four phases of the RPI framework and their benefits
* Identify pain points in traditional enterprise AI-assisted development that HVE-Core addresses
* Gather relevant statistics (productivity gains, time savings, adoption metrics)
* Catalog reusable diagrams, markdown files, and presentation-generation scripts

## Scope and Success Criteria

* Scope: All HVE-Core repository documentation, 8 installed VS Code HVE extensions, architecture docs, roadmap, CI/CD pipeline, and scripts
* Assumptions:
  * Audience is mixed (developers, TPMs, leads, executives)
  * Presentation uses slides with diagrams and speaker notes
  * Statistics are roadmap targets rather than measured actuals (no telemetry in the repo)
* Success Criteria:
  * Clear, quotable messaging for each slide topic
  * Complete catalog of reusable visual assets with file paths and line numbers
  * Evidence-backed talking points traced to source documents
  * Recommended slide structure with flow and ordering

## Outline

1. [What is HVE-Core?](#1-what-is-hve-core) — elevator pitch, component counts, architecture
2. [The Problem](#2-the-problem) — traditional AI coding failures, root cause analysis
3. [The RPI Framework](#3-the-rpi-framework) — four phases, constraints, quality differences
4. [Pain Points and Quality Comparison](#4-pain-points-and-quality-comparison) — traditional vs RPI side-by-side
5. [Extension Ecosystem](#5-extension-ecosystem) — 8 packages, role-based collections
6. [Enterprise Validation Pipeline](#6-enterprise-validation-pipeline) — CI/CD, JSON schema, maturity lifecycle
7. [Metrics and Adoption](#7-metrics-and-adoption) — roadmap targets, compounding value narrative
8. [Reusable Visual Assets](#8-reusable-visual-assets) — mermaid diagrams, ASCII art, generation scripts
9. [Suggested Slide Structure](#9-suggested-slide-structure) — ordering and flow recommendations

## Potential Next Research

* Measure actual VS Code Marketplace install counts via Marketplace API
  * Reasoning: Roadmap cites 10,000+ target; actuals would strengthen the story
  * Reference: [ROADMAP.md](../../docs/contributing/ROADMAP.md#L148)
* Gather customer/team testimonials or case studies
  * Reasoning: Anecdotal evidence resonates with mixed audiences
  * Reference: None found in repo
* Create an HVE-Core-specific PowerPoint generation script
  * Reasoning: Existing scripts in `scripts/powerpoint/` target other projects; a purpose-built script would produce a ready-to-deliver deck
  * Reference: [scripts/powerpoint/](../../scripts/powerpoint/)
* Competitive positioning analysis
  * Reasoning: No comparison against other prompt frameworks (Cursor rules, aider, etc.) exists in the docs
  * Reference: None found in repo

## Research Executed

### File Analysis

* [README.md](../../README.md) — elevator pitch, component counts, quick start, project structure
* [docs/README.md](../../docs/README.md) — audience routing table, documentation index
* [docs/rpi/README.md](../../docs/rpi/README.md) — RPI four-phase overview, when-to-use matrix, quick start steps
* [docs/rpi/why-rpi.md](../../docs/rpi/why-rpi.md) — problem statement, counterintuitive insight, quality comparison table, learning curve, strict vs rpi-agent decision matrix
* [docs/rpi/task-researcher.md](../../docs/rpi/task-researcher.md) — research phase details, constraint rationale, output artifacts
* [docs/rpi/task-planner.md](../../docs/rpi/task-planner.md) — planning phase details, traceability chain, output artifacts
* [docs/rpi/task-implementor.md](../../docs/rpi/task-implementor.md) — implementation phase, stop controls
* [docs/rpi/task-reviewer.md](../../docs/rpi/task-reviewer.md) — review phase, severity levels, feedback loops
* [docs/rpi/using-together.md](../../docs/rpi/using-together.md) — complete walkthrough (Azure Blob Storage example), ASCII workflow diagram
* [docs/getting-started/first-workflow.md](../../docs/getting-started/first-workflow.md) — 15-minute hands-on tutorial
* [docs/getting-started/install.md](../../docs/getting-started/install.md) — 7 installation methods, decision matrix
* [docs/architecture/ai-artifacts.md](../../docs/architecture/ai-artifacts.md) — four-tier artifact model, delegation flow, collection manifests
* [docs/architecture/workflows.md](../../docs/architecture/workflows.md) — CI/CD pipeline architecture, 12 parallel jobs
* [docs/architecture/README.md](../../docs/architecture/README.md) — system architecture mermaid diagram
* [docs/contributing/ROADMAP.md](../../docs/contributing/ROADMAP.md) — success metrics, timeline Q1 2026–Q1 2027
* [docs/contributing/release-process.md](../../docs/contributing/release-process.md) — maturity lifecycle, version channels
* [docs/agents/README.md](../../docs/agents/README.md) — 9 agent groups catalog
* [.github/CUSTOM-AGENTS.md](../../.github/CUSTOM-AGENTS.md) — all 22 agents with descriptions
* [extension/PACKAGING.md](../../extension/PACKAGING.md) — extension packaging pipeline with 4 mermaid diagrams
* [CHANGELOG.md](../../CHANGELOG.md) — version history from v0.0.0 through v2.3.4

### Code Search Results

* `mermaid` in `**/*.md` — 15 mermaid diagrams across 7 files
* `statistics|productivity|metric` in `docs/**/*.md` — no quantitative productivity metrics; roadmap targets only
* `diagram|svg|presentation|slide` in `**/*.md` — identified 4 Python presentation scripts in `scripts/powerpoint/`

### External Research

* VS Code Marketplace extension listings confirmed for 8 `ise-hve-essentials.*` packages
* All 8 extension `package.json` files analyzed for artifact contribution counts

### Project Conventions

* Standards referenced: markdown.instructions.md, writing-style.instructions.md, prompt-builder.instructions.md
* Instructions followed: Task Researcher mode constraints — research only, no code changes

---

## Key Discoveries

### 1. What is HVE-Core?

**Elevator pitch (1 sentence):**

> HVE Core is an enterprise-ready prompt engineering framework for GitHub Copilot that uses constraint-based AI workflows to turn AI from a code generator into a research partner.

**Extended pitch (2 sentences):**

> HVE Core is an enterprise-ready prompt engineering framework for GitHub Copilot providing 22 specialized agents, 27 reusable prompts, and 24 instruction sets with JSON schema validation. Its RPI methodology separates complex engineering tasks into Research, Plan, Implement, and Review phases where AI knows what it cannot do — changing optimization targets from "plausible code" to "verified truth."

**Source:** [README.md](../../README.md#L25), [docs/README.md](../../docs/README.md#L10)

**Component summary:**

| Component    | Count | Purpose                                                        |
|--------------|-------|----------------------------------------------------------------|
| Agents       | 22    | Specialized AI assistants for 9 functional domains             |
| Prompts      | 27    | Workflow entry points for common tasks                         |
| Instructions | 24    | Technology-specific coding standards (auto-applied by file pattern) |
| Skills       | 1     | Executable utility packages with cross-platform scripts        |
| Collections  | 10    | Role-based artifact filtering for 8 extension packages         |

**Source:** Repository filesystem counts, [.github/CUSTOM-AGENTS.md](../../.github/CUSTOM-AGENTS.md), [docs/architecture/ai-artifacts.md](../../docs/architecture/ai-artifacts.md)

**Four-tier artifact model:** User Request → Prompt → Agent → Instructions + Skills

Each tier serves a distinct purpose in the delegation chain:

| Artifact         | Purpose                                               | Activation                   |
|------------------|-------------------------------------------------------|------------------------------|
| **Prompts**      | Workflow entry points; capture user intent             | Manual via `/prompt` command |
| **Agents**       | Task orchestration with tool access and constraints    | Via prompt reference or picker |
| **Instructions** | Technology-specific standards applied automatically    | Auto via `applyTo` glob pattern |
| **Skills**       | Executable utilities with cross-platform scripts       | Explicit invocation          |

**Source:** [docs/architecture/ai-artifacts.md](../../docs/architecture/ai-artifacts.md#L12-L140)

---

### 2. The Problem

**Root cause:** AI can't tell the difference between investigating and implementing. When you ask for code, it writes code — without verifying patterns, conventions, or dependencies against the actual codebase.

**The failure mode (slide-ready example):**

> **The failure mode you'll recognize**
>
> You: "Build me a Terraform module for Azure IoT"
>
> AI: *immediately generates 2000 lines of code*
>
> Reality: Missing dependencies, wrong variable names, outdated patterns, breaks existing infrastructure

**Source:** [docs/rpi/why-rpi.md](../../docs/rpi/why-rpi.md#L22-L30)

**Key quotable phrases:**

| Quote | Best slide use |
|-------|----------------|
| "AI writes first and thinks never" | Problem statement |
| "Plausible and correct aren't the same thing" | Problem framing |
| "The solution isn't teaching AI to be smarter. It's preventing AI from doing certain things at certain times." | Core insight |
| "The constraint changes the goal" | One-liner takeaway |
| "Research partner first, code generator second" | Vision/paradigm shift |
| "The code comes last, after the hard work of understanding is complete" | Philosophy |
| "Stops optimizing for plausible code and starts optimizing for verified truth" | Before/after transformation |

**Source:** [docs/rpi/why-rpi.md](../../docs/rpi/why-rpi.md)

---

### 3. The RPI Framework

**Type transformation pipeline:**

```text
Uncertainty → Knowledge → Strategy → Working Code → Validated Code
```

Each phase converts one form of understanding into the next. Skipping a phase means operating on the wrong type.

**Source:** [docs/rpi/README.md](../../docs/rpi/README.md#L20-L22)

#### Phase 1: Research (Task Researcher)

| Attribute | Detail |
|-----------|--------|
| **Purpose** | Transform uncertainty into verified knowledge |
| **Key constraint** | Knows it will never write code — searches for existing patterns instead of inventing |
| **Key behaviors** | Investigates codebase, external APIs, docs; cites specific files and line numbers; questions its own assumptions |
| **Output** | `.copilot-tracking/research/{{YYYY-MM-DD}}-<topic>-research.md` |
| **Duration** | 20–60 minutes (autonomous) |
| **Invocation** | `/task-research <topic>` |

**Source:** [docs/rpi/task-researcher.md](../../docs/rpi/task-researcher.md)

#### Phase 2: Plan (Task Planner)

| Attribute | Detail |
|-----------|--------|
| **Purpose** | Transform knowledge into actionable strategy |
| **Key constraint** | Cannot implement — focuses on sequencing, dependencies, success criteria |
| **Key behaviors** | Validates research exists (mandatory); creates checkboxes with line refs; organizes into phases |
| **Output** | Plan file + Details file in `.copilot-tracking/plans/` and `.copilot-tracking/details/` |
| **Invocation** | `/task-plan` with research file open |

**Traceability chain:** Plan → Details (Lines X–Y) → Research (Lines A–B)

**Source:** [docs/rpi/task-planner.md](../../docs/rpi/task-planner.md)

#### Phase 3: Implement (Task Implementor)

| Attribute | Detail |
|-----------|--------|
| **Purpose** | Transform strategy into working code |
| **Key constraint** | Follows the plan using documented patterns — no creative decisions that break existing patterns |
| **Key behaviors** | Executes phase by phase, task by task; tracks changes; verifies success criteria |
| **Output** | Working code + `.copilot-tracking/changes/{{YYYY-MM-DD}}-<topic>-changes.md` |
| **Stop controls** | `phaseStop=true` (default), `taskStop=true` |
| **Invocation** | `/task-implement` |

**Source:** [docs/rpi/task-implementor.md](../../docs/rpi/task-implementor.md)

#### Phase 4: Review (Task Reviewer)

| Attribute | Detail |
|-----------|--------|
| **Purpose** | Transform working code into validated code |
| **Key constraint** | Validates against documented specifications, not assumptions |
| **Key behaviors** | Extracts checklist from research + plan; validates each item with evidence; runs lint/build/test; documents findings with severity |
| **Output** | `.copilot-tracking/reviews/{{YYYY-MM-DD}}-<topic>-review.md` |
| **Severity levels** | Critical, Major, Minor |
| **Invocation** | `/task-review` |

**Feedback loop:** Review can escalate back to Research (gaps found), Plan (scope changes), or Implement (fixes needed).

**Source:** [docs/rpi/task-reviewer.md](../../docs/rpi/task-reviewer.md), [docs/rpi/using-together.md](../../docs/rpi/using-together.md#L225-L265)

#### The /clear Rule

```text
Task Researcher → /clear → Task Planner → /clear → Task Implementor → /clear → Task Reviewer
```

Context clearing between phases prevents contamination. Research findings live in files, not chat history. Clean context lets each agent work optimally with its own behavioral instructions.

**Source:** [docs/rpi/README.md](../../docs/rpi/README.md#L70-L79)

#### Strict RPI vs rpi-agent Decision Matrix

| Factor | Strict RPI | rpi-agent |
|--------|-----------|-----------|
| Research depth | Deep, verified, cited | Moderate, inline |
| Context contamination | Eliminated via `/clear` | Possible |
| Audit trail | Complete artifacts | Summary only |
| Review phase | Explicit findings log | Integrated loop |
| Best for | Complex, unfamiliar, team work | Simple, familiar, solo work |

**Escalation path:** Start with rpi-agent. If complexity emerges, hand off to Task Researcher. No upfront commitment required.

**Source:** [docs/rpi/why-rpi.md](../../docs/rpi/why-rpi.md#L130-L172)

---

### 4. Pain Points and Quality Comparison

**Traditional vs RPI (slide-ready comparison table):**

| Aspect | Traditional AI Coding | RPI Approach |
|--------|----------------------|--------------|
| **Pattern matching** | Invents plausible patterns | Uses verified existing patterns |
| **Traceability** | "The AI wrote it this way" | "Research document cites lines 47-52" |
| **Knowledge transfer** | Tribal knowledge in your head | Research documents anyone can follow |
| **Rework** | Frequent — assumptions discovered wrong after the fact | Rare — assumptions verified before implementation |
| **Validation** | Hope it works or manual testing | Validated against specifications with evidence |

**Source:** [docs/rpi/why-rpi.md](../../docs/rpi/why-rpi.md#L98-L112)

**The paradigm shift:**

> Stop asking AI: "Write this code."
>
> Start asking: "Help me research, plan, then implement with evidence."

**Source:** [docs/rpi/why-rpi.md](../../docs/rpi/why-rpi.md#L92-L96)

---

### 5. Extension Ecosystem

Eight VS Code extension packages under the `ise-hve-essentials` publisher, each targeting a specific workflow domain:

| Extension | Focus | Agents | Prompts | Instructions |
|-----------|-------|--------|---------|--------------|
| **hve-core** (full) | All artifacts | 21 | 23 | 18 |
| **hve-ado** | Azure DevOps | 9 | 19 | 10 |
| **hve-github** | GitHub Backlog | 9 | 19 | 10 |
| **hve-project-planning** | PRDs/BRDs/ADRs | 13 | 15 | 5 |
| **hve-security-planning** | Security Plans | 9 | 16 | 5 |
| **hve-rpi** | RPI Workflow | 8 | 14 | 5 |
| **hve-prompt-engineering** | Prompt Tools | 8 | 14 | 5 |
| **hve-data-science** | Data Science | 1 | 1 | 0 |

All v2.3.10 extensions share a common base of 8 agents (memory, pr-review, prompt-builder, rpi-agent, task-implementor, task-planner, task-researcher, task-reviewer) and 5 core instructions, then add domain-specific artifacts.

**Source:** Extension `package.json` files at `/home/vscode/.vscode-server/extensions/ise-hve-essentials.*/`

---

### 6. Enterprise Validation Pipeline

12 parallel CI/CD validation jobs run on every pull request:

| Category | Jobs |
|----------|------|
| **Linting** (7 jobs) | spell-check, markdown-lint, table-format, yaml-lint, frontmatter-validation, link-lang-check, markdown-link-check |
| **Analysis** (2 jobs) | psscriptanalyzer, pester-tests |
| **Security** (3 jobs) | dependency-pinning-check, npm-audit, codeql |

**Schema validation pipeline:**

```text
*.instructions.md → instruction-frontmatter.schema.json
*.prompt.md       → prompt-frontmatter.schema.json
*.agent.md        → agent-frontmatter.schema.json
SKILL.md          → skill-frontmatter.schema.json
```

**Maturity lifecycle:** `experimental → preview → stable → deprecated`

| Level | Stable Channel | Pre-release Channel |
|-------|----------------|---------------------|
| experimental | Excluded | Included |
| preview | Excluded | Included |
| stable | Included | Included |
| deprecated | Excluded | Excluded |

**Source:** [docs/architecture/workflows.md](../../docs/architecture/workflows.md), [docs/contributing/release-process.md](../../docs/contributing/release-process.md)

---

### 7. Metrics and Adoption

**Roadmap success metrics (targets, not measured actuals):**

| Metric | Target | Current Status |
|--------|--------|----------------|
| Agent coverage | 25+ | 22 (88%) |
| Instruction coverage | 35+ | 24 (69%) |
| VS Code extension installs | 10,000+ | Not publicly available |
| GitHub stars | 500+ | Not publicly available |
| Active contributors | 10+ | Not publicly available |
| Issue response time | < 7 days | Not measured |
| Documentation completeness | 100% | 2 of 9 agent groups documented |

**Source:** [docs/contributing/ROADMAP.md](../../docs/contributing/ROADMAP.md#L146-L155)

**Version velocity narrative:**

| Version | Date | Milestone |
|---------|------|-----------|
| 1.1.0 | 2026-01-19 | Foundation: devcontainer, agents, RPI docs, VS Code extension |
| 2.0.0 | 2026-01-28 | **Breaking:** Task Reviewer added, RPI expanded to 4 phases |
| 2.3.4 | 2026-02-13 | Current: GitHub backlog management, CLI plugin generation |

**Narrative arc:** Zero to enterprise-grade in ~4 weeks. The 2.0 breaking change (adding Review) demonstrates commitment to validated, evidence-based AI work.

**Source:** [CHANGELOG.md](../../CHANGELOG.md)

**Compounding value story:**

> "By your third feature, the workflow feels natural. The research phase becomes faster because you know what questions to ask. The planning phase tightens because you recognize what level of detail works for your codebase. Implementation becomes almost mechanical."

> "Research documents accumulate into institutional memory. New team members can read how past decisions were made. Patterns get documented once and referenced forever."

**Source:** [docs/rpi/why-rpi.md](../../docs/rpi/why-rpi.md#L127-L133)

**Learning curve (honest framing):**

> "Let's be honest: your first RPI workflow will feel slower."

This candor builds credibility with the audience. Follow immediately with the "third feature" payoff.

---

### 8. Reusable Visual Assets

#### Mermaid Diagrams (15 total)

**High-value for HVE-Core/RPI presentation:**

| # | Diagram | File:Line | Best slide use |
|---|---------|-----------|----------------|
| 1 | System architecture (components) | [docs/architecture/README.md](../../docs/architecture/README.md#L15) | "What's Included" overview |
| 2 | Delegation flow (User→Prompt→Agent→Instructions) | [docs/architecture/ai-artifacts.md](../../docs/architecture/ai-artifacts.md#L143) | Artifact model explanation |
| 3 | RPI dependency tree | [docs/architecture/ai-artifacts.md](../../docs/architecture/ai-artifacts.md#L305) | Agent relationships |
| 4 | Maturity lifecycle state diagram | [docs/contributing/release-process.md](../../docs/contributing/release-process.md#L152) | Enterprise governance |
| 5 | Release workflow | [docs/contributing/release-process.md](../../docs/contributing/release-process.md#L15) | CI/CD story |
| 6 | PR validation pipeline (12 jobs) | [docs/architecture/workflows.md](../../docs/architecture/workflows.md#L80) | Validation rigor |
| 7 | Pipeline overview (4 triggers) | [docs/architecture/workflows.md](../../docs/architecture/workflows.md#L13) | CI/CD architecture |

**Additional diagrams:** 8 more in [docs/architecture/workflows.md](../../docs/architecture/workflows.md), [extension/PACKAGING.md](../../extension/PACKAGING.md), [docs/security/threat-model.md](../../docs/security/threat-model.md)

#### ASCII Art Diagrams (8 total)

**High-value for presentation:**

| # | Diagram | File:Line | Best slide use |
|---|---------|-----------|----------------|
| 1 | **Complete RPI workflow** (signature visual) | [docs/rpi/using-together.md](../../docs/rpi/using-together.md#L21) | RPI overview slide |
| 2 | Schema validation pipeline | [README.md](../../README.md#L153) | Enterprise validation |
| 3 | Project structure tree | [README.md](../../README.md#L171) | Architecture overview |
| 4 | Installation decision tree | [docs/getting-started/install.md](../../docs/getting-started/install.md#L119) | Getting started |

#### Presentation Generation Scripts (4 scripts, pattern reference)

Located in [scripts/powerpoint/](../../scripts/powerpoint/):

| Script | Output | Lines |
|--------|--------|-------|
| `generate-poc-presentation.py` | `.pptx` | 2793 |
| `generate-poc-svgs.py` | `.svg` | 1703 |
| `generate-leak-detection-presentation.py` | `.pptx` | 1123 |
| `generate-leak-detection-svgs.py` | `.svg` | 832 |

All use `python-pptx`, `Pillow`, Microsoft brand-adjacent dark palette, reusable helpers (`add_text_box`, `add_shape_with_text`, `add_connector_line`, `set_speaker_notes`), and output to `.copilot-tracking/presentation-assets/`. These provide a battle-tested pattern for creating an HVE-Core-specific presentation generator.

#### Source Markdown Files for Reuse

| File | Content | Direct copy-paste? |
|------|---------|---------------------|
| [docs/rpi/why-rpi.md](../../docs/rpi/why-rpi.md) | Problem statement, quality table, quotes | Yes — most quotable source |
| [docs/rpi/README.md](../../docs/rpi/README.md) | Four-phase overview, when-to-use table | Yes — framework summary |
| [docs/rpi/using-together.md](../../docs/rpi/using-together.md) | Walkthrough, ASCII diagram, feedback loops | Yes — demo material |
| [docs/getting-started/first-workflow.md](../../docs/getting-started/first-workflow.md) | 15-min tutorial structure | Yes — live demo script |
| [README.md](../../README.md) | Elevator pitch, component table | Yes — opening slide |

---

## Technical Scenarios

### Scenario: Presenting to a Mixed Audience

**Requirements:**

* Developers need concrete examples and tool familiarity
* TPMs/leads need traceability and team scaling story
* Executives need velocity narrative and quality differentiation

**Preferred Approach: Problem-First Storytelling with Layered Depth**

Start with the universally relatable failure mode, introduce the counterintuitive insight, then layer detail for each audience segment.

#### Recommended Slide Flow

| # | Slide Title | Content Source | Audience Target |
|---|-------------|----------------|-----------------|
| 1 | **The Problem** | Terraform failure mode from [why-rpi.md](../../docs/rpi/why-rpi.md#L22) | All |
| 2 | **Why It Happens** | "AI writes first, thinks never" — root cause | All |
| 3 | **The Counterintuitive Insight** | "Preventing AI from doing certain things at certain times" | All |
| 4 | **What is HVE-Core?** | Elevator pitch + component table from [README.md](../../README.md#L25) | All |
| 5 | **The Four-Tier Artifact Model** | Delegation flow mermaid from [ai-artifacts.md](../../docs/architecture/ai-artifacts.md#L143) | Platform/Leads |
| 6 | **The RPI Pipeline** | Type transformation + ASCII workflow from [using-together.md](../../docs/rpi/using-together.md#L21) | All |
| 7 | **Deep Dive: Each Phase** | Phase tables from sections above | Developers |
| 8 | **Quality Comparison** | Traditional vs RPI table from [why-rpi.md](../../docs/rpi/why-rpi.md#L98) | All |
| 9 | **The Extension Ecosystem** | 8-package table + collection model | Leads/Platform |
| 10 | **Enterprise Validation** | 12 parallel CI jobs, schema validation | Platform/Execs |
| 11 | **Learning Curve & Compounding Value** | "Third feature" narrative + institutional memory | Execs/Leads |
| 12 | **Version Velocity** | v0→v2.3 in 4 weeks, milestone table | Execs |
| 13 | **Live Demo** | 15-min first-workflow tutorial from [first-workflow.md](../../docs/getting-started/first-workflow.md) | Developers |
| 14 | **Getting Started** | Install methods, marketplace link | All |

#### Audience-Specific Angles

| Audience | Lead With | Supporting Evidence |
|----------|-----------|---------------------|
| **Developers** | The Terraform failure → constraint fix → agent picker UX | First-workflow tutorial, `/task-research` command |
| **Engineering Leads/TPMs** | Traceability table, institutional memory, team scaling | Research docs as audit trail, 7 install methods, collection filtering |
| **Platform Engineers** | JSON schema validation, 12-job CI pipeline, maturity lifecycle | `npm run lint:frontmatter`, release channels |
| **Executives** | "Zero to enterprise-grade in 4 weeks," rework reduction | OpenSSF badges, version velocity, compounding value |

#### Considered Alternatives

**Alternative 1: Feature-first approach** — Lead with component counts and capabilities. Rejected because it lacks emotional hook and doesn't establish the "why" before the "what."

**Alternative 2: Demo-first approach** — Open with the live 15-minute RPI workflow. Rejected for mixed audiences because executives may not sit through a 15-minute technical demo. Better as a closing segment.

**Alternative 3: Metrics-first approach** — Open with adoption targets and velocity. Rejected because most metrics are targets rather than actuals, which weakens credibility as an opener.

---

## Subagent Research References

* [hve-core-messaging-research.md](../subagents/2026-02-19/hve-core-messaging-research.md) — Elevator pitch, problem statement, quotable phrases, version history
* [rpi-framework-research.md](../subagents/2026-02-19/rpi-framework-research.md) — Phase details, quality comparison, decision matrices, walkthrough example
* [metrics-ecosystem-visuals-research.md](../subagents/2026-02-19/metrics-ecosystem-visuals-research.md) — Artifact counts, extension ecosystem, CI/CD pipeline, visual asset catalog
