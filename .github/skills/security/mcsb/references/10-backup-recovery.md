---
title: 'BR: Backup and Recovery'
description: MCSB Backup and Recovery control domain reference for assessing recoverable, protected, and tested backups on Azure.
---

# 10 Backup and Recovery

Identifier: BR
Category: Resilience

## Objective

Automate, protect, monitor, and test recoverable backups and recovery processes for Azure resources. Backup and Recovery controls ensure data and services can be restored after loss, corruption, or ransomware.

## Assessment checklist

* Backups are configured for critical data and services with an appropriate schedule.
* Backup data is encrypted and protected against unauthorized deletion.
* Immutable or soft-delete protection guards against ransomware and accidental loss.
* Restore procedures are documented and periodically tested.
* Backup coverage and job success are monitored with alerting on failures.

## Controls and mitigations

1. Configure Azure Backup (or equivalent) for critical workloads and data.
2. Enable soft-delete and immutability to resist tampering.
3. Encrypt backup data and control access to recovery points.
4. Test restores on a regular cadence and document recovery objectives.
5. Monitor backup jobs and alert on failures or gaps.

## Anti-patterns

* Critical data without any configured backup.
* Backups deletable by the same identities that manage production.
* Restores never tested.
* No monitoring of backup job success.

## Framework crosswalk

* NIST 800-53 Rev. 5: AU, CP, SC, SI
* CIS Controls v8.1: 3, 8, 11

## Volatile lookup

For the specific BR control identifiers that apply to a given Azure service, retrieve them at runtime per [lookup-playbook.md](lookup-playbook.md).

---

Original prose paraphrasing the MCSB v2 Backup and Recovery control domain, accessed 2026-07-21: <https://learn.microsoft.com/en-us/security/benchmark/azure/mcsb-v2-backup-recovery>.
