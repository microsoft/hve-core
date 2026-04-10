<!-- markdownlint-disable-file -->
# Data Science

Data specification generation, Jupyter notebooks, and Streamlit dashboards

> [!CAUTION]
> This collection includes RAI (Responsible AI) agents and prompts that are **assistive tools only**. They do not replace qualified responsible AI review, ethics board oversight, or established organizational RAI governance processes. All AI-generated RAI assessments, impact analyses, and recommendations **must** be reviewed and validated by qualified professionals before use. AI outputs may contain inaccuracies, miss critical risk categories, or produce recommendations that are incomplete or inappropriate for your context.

## Overview

Generate data specifications, Jupyter notebooks, and Streamlit dashboards from natural language descriptions. Evaluate AI-powered data systems against Responsible AI standards. This collection includes specialized agents for data science workflows in Python and RAI assessment.

> [!CAUTION]
> The RAI agents and prompts in this collection are **assistive tools only**. They do not replace qualified human review, organizational RAI review boards, or regulatory compliance programs. All AI-generated RAI artifacts **must** be reviewed and validated by qualified professionals before use. AI outputs may contain inaccuracies, miss critical risks, or produce recommendations that are incomplete or inappropriate for your context.

This collection includes agents for:

- **Data Specification Generation** — Create structured data schemas and specifications from requirements
- **Jupyter Notebook Generation** — Build data analysis notebooks with visualizations and documentation
- **Streamlit Dashboard Generation** — Create interactive dashboards from data sources
- **Dashboard Testing** — Comprehensive test suites for Streamlit applications
- **RAI Planner** — Responsible AI assessment with security model analysis, impact assessment, and dual-format backlog handoff

## Install

```bash
copilot plugin install data-science@hve-core
```

## Agents

| Agent                    | Description                                                                                                                                                                                                                                                                                                  |
|--------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| gen-data-spec            | Generate comprehensive data dictionaries, machine-readable data profiles, and objective summaries for downstream analysis (EDA notebooks, dashboards) through guided discovery                                                                                                                               |
| gen-jupyter-notebook     | Create structured exploratory data analysis Jupyter notebooks from available data sources and generated data dictionaries                                                                                                                                                                                    |
| gen-streamlit-dashboard  | Develop a multi-page Streamlit dashboard                                                                                                                                                                                                                                                                     |
| test-streamlit-dashboard | Automated testing for Streamlit dashboards using Playwright with issue tracking and reporting                                                                                                                                                                                                                |
| rai-planner              | Responsible AI assessment planning agent with 6-phase conversational workflow. Guides planning against NIST AI RMF 1.0 as the default evaluation framework. Prepares RAI security model, impact assessment, control surface catalog, and dual-format backlog handoff. - Brought to you by microsoft/hve-core |
| researcher-subagent      | Research subagent using search tools, read tools, fetch web page, github repo, and mcp tools                                                                                                                                                                                                                 |

## Commands

| Command                     | Description                                                                                                                                     |
|-----------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------|
| rai-capture                 | Initiate responsible AI assessment planning from existing knowledge using the RAI Planner agent in capture mode                                 |
| rai-plan-from-prd           | Initiate responsible AI assessment planning from PRD/BRD artifacts using the RAI Planner agent in from-prd mode                                 |
| rai-plan-from-security-plan | Initiate responsible AI assessment planning from a completed Security Plan using the RAI Planner agent in from-security-plan mode (recommended) |

## Instructions

| Instruction                        | Description                                                                                                                                                                                                                                                 |
|------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| python-script.instructions         | Instructions for Python scripting implementation - Brought to you by microsoft/hve-core                                                                                                                                                                     |
| uv-projects.instructions           | Create and manage Python virtual environments using uv commands                                                                                                                                                                                             |
| rai-backlog-handoff.instructions   | RAI review and backlog handoff for Phase 6: review rubric, RAI review summary, dual-format backlog generation                                                                                                                                               |
| rai-identity.instructions          | RAI Planner identity, 6-phase orchestration, state management, and session recovery - Brought to you by microsoft/hve-core                                                                                                                                  |
| rai-impact-assessment.instructions | RAI impact assessment for Phase 5: control surface taxonomy, evidence register, tradeoff documentation, and work item generation - Brought to you by microsoft/hve-core                                                                                     |
| rai-security-model.instructions    | RAI security model analysis for Phase 4: AI STRIDE extensions, dual threat IDs, ML STRIDE matrix, and security model merge protocol - Brought to you by microsoft/hve-core                                                                                  |
| rai-standards.instructions         | Embedded RAI standards for Phase 3: NIST AI RMF 1.0 trustworthiness characteristics, subcategory mappings, and framework isolation architecture - Brought to you by microsoft/hve-core                                                                      |
| rai-capture-coaching.instructions  | Exploration-first questioning techniques for RAI capture mode adapted from Design Thinking research methods - Brought to you by microsoft/hve-core                                                                                                          |
| hve-core-location.instructions     | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

