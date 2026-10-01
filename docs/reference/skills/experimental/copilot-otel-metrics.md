---
title: copilot-otel-metrics
description: "Set up GitHub Copilot OpenTelemetry capture: configure the VS Code export settings, generate a local Grafana stack and dashboard, or generate the Azure collector, infrastructure, and dashboard for an organization."
sidebar_position: 2
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - skill
  - experimental
  - copilot-otel-metrics
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                               |
|-------------|-----------------------------------------------------------------------------------------------------|
| Kind        | skill                                                                                               |
| Source      | `.github/skills/experimental/copilot-otel-metrics`                                                  |
| Invocation  | Invoked directly as `/copilot-otel-metrics`; model invocation is disabled, so agents do not load it |
| Interactive | No                                                                                                  |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Set up GitHub Copilot OpenTelemetry capture: configure the VS Code export settings, generate a local Grafana stack and dashboard, or generate the Azure collector, infrastructure, and dashboard for an organization.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Reach for this skill when you want to measure your own Copilot usage rather than estimate it: which models you use, how long calls take, which tools run most, how many tokens you burn, and how much of that is served from cache.

Unlike most skills here, this one runs only when you ask for it. It is user-invocable with model invocation disabled, so no agent loads it on your behalf. Invoke it as `/copilot-otel-metrics`.

It has four independent modes. Name one directly, or describe the outcome you want and let the skill choose and tell you what it chose.

| Mode               | Use it when you want to                                              |
|--------------------|----------------------------------------------------------------------|
| `local-setup`      | Turn Copilot's OTel export on for this machine                       |
| `local-stack`      | Stand up a Grafana, Prometheus, and Tempo backend here to receive it |
| `org-distribution` | Push OTel settings to a fleet through Copilot managed settings       |
| `azure-capture`    | Collect a fleet's telemetry into Azure and chart it                  |

Reach for something else when:

* You want seat-level Copilot adoption figures across an organization. The GitHub Copilot Metrics API answers that far more cheaply, though it returns no spans, tokens, or latency.
* You want session lifecycle events rather than OTel signals. This skill covers OTel signals only.
* You are instrumenting your own service rather than measuring Copilot. [telemetry-foundations](../shared/telemetry-foundations) carries the OpenTelemetry naming conventions for that.

## Example usage

Ask for the outcome and let the skill route:

```text
/copilot-otel-metrics I want to see my own token usage and which tools I call most
```

That resolves to `local-setup` followed by `local-stack`, and proceeds in this order:

1. Confirms which VS Code build you run, and which global `settings.json` those application-scoped keys actually resolve from.
2. Backs that file up, shows you a unified diff of the keys it wants to add, and stops. Nothing is written before you approve it.
3. Writes the compose file and dashboard into a path it names first, then hands you `docker compose up -d` to run yourself.
4. Prompts you for **Developer: Reload Window**, because these settings are read at startup.
5. Queries Prometheus to confirm series actually landed, rather than reporting success from an HTTP 200.
6. Offers the dashboard JSON to import.

Naming a mode skips the routing:

```text
/copilot-otel-metrics azure-capture
```

That path asks for subscription, region, resource naming, and the RBAC principal before generating anything. It then writes the collector configuration, Bicep, Terraform, an Azure CLI script, and a KQL dashboard, hands over the deploy commands, and stops. It does not run `az deployment` or `terraform apply`, and it never writes your ingestion key into a file.

The full walkthrough, query reference, and screenshots live in [Copilot OpenTelemetry Metrics](../../../customization/copilot-otel-metrics).
