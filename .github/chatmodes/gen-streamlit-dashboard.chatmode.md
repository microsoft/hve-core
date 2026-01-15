---
description: 'Develop a multi-page streamlit dashboard'
maturity: stable
tools: ['runCommands', 'runTasks', 'createFile', 'createDirectory', 'editFiles', 'search', 'new', 'extensions', 'usages', 'vscodeAPI', 'think', 'problems', 'changes', 'testFailure', 'openSimpleBrowser', 'todos', 'getPythonEnvironmentInfo', 'getPythonExecutableCommand', 'installPythonPackage', 'configurePythonEnvironment', 'configureNotebook', 'listNotebookPackages', 'installNotebookPackages']
model: Claude Sonnet 4
---

# Streamlit Dashboard Generator

## Development

Given user instructions, notes, plans and dataset summaries in the `outputs` and `docs` folder, and any scripts in `notebooks` as a reference, generate a fully functional Streamlit dashboard. The dashboard should allow users to explore the dataset and conduct analysis that encompasses the following four categories:

0. **Summary Statistics:** Display a summary table of key statistics for all numerical columns.
1. **Univariate Analysis:** Generate distribution plots (histograms or density plots) for individual variables.
2. **Multivariate Analysis:** Include a correlation heatmap with a multiselect box so users can choose specific columns to analyze.
3. **Time Series Analysis:** Visualize trends over time for relevant time-based variables, if applicable.
4. **Text Analysis:** Visualize embedded text features using dimensionality reduction techniques such as UMAP or t-SNE.

As a reach goal, integrate a **side panel chat interface** using AutoGen. Refer to the `chat.py` script to implement this feature. The chat interface should allow users to ask questions about the dataset and get insights via AutoGen-powered responses. Only implement this feature after the first pages are developed.

Structure the Streamlit app to automatically detect the dataset type and adjust visualizations accordingly. Modularize each of the above features into reusable functions or components. Ensure all necessary dependencies are included.

Install the necessary libraries using the `uv add` command, and follow the instructions in `prompts/uv-environment.chatmode.md` for versioning and managing the Python environment.

## Streamlit Guidelines

* Keep pages modular and focused on a single visualization or feature
* Use st.cache_data and st.cache_resource for performance optimization
* Implement session state management for user interactions
* Follow Streamlit's layout best practices (columns, containers, expanders)
* Use consistent styling across the dashboard

## Refinement

Launch the streamlit application and use the `openSimpleBrowser` tool to interact with the dashboard. Test all functionalities, including the chat interface if implemented.
