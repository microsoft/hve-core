---
title: MCSB Lookup Playbook
description: Delegation guardrail for retrieving volatile per-Azure-service MCSB content at runtime.
---

# MCSB Lookup Playbook

This skill contains only the durable MCSB layer: the control-domain taxonomy and per-domain assessment references ([00-control-index.md](00-control-index.md) and the numbered domain files) plus a representative domain-grain crosswalk in the index. Anything that changes on Microsoft's release cadence is intentionally excluded and retrieved at runtime.

## What stays out of this skill (volatile)

Never embed the following — retrieve it when a specific Azure resource is in scope:

* Per-Azure-service security baselines and per-service control identifiers (for example, which `NS`/`DP` controls apply to Azure Storage or AKS).
* Azure Policy mappings, policy definition names, effects, and versions.
* Defender for Cloud assessment specifics and compliance results.
* Framework mappings when Microsoft revises the benchmark or the referenced standards.

## How to delegate

When a specific Azure resource needs its applicable control identifiers, delegate to the Researcher Subagent:

```text
Agent: Researcher Subagent
Topic: Identify MCSB controls applicable to {component} of type {resource type} in {Azure service}.
Context: Component "{name}" in bucket "{bucket}" using {technology stack} on Azure.
Output: .copilot-tracking/research/subagents/{{YYYY-MM-DD}}/{component-name}-mcsb.md
```

Response format: return findings as a markdown document with Applicable Controls, Findings, and Recommendations sections, each control identified by its MCSB control ID and mapped back to a domain in [00-control-index.md](00-control-index.md).

Execution constraints: complete research within a single invocation and do not delegate to additional subagents. When neither `runSubagent` nor `task` is available, inform the user that one of these tools is required; do not synthesize per-service control mappings from training data.

## Reconciling results

* Map each returned control identifier back to its domain and to the framework families in [00-control-index.md](00-control-index.md).
* Record the retrieval date alongside the findings, because per-service baselines and policy mappings change over time.

## Source

Guidance derived from the Microsoft Cloud Security Benchmark controls-to-Azure-Policy mapping and per-service baseline documentation on Microsoft Learn, accessed 2026-07-21: <https://learn.microsoft.com/en-us/security/benchmark/azure/overview>.
