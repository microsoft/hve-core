---
title: Data Scientist Guide
description: HVE Core support for data scientists building notebooks, dashboards, data specifications, and analytics workflows
sidebar_position: 9
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
> Install the [HVE Core extension](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core) from the VS Code Marketplace to get all stable artifacts with zero configuration.
>
> Your primary collections are `data-science` (notebook generation, dashboard creation, and data specification tools) and `rpi` (research and planning workflows for larger analytics projects). For clone-based setups, use the **hve-core-installer** agent with `install data-science rpi`.

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

1. Stage 2: Discovery. Use the **task-researcher** agent to investigate data sources, explore available datasets, and research analytical approaches.
2. Stage 3: Product Definition. Run the **gen-data-spec** agent to define data schemas, sources, and transformation requirements as structured specification documents.
3. Stage 6: Notebook Development. Generate analysis notebooks with the **gen-jupyter-notebook** agent and create dashboards with the **gen-streamlit-dashboard** agent.
4. Stage 7: Validation. Test generated dashboards with the **test-streamlit-dashboard** agent and review analysis results for accuracy and completeness.
5. Stage 8: Delivery. Package notebooks, dashboards, and documentation for sharing with stakeholders and engineering teams.

## Starter Prompts

Select **gen-jupyter-notebook** agent:

```text
Create a data analysis notebook for the Q4 sales transactions dataset in
data/sales-q4-2025.parquet. Include data quality assessment, revenue trend
analysis by product category and region, and customer cohort segmentation
using RFM scoring with matplotlib visualizations.
```

Select **gen-data-spec** agent:

```text
Define a data specification for the customer event ingestion pipeline.
Source is a Kafka topic with Avro encoding, target is a Delta Lake table.
Include timestamp normalization, PII hashing transformations, quality
rules for null checks, and partitioning by event_date and event_type.
```

Select **gen-streamlit-dashboard** agent:

```text
Build a dashboard for API latency and error rate metrics from the
Prometheus endpoint at /metrics. Include P50/P95/P99 latency percentiles,
error rate breakdown by endpoint (5xx vs 4xx), and a 30-day daily active
users trend. Set refresh interval to 5 minutes.
```

Select **test-streamlit-dashboard** agent:

```text
Validate the dashboard at dashboards/api-performance.json. Check that all
queries return data for the last 7 days, panels render without errors, and
the refresh rate does not exceed Prometheus scrape intervals.
```

Select **task-researcher** agent:

```text
Research data sources for predicting customer churn in the SaaS platform.
Identify internal sources like usage telemetry and billing history,
external benchmark datasets, data freshness requirements for daily
granularity, and GDPR privacy constraints for EU customer data.
```

## Key Agents and Workflows

| Agent                        | Purpose                                    | Docs                                            |
|------------------------------|--------------------------------------------|-------------------------------------------------|
| **gen-jupyter-notebook**     | Jupyter notebook generation                | Agent file                                      |
| **gen-streamlit-dashboard**  | Streamlit dashboard creation               | Agent file                                      |
| **gen-data-spec**            | Data specification document creation       | Agent file                                      |
| **test-streamlit-dashboard** | Dashboard functional testing               | Agent file                                      |
| **task-researcher**          | Data source and pattern research           | [Task Researcher](../../rpi/task-researcher.md) |
| **task-planner**             | Analytics pipeline planning                | [Task Planner](../../rpi/task-planner.md)       |
| **memory**                   | Session context and preference persistence | Agent file                                      |

Prompts complement the agents for cross-cutting workflows:

| Prompt       | Purpose                                                       | Invoke          |
|--------------|---------------------------------------------------------------|-----------------|
| git-commit   | Stage and commit changes with conventional message formatting | `/git-commit`   |
| pull-request | Create a pull request with structured description             | `/pull-request` |

Python environment management follows the `uv` virtual environment instructions for reproducible analysis environments.

## Tips

| Do                                                                          | Don't                                                        |
|-----------------------------------------------------------------------------|--------------------------------------------------------------|
| Start with the **gen-data-spec** agent to define schemas before coding      | Jump straight to notebook coding without data specifications |
| Use the **gen-jupyter-notebook** agent for structured, documented notebooks | Create raw notebooks without documentation cells             |
| Test dashboards with the **test-streamlit-dashboard** agent                 | Deploy dashboards without functional validation              |
| Research data sources with the **task-researcher** agent first              | Assume data availability without investigation               |
| Use `uv` for reproducible Python environments                               | Install packages globally or skip environment isolation      |

## Related Roles

* Data Scientist + Engineer: Analytics pipelines bridge data exploration with production integration. Engineers implement production-grade versions of prototype analyses. See the [Engineer Guide](engineer.md).
* Data Scientist + TPM: Data requirements feed into product specifications. Analytics capabilities shape feature definitions. See the [TPM Guide](tpm.md).

## Next Steps

> [!TIP]
> Explore the data science collection: [Data Science Collection](https://github.com/microsoft/hve-core/blob/main/collections/data-science.collection.md)
> Set up your Python environment: [uv Projects](https://github.com/microsoft/hve-core/blob/main/.github/instructions/coding-standards/uv-projects.instructions.md)
> See how analytics fits the project lifecycle: [AI-Assisted Project Lifecycle](../lifecycle/)

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
