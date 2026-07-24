---
title: 'LT: Logging and Threat Detection'
description: MCSB Logging and Threat Detection control domain reference for assessing log collection, retention, and threat detection on Azure.
---

# 06 Logging and Threat Detection

Identifier: LT
Category: Detection and Response

## Objective

Detect threats and collect, centralize, retain, and analyze security-relevant logs across Azure resources. Logging and Threat Detection controls provide the telemetry needed to identify and investigate malicious activity.

## Assessment checklist

* Diagnostic and audit logs are enabled for resources and sent to a central workspace.
* Microsoft Defender for Cloud plans are enabled for in-scope resource types.
* Log retention meets policy and regulatory requirements.
* Alerts route to a monitored destination (SIEM, Sentinel, or ticketing).
* Control-plane activity logs are captured and protected from tampering.
* Time synchronization is consistent across logged sources.

## Controls and mitigations

1. Enable diagnostic settings on resources and centralize to Log Analytics or Sentinel.
2. Turn on Defender for Cloud threat detection for supported services.
3. Configure retention aligned with compliance obligations.
4. Route high-severity alerts to a monitored response channel.
5. Protect log stores against modification and deletion.

## Anti-patterns

* Resources with no diagnostic logging enabled.
* Logs stored only locally or with very short retention.
* Alerts generated but not routed to any responder.
* Defender plans disabled on sensitive workloads.

## Framework crosswalk

* NIST 800-53 Rev. 5: AU, IA, SI
* CIS Controls v8.1: 6, 8, 13, 17

## Volatile lookup

For the specific LT control identifiers that apply to a given Azure service, retrieve them at runtime per [lookup-playbook.md](lookup-playbook.md).

---

Original prose paraphrasing the MCSB v2 Logging and Threat Detection control domain, accessed 2026-07-21: <https://learn.microsoft.com/en-us/security/benchmark/azure/mcsb-v2-logging-threat-detection>.
