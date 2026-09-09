---
title: EDA notebook authoring
description: Section sequence, visualization selection thresholds, modularity expectations, and completeness criteria for exploratory data analysis notebooks
---

## Scope

These are HVE Core authoring conventions for exploratory notebooks. They describe editorial judgment: what sections belong, in what order, which figure answers which question, and when scale forces a different treatment. Notebook creation, cell editing, execution, and output inspection are native tool capabilities and are not described here.

Column semantics and profile contracts belong to `data-catalog`. Persistence format and dataset versioning belong to `dataops`.

## Section sequence

Compose an exploratory notebook in this order. Sections marked conditional appear only when the data supports them; an empty conditional section is worse than an absent one.

| Order | Section                                                              | Conditional on                   |
|-------|----------------------------------------------------------------------|----------------------------------|
| 1     | Title and analysis question                                          | Always                           |
| 2     | Data assets summary, referencing profiles rather than restating them | Always                           |
| 3     | Configuration and imports                                            | Always                           |
| 4     | Data loading with parameterized paths                                | Always                           |
| 5     | Structure and quality checks: shape, dtypes, missingness             | Always                           |
| 6     | Univariate distributions                                             | Always                           |
| 7     | Multivariate relationships                                           | Two or more analyzable variables |
| 8     | Temporal trends                                                      | A datetime field exists          |
| 9     | Feature interactions and faceting                                    | A grouping variable exists       |
| 10    | Outliers and anomalies                                               | Numeric variables exist          |
| 11    | Derived features                                                     | Feature engineering is in scope  |
| 12    | Summary insights and hypotheses                                      | Always                           |
| 13    | Next steps and open questions                                        | Always                           |

The sequence moves from what the data is, to what each variable looks like alone, to how variables relate, to what that implies. Reordering breaks the reader's ability to trust a relationship claim before seeing the underlying distributions.

## Visualization selection

Prefer an interactive plotting library so distributions and outliers remain open to inspection. Use a static library only when a plot type is not reasonably expressible in the interactive one.

| Analytical goal                            | Figure type                         | Scale and encoding guidance                                                     |
|--------------------------------------------|-------------------------------------|---------------------------------------------------------------------------------|
| Numeric distribution                       | Histogram with a marginal box       | Choose bin count near the square root of the observation count                  |
| Categorical distribution                   | Bar chart over value counts         | Show top categories and group the remainder when cardinality is high            |
| Relationship between two numeric variables | Scatter with an optional trend line | Sample above roughly fifty thousand points and reduce opacity for dense regions |
| Correlation overview                       | Matrix heatmap                      | Restrict to numeric columns and fix a diverging scale from minus one to one     |
| Temporal trend                             | Line with markers                   | Add a rolling mean as a separate trace rather than smoothing in place           |
| Conditional distribution                   | Histogram split by color or facet   | Keep facet count in the low dozens; beyond that, aggregate instead              |
| Magnitude across two keys                  | Matrix heatmap                      | State units in the color-bar title                                              |

Fixing the correlation scale matters: an auto-scaled correlation matrix visually exaggerates weak relationships, because the color range expands to fill whatever the data happens to contain.

### Color is never the only encoding

Colour carries meaning for readers who can distinguish it. Roughly one in twelve men and one in two hundred women cannot distinguish some colour pairs, and a figure that encodes a distinction in hue alone is unreadable to them. Print and greyscale rendering lose the distinction for everyone.

Encode every meaningful distinction in at least one channel besides colour:

* Categorical series: pair colour with marker shape, line dash pattern, or direct labelling on the series itself.
* Ordered or diverging scales: pair colour with position, size, or an annotated value, and keep the scale monotonic in lightness so it survives greyscale conversion.
* Faceted or split distributions: rely on the facet structure or an explicit label rather than fill colour alone to identify each group.

Select a colourblind-safe qualitative palette for categorical encodings, and a perceptually uniform sequential or diverging scale for continuous ones. Avoid a red-to-green ramp, which is the pairing most commonly confused. When a plotting library's default palette is not colourblind-safe, set the palette explicitly rather than accepting the default.

State the encoding in the axis title, the legend, or the figure caption so the reader knows which channel carries the distinction without inferring it from the colours.

## Composition expectations

* Keep one concept per cell, and keep transformation logic in a cell short enough to read at a glance. Roughly fifteen logical lines is the point at which extraction into a helper is usually warranted.
* Precede each figure with the question it answers, and follow it with an interpretation placeholder or an actual reading. A figure with no stated question is decoration.
* Give figures semantic names that describe their subject rather than their order.
* Label axes and legends without unexplained abbreviations, and keep theming consistent across the notebook.
* Extract repeated transformations into helper functions kept free of hidden global side effects.
* Summarize schema information rather than inlining large structures.
* Guard figure cells against missing columns so a partially available dataset does not halt the run.
* Parameterize paths and avoid environment-specific absolute locations.
* Show structural summaries rather than printing entire frames.

## Completeness criteria

An exploratory notebook is complete when it contains, at minimum:

* The analysis question and dataset context
* Configuration, imports, and parameterized loading
* A structural summary covering shape, types, and missingness
* At least three univariate figures
* At least two multivariate figures
* A correlation view when two or more numeric variables exist
* A temporal view when a datetime field exists
* An outlier inspection
* Written insights, limitations, and next steps

The notebook should run start to finish once paths are configured, without manual cell reordering.

## Recording uncertainty

Write down data limitations, emerging hypotheses, feature ideas, and questions for domain experts as explicit notes inside the notebook. An exploratory notebook whose only output is figures transfers no interpretation to the next reader.
