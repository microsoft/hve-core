---
title: 'PA: Privileged Access'
description: MCSB Privileged Access control domain reference for assessing administrative access constraint, elevation, and review on Azure.
---

# 03 Privileged Access

Identifier: PA
Category: Access Control

## Objective

Constrain, elevate, monitor, and periodically review administrative access to Azure resources. Privileged Access controls limit standing high-privilege access and make elevation auditable and time-bound.

## Assessment checklist

* Privileged roles are assigned just-in-time rather than as standing access.
* Role assignments follow least privilege, using built-in roles scoped narrowly.
* Break-glass emergency accounts exist, are monitored, and are excluded from routine use.
* Administrative access requires MFA and, where possible, privileged access workstations.
* Access reviews are conducted periodically for privileged role assignments.
* Subscription owner and User Access Administrator assignments are minimized.

## Controls and mitigations

1. Use Privileged Identity Management (PIM) for just-in-time role activation.
2. Scope role assignments to the narrowest resource group or resource needed.
3. Require approval and justification for privileged elevation.
4. Configure and monitor break-glass accounts with alerting.
5. Run recurring access reviews and remove unused assignments.

## Anti-patterns

* Standing Owner or Contributor at subscription scope for routine operators.
* Shared administrative accounts without individual accountability.
* No periodic review of privileged assignments.
* Privileged access granted without MFA.

## Framework crosswalk

* NIST 800-53 Rev. 5: AC, AU, CA, CP, IA, IR
* CIS Controls v8.1: 4, 5, 6, 8, 17

## Volatile lookup

For the specific PA control identifiers that apply to a given Azure service, retrieve them at runtime per [lookup-playbook.md](lookup-playbook.md).

---

Original prose paraphrasing the MCSB v2 Privileged Access control domain, accessed 2026-07-21: <https://learn.microsoft.com/en-us/security/benchmark/azure/mcsb-v2-privileged-access>.
