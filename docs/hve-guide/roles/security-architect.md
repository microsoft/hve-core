---
title: Security Architect Guide
description: HVE Core support for security architects building threat models, security plans, and compliance verification
author: Microsoft
ms.date: 2026-02-18
ms.topic: how-to
keywords:
  - security
  - threat modeling
  - risk assessment
  - compliance
estimated_reading_time: 10
---

This guide is for you if you perform threat modeling, build security plans, assess risks, define compliance requirements, or review system security posture. Security architects have focused but deep tooling, with 9 addressable assets centered on security planning and risk management.

## Recommended Collections

> [!TIP]
> Install the collection that matches your workflow:
>
> ```text
> @hve-core-installer install security-planning
> ```
>
> The `security-planning` collection provides security plan creation, risk registers, and incident response tools. For broader project context, pair with `project-planning`.

## What HVE Core Does for You

1. Creates comprehensive security plans with threat modeling and mitigation strategies
2. Generates and manages risk registers for component-level risk assessment
3. Provides incident response runbook templates and playbooks
4. Supports security architecture research through deep codebase analysis
5. Reviews implementation against security requirements and best practices

## Your Lifecycle Stages

> [!NOTE]
> Security architects primarily operate in these lifecycle stages:
>
> [Stage 2: Discovery](../lifecycle/discovery.md): Research security requirements, investigate threat landscape, gather evidence
> [Stage 3: Product Definition](../lifecycle/product-definition.md): Define threat models, security specifications, and compliance requirements
> [Stage 7: Review](../lifecycle/review.md): Validate implementation against security requirements
> [Stage 9: Operations](../lifecycle/operations.md): Monitor security posture, update threat models, manage incident response

## Stage Walkthrough

1. Stage 2: Discovery. Use `@task-researcher` to investigate the threat landscape, existing security controls, and compliance requirements for your system.
2. Stage 3: Product Definition. Run `@security-plan-creator` to generate a comprehensive security plan with threat models, attack vectors, and mitigation strategies.
3. Stage 3: Product Definition. Use `/risk-register` to assess and document component-level risks with severity ratings, likelihood, and mitigation plans.
4. Stage 7: Review. Validate implementation against security requirements using `@task-reviewer` for code-level security compliance checks.
5. Stage 9: Operations. Maintain incident response readiness with `/incident-response` and update threat models as the system evolves.

## Starter Prompts

```text
@security-plan-creator Generate a security plan for {system}
```

```text
/risk-register Assess and document risks for {component}
```

```text
/incident-response Create an incident response runbook for {scenario}
```

```text
@task-researcher Research security patterns for {technology}
```

## Key Agents and Workflows

| Agent                 | Purpose                                       | Invoke                   | Docs                                                   |
|-----------------------|-----------------------------------------------|--------------------------|--------------------------------------------------------|
| security-plan-creator | Security plan and threat model generation     | `@security-plan-creator` | Agent file                                             |
| task-researcher       | Security-focused codebase and threat research | `@task-researcher`       | [Task Researcher](../rpi/task-researcher.md)           |
| task-reviewer         | Security compliance review                    | `@task-reviewer`         | [Task Reviewer](../rpi/task-reviewer.md)               |
| memory                | Session context and preference persistence    | `@memory`                | Agent file                                             |

Prompts complement the agents for targeted security workflows:

| Prompt             | Purpose                                      | Invoke               |
|--------------------|----------------------------------------------|-----------------------|
| risk-register      | Component risk assessment and documentation  | `/risk-register`      |
| incident-response  | Incident response runbook creation           | `/incident-response`  |

## Tips

| Do                                                           | Don't                                                        |
|--------------------------------------------------------------|--------------------------------------------------------------|
| Start with `@security-plan-creator` for comprehensive models | Create ad-hoc security notes without structured threat models |
| Use `/risk-register` for each significant component          | Track risks informally or skip risk documentation             |
| Research the threat landscape before defining mitigations     | Assume threat models from other projects directly apply       |
| Update threat models as the system architecture evolves      | Treat security plans as static, one-time documents            |
| Map security requirements to specific lifecycle stages       | Isolate security from the broader product lifecycle           |

## Related Roles

* Security Architect + TPM: Security requirements integrate into BRDs and PRDs. Threat models inform product specifications and compliance gates. See the [TPM Guide](tpm.md).
* Security Architect + Tech Lead: Security architecture decisions align with overall system design. Threat models shape architectural choices. See the [Tech Lead Guide](tech-lead.md).
* Security Architect + SRE: Operational security, incident response, and monitoring bridge security planning with production operations. See the [SRE / Operations Guide](sre-operations.md).

## Next Steps

> [!TIP]
> Explore security planning tools: [Security Planning Collection](../../collections/security-planning.collection.md)
> Review the threat model documentation: [Threat Model](../security/threat-model.md)
> See how security fits the project lifecycle: [AI-Assisted Project Lifecycle](../lifecycle/)

---

> [!IMPORTANT]
> Security-specific tooling covers Stage 2, Stage 3, Stage 7, and Stage 9 only. Stages 4 through 6 and Stage 8 rely on general-purpose agents (`@task-researcher`, `@task-reviewer`) rather than dedicated security tooling. Specialized security coverage for decomposition, sprint planning, implementation, and delivery is a planned improvement.

<!-- -->

> [!NOTE]
> Automated compliance verification (GAP-11a), SAST/DAST orchestration (GAP-11b), and dependency vulnerability scanning (GAP-12) are planned improvements.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
