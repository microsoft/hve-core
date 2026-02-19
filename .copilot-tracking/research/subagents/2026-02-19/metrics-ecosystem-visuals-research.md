---
title: Metrics, Ecosystem, and Visual Assets Research
description: Research findings covering roadmap metrics, extension ecosystem, CI/CD pipeline, and reusable visual assets for HVE-Core presentation
ms.date: 2026-02-19
ms.topic: research
---

## Roadmap Success Metrics

From [ROADMAP.md](../../../../docs/contributing/ROADMAP.md), the success metrics table for 2026-2027:

| Metric                     | Target                                 | Rationale                                     |
|----------------------------|----------------------------------------|-----------------------------------------------|
| Agent coverage             | 25+ agents                             | Cover common Azure development scenarios      |
| Instruction coverage       | 35+ instructions                       | Address major Azure technologies and patterns |
| VS Code extension installs | 10,000+                                | Validate community adoption                   |
| GitHub stars               | 500+                                   | Measure community interest                    |
| Active contributors        | 10+                                    | Ensure project sustainability                 |
| Issue response time        | < 7 days                               | Maintain community engagement                 |
| Documentation completeness | 100% of agents/instructions documented | Enable self-service adoption                  |

### Current Progress vs. Targets

| Metric               | Target | Current (Repo) | Status       |
|----------------------|--------|----------------|--------------|
| Agents               | 25+    | 22             | 88% achieved |
| Instructions         | 35+    | 24             | 69% achieved |
| Prompts              | N/A    | 27             | not targeted |
| Skills               | N/A    | 1              | early stage  |
| Collection manifests | N/A    | 10             | mature       |

## Repository Artifact Counts

Direct filesystem counts from the hve-core repository:

| Artifact Type | Count | Location                        |
|---------------|-------|---------------------------------|
| Agents        | 22    | `.github/agents/*.agent.md`     |
| Prompts       | 27    | `.github/prompts/*.prompt.md`   |
| Instructions  | 24    | `.github/instructions/**`       |
| Skills        | 1     | `.github/skills/*/SKILL.md`     |
| Collections   | 10    | `collections/*.collection.yml`  |
| **Total**     | **74** |                                |

## Extension Ecosystem Summary (8 Packages)

Eight VS Code extension packages are published under the `ise-hve-essentials` publisher. Each targets a specific workflow domain.

| # | Extension ID                        | Display Name                         | Version | Agents | Prompts | Instructions | Skills | Total |
|---|-------------------------------------|--------------------------------------|---------|--------|---------|--------------|--------|-------|
| 1 | `hve-core-2.2.0`                   | HVE Core                            | 2.2.0   | 21     | 23      | 18           | 0      | 62    |
| 2 | `hve-ado-2.3.10`                   | HVE Core - Azure DevOps Integration | 2.3.10  | 9      | 19      | 10           | 0      | 38    |
| 3 | `hve-github-2.3.10`               | HVE Core - GitHub Backlog Management | 2.3.10  | 9      | 19      | 10           | 0      | 38    |
| 4 | `hve-project-planning-2.3.10`     | HVE Core - Project Planning          | 2.3.10  | 13     | 15      | 5            | 0      | 33    |
| 5 | `hve-security-planning-2.3.10`    | HVE Core - Security Planning         | 2.3.10  | 9      | 16      | 5            | 0      | 30    |
| 6 | `hve-rpi-2.3.10`                  | HVE Core - RPI Workflow              | 2.3.10  | 8      | 14      | 5            | 0      | 27    |
| 7 | `hve-prompt-engineering-2.3.10`   | HVE Core - Prompt Engineering        | 2.3.10  | 8      | 14      | 5            | 0      | 27    |
| 8 | `hve-data-science-0.1.3`          | HVE Data Science                     | 0.1.3   | 1      | 1       | 0            | 0      | 2     |

### Ecosystem Totals (Deduplicated)

Many artifacts are shared across collection packages (base `hve-core-all` artifacts appear in every collection). The source-of-truth counts are the repository counts above (74 unique artifacts). The aggregate across all installed packages is 257 contribution registrations, reflecting shared base artifacts.

### Collection Manifests (10 Total)

| Collection             | Focus Area                                      |
|------------------------|------------------------------------------------|
| `hve-core-all`         | Universal base; all stable artifacts            |
| `ado`                  | Azure DevOps work items, builds, pull requests  |
| `github`               | GitHub issue discovery, triage, sprint planning |
| `project-planning`     | PRDs, BRDs, ADRs, architecture documentation    |
| `security-planning`    | Security plans, threat models, risk registers   |
| `rpi`                  | Research, Plan, Implement, Review workflow       |
| `prompt-engineering`   | Prompt/agent/instruction authoring tools         |
| `coding-standards`     | Language-specific coding conventions             |
| `data-science`         | Data notebooks, dashboards, ETL pipelines        |
| `git`                  | Git workflows, commit conventions, branching     |

## CI/CD Validation Pipeline (12 Parallel Jobs)

From [workflows.md](../../../../docs/architecture/workflows.md), the PR validation pipeline runs 12 jobs in parallel with no inter-job dependencies, targeting sub-3-minute feedback.

### PR Validation Jobs

| #  | Job                      | Category | Validates                      |
|----|--------------------------|----------|--------------------------------|
| 1  | spell-check              | Linting  | Spelling across all files      |
| 2  | markdown-lint            | Linting  | Markdown formatting rules      |
| 3  | table-format             | Linting  | Markdown table structure       |
| 4  | yaml-lint                | Linting  | YAML syntax                    |
| 5  | frontmatter-validation   | Linting  | AI artifact metadata schemas   |
| 6  | link-lang-check          | Linting  | Link accessibility             |
| 7  | markdown-link-check      | Linting  | Broken links                   |
| 8  | psscriptanalyzer         | Analysis | PowerShell code quality        |
| 9  | pester-tests             | Analysis | PowerShell unit tests          |
| 10 | dependency-pinning-check | Security | Action SHA pinning             |
| 11 | npm-audit                | Security | npm dependency vulnerabilities |
| 12 | codeql                   | Security | Code security patterns         |

### Pipeline Architecture

Four workflow trigger categories:

| Trigger    | Workflow                          | Purpose                                         |
|------------|-----------------------------------|------------------------------------------------|
| PR         | `pr-validation.yml`               | 12 parallel quality gate jobs                   |
| Main merge | `main.yml`                        | Post-merge validation + release-please          |
| Scheduled  | `weekly-security-maintenance.yml` | Sunday 2AM UTC security posture review          |
| Manual     | `extension-publish.yml`           | VS Code Marketplace publishing via OIDC + vsce  |

### Main Branch Pipeline

Post-merge flow: 5 validation jobs feed into `release-please`, which conditionally triggers `extension-package-release` and `attest-and-upload` (Sigstore attestation).

## Four-Tier Artifact Model

From [ai-artifacts.md](../../../../docs/architecture/ai-artifacts.md):

```text
Prompts → Agents → Instructions → Skills
```

| Tier           | File Pattern          | Purpose                               | Activation            |
|----------------|-----------------------|---------------------------------------|-----------------------|
| **Prompts**    | `.prompt.md`          | Workflow entry points; user intent    | Explicit `/prompt`    |
| **Agents**     | `.agent.md`           | Task orchestration with tool access   | Prompt reference      |
| **Instructions** | `.instructions.md` | Technology-specific standards         | Auto via glob match   |
| **Skills**     | `SKILL.md`            | Executable utilities with scripts     | Explicit invocation   |

### Delegation Flow

User Request → Prompt → Agent → Instructions + Skills

Key distinctions:

* **Instructions** are passive reference (standards/conventions, auto-activated by file patterns)
* **Skills** are active execution (scripts/utilities, explicitly invoked)

## Maturity Lifecycle

From [release-process.md](../../../../docs/contributing/release-process.md):

```text
[*] → experimental → preview → stable → deprecated → [*]
```

| Level          | Description                                 | Stable Channel | Pre-release Channel |
|----------------|---------------------------------------------|----------------|---------------------|
| `experimental` | Early development, may change significantly | Excluded       | Included            |
| `preview`      | Feature-complete, may have rough edges      | Excluded       | Included            |
| `stable`       | Production-ready, fully tested              | Included       | Included            |
| `deprecated`   | Scheduled for removal                       | Excluded       | Excluded            |

### Version Channels

| Channel     | Version Pattern    | Marketplace      |
|-------------|--------------------|-------------------|
| Stable      | Even minor (1.2.0) | Main listing      |
| Pre-release | Odd minor (1.3.0)  | Pre-release flag  |

## Mermaid Diagram Catalog (15 Diagrams)

Complete catalog of reusable Mermaid diagrams across the repository:

| #  | File                                   | Line | Type         | Description                                               |
|----|----------------------------------------|------|--------------|-----------------------------------------------------------|
| 1  | `docs/architecture/workflows.md`       | 13   | flowchart TD | Pipeline overview: PR, Main, Scheduled, Manual triggers   |
| 2  | `docs/architecture/workflows.md`       | 80   | flowchart LR | PR validation: 12 parallel jobs in 3 groups               |
| 3  | `docs/architecture/workflows.md`       | 127  | flowchart LR | Main branch pipeline with release-please                  |
| 4  | `docs/architecture/workflows.md`       | 182  | flowchart LR | Extension publishing: changelog → discover → package → publish |
| 5  | `docs/architecture/ai-artifacts.md`    | 143  | graph LR     | Delegation flow: User → Prompt → Agent → Instructions/Skills |
| 6  | `docs/architecture/ai-artifacts.md`    | 305  | graph TD     | Dependency resolution: rpi-agent dependency tree          |
| 7  | `docs/architecture/README.md`         | 15   | graph TD     | System architecture: Extension, Scripts, Docs components  |
| 8  | `docs/contributing/release-process.md` | 15   | flowchart LR | Release flow: Feature PR → main → release-please → publish |
| 9  | `docs/contributing/release-process.md` | 152  | stateDiagram  | Maturity lifecycle: experimental → preview → stable → deprecated |
| 10 | `docs/security/threat-model.md`        | 80   | flowchart TD | Security data flow: Developer Workstation ↔ GitHub Platform |
| 11 | `docs/templates/security-plan-template.md` | 46 | graph LR   | Template: Azure cloud resource group topology             |
| 12 | `extension/PACKAGING.md`               | 67   | flowchart LR | Packaging pipeline: Prepare → Package → VSIX              |
| 13 | `extension/PACKAGING.md`               | 89   | flowchart TB | Artifact discovery and resolution pipeline                |
| 14 | `extension/PACKAGING.md`               | 182  | flowchart TB | Package-Extension.ps1 internal flow                       |
| 15 | `extension/PACKAGING.md`               | 423  | flowchart TB | Collection resolution: multi-stage filter pipeline        |

## ASCII Art Diagram Catalog (8 Diagrams)

| #  | File                                            | Line | Description                                                |
|----|-------------------------------------------------|------|------------------------------------------------------------|
| 1  | `docs/security/threat-model.md`                 | 128  | Trust boundary diagram: Repository → CI/CD → External Deps |
| 2  | `docs/rpi/using-together.md`                    | 21   | RPI workflow: Researcher → Planner → Implementor → Reviewer |
| 3  | `docs/getting-started/install.md`               | 119  | Quick decision tree for installation method selection      |
| 4  | `docs/getting-started/methods/multi-root.md`    | 36   | Multi-root workspace layout diagram                        |
| 5  | `docs/getting-started/methods/mounted.md`       | 67   | Mounted directory installation phases                      |
| 6  | `docs/agents/github-backlog/using-together.md`  | 19   | Backlog pipeline: Discovery → Triage → Sprint → Execution |
| 7  | `docs/architecture/ai-artifacts.md`             | 210  | Collection manifest architecture (manifests → build system) |
| 8  | `.github/agents/hve-core-installer.agent.md`    | 1450 | Upgrade diff display format example                        |

### Roadmap Timeline (ASCII)

Additionally, [ROADMAP.md](../../../../docs/contributing/ROADMAP.md) contains a text-format timeline spanning Q1 2026 through Q1 2027.

## Presentation Script Inventory

Four Python scripts in `scripts/powerpoint/`:

| Script                                  | Lines | Purpose                                              | Output Format |
|-----------------------------------------|-------|------------------------------------------------------|---------------|
| `generate-poc-presentation.py`          | 2793  | Media Broker PoC PowerPoint with diagrams and notes  | `.pptx`       |
| `generate-poc-svgs.py`                  | 1703  | SVG diagrams for Media Broker PoC (12 diagram types) | `.svg`        |
| `generate-leak-detection-presentation.py` | 1123 | Leak Detection at the Edge PowerPoint presentation   | `.pptx`       |
| `generate-leak-detection-svgs.py`       | 832   | SVG diagrams for Leak Detection (8 diagram types)    | `.svg`        |

All scripts use `python-pptx` and `Pillow` libraries, Microsoft brand-adjacent dark theme palette, and output to `.copilot-tracking/presentation-assets/`.

## Agent Systems Catalog

From [agents/README.md](../../../../docs/agents/README.md), nine agent groups:

| Group                     | Agents   | Complexity  | Documentation Status |
|---------------------------|----------|-------------|----------------------|
| RPI Orchestration         | 5        | High        | Documented           |
| GitHub Backlog Management | 1 active | Very High   | Documented           |
| ADO Integration           | 1        | Medium-High | Planned              |
| Document Builders         | 4        | Medium-High | Planned              |
| Data Pipeline             | 4        | Medium      | Planned              |
| DevOps Quality            | 2        | High        | Planned              |
| Meta/Engineering          | 1        | High        | Planned              |
| Infrastructure            | 1        | Very High   | Planned              |
| Utility                   | 1        | Low-Medium  | Planned              |

## Identified Gaps

| Gap                                   | Impact                                                        |
|---------------------------------------|---------------------------------------------------------------|
| No HVE-Core-specific presentation script | Existing scripts target PoC and Leak Detection projects, not HVE-Core itself |
| Skills count at 1                     | Significantly below agent/prompt counts; expansion needed     |
| 7 of 9 agent groups lack documentation | Only RPI and GitHub Backlog have full docs                    |
| No extension install metrics available | Target is 10,000+ installs but no current count accessible    |
| No GitHub stars count accessible      | Target is 500+ stars but no current count accessible          |
| Data Science extension at 0.1.3       | Significantly behind other extensions (2.3.10); early stage   |
