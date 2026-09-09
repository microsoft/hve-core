---
title: Data Scientist Guide
description: HVE Core support for data scientists building notebooks, dashboards, data specifications, and analytics workflows
sidebar_position: 9
author: Microsoft
ms.date: 2026-08-03
ms.topic: how-to
keywords:
  - data science
  - notebooks
  - dashboards
  - analytics
estimated_reading_time: 10
---

This guide is for you if you analyze data, build Jupyter notebooks, create dashboards, define data specifications, or develop analytics pipelines. Data scientists have focused tooling with 13 addressable assets spanning data exploration, visualization, and pipeline development.

## Capability Groups

> [!TIP]
> Install the [HVE Core extension](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core) from the VS Code Marketplace for the complete active component set with zero configuration.
>
> For selective clone adoption, choose notebook generation, dashboard, data specification, Python environment, and research components that match your analytics workflow. Capability groups help you discover related components; they are not independently installable products. See the [Installation Guide](../../getting-started/install.md).

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

1. Stage 2: Discovery. Use `/rpi-research` to investigate data sources, explore available datasets, and research analytical approaches.
2. Stage 3: Product Definition. Select the **Data Science and Engineering Coach** and confirm the catalog job to define entities, relationships, and dataset profiles as a durable catalog.
3. Stage 6: Notebook Development. Confirm the analysis job to produce notebooks and dashboards, and the pipeline job to produce transformation and validation code.
4. Stage 7: Validation. Confirm the testing job for dashboard and pipeline validation, and the evaluation job when an AI system needs an evaluation dataset.
5. Stage 8: Delivery. Package notebooks, dashboards, and documentation for sharing with stakeholders and engineering teams.

## Starter Prompts

Select the **Data Science and Engineering Coach** agent and confirm the analysis job:

```text
Create a data analysis notebook for the Q4 sales transactions dataset in
data/sales-q4-2025.parquet. Include data quality assessment, revenue trend
analysis by product category and region, and customer cohort segmentation
using RFM scoring.
```

Select the **Data Science and Engineering Coach** agent and confirm the catalog job:

```text
Catalog the customer event ingestion pipeline. Source is a Kafka topic with
Avro encoding, target is a Delta Lake table. Capture entities, relationships,
sensitivity classification, and a dataset profile covering timestamp
normalization and null-check quality rules.
```

Select the **Data Science and Engineering Coach** agent and confirm the analysis job for a dashboard:

```text
Build a dashboard for API latency and error rate metrics from the
Prometheus endpoint at /metrics. Include P50/P95/P99 latency percentiles,
error rate breakdown by endpoint (5xx vs 4xx), and a 30-day daily active
users trend.
```

Select the **Data Science and Engineering Coach** agent and confirm the evaluation job:

```text
Build an evaluation dataset for our grounded support assistant. It answers
from the product knowledge base, calls a ticket-lookup tool, and must refuse
account changes. We evaluate in batch before each release.
```

Use `/rpi-research`:

```text
Research data sources for predicting customer churn in the SaaS platform.
Identify internal sources like usage telemetry and billing history,
external benchmark datasets, data freshness requirements for daily
granularity, and GDPR privacy constraints for EU customer data.
```

## Key Agents and Workflows

| Agent or skill                         | Purpose                                                          | Docs                       |
|----------------------------------------|------------------------------------------------------------------|----------------------------|
| **Data Science and Engineering Coach** | Persistent data science and engineering coaching and job routing | Agent file                 |
| **analysis-authoring**                 | Notebook and dashboard authoring and validation                  | Skill file                 |
| **data-catalog**                       | Catalog entities, relationships, and profiles                    | Skill file                 |
| **dataops**                            | Pipeline invariants, validation, and testing                     | Skill file                 |
| **evaluation-design**                  | AI-system evaluation dataset design                              | Skill file                 |
| **rpi-research**                       | Data source and pattern research                                 | [RPI workflow](../../rpi/) |
| **rpi-plan**                           | Analytics pipeline planning                                      | [RPI workflow](../../rpi/) |

Prompts complement the agents for cross-cutting workflows:

| Prompt       | Purpose                                                       | Invoke          |
|--------------|---------------------------------------------------------------|-----------------|
| git-commit   | Stage and commit changes with conventional message formatting | `/git-commit`   |
| pull-request | Create a pull request with structured description             | `/pull-request` |

Python environment management follows the `uv` virtual environment instructions for reproducible analysis environments.

## Tips

| Do                                                       | Don't                                                       |
|----------------------------------------------------------|-------------------------------------------------------------|
| Confirm the catalog job to define entities before coding | Jump straight to notebook coding without data understanding |
| Let the coach route analysis work to its owning skill    | Create raw notebooks without documentation cells            |
| Confirm the testing job before shipping a dashboard      | Deploy dashboards without functional validation             |
| Research data sources with `/rpi-research` first         | Assume data availability without investigation              |
| Use `uv` for reproducible Python environments            | Install packages globally or skip environment isolation     |

## Related Roles

* Data Scientist + Engineer: Analytics pipelines bridge data exploration with production integration. Engineers implement production-grade versions of prototype analyses. See the [Engineer Guide](engineer.md).
* Data Scientist + TPM: Data requirements feed into product specifications. Analytics capabilities shape feature definitions. See the [TPM Guide](tpm.md).

## Next Steps

> [!TIP]
> Browse the complete HVE Core inventory: [HVE Core](../../plugins/hve-core)
> Set up your Python environment: [uv Projects](https://github.com/microsoft/hve-core/blob/main/.github/instructions/coding-standards/uv-projects.instructions.md)
> See how analytics fits the project lifecycle: [AI-Assisted Project Lifecycle](../lifecycle/)

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
