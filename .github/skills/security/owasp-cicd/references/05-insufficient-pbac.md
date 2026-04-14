---
title: 'CICD-SEC-5: Insufficient PBAC'
description: OWASP CI/CD Top 10 reference for insufficient pipeline-based access controls including overprivileged execution nodes and shared environments
---

# 05 Insufficient PBAC

Identifier: CICD-SEC-5:2025
Category: Access Controls

## Description

Pipeline-Based Access Controls (PBAC) refer to the context in which each pipeline, and each step
within that pipeline, is running. Given the highly sensitive and critical nature of each pipeline,
it is imperative to limit each pipeline to the exact set of data and resources it needs access to.

Pipeline execution nodes carry out commands specified in the pipeline configuration, performing
sensitive activities including accessing source code, obtaining secrets from vaults and cloud
identity services, creating and deploying artifacts, and connecting to production systems. When
running malicious code within a pipeline, adversaries leverage insufficient PBAC to abuse the
permissions granted to the pipeline for lateral movement within or outside the CI/CD system.

PBAC includes controls relating to access within the pipeline execution environment (code, secrets,
environment variables, other pipelines), permissions to the underlying host and other pipeline
nodes, and ingress and egress network filters.

## Risk

* Malicious code running in the context of a pipeline execution node has the full permissions of
  the pipeline stage, including access to all available secrets.
* Access to the underlying host and ability to connect to any system the pipeline has access to.
* Exposure of confidential data through overly broad secret scoping.
* Lateral movement within the CI environment and to servers and systems outside the CI
  environment.
* Deployment of malicious artifacts down the pipeline, including to production.
* The extent of potential damage from a compromise is directly determined by the granularity of
  PBAC in the environment.

## Vulnerability checklist

* Shared pipeline nodes are used for pipelines with different levels of sensitivity or access
  requirements.
* Secrets are not scoped to individual pipelines and steps, allowing broader access than required.
* Pipeline execution nodes are not reverted to a pristine state after each execution.
* The OS user running pipeline jobs has excessive permissions on the execution node.
* Pipeline jobs run on the controller node rather than separate dedicated nodes.
* Execution nodes are not regularly patched.
* Network segmentation does not restrict execution node access to only required resources.
* Build nodes have unrestricted internet access.
* Installation scripts execute with access to secrets and sensitive resources from other build
  stages.

## Prevention controls

1. Do not use shared nodes for pipelines with different levels of sensitivity. Use shared nodes
   only for pipelines with identical levels of confidentiality.
2. Scope secrets so that each pipeline and step has access to only the secrets it requires.
3. Revert the execution node to its pristine state after each pipeline execution.
4. Ensure the OS user running the pipeline job has permissions granted according to the principle
   of least privilege.
5. Run CI and CD pipeline jobs on separate, dedicated nodes rather than the controller node.
6. Keep execution nodes appropriately patched.
7. Configure network segmentation so execution nodes can access only the resources they require.
   Refrain from granting unlimited internet access to build nodes.
8. Ensure installation scripts execute in a separate context without access to secrets or
   sensitive resources from other build stages.

## Example attack scenarios

### Scenario A — Shared node secret leakage

An organization runs all pipeline jobs on a shared pool of nodes. A low-sensitivity open source
project pipeline and a high-sensitivity production deployment pipeline share the same nodes.
An attacker poisons the open source project's pipeline to enumerate environment variables and
filesystem contents on the shared node. Because secrets from the production pipeline persist in
memory and on disk from prior executions, the attacker exfiltrates production deployment
credentials.

### Scenario B — Unrestricted network lateral movement

A build node has unrestricted network access within the corporate environment. An attacker gains
code execution on the build node through a compromised dependency. Using the node's network
access, the attacker scans internal systems, discovers an unprotected internal service, and pivots
to access production databases containing customer data.

## Detection guidance

* Audit pipeline configurations to identify shared nodes servicing pipelines with differing
  sensitivity levels.
* Review secret scoping across CI/CD systems to detect overly broad access grants.
* Monitor execution node state to verify pristine-state restoration after each pipeline run.
* Inspect OS user permissions on execution nodes.
* Monitor network traffic from execution nodes for connections to unexpected destinations.
* Alert on pipeline jobs executing on controller nodes.

## Remediation

* Segregate pipeline execution nodes by sensitivity level, dedicating node pools to pipelines
  with matching confidentiality requirements.
* Re-scope all secrets to the minimum set of pipelines and steps that require them.
* Implement ephemeral pipeline execution nodes that are destroyed and recreated for each job.
* Reduce OS user privileges on execution nodes to the minimum required for job execution.
* Move all pipeline jobs off the controller node to dedicated worker nodes.
* Establish a patch management cadence for all execution nodes.
* Implement network segmentation and egress filtering on all build node networks.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
