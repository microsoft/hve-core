---
title: Azure Capture Templates
description: Collector configuration, Bicep, Terraform, and Azure CLI templates for collecting GitHub Copilot fleet telemetry into Azure
author: Microsoft
ms.date: 2026-07-27
ms.topic: reference
keywords:
  - opentelemetry
  - copilot
  - azure
  - bicep
  - terraform
estimated_reading_time: 4
---

## What is here

Templates to copy, adapt, and deploy yourself. Nothing here runs automatically, and the skill will not run any of it for you. Each one creates billable Azure resources.

| File                         | Deploys                                                                 |
|------------------------------|-------------------------------------------------------------------------|
| `otel-collector-config.yaml` | Collector pipeline receiving OTLP and exporting to Application Insights |
| `main.bicep`                 | Log Analytics workspace, Application Insights, Azure Monitor dashboard  |
| `main.tf` and friends        | The same resources through Terraform                                    |
| `deploy.sh`                  | The same resources through the Azure CLI                                |

Pick one deployment path. They are three routes to the same result, not three stages.

## Before you deploy

Read `references/azure-capture.md` in the skill root first. Three things there change how you should approach this:

* A collector is mandatory. Copilot cannot export to Azure Monitor directly, because it sends static headers and Azure Monitor requires rotating Entra credentials.
* The connection string is a fleet-wide write credential. Every workstation gets the same value, and there is no documented in-place rotation.
* The Grafana surface is free; the data underneath it is not. `captureContent` is the dominant cost multiplier and the dominant privacy exposure.

## Values you must supply

None of these have safe defaults, so all of them are required inputs:

* Subscription and tenant.
* Region. The dashboard must sit in the same region as the workspace.
* Resource naming, which usually follows an existing organizational convention.
* The principal that will hold `Monitoring Reader` on the workspace.
* Retention and the daily ingestion cap, which are cost decisions.

## Prerequisites

`deploy.sh` needs the `application-insights` CLI extension. It checks and exits rather than installing it for you:

```bash
az extension add --name application-insights
```

Azure Managed Grafana, if you decide its triggers apply, needs `az extension add --name amg`.

## Deploying

```bash
# Bicep
az deployment group create -g <resource-group> -f main.bicep -p namePrefix=<prefix>

# Terraform
terraform init
terraform plan  -var name_prefix=<prefix> -var resource_group_name=<rg> -var location=<region>
terraform apply -var name_prefix=<prefix> -var resource_group_name=<rg> -var location=<region>

# Azure CLI
RESOURCE_GROUP=<rg> LOCATION=<region> NAME_PREFIX=<prefix> ./deploy.sh
```

`backend.tf` is intentionally absent from the Terraform configuration. Remote state belongs to the repository that consumes these files, not to the template.

## After you deploy

1. Retrieve the Application Insights connection string and put it in a secret store. Do not commit it.
2. Run the collector somewhere the fleet can reach, with `APPLICATIONINSIGHTS_CONNECTION_STRING` supplied from that secret store. Where it runs is your platform decision; Container Apps, AKS, and a VM behind a load balancer all work.
3. Distribute the endpoint through Copilot managed settings. See `references/org-distribution.md`.
4. Import `../dashboards/copilot-otel-azure.json` into Azure Monitor dashboards with Grafana and set the workspace variable to your Log Analytics resource ID. The templates provision the dashboard resource empty; this import is what fills it.
5. Confirm data landed by querying Log Analytics, not by checking that the collector reports success.

## API versions

`Microsoft.Dashboard/dashboards@2025-08-01` was verified current on 2026-07-27. The other API and provider versions in these files were not verified in that session. Check before deploying:

```bash
az provider show -n Microsoft.OperationalInsights \
  --query "resourceTypes[?resourceType=='workspaces'].apiVersions" -o tsv | head
```

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
