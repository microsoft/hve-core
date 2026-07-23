---
title: 'ES: Endpoint Security'
description: MCSB Endpoint Security control domain reference for assessing endpoint detection and response and anti-malware on Azure compute.
---

# 09 Endpoint Security

Identifier: ES
Category: Endpoint

## Objective

Protect cloud compute endpoints with endpoint detection and response (EDR), modern anti-malware, and current protection updates. Endpoint Security controls defend virtual machines and container hosts against malicious code.

## Assessment checklist

* EDR (Defender for Endpoint) is deployed to virtual machines and servers.
* Anti-malware is enabled with automatic signature and platform updates.
* Endpoint protection status is monitored centrally with alerting on gaps.
* Compute images are hardened before deployment.
* Endpoint detections integrate with the central threat-detection pipeline.

## Controls and mitigations

1. Deploy Defender for Endpoint / EDR to all supported compute endpoints.
2. Enable anti-malware with automatic updates.
3. Monitor protection coverage and remediate unprotected endpoints.
4. Harden base images and remove unnecessary software.
5. Route endpoint detections to the security operations pipeline.

## Anti-patterns

* Virtual machines without EDR or anti-malware.
* Protection present but signatures or agents out of date.
* No central visibility into endpoint protection status.
* Detections not integrated with response workflows.

## Framework crosswalk

* NIST 800-53 Rev. 5: IR, SI
* CIS Controls v8.1: 7, 8, 10, 13

## Volatile lookup

For the specific ES control identifiers that apply to a given Azure service, retrieve them at runtime per [lookup-playbook.md](lookup-playbook.md).

---

Original prose paraphrasing the MCSB v2 Endpoint Security control domain, accessed 2026-07-21: <https://learn.microsoft.com/en-us/security/benchmark/azure/mcsb-v2-endpoint-security>.
