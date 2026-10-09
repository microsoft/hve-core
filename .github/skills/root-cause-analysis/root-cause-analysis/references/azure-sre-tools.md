---
description: Azure SRE host detection signals and read-only tool catalog for the root-cause-analysis skill
---

# Azure SRE Tool Catalog

Read this reference only after `root-cause-analysis` selects Azure SRE mode. Tool names describe
host capabilities; they do not grant access, change approval boundaries, or require an unrelated
tool call.

## Detection

Follow the fail-closed host-mode detection rule in `root-cause-analysis/SKILL.md`. This reference
does not define additional detection signals.

## Allowlist Provenance

The package maintainers preselected these tools as reasonably suitable for RCA evidence collection.
This catalog is a reviewed allowlist, not a declaration that every listed tool is safe to invoke
automatically in every incident.

* Supplier sources: Azure SRE Agent built-in tools and the Azure Monitor MCP connector
* Catalog version: 2026-10-07
* Last verified: 2026-10-07
* Verification basis: published Azure SRE Agent and Azure Monitor MCP tool catalogs

Bind a catalog entry to the verified Azure SRE built-in tool provider or Azure Monitor MCP
connector reported by the host. A matching bare tool name from another server or connector is not
allowlisted. Treat a changed description or schema as an untrusted capability change that requires
approval and catalog review.

## Use

Inspect the host-reported schema before each tool's first use. Automatically invoke an entry marked
`Yes` only when its schema confirms a read-only operation, its target is inside the declared
collection scope, and its sensitivity fits the incident purpose. An entry marked `No` requires
explicit approval for the exact tool, target, parameters, returned data, and expiry. Skip
unavailable, unrelated, duplicative, write-capable, evidence-altering, or broader-than-declared
operations.

Classifications use these values:

* Operation is `Read`, `Active probe`, or `Delay`.
* Sensitivity is `Operational`, `Source`, `Personal`, or `Secret-risk`.
* Auto indicates whether the operation may run without case-specific approval after all RCA scope,
  authorization, and schema gates pass.

## Catalog

### Azure resource and connectivity

| Tool                                        | Operation    | Sensitivity | Auto |
|---------------------------------------------|--------------|-------------|------|
| `CheckIfResourceExists`                     | Read         | Operational | Yes  |
| `CheckTcpConnectivity`                      | Active probe | Operational | No   |
| `GetAllAzureDataFactoryPipelinesStatus`     | Read         | Operational | Yes  |
| `GetAllAzureFrontDoorEndpointOriginsStatus` | Read         | Operational | Yes  |
| `GetAppSetting`                             | Read         | Secret-risk | No   |
| `GetArmResourceAsJson`                      | Read         | Operational | Yes  |
| `GetAzCliHelp`                              | Read         | Operational | Yes  |
| `GetTlsSettings`                            | Read         | Operational | Yes  |
| `RunAzCliReadCommands`                      | Read         | Operational | No   |
| `WaitInMilliSeconds`                        | Delay        | Operational | No   |

Use `WaitInMilliSeconds` only for a documented ingestion delay or retry backoff. Cap each wait at
30 seconds and record the reason. Never use it to imply background continuation.

### Repository and work tracking

| Tool                                    | Operation | Sensitivity | Auto |
|-----------------------------------------|-----------|-------------|------|
| `FetchGithubIssue`                      | Read      | Operational | Yes  |
| `FetchGithubIssueComments`              | Read      | Personal    | Yes  |
| `FetchGithubIssues`                     | Read      | Operational | Yes  |
| `FetchGithubSecurityDependabotAlerts`   | Read      | Operational | Yes  |
| `FindConnectedGitHubRepo`               | Read      | Operational | Yes  |
| `FindConnectedRepositoryForAzureDevOps` | Read      | Operational | Yes  |
| `GetIaCForGitHub`                       | Read      | Source      | Yes  |
| `GetUserOrganizations`                  | Read      | Personal    | No   |

### Investigation and change history

| Tool                        | Operation | Sensitivity | Auto |
|-----------------------------|-----------|-------------|------|
| `AnalyzeDeploymentFailures` | Read      | Operational | Yes  |
| `GetActivityLogsSummary`    | Read      | Personal    | Yes  |
| `GetAnalysis`               | Read      | Operational | Yes  |
| `GetChangeHistory`          | Read      | Personal    | Yes  |
| `GetTaskExecutionHistory`   | Read      | Operational | Yes  |
| `ListScheduledTasks`        | Read      | Operational | Yes  |
| `SearchIncidentKnowledge`   | Read      | Personal    | Yes  |
| `SearchMemory`              | Read      | Personal    | No   |
| `ShowChangeDiffViewer`      | Read      | Source      | Yes  |

### Logs, metrics, and queries

| Tool                                          | Operation | Sensitivity | Auto |
|-----------------------------------------------|-----------|-------------|------|
| `ExecuteClusterKustoQuery`                    | Read      | Personal    | Yes  |
| `GetDimensionNames`                           | Read      | Operational | Yes  |
| `GetMetricTimeSeriesElementsForAzureResource` | Read      | Operational | Yes  |
| `KustoClient`                                 | Read      | Personal    | No   |
| `ListAvailableMetrics`                        | Read      | Operational | Yes  |
| `QueryAppInsightsByAppId`                     | Read      | Personal    | Yes  |
| `QueryAppInsightsByResourceId`                | Read      | Personal    | Yes  |
| `QueryLogAnalyticsByResourceId`               | Read      | Personal    | Yes  |
| `QueryLogAnalyticsByWorkspaceId`              | Read      | Personal    | Yes  |
| `ValidateQuery`                               | Read      | Operational | Yes  |

### Pipelines and builds

| Tool                           | Operation | Sensitivity | Auto |
|--------------------------------|-----------|-------------|------|
| `CompareRuns`                  | Read      | Operational | Yes  |
| `CompareWithLastSuccessfulRun` | Read      | Operational | Yes  |
| `DiscoverPipelinesForRepo`     | Read      | Operational | Yes  |
| `GetBuildDetails`              | Read      | Operational | Yes  |
| `GetBuildTimeline`             | Read      | Operational | Yes  |
| `GetPipelineRunHistory`        | Read      | Operational | Yes  |
| `GetPipelineRunStatus`         | Read      | Operational | Yes  |
| `GetTaskLogExcerpt`            | Read      | Personal    | Yes  |
| `InvestigateBuildFailure`      | Read      | Operational | Yes  |

### Time, visualization, and reports

| Tool                           | Operation | Sensitivity | Auto |
|--------------------------------|-----------|-------------|------|
| `GenerateRunDiffReport`        | Read      | Operational | No   |
| `GetCurrentUtcTime`            | Read      | Operational | Yes  |
| `PlotAreaChartWithCorrelation` | Read      | Operational | No   |
| `PlotBarChart`                 | Read      | Operational | No   |
| `PlotHeatmap`                  | Read      | Operational | No   |
| `PlotPieChart`                 | Read      | Operational | No   |
| `PlotScatter`                  | Read      | Operational | No   |

### Azure Monitor MCP

| Tool                                                               | Operation | Sensitivity | Auto |
|--------------------------------------------------------------------|-----------|-------------|------|
| `system-mcp-monitor_monitor_activitylog_list`                      | Read      | Personal    | Yes  |
| `system-mcp-monitor_monitor_healthmodels_entity_get`               | Read      | Operational | Yes  |
| `system-mcp-monitor_monitor_instrumentation_get-learning-resource` | Read      | Operational | No   |
| `system-mcp-monitor_monitor_metrics_definitions`                   | Read      | Operational | Yes  |
| `system-mcp-monitor_monitor_metrics_query`                         | Read      | Operational | Yes  |
| `system-mcp-monitor_monitor_resource_log_query`                    | Read      | Personal    | Yes  |
| `system-mcp-monitor_monitor_table_list`                            | Read      | Operational | Yes  |
| `system-mcp-monitor_monitor_table_type_list`                       | Read      | Operational | Yes  |
| `system-mcp-monitor_monitor_webtests_get`                          | Read      | Operational | Yes  |
| `system-mcp-monitor_monitor_workspace_list`                        | Read      | Operational | Yes  |
| `system-mcp-monitor_monitor_workspace_log_query`                   | Read      | Personal    | Yes  |
