---
name: DS Gen Jupyter Notebook
description: 'Create structured exploratory data analysis Jupyter notebooks from available data sources and generated data dictionaries'
---

# Jupyter Notebook Generator

Generate reusable, modular EDA notebooks with parameterized data loading, interactive visualizations, and interpretive markdown placeholders. Notebooks follow a standard section layout and reference (not duplicate) existing data dictionaries.

## Required Phases

### Phase 1: Context Gathering

Collect information about available data before generating notebook cells.

Actions:

1. Inspect data dictionary outputs in `outputs/` (for example, `data-dictionary-*.md`, `data-summary-*.md`).
2. Identify dataset locations in `data/` and determine relative paths from `notebooks/`.
3. Catalog primary entities, variable types (numeric, categorical, datetime, boolean), and potential join keys or time indices.

Proceed to Phase 2 after confirming data sources and structure with the user.

### Phase 2: Notebook Generation

Generate notebook cells following the Notebook Section Layout. Apply the Visualizations Guidance and Data Handling Constraints throughout.

Proceed to Phase 3 after generating all required sections.

### Phase 3: Validation

Review the generated notebook against the Completion Criteria. Install missing dependencies via `uv add`. Return to Phase 2 if corrections are needed.

## Notebook Section Layout

Generate sections in this order:

1. Title & Overview
2. Data Assets Summary (derived from dictionaries; no raw data dump)
3. Configuration & Imports
4. Data Loading (parameterized paths; small samples if needed)
5. Data Quality & Structure Checks (shape, dtypes, missing overview)
6. Univariate Distributions
   * Numeric: histograms, KDE, boxplots, violin
   * Categorical: count plots, bar charts (top-N if high cardinality)
7. Multivariate Relationships
   * Scatter and pair plots (sample if large)
   * Correlation matrix (filtered to numeric)
   * Grouped statistics and aggregation examples
   * Conditional density or boxplots faceted by categorical variables
8. Temporal Trends (include only if datetime fields exist)
   * Line plots with rolling means
   * Seasonal decomposition placeholder (optional)
9. Feature Interactions & Faceting
   * Multi-facet grid examples
10. Outliers & Anomalies (IQR, z-score, or rolling deviation examples)
11. Derived Features (placeholder for engineered columns and transformations)
12. Summary Insights & Hypotheses (markdown placeholders)
13. Next Steps & Further Discovery (markdown checklist)

## Visualizations Guidance

Primary library: Plotly Express for interactive visualizations. Use seaborn or matplotlib only when a plot type is not easily expressed in Plotly.

Principles:

* One concept per cell with code under 15 logical lines.
* Precede each plot with a markdown rationale explaining what question the plot answers.
* Use semantic figure variable names (for example, `fig_corr`, `fig_room_energy`).
* Apply consistent theming and axis labeling without unexplained abbreviations.
* Use transparency (`opacity`) and sampling for dense scatter plots.
* Add trend lines (`trendline='ols'`) where relationship strength is informative.

Standard pattern:

```python
fig = px.bar(df_grouped, x='room', y='count', color='room', title='Records by Room')
fig.update_layout(xaxis_title='Room', yaxis_title='Count')
fig.show()
```

Plot type guidance:

| Goal                       | Function                                   | Notes                              |
|----------------------------|--------------------------------------------|------------------------------------|
| Distribution (numeric)     | `px.histogram` with `marginal='box'`       | Use `nbins` heuristic (sqrt(n))    |
| Distribution (categorical) | `px.bar` on value_counts                   | Top-N if high cardinality          |
| Relationship (2 numeric)   | `px.scatter` with `trendline='ols'`        | Sample if over 50k rows            |
| Correlation overview       | `px.imshow` with `text_auto=True`          | Diverging scale, zmin=-1, zmax=1   |
| Temporal trend             | `px.line` with `markers=True`              | Add rolling mean in separate trace |
| Conditional distribution   | `px.histogram` with `color` or `facet_col` | Keep facet count under 12          |
| Energy or metric heatmap   | `px.imshow`                                | Provide units in colorbar title    |

Faceting: Prefer `facet_col` with `facet_col_wrap` for comparisons across categories.

## Data Handling Constraints

Data loading and display:

* Show `.head()` and `.info()` summarizations instead of printing entire DataFrames.
* Parameterize file paths (for example, `DATA_DIR = Path('data')`).
* Add lightweight caching or sampling for large datasets.
* Use explicit dtype coercion where helpful (for example, parse dates).

Data persistence:

* Persist curated or derived datasets to `data/processed/` in columnar format (`.parquet`).
* Use semantic, lowercase, hyphenated filenames: `<entity>-<scope>-<transform>-v<major>.<minor>.parquet`
* Increment minor version for additive changes; major version for schema changes.

Avoid:

* Copying full data dictionary text; link or summarize instead.
* Hard-coding environment-specific absolute paths.
* Installing packages in the notebook (use `uv add` instead).

## Modularity & Reuse

Encapsulate repetitive transforms into helper functions in a Utilities code cell. Keep logic pure without hidden global side effects.

Include markdown TODO blocks for data limitations, emerging hypotheses, feature engineering ideas, and questions for domain experts.

## Minimum Required Cells

* Overview and context
* Imports and configuration
* Data loading (parameterized)
* Structural summary (shape, dtypes, missingness)
* At least 3 univariate plots
* At least 2 multivariate relationship plots
* Correlation matrix (if 2 or more numeric variables)
* Temporal trend (if datetime present)
* Outlier inspection
* Insights and next steps section

## Generation Guidelines

Cell structure:

* Use separate markdown and code cells (never mix).
* Include explanatory markdown above each visualization.
* Keep cells small and focused on one conceptual action.
* Summarize schema information instead of inlining massive JSON.
* Provide placeholders instead of assumptions when uncertain.

Path resolution (include in Configuration & Imports):

```python
from pathlib import Path

NOTEBOOK_DIR = Path(__file__).resolve().parent if '__file__' in globals() else Path.cwd()
PROJECT_ROOT = NOTEBOOK_DIR.parent
DATA_DIR = PROJECT_ROOT / 'data'
OUTPUTS_DIR = PROJECT_ROOT / 'outputs'
PROCESSED_DIR = DATA_DIR / 'processed'
PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
```

Guard visualization cells with column existence checks to prevent runtime errors when columns are missing.

## Completion Criteria

The notebook runs top-to-bottom without manual edits after file paths are set. Analytical sections are clearly demarcated with safe data loading patterns, modular visualization helpers, and interpretive markdown placeholders referencing existing dictionary artifacts.

After generating, review imports against `pyproject.toml` and install missing dependencies via `uv add`.
