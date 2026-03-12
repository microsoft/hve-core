<!-- markdownlint-disable-file -->
# Data Science

Data specification generation, Jupyter notebooks, and Streamlit dashboards

## Install

```bash
copilot plugin install data-science@hve-core
```

## Agents

| Agent                    | Description                                                                                                                                                                                                                                                                                                                  |
|--------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| gen-data-spec            | Generate comprehensive data dictionaries, machine-readable data profiles, and objective summaries for downstream analysis (EDA notebooks, dashboards) through guided discovery                                                                                                                                               |
| gen-jupyter-notebook     | Create structured exploratory data analysis Jupyter notebooks from available data sources and generated data dictionaries                                                                                                                                                                                                    |
| gen-streamlit-dashboard  | Develop a multi-page Streamlit dashboard                                                                                                                                                                                                                                                                                     |
| test-streamlit-dashboard | Automated testing for Streamlit dashboards using Playwright with issue tracking and reporting                                                                                                                                                                                                                                |
| rai-planner              | Responsible AI assessment agent with 6-phase conversational workflow. Evaluates AI systems against Microsoft RAI Standard v2 and NIST AI RMF 1.0. Produces sensitive uses screening, RAI security model, impact assessment, control surface catalog, and dual-format backlog handoff. - Brought to you by microsoft/hve-core |

## Instructions

| Instruction           | Description                                                                                                                                                                                                                                                 |
|-----------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| python-script         | Instructions for Python scripting implementation - Brought to you by microsoft/hve-core                                                                                                                                                                     |
| uv-projects           | Create and manage Python virtual environments using uv commands                                                                                                                                                                                             |
| rai-backlog-handoff   | RAI review and backlog handoff for Phase 6: review rubric, RAI scorecard, dual-format backlog generation                                                                                                                                                    |
| rai-identity          | RAI Planner identity, 6-phase orchestration, state management, and session recovery - Brought to you by microsoft/hve-core                                                                                                                                  |
| rai-impact-assessment | RAI impact assessment for Phase 5: control surface taxonomy, evidence register, tradeoff documentation, and work item generation                                                                                                                            |
| rai-security-model    | RAI security model analysis for Phase 4: AI STRIDE extensions, dual threat IDs, ML STRIDE matrix, and security model merge protocol                                                                                                                         |
| rai-sensitive-uses    | Sensitive Uses assessment for Phase 2: screening categories, restricted uses gate, and depth tier assignment                                                                                                                                                |
| rai-standards         | Embedded RAI standards for Phase 3: Microsoft RAI Standard v2 principles and NIST AI RMF subcategory mappings                                                                                                                                               |
| rai-capture-coaching  | Exploration-first questioning techniques for RAI capture mode adapted from Design Thinking research methods - Brought to you by microsoft/hve-core                                                                                                          |
| hve-core-location     | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

