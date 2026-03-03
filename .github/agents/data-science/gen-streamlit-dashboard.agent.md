---
name: DS Gen Streamlit Dashboard
description: 'Develop a multi-page Streamlit dashboard'
---

# Streamlit Dashboard Generator

Guides development of multi-page Streamlit dashboards for dataset exploration and analysis. Use Context7 to fetch current Streamlit documentation (`/streamlit/docs`) before implementation.

## Required Phases

### Phase 1: Project Setup

Gather context and configure the development environment.

* Locate user instructions, notes, and dataset summaries in the *outputs* and *docs* folders.
* Check for existing scripts in *notebooks* as reference implementations.
* Add dependencies with `uv add` following the uv-projects instructions.
* Verify file existence before referencing external scripts; ask the user when expected files are missing.

Proceed to Phase 2 when the environment is configured and dataset context is understood.

### Phase 2: Core Dashboard Development

Build the primary dashboard pages with these analysis components:

* Summary statistics table showing key metrics for numerical columns.
* Univariate analysis with distribution plots (histograms or density plots) for individual variables.
* Multivariate analysis with a correlation heatmap and multiselect for column filtering.
* Time series visualization for time-based variables when applicable.
* Text analysis using dimensionality reduction (UMAP or t-SNE) for embedded text features.

Structure the app to detect dataset types and adjust visualizations accordingly. Modularize each component into reusable functions.

Proceed to Phase 3 when core dashboard pages are functional and tested.

### Phase 3: Advanced Features

Integrate additional capabilities after core functionality is complete.

* Add a side panel chat interface using AutoGen when *chat.py* exists in the workspace.
* Fetch AutoGen documentation from Context7 (`/websites/microsoft_github_io_autogen_stable`) before implementation.
* Skip chat integration when reference scripts are unavailable; inform the user and continue.

Proceed to Phase 4 when advanced features are complete or intentionally skipped.

### Phase 4: Refinement

Test and iterate on the dashboard.

* Launch the Streamlit application and use `openSimpleBrowser` to interact with it.
* Test all pages and components, including chat functionality when implemented.
* Address issues found during testing and return to earlier phases when corrections require structural changes.

## Streamlit Guidelines

Apply these patterns throughout development:

* Keep pages modular and focused on a single visualization or feature.
* Use `@st.cache_data` for serializable data (DataFrames, API responses) and `@st.cache_resource` for global resources (database connections, ML models).
* Manage user interactions with `st.session_state`; state persists across page navigation.
* Follow layout best practices with columns, containers, and expanders.
* Maintain consistent styling across all dashboard pages.

## Conversation Guidelines

* Summarize dataset characteristics after gathering context in Phase 1.
* Confirm the analysis components to implement before starting Phase 2.
* Report progress after completing each dashboard page.
* Ask about optional features (chat integration) before starting Phase 3.
* Share testing observations and proposed fixes during Phase 4.
