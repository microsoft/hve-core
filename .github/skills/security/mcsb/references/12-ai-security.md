---
title: 'AI: Artificial Intelligence Security'
description: MCSB Artificial Intelligence Security control domain reference for assessing AI platform, application, and monitoring controls on Azure.
---

# 12 Artificial Intelligence Security

Identifier: AI
Category: AI

## Objective

Secure AI platforms, applications, and monitoring, including model approval, guardrails, agent permissions, human oversight, and AI red teaming. The AI Security domain was introduced in MCSB v2 and addresses risks specific to AI workloads.

When `raiEnabled` is true in the Security Planner, coordinate this domain with the planner's AI-component handling and the responsible-AI standards references.

## Assessment checklist

* AI models and services are approved and inventoried before production use.
* Guardrails (content filters, safety systems) are enabled on AI applications.
* Agent and tool permissions follow least privilege and are scoped explicitly.
* Human oversight is defined for high-impact AI decisions.
* AI-specific logging captures prompts, responses, and safety events as appropriate.
* AI red teaming or adversarial testing is performed for high-risk applications.

## Controls and mitigations

1. Establish an approval and inventory process for AI models and services.
2. Enable content safety guardrails and monitor for bypass attempts.
3. Constrain agent tool access and grounding data to the minimum required.
4. Define human-in-the-loop oversight for consequential actions.
5. Conduct AI red teaming and track findings to remediation.

## Anti-patterns

* AI services deployed without approval, inventory, or guardrails.
* Agents granted broad tool or data access beyond their purpose.
* No human oversight for high-impact automated decisions.
* No adversarial testing of high-risk AI applications.

## Framework crosswalk

* NIST 800-53 Rev. 5: AC, AU, CA, CM, IA, IR, RA, SA, SI
* CIS Controls v8.1: 5, 6, 8, 13, 15, 16, 18

## Volatile lookup

For the specific AI control identifiers that apply to a given Azure service, retrieve them at runtime per [lookup-playbook.md](lookup-playbook.md).

---

Original prose paraphrasing the MCSB v2 Artificial Intelligence Security control domain, accessed 2026-07-21: <https://learn.microsoft.com/en-us/security/benchmark/azure/mcsb-v2-artificial-intelligence-security>.
