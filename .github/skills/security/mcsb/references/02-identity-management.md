---
title: 'IM: Identity Management'
description: MCSB Identity Management control domain reference for assessing centralized identity, authentication, and credential protection on Azure.
---

# 02 Identity Management

Identifier: IM
Category: Identity

## Objective

Establish a centralized identity system with strong authentication, managed workload identities, and credential protection. Identity Management controls ensure that access to Azure resources is governed by a single, auditable identity provider.

## Assessment checklist

* Microsoft Entra ID is the central identity provider for user and workload authentication.
* Managed identities are used for service-to-service authentication instead of secrets.
* Access keys and connection strings are avoided where identity-based auth is available.
* Multi-factor authentication is enforced for interactive user sign-in.
* Application secrets and certificates are stored in Key Vault, not in code or config.
* Conditional Access policies restrict sign-in by risk, device, and location.

## Controls and mitigations

1. Use Microsoft Entra ID authentication in preference to shared keys or local accounts.
2. Assign managed identities to compute resources for downstream service access.
3. Store and rotate credentials in Key Vault; reference them rather than embedding.
4. Enforce MFA and Conditional Access for all interactive access.
5. Disable legacy or basic authentication protocols.

## Anti-patterns

* Storage account keys or SQL connection strings embedded in application code.
* Long-lived service principal secrets checked into source control.
* Local database or VM accounts used instead of centralized identity.
* MFA not enforced for privileged or standard users.

## Framework crosswalk

* NIST 800-53 Rev. 5: AC, IA, RA, SC, SI
* CIS Controls v8.1: 3, 5, 6, 8, 12, 16

## Volatile lookup

For the specific IM control identifiers that apply to a given Azure service, retrieve them at runtime per [lookup-playbook.md](lookup-playbook.md).

---

Original prose paraphrasing the MCSB v2 Identity Management control domain, accessed 2026-07-21: <https://learn.microsoft.com/en-us/security/benchmark/azure/mcsb-v2-identity-management>.
