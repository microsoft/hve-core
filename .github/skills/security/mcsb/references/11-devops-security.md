---
title: 'DS: DevOps Security'
description: MCSB DevOps Security control domain reference for assessing secure supply chain, CI/CD, and workload artifacts on Azure.
---

# 11 DevOps Security

Identifier: DS
Category: DevOps

## Objective

Secure design, supply chain, CI/CD infrastructure, testing, workload artifacts, and DevOps telemetry. DevOps Security controls protect the pipeline that builds and deploys Azure workloads.

## Assessment checklist

* Pipeline credentials use managed identities or federated credentials, not long-lived secrets.
* Infrastructure as code is scanned for misconfiguration before deployment.
* Dependencies and artifacts are scanned and provenance is verifiable.
* Pipeline definitions and runners are hardened and access-controlled.
* Secrets are sourced from a vault at deploy time, not stored in the repo.
* Security testing (SAST/DAST/IaC scanning) is integrated into CI.

## Controls and mitigations

1. Use workload identity federation for pipeline authentication to Azure.
2. Scan IaC, dependencies, and images as pipeline gates.
3. Enforce branch protection and reviewed changes for infrastructure code.
4. Restrict and audit access to pipelines, runners, and service connections.
5. Retrieve secrets from Key Vault at deploy time.

## Anti-patterns

* Long-lived service principal secrets stored in pipeline variables or repos.
* No IaC or dependency scanning before deployment.
* Unrestricted access to pipeline service connections.
* Artifacts deployed without provenance or scanning.

## Framework crosswalk

* NIST 800-53 Rev. 5: AC, AU, CA, CM, PL, RA, SA, SI, SR
* CIS Controls v8.1: 4, 6, 7, 8, 14, 16

## Volatile lookup

For the specific DS control identifiers that apply to a given Azure service, retrieve them at runtime per [lookup-playbook.md](lookup-playbook.md).

---

Original prose paraphrasing the MCSB v2 DevOps Security control domain, accessed 2026-07-21: <https://learn.microsoft.com/en-us/security/benchmark/azure/mcsb-v2-devops-security>.
