---
title: Phase Reference
description: Detailed reference for each of the Security Planner's six phases, including inputs, outputs, artifacts, and state transitions
sidebar_position: 5
sidebar_label: Phase Reference
keywords:
  - security planner
  - phases
  - threat modeling
  - STRIDE
  - standards mapping
tags:
  - agents
  - security
author: Microsoft
ms.date: 2026-03-11
ms.topic: reference
estimated_reading_time: 8
---

Each of the Security Planner's six phases has defined inputs, outputs, state transitions, and artifacts. This reference documents the details that govern how the agent moves through a complete security analysis.

## Phase Summary

| Phase | Name               | Key output               | State fields updated                      |
|-------|--------------------|--------------------------|-------------------------------------------|
| 1     | Project Scoping    | Scope definition         | `entryMode`, `raiEnabled`, `aiComponents` |
| 2     | Bucket Analysis    | Bucket classification    | `bucketsCompleted`                        |
| 3     | Standards Mapping  | Controls per bucket      | `standardsMapped`                         |
| 4     | Security Model     | Threat catalog           | `riskSurfaceStarted`                      |
| 5     | Backlog Generation | Work items               | `handoffGenerated`                        |
| 6     | Review & Handoff   | Summary and RAI dispatch | `raiPlannerDispatched`                    |

## Phase 1: Project Scoping

### Purpose

Capture the project's purpose, technology stack, deployment model, data classification, and compliance requirements. Detect AI/ML components that trigger downstream RAI assessment.

### Inputs

* User responses to scoping questions (capture mode).
* PRD/BRD artifacts from `.copilot-tracking/` (scoping mode).

### Process

The agent asks 3-5 questions per turn covering:

* Project purpose and business context.
* Technology stack and programming languages.
* Deployment model (cloud, on-premises, hybrid).
* Data classification and sensitivity levels.
* Compliance and regulatory requirements.
* AI/ML component identification.

### Outputs

* Completed scope definition in the plan file.
* AI/ML detection results stored in state (`raiEnabled`, `raiScope`, `raiTier`, `aiComponents`).

### State Transitions

| Field          | Before | After                            |
|----------------|--------|----------------------------------|
| `currentPhase` | 1      | 2 (on user confirmation)         |
| `entryMode`    | unset  | `scoping` or `capture`           |
| `raiEnabled`   | unset  | `true` or `false`                |
| `raiScope`     | unset  | `none`, `lightweight`, or `full` |
| `raiTier`      | unset  | `none` through `comprehensive`   |

## Phase 2: Bucket Analysis

### Purpose

Classify all application components into seven operational buckets with a cross-cutting overlay.

### The Seven Buckets

| Bucket                | Covers                                                 |
|-----------------------|--------------------------------------------------------|
| Infrastructure        | Networking, compute, storage, cloud resources          |
| DevOps / Platform-ops | CI/CD pipelines, deployment, monitoring                |
| Build                 | Build systems, dependency management, artifact signing |
| Messaging             | Queues, event buses, pub/sub, webhooks                 |
| Data                  | Databases, caches, data lakes, ETL pipelines           |
| Web / UI / Reporting  | Frontend apps, APIs, dashboards, reporting             |
| Identity / Auth       | Authentication, authorization, secrets management      |

The **GS (cross-cutting)** overlay captures concerns that span multiple buckets, such as logging, encryption at rest, and network segmentation.

### Process

The agent walks through each bucket, asking which components belong to it, and identifies cross-cutting concerns. Components can belong to multiple buckets.

### State Transitions

| Field              | Before | After                            |
|--------------------|--------|----------------------------------|
| `currentPhase`     | 2      | 3 (on user confirmation)         |
| `bucketsCompleted` | `[]`   | Populated with completed buckets |

## Phase 3: Standards Mapping

### Purpose

Map each operational bucket to the relevant controls from OWASP Top 10, NIST 800-53, and CIS Benchmarks.

### Frameworks

| Framework      | Scope                           | Usage                              |
|----------------|---------------------------------|------------------------------------|
| OWASP Top 10   | Web application risks           | Mapped to Web/UI and Data buckets  |
| NIST 800-53    | Comprehensive security controls | Mapped across all buckets          |
| CIS Benchmarks | Configuration baselines         | Mapped to Infrastructure and Build |

The agent dispatches the Researcher Subagent to perform WAF (Well-Architected Framework) and CAF (Cloud Adoption Framework) runtime lookups when cloud-hosted components are in scope.

### State Transitions

| Field             | Before | After                         |
|-------------------|--------|-------------------------------|
| `currentPhase`    | 3      | 4 (on user confirmation)      |
| `standardsMapped` | `[]`   | Populated with mapped buckets |

## Phase 4: Security Model Analysis

### Purpose

Perform STRIDE-based threat modeling per bucket, generating a structured threat catalog.

### STRIDE Categories

<!-- cspell:disable -->
| Category                   | Question the threat answers                              |
|----------------------------|----------------------------------------------------------|
| **S**poofing               | Can an attacker impersonate a legitimate user or system? |
| **T**ampering              | Can data or code be modified without detection?          |
| **R**epudiation            | Can actions be denied or hidden?                         |
| **I**nformation Disclosure | Can sensitive data be exposed?                           |
| **D**enial of Service      | Can the system be made unavailable?                      |
| **E**levation of Privilege | Can an attacker gain unauthorized access?                |
<!-- cspell:enable -->

### Threat Identification Format

Each threat receives a unique identifier in the format `T-{BUCKET}-{NNN}`, where `BUCKET` is the operational bucket abbreviation and `NNN` is a sequential number.

### Severity Rating

Threats are rated using a likelihood-impact matrix:

| Likelihood × Impact | Result   |
|---------------------|----------|
| High × High         | Critical |
| High × Medium       | High     |
| Medium × High       | High     |
| Medium × Medium     | Medium   |
| Low × any           | Low      |

### State Transitions

| Field                | Before  | After  |
|----------------------|---------|--------|
| `currentPhase`       | 4       | 5      |
| `riskSurfaceStarted` | `false` | `true` |

## Phase 5: Backlog Generation

### Purpose

Convert identified threats into actionable backlog items with acceptance criteria and autonomy tier assignments.

### Work Item Formats

| Platform | ID format    | Example      |
|----------|--------------|--------------|
| ADO      | `WI[NNN]`    | `WI[001]`    |
| GitHub   | `{{TEMP-N}}` | `{{TEMP-1}}` |

### Autonomy Tiers

| Tier    | Human involvement          | Typical use                             |
|---------|----------------------------|-----------------------------------------|
| Full    | None required              | Low-risk configuration changes          |
| Partial | Review and approve         | Default for most security remediations  |
| Manual  | Human plans and implements | Architectural changes, policy decisions |

### State Transitions

| Field              | Before                        | After              |
|--------------------|-------------------------------|--------------------|
| `currentPhase`     | 5                             | 6                  |
| `handoffGenerated` | `{ado: false, github: false}` | Updated per target |

## Phase 6: Review and Handoff

### Purpose

Validate the complete analysis, present a summary, and trigger RAI Planner dispatch when AI/ML components are in scope.

### Review Checklist

The agent validates:

* All operational buckets have been classified.
* Standards are mapped for each bucket.
* Threats exist for each bucket with severity ratings.
* Backlog items are linked to their source threats.
* AI/ML components (if detected) have been flagged for RAI assessment.

### RAI Dispatch

When `raiEnabled` is `true`, the agent:

1. Presents the RAI Planner agent path (`.github/agents/rai-planning/rai-planner.agent.md`).
2. Suggests the `from-security-plan` entry mode.
3. Identifies the state file and project slug for the RAI Planner to consume.
4. Sets `raiPlannerDispatched` to `true` in state.

### State Transitions

| Field                  | Before  | After  |
|------------------------|---------|--------|
| `currentPhase`         | 6       | 6      |
| `raiPlannerDispatched` | `false` | `true` |

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
