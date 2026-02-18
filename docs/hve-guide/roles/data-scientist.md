---
title: Data Scientist Guide
description: HVE Core support for data scientists building notebooks, dashboards, data specifications, and analytics workflows
author: Microsoft
ms.date: 2026-02-18
ms.topic: how-to
keywords:
  - data science
  - notebooks
  - dashboards
  - analytics
estimated_reading_time: 10
---

This guide is for you if you analyze data, build Jupyter notebooks, create dashboards, define data specifications, or develop analytics pipelines. Data scientists have focused tooling with 13 addressable assets spanning data exploration, visualization, and pipeline development.

## Recommended Collections

> [!TIP]
> Install the collections that match your workflow:
>
> ```text
> Minimum: @hve-core-installer install data-science
> Full:    @hve-core-installer install data-science rpi
> ```
>
> The `data-science` collection provides notebook generation, dashboard creation, and data specification tools. Adding `rpi` enables research and planning workflows for larger analytics projects.

## What HVE Core Does for You

1. Generates Jupyter notebooks with proper structure, documentation cells, and reproducible analysis patterns
2. Creates Streamlit dashboards from data specifications or requirements
3. Builds and validates data specification documents defining schemas, sources, and transformations
4. Tests generated dashboards for functional correctness
5. Supports research and planning workflows for complex analytics pipelines
6. Manages Python virtual environments with uv for reproducible workflows

## Your Lifecycle Stages

> [!NOTE]
> Data scientists primarily operate in these lifecycle stages:
>
> [Stage 2: Discovery](../lifecycle/discovery.md): Research data sources, explore datasets, investigate patterns
> [Stage 3: Product Definition](../lifecycle/product-definition.md): Define data schemas, sources, and transformation requirements
> [Stage 6: Implementation](../lifecycle/implementation.md): Build notebooks, create dashboards, develop pipelines
> [Stage 7: Review](../lifecycle/review.md): Validate analysis, review data quality, test dashboards
> [Stage 8: Delivery](../lifecycle/delivery.md): Package notebooks, dashboards, and documentation for stakeholders

## Stage Walkthrough

1. Stage 2: Discovery. Use `@task-researcher` to investigate data sources, explore available datasets, and research analytical approaches.
2. Stage 3: Product Definition. Run `@gen-data-spec` to define data schemas, sources, and transformation requirements as structured specification documents.
3. Stage 6: Notebook Development. Generate analysis notebooks with `@gen-jupyter-notebook` and create dashboards with `@gen-streamlit-dashboard`.
4. Stage 7: Validation. Test generated dashboards with `@test-streamlit-dashboard` and review analysis results for accuracy and completeness.
5. Stage 8: Delivery. Package notebooks, dashboards, and documentation for sharing with stakeholders and engineering teams.

## Starter Prompts

```text
@gen-jupyter-notebook Create an analysis notebook for {dataset}
```

```text
@gen-data-spec Define a data specification for {data pipeline}
```

```text
@gen-streamlit-dashboard Build a dashboard for {metrics}
```

```text
@test-streamlit-dashboard Validate the dashboard at {path}
```

```text
@task-researcher Research data sources for {analysis goal}
```

## Key Agents and Workflows

| Agent                    | Purpose                                    | Invoke                      | Docs                                         |
|--------------------------|--------------------------------------------|-----------------------------|----------------------------------------------|
| gen-jupyter-notebook     | Jupyter notebook generation                | `@gen-jupyter-notebook`     | Agent file                                   |
| gen-streamlit-dashboard  | Streamlit dashboard creation               | `@gen-streamlit-dashboard`  | Agent file                                   |
| gen-data-spec            | Data specification document creation       | `@gen-data-spec`            | Agent file                                   |
| test-streamlit-dashboard | Dashboard functional testing               | `@test-streamlit-dashboard` | Agent file                                   |
| task-researcher          | Data source and pattern research           | `@task-researcher`          | [Task Researcher](../rpi/task-researcher.md) |
| task-planner             | Analytics pipeline planning                | `@task-planner`             | [Task Planner](../rpi/task-planner.md)       |
| memory                   | Session context and preference persistence | `@memory`                   | Agent file                                   |

Python environment management follows the `uv` virtual environment instructions for reproducible analysis environments.

## Tips

| Do                                                               | Don't                                                        |
|------------------------------------------------------------------|--------------------------------------------------------------|
| Start with `@gen-data-spec` to define schemas before coding      | Jump straight to notebook coding without data specifications |
| Use `@gen-jupyter-notebook` for structured, documented notebooks | Create raw notebooks without documentation cells             |
| Test dashboards with `@test-streamlit-dashboard`                 | Deploy dashboards without functional validation              |
| Research data sources with `@task-researcher` first              | Assume data availability without investigation               |
| Use `uv` for reproducible Python environments                    | Install packages globally or skip environment isolation      |

## Related Roles

* Data Scientist + Engineer: Analytics pipelines bridge data exploration with production integration. Engineers implement production-grade versions of prototype analyses. See the [Engineer Guide](engineer.md).
* Data Scientist + TPM: Data requirements feed into product specifications. Analytics capabilities shape feature definitions. See the [TPM Guide](tpm.md).

## Next Steps

> [!TIP]
> Explore the data science collection: [Data Science Collection](../../collections/data-science.collection.md)
> Set up your Python environment: [uv Projects](../../.github/instructions/uv-projects.instructions.md)
> See how analytics fits the project lifecycle: [AI-Assisted Project Lifecycle](../lifecycle/)

---

> [!NOTE]
> Model evaluation harness (GAP-09), advanced autoML integration, and MLflow experiment tracking are planned improvements.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
