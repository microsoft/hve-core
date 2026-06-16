<!-- markdownlint-disable-file -->
# Data Science

Evaluation dataset creation, data specification generation, Jupyter notebooks, and Streamlit dashboards

> [!CAUTION]
> This collection includes RAI (Responsible AI) agents and prompts that are **assistive tools only**. They do not replace qualified responsible AI review, ethics board oversight, or established organizational RAI governance processes. All AI-generated RAI assessments, impact analyses, and recommendations **must** be reviewed and validated by qualified professionals before use. AI outputs may contain inaccuracies, miss critical risk categories, or produce recommendations that are incomplete or inappropriate for your context.

## Overview

Generate data specifications, Jupyter notebooks, and Streamlit dashboards from natural language descriptions. Evaluate AI-powered data systems against Responsible AI standards. This collection includes specialized agents for data science workflows in Python and RAI assessment.

> [!CAUTION]
> The RAI agents and prompts in this collection are **assistive tools only**. They do not replace qualified human review, organizational RAI review boards, or regulatory compliance programs. All AI-generated RAI artifacts **must** be reviewed and validated by qualified professionals before use. AI outputs may contain inaccuracies, miss critical risks, or produce recommendations that are incomplete or inappropriate for your context.

## Included Artifacts

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

### Chat Agents

| Name                         | Description                                                                                                                                                            |
|------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **eval-dataset-creator**     | Creates evaluation datasets and documentation for AI agent testing using interview-driven data curation                                                                |
| **gen-data-spec**            | Generate data dictionaries, machine-readable data profiles, and summaries for downstream EDA notebooks and dashboards                                                  |
| **gen-jupyter-notebook**     | Create exploratory data analysis (EDA) Jupyter notebooks from data sources and data dictionaries                                                                       |
| **gen-streamlit-dashboard**  | Develop a multi-page Streamlit dashboard                                                                                                                               |
| **rai-planner**              | Responsible AI assessment planner evaluating against NIST AI RMF 1.0, producing an RAI security model, impact assessment, control surface catalog, and backlog handoff |
| **researcher-subagent**      | Research subagent using search, read, web-fetch, GitHub repo, and MCP tools                                                                                            |
| **test-streamlit-dashboard** | Automated testing for Streamlit dashboards using Playwright with issue tracking and reporting                                                                          |

### Prompts

| Name                            | Description                                                                                                                                  |
|---------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------|
| **rai-capture**                 | Start responsible AI assessment planning from existing knowledge using the RAI Planner agent in capture mode                                 |
| **rai-plan-from-prd**           | Start responsible AI assessment planning from PRD/BRD artifacts using the RAI Planner agent in from-prd mode                                 |
| **rai-plan-from-security-plan** | Start responsible AI assessment planning from a completed Security Plan using the RAI Planner agent in from-security-plan mode (recommended) |
| **synth-data-generate**         | Generate synthetic data for any subject with realistic patterns and relationships                                                            |

### Instructions

| Name                                     | Description                                                                                                                                                                                                                                                 |
|------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **coding-standards/python-script**       | Python scripting conventions                                                                                                                                                                                                                                |
| **coding-standards/uv-projects**         | Create and manage Python virtual environments using uv commands                                                                                                                                                                                             |
| **rai-planning/rai-backlog-handoff**     | RAI review and backlog handoff for Phase 6: review rubric, RAI review summary, dual-format backlog generation                                                                                                                                               |
| **rai-planning/rai-capture-coaching**    | Exploration-first questioning techniques for RAI capture mode adapted from Design Thinking research methods                                                                                                                                                 |
| **rai-planning/rai-identity**            | RAI Planner identity, 6-phase orchestration, state management, and session recovery                                                                                                                                                                         |
| **rai-planning/rai-impact-assessment**   | RAI impact assessment for Phase 5: control surface taxonomy, evidence register, tradeoff documentation, and work item generation                                                                                                                            |
| **rai-planning/rai-risk-classification** | Risk classification screening for Phase 2: prohibited uses gate, risk indicator assessment, and depth tier assignment                                                                                                                                       |
| **rai-planning/rai-security-model**      | RAI security model analysis for Phase 4: AI STRIDE extensions, dual threat IDs, ML STRIDE matrix, and security model merge protocol                                                                                                                         |
| **rai-planning/rai-standards**           | Embedded RAI standards for Phase 3: NIST AI RMF 1.0 trustworthiness characteristics, subcategory mappings, and framework isolation architecture                                                                                                             |
| **shared/hve-core-location**             | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

<!-- END AUTO-GENERATED ARTIFACTS -->

## Install

```bash
copilot plugin install data-science@hve-core
```

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

