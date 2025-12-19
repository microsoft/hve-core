---
description: 'Create a structured exploratory data analysis Jupyter notebook leveraging available data sources & generated data dictionaries WITHOUT directly embedding raw data dumps.'
tools: ['runCommands', 'runTasks', 'edit', 'runNotebooks', 'search', 'new', 'extensions', 'usages', 'vscodeAPI', 'think', 'problems', 'changes', 'testFailure', 'openSimpleBrowser', 'githubRepo', 'todos', 'github.vscode-pull-request-github/copilotCodingAgent', 'github.vscode-pull-request-github/activePullRequest', 'getPythonEnvironmentInfo', 'getPythonExecutableCommand', 'installPythonPackage', 'configurePythonEnvironment', 'configureNotebook', 'listNotebookPackages', 'installNotebookPackages']
---

# Jupyter Notebook Generator

## Purpose

Generate a reusable, modular exploratory data analysis (EDA) notebook that:

1. Reads available data sources and summarizes key summary statistics and distributions.
2. Encourages clean, parameterized data loading cells separated from visualization logic.
3. Provides clearly labeled sections for univariate, multivariate, temporal, and categorical facet analyses.
4. Leaves intentional markdown placeholders for interpretation, insights, hypotheses, and follow-up questions.

## First Steps (Context Gathering Only)

Before writing any code cells:

1. Inspect file names & data dictionary outputs in `outputs/` (e.g. `data-dictionary-*.md`, `data-summary-*.md`, `data-profile-*.json`).
2. Identify where the main dataset(s) live (e.g. `data/` folder), and properly specify the relative paths to load them (assume notebook lives under `notebooks/`, in the same directory as `data`, so you will need to access them from a directory above, i.e., `../data/`).
3. Identify:

* Primary entities (tables/files)
* Key variable types (numeric, categorical, datetime, boolean)
* Potential join keys or time indices

## Notebook Section Layout (Required Order)

1. Title & Overview
2. Data Assets Summary (derived from dictionaries & summaries; no raw data dump)
3. Configuration & Imports
4. Data Loading (parameterized paths; small samples if needed)
5. Data Quality & Structure Checks (shape, dtypes, missing overview)
6. Univariate Distributions

* Numeric: histograms, KDE, boxplots, violin (where relevant)
* Categorical: count plots / bar charts (top-N if high cardinality)

1. Multivariate Relationships

* Scatter / pair plots (sample if large)
* Correlation matrix (filtered to numeric, optionally masked)
* Grouped statistics (aggregation examples)
* Conditional density or boxplots faceted by key categorical variables

1. Time Series / Temporal Trends (include ONLY if datetime fields exist)

* Line plots with rolling means
* Seasonal decomposition placeholder (optional)

1. Feature Interactions / Faceting

* Multi-facet grid examples (e.g. seaborn FacetGrid)

1. Outliers & Anomalies (IQR / z-score / rolling deviation examples)
1. Derived Features (placeholder: engineered columns, transformations)
1. Summary Insights & Hypotheses (markdown placeholders)
1. Next Steps / Further Discovery (markdown checklist)

## Visualizations Guidance (Plotly-First)

Primary visualization library: Plotly Express (interactive, concise). Use seaborn/matplotlib only when:

1. A plot type is not easily expressed in Plotly (e.g., complex statistical diagnostic)
2. You need layered customization not yet required in Plotly

**Note**: you will need to also install `nbformat`: `uv add nbformat`

Principles:

* One concept per cell (keep code under ~15 logical lines)
* Always precede with a markdown rationale: what question the plot answers
* Favor wide-form → tidy transforms explicitly (show minimal reshaping steps)
* Prefer readable, semantic figure variable names (e.g., `fig_corr`, `fig_room_energy`)
* Apply consistent theming & axis labeling; no unexplained abbreviations
* Use transparency (`opacity`) & sampling for dense scatter plots
* Add trend lines (`trendline='ols'`) where relationship strength is informative

Standard Plotly Express Pattern:

```python
fig = px.bar(df_grouped, x='room', y='count', color='room', title='Records by Room')
fig.update_layout(xaxis_title='Room', yaxis_title='Count')
fig.show()
```

Heatmaps:

* Use `px.imshow` for pivoted matrices (e.g., energy vs hour vs room)
* Provide color scale rationale in markdown (e.g., sequential for magnitude, diverging for signed correlations)

Faceting:

* Prefer `facet_col` (wrapped) for comparisons across categories ≤ 12
* Use `facet_col_wrap` to avoid horizontal scrolling

Correlation:

1. Filter numeric columns
2. Compute `corr()`
3. Use `px.imshow(corr_df, text_auto=True)` with `zmin=-1, zmax=1` and diverging scale

Time Series:

* Derive temporal features (hour, day_of_week) in a dedicated preprocessing cell
* Use lines with markers for aggregated series; show range (min/max) only if narratively useful

Multivariate Density / Distribution:

* Use histogram with `marginal='box'` or `marginal='violin'` instead of separate plots when appropriate

3D / High-dimensional:

* Restrict 3D scatter usage to compelling multi-axis tradeoff illustration (e.g., temperature vs humidity vs energy)
* Avoid gratuitous 3D if 2D suffices

Outliers:

* Use box/violin marginal options or dedicated filtered scatter
* Consider IQR-based filtering demonstration (explanatory, not destructive)

Artifact Plots:

* If derived features created, add a clearly separated subsection: "Derived Feature Validation"

Markdown Rationale Template (preceding each plot):

```markdown
**Question:** What varies across rooms?
**Approach:** Count records per room using aggregated bar chart.
**Expectation:** Kitchen & living areas dominate volume.
```

### Recommended Plot Templates (Plotly Express)

| Goal                        | Plot Type / Function                        | Notes                              |
|-----------------------------|---------------------------------------------|------------------------------------|
| Distribution (numeric)      | `px.histogram` (marginal='box')             | Add `nbins` heuristic (sqrt(n))    |
| Distribution (categorical)  | `px.bar` on value_counts reset_index        | Top-N if high cardinality          |
| Spread & outliers           | `px.box` or histogram with marginal         | Avoid overlapping swarm clutter    |
| Relationship (2 numeric)    | `px.scatter` (trendline='ols', opacity=0.3) | Sample if >50k rows                |
| Correlation overview        | `px.imshow`                                 | Diverging scale, show text         |
| Temporal trend              | `px.line` (markers=True)                    | Add rolling mean in separate trace |
| Conditional distribution    | `px.histogram` with `color` or `facet_col`  | Keep facet count ≤ 12              |
| High-dimensional snapshot   | `px.scatter_3d`                             | Only if clear added insight        |
| Categorical vs numeric grid | `px.box` faceted                            | Uniform y-axis scaling             |
| Energy/metric heatmap       | `px.imshow`                                 | Provide units in colorbar title    |

## Dependency & Environment Policy

If you need packages:

1. Add them via project dependency management, e.g.:

```bash
uv add pandas seaborn plotly
```

1. Never install ad hoc within the notebook (no !pip, no %pip).

## Data Handling Constraints

Must:

* Avoid printing entire DataFrames (show `.head()`, `.info()` summarizations only)
* Parameterize file paths (e.g., `DATA_DIR = Path('data')`)
* Add lightweight caching or sampling if dataset is large
* Persist any curated/derived interim datasets into `data/processed/` with semantic, lowercase, hyphenated filenames
Should:
* Use explicit dtype coercion where helpful (e.g. parse dates)
Should NOT:
* Copy full data dictionary text; link or summarize
* Hard-code environment-specific absolute paths

### Processed Data Persistence Policy

Directory: `data/processed/`

Filename pattern (semantic, components optional where not applicable):

```text
<entity>-<scope>-<transform>-v<major>.<minor>.parquet
```

Examples:

```text
events-cleaned-dtypes-v1.0.parquet
sensor-readings-hourly-aggregated-v1.0.parquet
users-features-encoded-v2.1.parquet
```

Rules:

1. Always write in columnar format (`.parquet`) unless justified otherwise.
2. Increment minor version for non-breaking additive changes; major for schema-altering changes.
3. Include a lightweight metadata registry (Python dict) accumulating entries for each artifact (path, rows, cols, schema hash, creation timestamp, brief description).
4. At notebook end, render a markdown table summarizing all processed artifacts.
5. Never overwrite without version bump; if re-running same logic, detect existing version and either reuse or increment.

Suggested helper for registry (add to Utilities section):

```python
from dataclasses import dataclass, asdict
from typing import List, Dict, Any
import hashlib, json, time

@dataclass(frozen=True)
class ArtifactRecord:
 name: str
 path: str
 rows: int
 cols: int
 schema_hash: str
 created_utc: float
 description: str

artifact_registry: List[ArtifactRecord] = []

def register_artifact(df, path: str, description: str) -> None:
 schema_sig = hashlib.sha256(json.dumps(sorted(df.dtypes.astype(str).to_dict().items())).encode()).hexdigest()[:12]
 artifact_registry.append(
  ArtifactRecord(
   name=path.split('/')[-1],
   path=path,
   rows=len(df),
   cols=df.shape[1],
   schema_hash=schema_sig,
   created_utc=time.time(),
   description=description,
  )
 )
```

Final section should convert registry to markdown table:

```python
import pandas as pd
if artifact_registry:
 display(pd.DataFrame([asdict(a) for a in artifact_registry]))
```

## Modularity & Reuse

Encapsulate repetitive transforms into small helper functions in a "Utilities" code cell (e.g., `def plot_hist(df, col, bins=30): ...`). Keep logic pure (no hidden global side effects).

## Placeholders to Include

Add markdown TODO blocks for:

* Data limitations
* Emerging hypotheses
* Potential feature engineering ideas
* Questions for domain experts

## Minimum Required Cells (Checklist)

* [ ] Overview & context
* [ ] Imports & configuration
* [ ] Data loading (lazy / parameterized)
* [ ] Structural summary (shape, dtypes, missingness)
* [ ] At least 3 univariate plots
* [ ] At least 2 multivariate relationship plots
* [ ] Correlation matrix (if >=2 numeric vars)
* [ ] Temporal trend (if datetime present)
* [ ] Outlier inspection
* [ ] Insights & next steps section
* [ ] Processed artifacts registry & summary table

## Quality Bar

Notebook should run top-to-bottom without manual edits after user sets file paths. All visualization cells must be guarded (e.g., check column existence before plotting) to avoid runtime errors if a column is missing.

## Generation Instructions

When generating the notebook JSON:

1. Use separate markdown + code cells (never mix).
2. Include explanatory markdown above each visualization.
3. Keep cells small & focused (one conceptual action each).
4. Do NOT inline massive schema JSON; summarize counts, types.
5. Provide placeholders instead of assumptions when uncertain.
6. Assume the notebook lives under `notebooks/` while raw data lives one directory up in `data/` and outputs in `outputs/`.

### Path Resolution & Directory Setup

In the notebook, resolve paths robustly so relative execution from `notebooks/` works:

```python
from pathlib import Path
NOTEBOOK_DIR = Path(__file__).resolve().parent if '__file__' in globals() else Path.cwd()
PROJECT_ROOT = NOTEBOOK_DIR.parent  # assumes standard layout
DATA_DIR = PROJECT_ROOT / 'data'
OUTPUTS_DIR = PROJECT_ROOT / 'outputs'
PROCESSED_DIR = DATA_DIR / 'processed'
PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
```

Use `DATA_DIR / 'home_assistant_data.csv'` style joins; never hard-code absolute OS-specific paths.

When persisting artifacts, build paths with:

```python
artifact_path = PROCESSED_DIR / filename  # filename produced per naming convention
```

Before reading, validate existence:

```python
assert DATA_DIR.exists(), f"Data directory missing: {DATA_DIR}"
```

Add a lightweight helper to safely load with optional sampling:

```python
def load_csv(path: Path, nrows: int | None = None, parse_dates: list[str] | None = None):
 import pandas as pd
 return pd.read_csv(path, nrows=nrows, parse_dates=parse_dates)
```

## Extension Hooks (Optional)

Leave commented placeholders for advanced sections (e.g., PCA, clustering) but do not implement unless requested.

## Completion Criteria

The produced notebook provides a ready-to-run scaffold with clearly demarcated analytical sections, safe data loading patterns, modular visualization helpers, and interpretive markdown placeholders referencing (not duplicating) existing dictionary artifacts.

## Notebook Dependencies

Review the notebook for any library imports after generating the notebook. If there are any new library usages (review the pyproject.toml file), use the `uv add` command to add it to the project dependencies. For example, to add pandas and seaborn, run:

```bash
uv add pandas seaborn
```

Never install packages directly in the notebook.

## Data Transforms & Analytical Flow

Follow this flow pattern in code cells:

1. Load (or sample) data
2. Validate structure
3. Univariate exploration
4. Multivariate / faceted exploration
5. Temporal (if applicable)
6. Derived features (optional placeholder)
7. Insights & questions

Guard each analytic code block with presence checks, e.g.:

```python
if {'temperature','humidity'} <= set(df.columns):
 sns.scatterplot(data=df, x='temperature', y='humidity')
```

Keep transformation functions pure & reusable.
