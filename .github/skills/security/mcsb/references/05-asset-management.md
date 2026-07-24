---
title: 'AM: Asset Management'
description: MCSB Asset Management control domain reference for assessing inventory, approval, ownership, and lifecycle visibility on Azure.
---

# 05 Asset Management

Identifier: AM
Category: Governance

## Objective

Maintain security visibility, inventory, approval, and lifecycle controls for Azure assets. Asset Management controls ensure resources are known, owned, governed, and monitored.

## Assessment checklist

* A complete inventory of Azure resources is maintained and kept current.
* Resources are tagged with owner, environment, and data classification.
* Only approved services and configurations are permitted, enforced by Azure Policy.
* Unmanaged, orphaned, or shadow resources are detected and remediated.
* Defender for Cloud (or equivalent) provides continuous asset visibility.

## Controls and mitigations

1. Use Azure Resource Graph and Defender for Cloud for continuous inventory.
2. Enforce required tags and allowed resource types with Azure Policy.
3. Establish an approval process for new services entering production.
4. Detect and remediate orphaned or non-compliant resources.
5. Assign clear ownership for every resource group and subscription.

## Anti-patterns

* No authoritative inventory of deployed resources.
* Resources lacking ownership or classification tags.
* Unrestricted creation of arbitrary services in production subscriptions.
* Orphaned resources left running without review.

## Framework crosswalk

* NIST 800-53 Rev. 5: AC, CM, PM, RA, SA, SC, SI
* CIS Controls v8.1: 1, 2, 4, 5, 6, 10, 15

## Volatile lookup

For the specific AM control identifiers that apply to a given Azure service, retrieve them at runtime per [lookup-playbook.md](lookup-playbook.md).

---

Original prose paraphrasing the MCSB v2 Asset Management control domain, accessed 2026-07-21: <https://learn.microsoft.com/en-us/security/benchmark/azure/mcsb-v2-asset-management>.
