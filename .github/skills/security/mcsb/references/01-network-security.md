---
title: 'NS: Network Security'
description: MCSB Network Security control domain reference for assessing Azure network boundary, connectivity, and DNS protections.
---

# 01 Network Security

Identifier: NS
Category: Network

## Objective

Protect Azure network boundaries, service-to-service connectivity, edge exposure, and DNS. Network Security controls limit which traffic can reach a resource, isolate workloads, and reduce public exposure.

## Assessment checklist

* Public network access is disabled on services that support private connectivity.
* Private endpoints or service endpoints are used for PaaS data services (Storage, SQL, Key Vault).
* Network security groups (NSGs) restrict inbound and outbound traffic to required flows only.
* Web-facing workloads sit behind a WAF (Azure Front Door or Application Gateway WAF).
* DDoS protection is enabled for internet-facing virtual networks where warranted.
* DNS is configured to prevent dangling records and subdomain takeover.
* Management ports (RDP/SSH) are not exposed to the internet; Bastion or just-in-time access is used.

## Controls and mitigations

1. Prefer private endpoints over public endpoints for data-plane access to PaaS services.
2. Apply least-privilege NSG and firewall rules; deny by default and allow explicitly.
3. Deploy a WAF in front of public HTTP(S) workloads and tune managed rule sets.
4. Segment virtual networks by trust level and control cross-segment traffic.
5. Use Azure Firewall or equivalent egress controls to constrain outbound traffic.

## Anti-patterns

* Storage accounts, databases, or Key Vaults left open to all networks.
* NSGs allowing `0.0.0.0/0` inbound on management or application ports.
* Management ports exposed directly to the internet.
* Public IP addresses attached to resources that only need private connectivity.

## Framework crosswalk

* NIST 800-53 Rev. 5: AC, CA, CM, SC, SI
* CIS Controls v8.1: 9, 12, 13

## Volatile lookup

For the specific NS control identifiers that apply to a given Azure service, retrieve them at runtime per [lookup-playbook.md](lookup-playbook.md).

---

Original prose paraphrasing the MCSB v2 Network Security control domain, accessed 2026-07-21: <https://learn.microsoft.com/en-us/security/benchmark/azure/mcsb-v2-network-security>.
