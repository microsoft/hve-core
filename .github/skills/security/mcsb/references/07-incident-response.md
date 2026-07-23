---
title: 'IR: Incident Response'
description: MCSB Incident Response control domain reference for assessing incident preparation, detection, and recovery on Azure.
---

# 07 Incident Response

Identifier: IR
Category: Detection and Response

## Objective

Prepare for, detect, investigate, prioritize, respond to, and learn from security incidents affecting Azure resources. Incident Response controls ensure detections lead to timely, effective action.

## Assessment checklist

* An incident response plan exists and defines roles, severity, and escalation.
* Defender for Cloud alerts and Sentinel incidents feed a defined triage process.
* Notification and escalation contacts are configured and current.
* Response playbooks or automation exist for common incident types.
* Post-incident reviews capture lessons learned and drive improvements.

## Controls and mitigations

1. Maintain an incident response plan with defined severities and owners.
2. Configure security contact details and alert notifications in Defender for Cloud.
3. Automate containment and enrichment with Sentinel playbooks where practical.
4. Conduct post-incident reviews and track remediation actions.
5. Test response procedures periodically.

## Anti-patterns

* Alerts generated with no defined triage or ownership.
* No configured security notification contacts.
* No post-incident review process.
* Response steps undocumented and improvised.

## Framework crosswalk

* NIST 800-53 Rev. 5: AU, CP, IR, RA, SI
* CIS Controls v8.1: 1, 8, 13, 17

## Volatile lookup

For the specific IR control identifiers that apply to a given Azure service, retrieve them at runtime per [lookup-playbook.md](lookup-playbook.md).

---

Original prose paraphrasing the MCSB v2 Incident Response control domain, accessed 2026-07-21: <https://learn.microsoft.com/en-us/security/benchmark/azure/mcsb-v2-incident-response>.
