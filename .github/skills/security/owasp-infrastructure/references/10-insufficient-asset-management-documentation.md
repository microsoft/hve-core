---
title: 'ISR10: Insufficient Asset Management and Documentation'
description: OWASP Infrastructure Top 10 reference for asset management vulnerabilities including incomplete inventories and missing documentation
---

# 10 Insufficient Asset Management and Documentation

Identifier: ISR10:2024
Category: Governance

## Description

Insufficient asset management refers to shortcomings in an organization's ability to accurately
identify, track, and document all its hardware and software assets, along with associated
configurations, dependencies, and lifecycles.
It encompasses the lack of an organized and up-to-date inventory of IT assets, which is essential
for effective security, compliance, and operational efficiency.
A complete asset inventory enables fast mapping of affected resources and accurate incident
response.

## Risk

- Unauthorized or unmanaged devices and software within the network make it difficult to enforce
  security policies and monitor for vulnerabilities effectively.
- Incident response capabilities are hampered because the organization may struggle to identify
  the scope and impact of a security incident or breach.
- Compliance with industry regulations and internal policies becomes challenging, exposing the
  organization to legal and financial liabilities.
- Inefficient resource allocation results in overspending on redundant assets or underinvesting
  in critical IT infrastructure.

## Vulnerability checklist

- No complete inventory of hardware and software assets exists.
- Asset inventory is not continuously updated to reflect changes in the environment.
- Assets are not classified by criticality and function.
- No lifecycle management process exists for procurement, deployment, maintenance, and disposal.
- Regular audits and vulnerability scanning cycles are not conducted.
- Process, responsibility, and implementation documentation is incomplete or absent.

## Prevention controls

1. Develop and maintain a complete inventory of all hardware and software assets, including
   servers, workstations, mobile devices, applications, and network equipment; continuously update
   this inventory.
2. Categorize assets based on criticality and function to prioritize security measures and
   resource allocation.
3. Implement a systematic approach to asset lifecycle management, including procurement,
   deployment, maintenance, and disposal; securely decommission or renew outdated assets before
   they become a security risk.
4. Conduct regular audits and reconciliation of the asset inventory to identify discrepancies,
   including regular vulnerability scanning cycles.
5. Provide accurate documentation describing all IT and business processes, corresponding
   responsibilities, and technical details.

## Example attack scenarios

### Scenario A — Undetected vulnerabilities
An organization has a vast and complex IT infrastructure.
Due to a lack of systematic vulnerability scanning and asset management, the IT team is unaware
of accumulating security weaknesses.
Attackers exploit undetected vulnerabilities to gain unauthorized access, disrupt operations, or
exfiltrate sensitive data.
As the organization expands, the risk associated with these undetected vulnerabilities grows.

### Scenario B — Incident response with good asset management
An incident response team confronts a critical security breach where attackers exploited a
software vulnerability in the corporate platform, compromising webservers and creating an entry
point to the internal network.
Due to accurate and up-to-date asset documentation, the team quickly identifies critical systems,
maps affected resources, defends weaknesses, and prevents significant data breaches.
Damaged systems are rebuilt without extended disruption.

## Detection guidance

- Compare deployed assets against the maintained inventory for discrepancies.
- Scan for unknown or unauthorized devices and software on the network.
- Review asset lifecycle records for items past end-of-life or end-of-support.
- Audit documentation completeness for IT processes, responsibilities, and technical details.

## Remediation

- Conduct a full asset discovery and build a comprehensive hardware and software inventory.
- Classify all assets by criticality and function.
- Establish lifecycle management processes covering procurement through secure disposal.
- Schedule recurring inventory audits and automated vulnerability scanning.
- Create and maintain documentation for all IT processes, responsibilities, and configurations.
- Assign ownership for inventory accuracy and documentation currency.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
