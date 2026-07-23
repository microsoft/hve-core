---
title: 'DP: Data Protection'
description: MCSB Data Protection control domain reference for assessing data classification, encryption, and key management on Azure.
---

# 04 Data Protection

Identifier: DP
Category: Data

## Objective

Classify, encrypt, monitor, and manage sensitive data and cryptographic material across Azure resources. Data Protection controls ensure data is protected at rest and in transit and that keys are managed securely.

## Assessment checklist

* Encryption at rest is enabled for storage, databases, and disks.
* TLS is enforced for data in transit; insecure protocol versions are disabled.
* Customer-managed keys are used where required and stored in Key Vault or Managed HSM.
* Sensitive data is discovered and classified (for example, with Purview).
* Key Vault soft-delete and purge protection are enabled.
* Public access to data stores is disabled; access uses identity and private networking.

## Controls and mitigations

1. Enforce encryption at rest and in transit for all data services.
2. Manage keys and secrets in Key Vault with rotation and access policies.
3. Enable purge protection and soft-delete for key material.
4. Classify sensitive data and apply protection commensurate with sensitivity.
5. Restrict and monitor data-plane access.

## Anti-patterns

* Storage or databases without encryption at rest configured.
* Endpoints accepting legacy TLS or unencrypted connections.
* Keys or secrets stored outside a managed vault.
* Purge protection disabled on vaults holding production keys.

## Framework crosswalk

* NIST 800-53 Rev. 5: AC, IA, RA, SC, SI
* CIS Controls v8.1: 3

## Volatile lookup

For the specific DP control identifiers that apply to a given Azure service, retrieve them at runtime per [lookup-playbook.md](lookup-playbook.md).

---

Original prose paraphrasing the MCSB v2 Data Protection control domain, accessed 2026-07-21: <https://learn.microsoft.com/en-us/security/benchmark/azure/mcsb-v2-data-protection>.
