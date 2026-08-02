---
title: Copilot OTel Metrics Skill Security Model
description: STRIDE threat model for the copilot-otel-metrics skill organized by assets, adversaries, and trust buckets (editor OTLP ingest, telemetry at rest, reference helper scripts, container image supply chain, editor-global configuration mutation, host process control, cloud control-plane artifact generation) with in-design mitigations and acknowledged enterprise readiness gaps
author: microsoft/hve-core
ms.date: 2026-07-30
ms.topic: reference
estimated_reading_time: 18
keywords:
  - security
  - STRIDE
  - copilot-otel-metrics
  - opentelemetry
  - threat model
---
<!-- markdownlint-disable-file -->
# Copilot OTel Metrics Skill Security Model

This document records the STRIDE threat model for the copilot-otel-metrics skill. The shipped runtime is `examples/compose.yaml` (the local stack definition), two Grafana dashboards under `examples/dashboards/`, four reference helper scripts under `examples/`, and the Azure templates under `examples/azure/` (collector configuration, Bicep, Terraform, and an Azure CLI script). The model is organized by trust bucket: editor OTLP ingest (B1), telemetry at rest and its query surfaces (B2), reference helper scripts to local service APIs (B3), container image supply chain (B4), editor-global configuration mutation (B5), host process control (B6), and cloud control-plane artifact generation (B7). Each bucket enumerates all six STRIDE categories. Assets and adversaries are enumerated first. Acknowledged enterprise readiness gaps are listed at the end.

The skill is an assistant rather than a reference pack, and that changes the model materially. It may write the user's global `settings.json` after presenting a diff and obtaining explicit approval, and it generates files intended for the user to execute. It never starts a service and never provisions infrastructure: `docker compose`, `az deployment`, and `terraform apply` are handed to the user, not run. Buckets B5 through B7 exist because generating and writing are themselves exposures, independent of who runs the result.

> **See also: repo-wide STRIDE model.** This skill participates in the repository-wide threat model at [`docs/security/security-model.md`](../../../../docs/security/security-model.md) and is registered in its [Skill Security Models](../../../../docs/security/security-model.md#skill-security-models) section.

## Executive Summary

The copilot-otel-metrics skill helps an operator turn on GitHub Copilot Chat's OTLP export and stand up somewhere for the data to land, locally or in Azure. Its highest-risk property is **not the code, it is the payload**. Spans emitted by the extension were directly observed carrying full prompt text, tool call arguments and results, and system instructions, on a configuration where content capture was left at its default. Anyone who follows this skill therefore accumulates a durable corpus of prompt content, in a Docker volume locally or in a billed Log Analytics workspace for an organization.

That exposure is **not harmless and is not accepted silently**. It is rated Medium residual for local single-user capture and is the reason organization capture ships with a collector processor that deletes the six observed content attributes before they reach billable storage. The skill states the same position everywhere it appears: content reaches the store regardless of the `captureContent` setting, so the endpoint and the backing store are sensitive either way, and the user owns the decision.

The design bounds the local case by construction: every published port binds to `127.0.0.1`, the stack image tag is pinned, the documented settings block omits `captureContent`, and the skill supplies a verification command so a reader checks rather than assumes. Residual risk concentrates in three places the skill cannot close: the extension's own span content behavior, the absence of authentication on loopback service APIs, and the lack of encryption or expiry on the persistent volume.

The assistant behaviors add three bounded exposures. The settings write mutates a user-owned JSONC file, which is contained by a mandatory backup, a per-key upsert that never reserializes, an approved diff, and a post-write parse with automatic restore. Generated compose and IaC files are inert until the user runs them, and the agent is prohibited from running them. Organization capture places a shared write-side credential on every workstation with no per-user binding and no documented in-place rotation, which is the single largest new exposure and is the reason the Azure path leads with that fact rather than with the architecture.

### Security Posture Overview

| Dimension          | Value                                                                                                                                                                                               |
|--------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Runtime surface    | Local compose stack, two Grafana dashboards, four standard-library Python helpers, collector configuration, Bicep, Terraform, and an Azure CLI script                                               |
| Trust buckets      | B1 editor OTLP ingest, B2 telemetry at rest, B3 helper scripts, B4 image supply chain, B5 editor-global configuration mutation, B6 host process control, B7 cloud control-plane artifact generation |
| Credentials        | Grafana default `admin`/`admin` for the local stack; an Application Insights connection string for the Azure path, supplied by the operator and never written by the skill                          |
| Network egress     | None locally after the image pull. The Azure path sends telemetry to a collector the operator runs, which forwards to Application Insights over TLS                                                 |
| Agent execution    | Writes the user's global `settings.json` after an approved diff; writes generated artifacts to disk. Never starts a service and never provisions infrastructure                                     |
| Open residual gaps | 16 registered, 5 open (highest: InfoDisc-High, prompt content present in spans despite the documented default)                                                                                      |

## Contents

* [System Description](#system-description)
* [Trust Boundaries](#trust-boundaries)
* [Assets](#assets)
* [Adversaries](#adversaries)
* [Bucket B1: Editor OTLP ingest](#bucket-b1-editor-otlp-ingest)
* [Bucket B2: Telemetry at rest and query surfaces](#bucket-b2-telemetry-at-rest-and-query-surfaces)
* [Bucket B3: Reference helper scripts to local service APIs](#bucket-b3-reference-helper-scripts-to-local-service-apis)
* [Bucket B4: Container image supply chain](#bucket-b4-container-image-supply-chain)
* [Bucket B5: Editor-global configuration mutation](#bucket-b5-editor-global-configuration-mutation)
* [Bucket B6: Host process control](#bucket-b6-host-process-control)
* [Bucket B7: Cloud control-plane artifact generation](#bucket-b7-cloud-control-plane-artifact-generation)
* [Enterprise Readiness Gaps](#enterprise-readiness-gaps)
* [References](#references)

## System Description

### Components

1. `examples/compose.yaml` — declares one `grafana/otel-lgtm` container publishing five loopback-bound ports, mounting an external named volume at `/data`, and passing delta-to-cumulative conversion plus 120-day retention to Prometheus.
2. `examples/dashboards/copilot-otel.json` — Grafana dashboard referencing the pre-provisioned `prometheus` and `tempo` datasource uids. Contains PromQL and TraceQL queries only.
3. `examples/verify.py` — read-only. Queries Grafana, Prometheus, and Tempo health plus stored signal presence. Exits non-zero when the stack is unhealthy.
4. `examples/baseline.py` — read-mostly. Snapshots Prometheus label values and Tempo trace names, writes one JSON file under the user cache directory, and diffs a later store state against it.
5. `examples/inspect_metrics.py` — read-only. Enumerates `copilot_chat` and `gen_ai` series with labels and current values.
6. `examples/validate_dashboard.py` — the only writing helper. Imports a dashboard through the Grafana API with `overwrite: true`, then replays each panel query against Prometheus or Tempo. Endpoint and credentials come from the environment, and it refuses a non-loopback Grafana unless `COPILOT_OTEL_ALLOW_REMOTE=1` is set.
7. `examples/dashboards/copilot-otel-azure.json` — Grafana dashboard for the Azure path. Contains KQL queries against Log Analytics only.
8. `examples/azure/otel-collector-config.yaml` — OpenTelemetry Collector pipeline. Receives OTLP, deletes the six observed plaintext content attributes plus `copilot_chat.reasoning_content` defensively, and exports to Application Insights using a connection string read from the environment.
9. `examples/azure/main.bicep`, `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `deploy.sh` — templates that create a Log Analytics workspace, an Application Insights component, an Azure Monitor dashboard, and an optional `Monitoring Reader` role assignment. Inert until an operator deploys them.
10. `SKILL.md` and `references/` — the instructional surface. It authorizes exactly two write behaviors: a diff-approved per-key upsert into the user's global `settings.json`, and writing generated artifacts to disk.

### Data Flow

```mermaid
flowchart TD
    subgraph AGENT["Copilot agent running this skill (trust zone)"]
        SKILL["SKILL.md and references"]
        WRITE["Diff-approved settings upsert"]
        GEN["Generated artifacts:<br/>compose, dashboards, IaC"]
    end
    subgraph EDITOR["VS Code process (operator trust zone)"]
        EXT["Copilot Chat extension<br/>OTel exporter"]
        SETTINGS["Global settings.json<br/>(application-scoped, default profile)"]
    end
    subgraph HOST["Operator workstation, loopback only (trust zone)"]
        HELPERS["verify.py / baseline.py<br/>inspect_metrics.py / validate_dashboard.py"]
        SNAP["~/.cache/copilot-otel/<br/>pre-enable-baseline.json"]
    end
    subgraph STACK["otel-lgtm container (trust zone)"]
        OTLP["OTLP receiver<br/>:4318 HTTP / :4317 gRPC"]
        PROM["Prometheus :9090"]
        TEMPO["Tempo :3200"]
        GRAF["Grafana :3000<br/>(default credentials)"]
        VOL[("copilot-otel-data<br/>volume /data")]
    end
    subgraph REGISTRY["Public container registry (external)"]
        IMG["grafana/otel-lgtm:0.29.2"]
    end
    subgraph AZURE["Azure subscription (external, operator-owned)"]
        COLL["OpenTelemetry Collector<br/>holds the connection string"]
        AI["Application Insights"]
        LAW[("Log Analytics workspace")]
        AMD["Azure Monitor dashboards<br/>with Grafana"]
    end
    SKILL --> WRITE
    SKILL --> GEN
    WRITE -->|"per-key upsert after approved diff"| SETTINGS
    GEN -.->|"written to disk, never executed by the agent"| HOST
    GEN -.->|"deployed by the operator"| AZURE
    SETTINGS -->|"configures endpoint"| EXT
    EXT -->|"OTLP/HTTP plaintext, spans carrying prompt content"| OTLP
    EXT -->|"OTLP over TLS, fleet path"| COLL
    OTLP -->|"metrics"| PROM
    OTLP -->|"traces"| TEMPO
    PROM -->|"persists"| VOL
    TEMPO -->|"persists"| VOL
    GRAF -->|"PromQL / TraceQL"| PROM
    GRAF -->|"TraceQL"| TEMPO
    HELPERS -->|"HTTP GET, unauthenticated"| PROM
    HELPERS -->|"HTTP GET, unauthenticated"| TEMPO
    HELPERS -->|"HTTP POST dashboard import, basic auth"| GRAF
    HELPERS -->|"writes snapshot"| SNAP
    COLL -->|"connection string, content attributes stripped"| AI
    AI -->|"persists"| LAW
    AMD -->|"KQL, current-user auth"| LAW
    IMG -.->|"docker pull, tag-pinned"| STACK
```

## Trust Boundaries

### Boundary Diagram

```text
┌────────────────────────────────────────────────────────────────┐
│ TRUST BOUNDARY: Copilot agent running this skill               │
│   writes settings (diff-approved) · writes generated files     │
│   NEVER starts a service · NEVER provisions infrastructure     │
└───────────┬──────────────────────────────┬─────────────────────┘
            │ per-key upsert               │ file writes only
┌───────────▼──────────────────────────────▼─────────────────────┐
│ TRUST BOUNDARY: Operator workstation                           │
│                                                                │
│  ┌──────────────────┐         ┌────────────────────────────┐   │
│  │ VS Code +        │         │ Reference helper scripts   │   │
│  │ Copilot Chat     │         │ (stdlib only, loopback)    │   │
│  │ global settings  │         │                            │   │
│  └────────┬─────────┘         └─────────────┬──────────────┘   │
│           │ OTLP/HTTP                       │ HTTP             │
│           │ prompt-bearing spans            │ queries          │
│  ─────────┼─────────────────────────────────┼───────────────   │
│           │   127.0.0.1 ONLY (no off-host listener)            │
│  ┌────────▼─────────────────────────────────▼───────────────┐  │
│  │ TRUST BOUNDARY: otel-lgtm container                      │  │
│  │  ┌──────────┐ ┌──────────┐ ┌────────┐ ┌───────────────┐  │  │
│  │  │ OTLP recv│ │Prometheus│ │ Tempo  │ │ Grafana       │  │  │
│  │  │ :4317/18 │ │  :9090   │ │ :3200  │ │ :3000 admin   │  │  │
│  │  └────┬─────┘ └────┬─────┘ └───┬────┘ └───────────────┘  │  │
│  │       └────────────┴───────────┘                         │  │
│  │                    │ persists                            │  │
│  │        ┌───────────▼────────────┐                        │  │
│  │        │ copilot-otel-data vol  │ prompt content at rest │  │
│  │        │ (unencrypted, 120d)    │ no expiry on traces    │  │
│  │        └────────────────────────┘                        │  │
│  └──────────────────────────────────────────────────────────┘  │
└───────────────────────────┬────────────────────────────────────┘
                            │ image pull (tag-pinned, not digest-pinned)
              ┌─────────────▼───────────────┐
              │ TRUST BOUNDARY: public      │
              │ container registry          │
              └─────────────────────────────┘

  Organization path only, operator-deployed:
              ┌──────────────────────────────────────────────┐
              │ TRUST BOUNDARY: Azure subscription           │
              │  Collector (holds fleet write credential)    │
              │       │                                      │
              │  App Insights ──▶ Log Analytics ──▶ Grafana  │
              │  content attributes stripped at the collector│
              └──────────────────────────────────────────────┘
```

### Boundary Descriptions

| Boundary             | Assets Protected                                    | Controls Enforced                                                                                                                                                                                 |
|----------------------|-----------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Copilot agent        | User configuration, host process state, cloud spend | Mandatory backup, per-key upsert, approved diff, post-write parse with restore; generation-only boundary on Docker and infrastructure commands                                                    |
| Operator workstation | Prompt content in transit, snapshot file            | Loopback-only port publishing; `captureContent` omitted from the documented settings block; stdlib-only helpers                                                                                   |
| otel-lgtm container  | Stored metrics and traces, Grafana configuration    | Container isolation; single named volume; default credentials paired with no off-host listener                                                                                                    |
| Public registry      | Image integrity, stack availability                 | Tag-pinned image reference; no build step and no third-party plugin installation                                                                                                                  |
| Azure subscription   | Fleet telemetry, ingestion spend, ingest credential | Collector strips content attributes before ingestion; connection string supplied from the operator's secret store and never written by the skill; daily ingestion cap defaulted in every template |

## Assets

| Id | Asset                                  | Lifetime                                    | Notes                                                                                                                  |
|----|----------------------------------------|---------------------------------------------|------------------------------------------------------------------------------------------------------------------------|
| A1 | Prompt and tool-call content in spans  | Persisted in the volume                     | Observed present despite content capture being left at its default. Highest-value asset here.                          |
| A2 | Usage and cost metrics                 | Persisted, 120-day retention                | Token counts, AIU billing proxy, tool call counts. Commercially sensitive in aggregate.                                |
| A3 | `copilot-otel-data` Docker volume      | Persistent until explicitly removed         | Unencrypted at rest. Survives `docker compose down` by design.                                                         |
| A4 | Grafana instance and dashboards        | Persistent                                  | Default `admin`/`admin` credentials; reachable on loopback only.                                                       |
| A5 | Baseline snapshot file                 | Persistent under the user cache             | Contains metric and service names plus session ids, not content.                                                       |
| A6 | Stack container image                  | External, pulled on first run               | `grafana/otel-lgtm:0.29.2`, tag-pinned rather than digest-pinned.                                                      |
| A7 | Global `settings.json`                 | Persistent, user-owned                      | JSONC with the user's own comments and formatting. Resolves from the default profile regardless of the active profile. |
| A8 | Application Insights connection string | Persistent until the component is recreated | Fleet-wide write credential. Supplied by the operator, never written into a generated file.                            |
| A9 | Generated infrastructure templates     | Persistent in the user's workspace          | Inert until deployed. Deployment creates billable resources and an optional role assignment.                           |

## Adversaries

| Id    | Adversary                                            | In-scope mitigations                                                                                                                                                          |
|-------|------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ADV-a | Off-host network attacker                            | Every published port binds `127.0.0.1`, so no listener is reachable off the host. Default Grafana credentials are never exposed to a network.                                 |
| ADV-b | Malicious or compromised process on the same host    | Not mitigated. Loopback services are unauthenticated and any local process can read or write them (G-SPF-1).                                                                  |
| ADV-c | Another user on a shared workstation                 | Bounded by Docker socket access and filesystem permissions on the volume. Not otherwise mitigated (G-INF-2).                                                                  |
| ADV-d | Upstream image or registry compromise                | Tag pinning limits drift; no digest verification or signature check is performed (G-SUP-1).                                                                                   |
| ADV-e | Operator error redirecting the exporter off-host     | Documentation states the endpoint carries prompt content and must be treated as sensitive regardless of the capture setting.                                                  |
| ADV-f | The agent itself, writing the wrong thing            | Backup before write, per-key upsert that never reserializes, exact diff, explicit approval, post-write parse with automatic restore (G-TAM-2).                                |
| ADV-g | A fleet member misusing the shared ingest credential | Not mitigated. The credential is write-side only and identical on every workstation, with no per-user binding and no in-place rotation (G-INF-3, G-DOS-2).                    |
| ADV-h | An operator deploying generated templates carelessly | Every template requires named inputs with no defaults for subscription, region, and naming; the role assignment is opt-in; a daily ingestion cap is set by default (G-EOP-3). |

## Bucket B1: Editor OTLP ingest

Covers the path from the Copilot Chat exporter to the container's OTLP receiver.

### Spoofing

The OTLP receiver performs no authentication. Any process able to reach `127.0.0.1:4318` can submit spans and metrics using the `copilot-chat` service name and genuine Copilot metric names, making injected series indistinguishable from real editor output by inspection alone. `examples/baseline.py` exists specifically to make this detectable after the fact: it captures the pre-enablement store state and reports discriminators that require real editor activity. Detection, not prevention. Tracked as G-SPF-1.

### Tampering

An unauthenticated writer can also poison existing series by submitting conflicting samples for the same metric and label set. The stack applies no ingest-side validation or allow-listing. Loopback binding limits this to local processes.

### Repudiation

The receiver records no provenance for accepted payloads beyond the resource attributes the sender chooses to supply, so a submitting process cannot be identified after ingest. `service_version` and `session_id` label values are attacker-controlled in the injection case. `baseline.py` diffing provides a coarse before-and-after record rather than per-payload attribution.

### Information Disclosure

This is the material risk in the entire model. Spans emitted with content capture left at its documented default were directly observed carrying `copilot_chat.user_request` (full prompt text), `gen_ai.input.messages`, `gen_ai.output.messages`, `gen_ai.tool.call.arguments`, `gen_ai.tool.call.result`, and `gen_ai.system_instructions` in plaintext. A seventh, `copilot_chat.reasoning_content`, was present but marked `[encrypted]`. The transport is plaintext HTTP. On loopback this is contained; the moment `otlpEndpoint` is redirected to a shared or hosted collector, prompt content leaves the machine in clear text. The skill documents this discrepancy explicitly and supplies a `curl` check so a reader verifies rather than trusts the documented default. Tracked as G-INF-1 and G-TLS-1.

### Denial of Service

Prometheus drops delta-temporality metrics by default, and a dropped delta metric was observed failing an entire batched write, discarding co-batched cumulative metrics. `compose.yaml` sets `--enable-feature=otlp-deltatocumulative` so conversion replaces dropping. The conversion state is held in memory and resets when the container restarts, producing a bounded gap rather than a persistent failure. Unauthenticated ingest also permits volumetric flooding of the local store by a local process. Tracked as G-DOS-1.

### Elevation of Privilege

Not applicable. The receiver executes no submitted content; OTLP payloads are parsed as data into the metric and trace stores, and no code path evaluates them.

### Risk Rating

| Threat                                         | Likelihood | Impact | Residual Risk | Status                                                |
|------------------------------------------------|------------|--------|---------------|-------------------------------------------------------|
| Local process injects synthetic Copilot series | Low        | Medium | Medium        | Detectable via `baseline.py`; not prevented (G-SPF-1) |
| Prompt content traverses plaintext OTLP        | High       | High   | Medium        | Contained by loopback binding only (G-INF-1, G-TLS-1) |
| Batched write loss from delta temporality      | Low        | Low    | Low           | Mitigated by delta-to-cumulative conversion (G-DOS-1) |
| Local flooding of the ingest endpoint          | Low        | Low    | Low           | Accepted for a single-machine demonstration stack     |

## Bucket B2: Telemetry at rest and query surfaces

Covers the persistent volume, Prometheus, Tempo, and the Grafana UI.

### Spoofing

Grafana ships with `admin`/`admin` and the skill does not change them. Any local process or local user can authenticate as the Grafana administrator. The compensating control is that Grafana is published on `127.0.0.1:3000` only, so the weak credential is never presented to a network. Prometheus and Tempo expose no authentication at all. Tracked as G-SPF-1.

### Tampering

A Grafana administrator can alter or delete dashboards and datasource definitions. `examples/validate_dashboard.py` performs exactly this operation with `overwrite: true`, which is intended for a dashboard the operator is checking but would overwrite an unrelated dashboard occupying the same uid. The helper refuses a non-loopback Grafana unless the operator sets `COPILOT_OTEL_ALLOW_REMOTE=1`, which confines the overwrite to a local stack by default. Direct volume access permits arbitrary modification of stored series. Tracked as G-TAM-1.

### Repudiation

Grafana's default configuration retains limited audit history, and Prometheus and Tempo record no query log. Actions taken through the shared `admin` account are attributable to the account, not to a person, so on a shared workstation no meaningful attribution exists.

### Information Disclosure

The volume holds A1 and A2 unencrypted for the life of the volume. Prometheus retention is set to 120 days deliberately, so monthly token aggregates are real rather than silently truncated at the 15-day default; the same setting extends how long usage data persists. Tempo retention is not configured here, so trace content carrying prompt text persists under the image's own default. Any local user with Docker access or filesystem access to the volume can read all of it. `docker compose down` deliberately preserves the volume, so an operator who believes they have torn the stack down has in fact retained the corpus. Teardown documentation states both variants explicitly. Tracked as G-INF-1 and G-INF-2.

### Denial of Service

The volume grows without bound for traces, because no Tempo retention limit is set. A long-running stack on a small disk can exhaust local storage. Prometheus is bounded by its 120-day retention setting.

### Elevation of Privilege

Grafana's administrator role is the highest privilege in this bucket and is reachable with published default credentials from any local process. That is privilege escalation within the stack, though not beyond the host user's existing authority, since the same actor could read the volume directly. Tracked as G-EOP-1.

### Risk Rating

| Threat                                            | Likelihood | Impact | Residual Risk | Status                                            |
|---------------------------------------------------|------------|--------|---------------|---------------------------------------------------|
| Prompt content readable at rest by any local user | Medium     | High   | Medium        | Unencrypted volume; no expiry on traces (G-INF-2) |
| Default Grafana credentials accepted              | High       | Medium | Low           | Loopback-only publishing (G-SPF-1, G-EOP-1)       |
| Dashboard overwritten by the validation helper    | Low        | Low    | Low           | Non-loopback targets refused by default (G-TAM-1) |
| Unbounded trace growth exhausts disk              | Low        | Medium | Low           | Accepted; operator removes the volume to reclaim  |

## Bucket B3: Reference helper scripts to local service APIs

Covers the four Python files under `examples/`. None is agent-executed.

### Spoofing

Every helper targets loopback `http://localhost` URLs by default with no certificate or identity verification, which is inherent to plaintext loopback HTTP. A local process that binds one of these ports before the container does can impersonate the service and return fabricated results, causing `verify.py` to report a healthy stack that does not exist. Low likelihood, and it requires an adversary already executing on the host. `validate_dashboard.py` accepts an environment override for its target and refuses a non-loopback host unless the operator sets `COPILOT_OTEL_ALLOW_REMOTE=1`, so redirecting it away from the local stack is a deliberate act rather than an accident.

### Tampering

Three of the four helpers issue only HTTP GET requests and mutate nothing. `validate_dashboard.py` issues one POST to the Grafana dashboard import API with `overwrite: true`, and it refuses to do so against a non-loopback host without an explicit opt-in. `baseline.py` writes a single JSON file, defaulting to `~/.cache/copilot-otel/pre-enable-baseline.json` and overridable through `COPILOT_OTEL_BASELINE`. The path is derived from the environment rather than from any service response, so a hostile service cannot redirect the write.

### Repudiation

Not applicable. The helpers are operator-invoked interactive tools that print their results to standard output and keep no log that a security decision depends on.

### Information Disclosure

The helpers print metric names, label values, and series values to the terminal. `inspect_metrics.py` prints label sets, which include model names, tool names, and session identifiers, but not span content: prompt-bearing attributes live on spans in Tempo and are not enumerated by any shipped helper. `baseline.py` persists metric names, service names, service versions, session ids, and trace names to its snapshot file. No helper writes prompt content to disk, and none transmits anything off the host. Terminal output may still be captured by shell history or a session recorder.

Everything returned from the store is untrusted data, never instructions. B1 Spoofing establishes that any local process can inject series carrying genuine Copilot names with attacker-controlled `service_version` and `session_id` values, and those values are exactly what these helpers print. The same applies to span attributes and trace names read through Tempo. Treat helper output, query results, and dashboard content as data to be inspected, and never act on text embedded in them.

### Denial of Service

`validate_dashboard.py` replays every dashboard panel query, which is the heaviest operation the skill performs against Prometheus and Tempo. It is bounded by the panel count and by per-request timeouts. `baseline.py` and `verify.py` issue one query per metric name, which scales with the store's cardinality. All are operator-triggered and none loops.

### Elevation of Privilege

Not applicable. The helpers run with the invoking user's privileges, spawn no subprocess, evaluate no fetched content, and require no elevation. They import only the Python standard library, so they introduce no third-party dependency.

### Risk Rating

| Threat                                             | Likelihood | Impact | Residual Risk | Status                                                            |
|----------------------------------------------------|------------|--------|---------------|-------------------------------------------------------------------|
| Local port impersonation misleads `verify.py`      | Low        | Low    | Low           | Accepted for loopback plaintext HTTP                              |
| Import helper overwrites a dashboard it should not | Low        | Low    | Low           | Refuses non-loopback targets without an explicit opt-in (G-TAM-1) |
| Sensitive label values reach terminal output       | Medium     | Low    | Low           | Labels only; span content is never enumerated by a helper         |

## Bucket B4: Container image supply chain

Covers acquisition of the `grafana/otel-lgtm` image.

### Spoofing

The image is referenced as `grafana/otel-lgtm:0.29.2` from the default public registry. A registry or namespace compromise able to repoint that tag would be accepted without challenge, because no digest pin and no signature verification are performed. Tracked as G-SUP-1.

### Tampering

Tags are mutable. A republished `0.29.2` would be pulled on any host that has not already cached the layers, and nothing in the skill would detect the substitution. Digest pinning is the standard control and is not applied here. Tracked as G-SUP-1.

### Repudiation

Docker records the resolved image digest locally after a pull, so the specific image actually running is identifiable on that host after the fact. The skill does not capture or compare that digest, so drift between two hosts pulling the same tag at different times goes unnoticed.

### Information Disclosure

Not applicable. The pull requests a public image by name and reveals nothing beyond ordinary registry access patterns. The skill supplies no credentials to the registry.

### Denial of Service

Registry unavailability blocks the first run only. Once layers are cached, `docker compose up -d` succeeds without network access, and `restart: unless-stopped` returns the stack after a host reboot.

### Elevation of Privilege

The container runs under the Docker daemon with whatever default privileges the image declares, and the compose definition adds no capabilities, no privileged flag, and no host mounts other than the single named data volume. A compromised image would nonetheless hold whatever authority the daemon grants, which on a typical developer workstation is root-equivalent. That is inherent to running any container and is bounded by the tag pin alone. Tracked as G-SUP-1 and G-EOP-2.

### Risk Rating

| Threat                                   | Likelihood | Impact | Residual Risk | Status                                          |
|------------------------------------------|------------|--------|---------------|-------------------------------------------------|
| Malicious image substitution under a tag | Low        | High   | Medium        | Tag-pinned, not digest-pinned (G-SUP-1)         |
| Compromised image gains daemon authority | Low        | High   | Medium        | No added capabilities or host mounts (G-EOP-2)  |
| Registry outage blocks first run         | Low        | Low    | Low           | Accepted; cached layers make later runs offline |

## Bucket B5: Editor-global configuration mutation

Covers the assisted write into the user's global `settings.json`. This bucket exists because the skill now acts on a file it does not own.

### Spoofing

Not applicable. The write is a local filesystem operation performed by the agent under the user's own identity. No authentication is presented and none is claimed.

### Tampering

This is the material risk in this bucket, and the tampering risk runs toward the user's file rather than from an attacker. `settings.json` is JSONC: it may hold comments, trailing commas, and formatting the user chose. A naive parse-and-reserialize destroys all of it silently. The mitigation is structural rather than advisory: a timestamped backup is taken first, the write is a per-key upsert that replaces only the value spans of the eleven target keys and inserts absent keys before the closing brace, all other content is left byte-identical, the resulting file is re-parsed, and a parse failure triggers an immediate restore from the backup. Concurrent writes by VS Code itself remain possible and are not preventable from outside the editor; the backup is the recovery path. Tracked as G-TAM-2.

### Repudiation

The write leaves the timestamped backup file beside the settings file, which records the pre-change state and the time. There is no per-key change log, so a user reconstructing what changed compares the backup against the current file. The approved diff shown before the write is the contemporaneous record and lives only in the conversation.

### Information Disclosure

The agent reads the whole settings file to perform the upsert, so unrelated settings enter model context. On a developer workstation that file frequently holds API endpoints, internal hostnames, and occasionally tokens that other extensions store there. The skill mitigates exposure in output rather than in reading: the presented diff shows only the changed lines, so unrelated values are not echoed. Tracked as G-INF-4.

### Denial of Service

A corrupted settings file would prevent VS Code from applying user configuration until repaired. The post-write parse plus automatic restore reduces this to a transient condition, and the backup makes it recoverable by hand even if the automatic restore fails.

### Elevation of Privilege

Not applicable. The write occurs under the invoking user's own filesystem privileges, targets a file that user already owns, and requires no elevation. Application-scoped settings confer no authority beyond the editor.

### Risk Rating

| Threat                                                  | Likelihood | Impact | Residual Risk | Status                                                                      |
|---------------------------------------------------------|------------|--------|---------------|-----------------------------------------------------------------------------|
| Reserialization destroys user comments and formatting   | Low        | Medium | Low           | Per-key upsert never reserializes; backup taken first (G-TAM-2)             |
| Write lands in a profile file and silently does nothing | Medium     | Low    | Low           | Procedure requires confirming the path via Open Application Settings (JSON) |
| Unrelated settings values enter model context           | Medium     | Low    | Low           | Whole file is read; only changed lines are echoed in the diff (G-INF-4)     |
| Concurrent VS Code write overwrites the change          | Low        | Low    | Low           | Not preventable externally; backup is the recovery path                     |
| Settings Sync propagates an unwanted change             | Low        | Low    | Low           | Behavior unconfirmed; disclosed as a caveat rather than asserted (G-REP-1)  |

## Bucket B6: Host process control

Covers artifacts the skill generates for the user to execute: the compose file and the local stack it defines.

### Spoofing

Not applicable. Generated files carry no identity claim and authenticate to nothing at generation time.

### Tampering

A generated compose file sits in the user's workspace between generation and execution, so anything with write access to that path can modify it before `docker compose up` runs. That is the ordinary trust model of any file in a workspace and is not specific to this skill. The relevant control is that the user reads and runs the file themselves, which puts a human between generation and execution.

### Repudiation

The generated file is the record of what was proposed. Because the agent does not run it, execution is attributable to the user's own shell history and Docker daemon records rather than to the agent.

### Information Disclosure

The generated compose file contains no credentials. Grafana's default credentials are the image's, not values the skill writes. What the generated stack subsequently collects is covered by B1 and B2.

### Denial of Service

Running the generated stack binds five loopback ports, pulls a multi-hundred-megabyte image, and creates a Docker volume that outlives the container. A port already in use causes the stack to fail to start rather than to displace the existing listener. These are the reasons the skill hands over the command rather than running it: they are consequences a user should choose.

### Elevation of Privilege

**This is the reason the boundary exists.** `docker compose up` executes with Docker daemon authority, which on a typical developer workstation is root-equivalent. An agent that ran generated compose files on the user's behalf would be converting file-write capability into root-equivalent execution without a human decision in between. The skill therefore prohibits it: `docker compose`, `az deployment`, `az group create`, and `terraform apply` are printed for the user, never executed. That prohibition is advisory prose rather than an enforced control, which is its residual weakness. Tracked as G-EOP-4.

### Risk Rating

| Threat                                                         | Likelihood | Impact | Residual Risk | Status                                                                              |
|----------------------------------------------------------------|------------|--------|---------------|-------------------------------------------------------------------------------------|
| Agent executes a generated file with daemon authority          | Low        | High   | Medium        | Prohibited in SKILL.md constraints and stop rules; advisory, not enforced (G-EOP-4) |
| Generated file modified between generation and execution       | Low        | Medium | Low           | User reads and runs it; ordinary workspace trust model                              |
| Generated stack consumes host ports, disk, and image bandwidth | Medium     | Low    | Low           | Consequences stated before generation; user chooses to run it                       |

## Bucket B7: Cloud control-plane artifact generation

Covers the collector configuration, Bicep, Terraform, and Azure CLI templates under `examples/azure/`, and the organization data path they establish.

### Spoofing

Fleet telemetry authenticates to the collector with whatever static credential the managed settings distribute, because Copilot's exporter can only send a fixed header set. Every workstation therefore presents the same credential and no request is bound to a particular user or device. Anything holding that value can submit telemetry indistinguishable from a real developer's. Tracked as G-INF-3.

### Tampering

The consequence of the shared credential is that dashboards can be made to say anything. An actor holding it can inject fabricated spans carrying real service names and attribute values, so token totals, tool counts, and per-team breakdowns are all forgeable. The blast radius is write-side only: the credential does not grant read access to the workspace, which is governed separately by Azure RBAC.

### Repudiation

Ingested telemetry carries no per-user provenance beyond the resource attributes the sender chose to send, and those are attacker-controlled in the injection case. There is no documented in-place rotation for the connection string, so revoking it means recreating the component and redistributing to the whole fleet. That makes incident response a fleet-wide operation rather than a per-user one.

### Information Disclosure

Prompt and response text has been observed on spans even with `captureContent` disabled, which for the organization path would place developer prompt content into a shared, queryable, billed workspace readable by anyone with `Monitoring Reader`. The generated collector configuration therefore deletes the six attributes observed carrying plaintext content, `copilot_chat.user_request`, `gen_ai.input.messages`, `gen_ai.output.messages`, `gen_ai.system_instructions`, `gen_ai.tool.call.arguments`, and `gen_ai.tool.call.result`, plus `copilot_chat.reasoning_content` defensively, which was observed marked `[encrypted]`. This is the strongest available control, because it acts before data reaches storage. It is defeated by removing the processor, so the configuration says so in place. The Azure dashboard also ships a panel that counts these attributes, so a workspace receiving content is visible rather than silent. Tracked as G-INF-1.

### Denial of Service

The shared credential permits unbounded ingestion against a billed backend, so the practical denial of service is financial rather than availability. Templates default `dailyQuotaGb` to 5 and name it as the only spend guardrail, and disabling the cap requires setting it to -1 deliberately. `captureContent` is named as the dominant volume multiplier wherever cost is discussed. Tracked as G-DOS-2.

### Elevation of Privilege

Deployment creates billable Azure resources and, when a principal is supplied, a `Monitoring Reader` role assignment on the workspace. That authority comes from the operator's own Azure credentials, which the agent never holds and never uses: the agent writes templates and the operator deploys them. The residual concern is a template that over-grants by default, which is why the role assignment is opt-in through an empty-by-default parameter rather than applied automatically. Tracked as G-EOP-3.

### Risk Rating

| Threat                                                    | Likelihood | Impact | Residual Risk | Status                                                                                    |
|-----------------------------------------------------------|------------|--------|---------------|-------------------------------------------------------------------------------------------|
| Shared fleet credential enables telemetry forgery         | Low        | Medium | Medium        | Inherent to static-header export; stated before generation (G-INF-3)                      |
| Credential cannot be rotated without a fleet redeployment | Medium     | Medium | Medium        | No documented in-place rotation; disclosed rather than mitigated (G-INF-3)                |
| Prompt content reaches a shared billed workspace          | Medium     | High   | Low           | Collector deletes six observed attributes plus one defensively (G-INF-1)                  |
| Ingestion cost inflation, accidental or deliberate        | Medium     | Medium | Low           | Daily cap defaulted in every template; `captureContent` named as the multiplier (G-DOS-2) |
| Generated template over-grants access on deployment       | Low        | Medium | Low           | Role assignment opt-in; agent never holds Azure credentials (G-EOP-3)                     |

## Enterprise Readiness Gaps

| Id      | Severity        | Gap                                                                                                                                                                                                                                       | Status                                                                                                                                                                                                                                                                 |
|---------|-----------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| G-INF-1 | InfoDisc-High   | Spans carry full prompt text, tool call arguments and results, and system instructions on a configuration where content capture was left at its documented default. The skill cannot change extension behavior.                           | Local: documented prominently with a verification command, contained only by loopback binding. Organization: the generated collector deletes seven content attributes before export, and the Azure dashboard counts them so a leak is visible.                         |
| G-INF-2 | InfoDisc-Med    | The `copilot-otel-data` volume stores captured content unencrypted, with no Tempo retention limit and no expiry, and survives `docker compose down` by design.                                                                            | Open, and stated as a real exposure rather than a harmless local condition. `SKILL.md` and this model agree that the store holds prompt content regardless of the capture setting; the user owns the decision. Teardown documentation states both variants explicitly. |
| G-INF-3 | InfoDisc-Med    | Organization capture distributes one static write-side credential to every workstation, with no per-user binding and no documented in-place rotation. Anything holding it can inject telemetry indistinguishable from a real developer's. | Open. Inherent to static-header export against a credentialed backend. Disclosed before any Azure artifact is generated, with the write-side-only blast radius stated plainly.                                                                                         |
| G-INF-4 | InfoDisc-Low    | The assisted settings write reads the whole global `settings.json`, so unrelated values in that file enter model context.                                                                                                                 | Accepted. Reading the whole document is required to preserve it; only the changed lines are echoed in the presented diff.                                                                                                                                              |
| G-SPF-1 | Spoofing-Med    | OTLP ingest, Prometheus, and Tempo are unauthenticated, and Grafana accepts published default credentials. Any local process can read or write the store.                                                                                 | Mitigated only by `127.0.0.1` port binding. `baseline.py` provides after-the-fact detection of injected series.                                                                                                                                                        |
| G-SUP-1 | SupplyChain-Med | The stack image is pinned by tag rather than by digest, and no signature or provenance verification is performed before the container runs.                                                                                               | Open. Digest pinning would close the substitution vector at the cost of manual updates.                                                                                                                                                                                |
| G-EOP-1 | EoP-Low         | Grafana administrator access is reachable from any local process using published default credentials.                                                                                                                                     | Accepted. The same actor can already read the volume directly, so the escalation does not cross the host user boundary.                                                                                                                                                |
| G-EOP-2 | EoP-Med         | A compromised stack image would execute with Docker daemon authority, which is root-equivalent on a typical developer workstation.                                                                                                        | Bounded by the tag pin, by adding no capabilities, and by mounting no host paths beyond the named volume.                                                                                                                                                              |
| G-TAM-1 | Tampering-Low   | `validate_dashboard.py` imports with `overwrite: true`, so it would replace an unrelated dashboard sharing the same uid.                                                                                                                  | Constrained. The helper refuses a non-loopback Grafana unless `COPILOT_OTEL_ALLOW_REMOTE=1` is set, and endpoint and credentials come from the environment rather than being hard-coded.                                                                               |
| G-TAM-2 | Tampering-Med   | The assisted settings write mutates a user-owned JSONC file that may hold comments, formatting, and unrelated configuration the skill did not create.                                                                                     | Mitigated structurally: timestamped backup, per-key upsert that never reserializes, exact diff, explicit approval, post-write parse with automatic restore. Concurrent VS Code writes remain unpreventable.                                                            |
| G-REP-1 | Repudiation-Low | Settings Sync conflict behavior for a write made outside the running VS Code instance was never confirmed.                                                                                                                                | Open. Disclosed to the user as a caveat before the write rather than asserted in either direction.                                                                                                                                                                     |
| G-DOS-1 | DoS-Low         | Delta-to-cumulative conversion state is held in memory and resets on container restart, producing a bounded gap in converted series.                                                                                                      | Accepted. Without the flag the failure mode is worse, because a dropped delta metric can fail an entire batched write.                                                                                                                                                 |
| G-DOS-2 | DoS-Low         | The shared fleet credential permits unbounded ingestion against a billed backend, so the practical denial of service is financial.                                                                                                        | Mitigated by a 5 GB daily cap defaulted in every generated template, and by naming `captureContent` as the dominant volume multiplier wherever cost is discussed.                                                                                                      |
| G-EOP-3 | EoP-Med         | Generated infrastructure templates provision billable Azure resources and can create a `Monitoring Reader` role assignment when deployed.                                                                                                 | Bounded. The agent never holds Azure credentials and never deploys; the role assignment is opt-in through an empty-by-default parameter; required inputs have no defaults.                                                                                             |
| G-EOP-4 | EoP-Med         | The prohibition on the agent running `docker compose`, `az deployment`, or `terraform apply` is advisory prose in `SKILL.md` rather than an enforced control.                                                                             | Open. Stated in the constraints and the stop rules and exercised by the behavior gate. A hook would make it enforced.                                                                                                                                                  |
| G-TLS-1 | InfoDisc-Low    | OTLP ingest and all service queries use plaintext HTTP with no transport security.                                                                                                                                                        | Acceptable on loopback. Material the moment `otlpEndpoint` targets a remote collector, which the skill states explicitly.                                                                                                                                              |

## References

* [Monitor agent usage with OpenTelemetry](https://code.visualstudio.com/docs/agents/guides/monitoring-agents)
* [Manage AI settings in enterprise environments](https://code.visualstudio.com/docs/enterprise/ai-settings)
* [OTel GenAI semantic conventions](https://github.com/open-telemetry/semantic-conventions/blob/main/docs/gen-ai/)
* [Grafana OTel-LGTM image](https://github.com/grafana/docker-otel-lgtm)
* [Prometheus OTLP receiver documentation](https://prometheus.io/docs/guides/opentelemetry/)
* [Visualize Azure Monitor data with Grafana](https://learn.microsoft.com/azure/azure-monitor/visualize/visualize-grafana-overview)
* [Azure Monitor OpenTelemetry overview](https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-overview)
* [Repo-wide STRIDE model](../../../../docs/security/security-model.md)

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
