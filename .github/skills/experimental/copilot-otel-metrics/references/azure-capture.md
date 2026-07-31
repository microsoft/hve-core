---
description: "Azure organization capture: the collector-mandatory data path, the Grafana product and cost comparison, and the generated collector, infrastructure, and KQL dashboard templates"
---

# Azure capture: collect and chart a fleet's telemetry

## Intended Use

Read this when the user wants organization telemetry in Azure. It carries the data path and why a collector is not optional, the comparison between the free in-portal Grafana and Azure Managed Grafana with the cost of each, the ingestion cost that sits underneath both, and the contract for every generated template.

## A collector is mandatory

The intuitive picture, where Copilot points at Azure the way it points at a local container, does not work. Copilot's exporter sends a static set of headers configured once. Azure Monitor's OTLP ingestion requires Microsoft Entra credentials that rotate. A static header cannot satisfy a rotating credential, so something in between has to hold the identity.

```text
Copilot (VS Code)  ──OTLP──▶  OpenTelemetry Collector  ──▶  Application Insights  ──▶  Log Analytics  ──▶  Grafana
   static headers              holds the Entra identity        connection string           KQL              dashboards
```

Azure Monitor documents three OTLP ingestion mechanisms and all of them are collector-class. There is no supported direct path. Say this early: a user who has budgeted for "point the endpoint at Azure" needs to know they are also standing up and operating a collector.

The collector is also where the useful controls live: it is the only place to filter attributes before they reach billable storage, and the only place to authenticate a fleet without giving every workstation an Azure identity.

## The credential is the security decision

Whatever channel distributes the collector configuration puts a **shared write-side secret on every workstation**. There is no per-user binding and no documented in-place rotation.

The blast radius is write-side only, which is narrower than a data breach. It is not nothing:

* Anyone holding it can inject fabricated telemetry, so dashboards can be made to say whatever the holder wants.
* Anyone holding it can inflate ingestion volume, and ingestion is billed.
* Revoking it means re-distributing to the whole fleet, which is a fleet-wide operation rather than a per-user one.

Say this before generating anything. It is a decision an organization should make on purpose. Never write the ingestion key or connection string into a generated file, a repository, or the conversation; leave it as a named input the operator supplies at deploy time from a secret store.

## Which Grafana

Two products. Default to the free one.

**Azure Monitor dashboards with Grafana** delivers Grafana dashboards inside the Azure portal at no cost and with no configuration. Microsoft's own comparison states it should be your first choice when you only want to use Azure Monitor data, which is exactly this scenario. It is also the ARM- and Bicep-deployable option: dashboards are native Azure resources of type `Microsoft.Dashboard/dashboards`, and the portal can export an existing dashboard as an ARM template.

**Azure Managed Grafana** is a fully managed Grafana with its own web interface. Recommend it only when one of its triggers actually applies:

* External or open-source data sources beyond Azure Monitor, Azure Managed Prometheus, and Azure Resource Graph.
* Grafana alerting or email notification.
* Scheduled reports.
* Sharing dashboard access without sharing access to the underlying data store. The free option authenticates data sources as the current user only, so a viewer needs their own data access.
* Private networking, deterministic outbound IP, or Grafana Enterprise plugins.

The free option does not support alerts, reports, library panels, snapshots, playlists, or app plugins. Those absences are the honest reason to upgrade, not the price.

Never quote a price. Rates move, and a stale figure carried in a skill is worse than no figure. State the shape instead: the free option costs nothing, and Azure Managed Grafana bills a per-instance rate plus a per-active-user charge, so its cost scales with how many people get access. Send the user to the [Azure Managed Grafana pricing page](https://azure.microsoft.com/pricing/details/managed-grafana/) for the product and the [Azure Monitor pricing page](https://azure.microsoft.com/pricing/details/monitor/) for ingestion, and let them price it against their own region and tenant.

A user who starts free is not stuck. A saved dashboard can be copied into an Azure Managed Grafana instance later from the portal.

## Free Grafana does not mean free telemetry

State this next to the recommendation, every time. The Grafana surface is free; **the data underneath it is not**. Azure Monitor and Log Analytics bill on data ingested and retained, and that bill is driven by how much Copilot sends.

`captureContent` is the dominant multiplier. Turning it on puts prompt text, response text, system instructions, and tool arguments onto spans, which changes span size by orders of magnitude rather than percentages. For a fleet, that is the difference between a modest bill and a surprising one, and it is also the setting with the largest privacy consequence. Recommend `captureContent: false` with `lockCaptureContent: true` for organization capture, and let a team opt in deliberately if they have a reason.

Two other levers worth naming: filter attributes at the collector before they reach ingestion, and set retention deliberately rather than accepting the default.

## The Copilot Metrics API is a complement, not a substitute

Users asking for "org metrics" often mean the GitHub Copilot Metrics API. It returns signed links to daily aggregate report files. There are no spans, no per-tool counts, no token figures, and no latency. It answers "how much is the organization using Copilot" and cannot answer "which tools are slow" or "where are tokens going."

Both are useful and they are not interchangeable. If the user's actual question is seat-level adoption, the API is the cheaper answer and this whole pipeline is unnecessary.

## Generated templates

Everything under `examples/azure/` is a template to copy, adapt, and deploy. The agent writes them; the user runs them, under the execution boundary in `SKILL.md`.

| Artifact                                               | Produces                                                                                        |
|--------------------------------------------------------|-------------------------------------------------------------------------------------------------|
| `otel-collector-config.yaml`                           | Collector pipeline exporting to Application Insights                                            |
| `main.bicep`                                           | Log Analytics workspace, Application Insights, and a `Microsoft.Dashboard/dashboards` dashboard |
| `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf` | The same resources via the AzureRM and AzAPI providers                                          |
| `deploy.sh`                                            | The Azure CLI equivalent, for operators who do not want an IaC toolchain                        |

Every one of them requires values the agent must not invent. Ask for subscription, region, and naming before generating anything, per the stop rule in `SKILL.md`. Values the user cannot supply yet stay as named parameters with no default, and are named back to the user as outstanding:

* Subscription and tenant.
* Region, which must be consistent across the resource group and the dashboard.
* Resource naming, which usually follows an existing organizational convention.
* The RBAC principal that will hold `Monitoring Reader`, and `Monitoring Data Reader` when Prometheus data is involved.
* Retention, which is a cost decision rather than a default.

Verify every API version and provider version against current documentation at generation time. Do not reuse a version because a template already contains it.

**Terraform.** State that `backend.tf` is intentionally absent: remote state configuration belongs to the consuming repository, not to a generated template. Note that dashboards need the separate Grafana provider if the user targets Azure Managed Grafana; the free in-portal dashboards deploy through AzureRM or AzAPI as ordinary Azure resources.

**Bicep.** The free in-portal dashboard is deployable; Azure Managed Grafana dashboards are not. That asymmetry is a real reason to prefer the free option when infrastructure-as-code matters.

**Azure CLI.** `az monitor account` is generally available and creates an Azure Monitor workspace. The generated script needs the `application-insights` CLI extension and checks for it rather than installing it, because installing an extension mutates the operator's CLI. Azure Managed Grafana commands need the separate `amg` extension.

## The Azure dashboard

The Azure dashboard is a separate deliverable from the local one and shares nothing with it. Local queries Prometheus in PromQL; Azure queries Log Analytics in KQL. Panels do not port between them.

* **Datasource:** Azure Monitor, pointed at the Log Analytics workspace backing the Application Insights resource.
* **Minimum Grafana version:** 10.0. The bundled Azure Monitor datasource plugin is present in both products.
* **Tables:** Copilot spans land as `dependencies` and `requests`, with custom attributes under `customDimensions`. Every generated KQL query names the table and the fields it reads so the user can check it against their own workspace.

Seed from `examples/dashboards/copilot-otel-azure.json`.

Microsoft publishes a prebuilt Copilot dashboard for Azure Managed Grafana at `aka.ms/amg/dash/gh-copilot`. Offer it as an alternative rather than a basis: its contents were never verified during this skill's research, so do not describe it as equivalent to the generated one or claim which panels it contains.

Do not assert that Copilot emits exponential histograms. Application Insights dashboards that depend on them need that confirmed first, and it has not been.

## Links

* [Visualize Azure Monitor data with Grafana](https://learn.microsoft.com/azure/azure-monitor/visualize/visualize-grafana-overview)
* [Use Azure Monitor dashboards with Grafana](https://learn.microsoft.com/azure/azure-monitor/visualize/visualize-use-grafana-dashboards)
* [Azure Managed Grafana overview](https://learn.microsoft.com/azure/managed-grafana/overview)
* [Azure Managed Grafana pricing](https://azure.microsoft.com/pricing/details/managed-grafana/)
* [Azure Monitor pricing](https://azure.microsoft.com/pricing/details/monitor/)
* [az monitor account](https://learn.microsoft.com/cli/azure/monitor/account)

