---
title: SRE / Operations Guide
description: HVE Core support for SRE and operations engineers managing infrastructure, incidents, and deployment workflows
author: Microsoft
ms.date: 2026-02-18
ms.topic: how-to
keywords:
  - SRE
  - operations
  - infrastructure
  - incident response
estimated_reading_time: 10
---

This guide is for you if you manage infrastructure, handle incidents, deploy systems, maintain CI/CD pipelines, or ensure production reliability. SRE and operations engineers have 13+ addressable assets spanning infrastructure as code, incident response, security operations, and deployment automation.

## Recommended Collections

> [!TIP]
> Install the collections that match your workflow:
>
> ```text
> Minimum: @hve-core-installer install coding-standards
> Full:    @hve-core-installer install coding-standards security-planning rpi
> ```
>
> The `coding-standards` collection activates IaC-specific instructions for Terraform, Bicep, Bash, and GitHub Actions. Adding `security-planning` enables incident response tooling, and `rpi` supports structured investigation and remediation workflows.

## What HVE Core Does for You

1. Activates infrastructure-as-code standards for Terraform, Bicep, Bash scripts, and GitHub Actions workflows automatically
2. Generates incident response runbooks and playbooks for operational scenarios
3. Supports structured investigation of production issues through research workflows
4. Validates dependency pinning and SHA integrity for supply chain security
5. Reviews infrastructure changes against operational best practices
6. Manages Git workflows for infrastructure repositories including merge and rebase operations

## Your Lifecycle Stages

> [!NOTE]
> SRE / Operations engineers primarily operate in these lifecycle stages:
>
> [Stage 1: Setup](../lifecycle/setup.md): Configure environments, install tooling, set up infrastructure
> [Stage 3: Product Definition](../lifecycle/product-definition.md): Define infrastructure requirements and operational specifications
> [Stage 6: Implementation](../lifecycle/implementation.md): Build infrastructure, write IaC, configure pipelines
> [Stage 8: Delivery](../lifecycle/delivery.md): Deploy infrastructure, validate environments, release changes
> [Stage 9: Operations](../lifecycle/operations.md): Monitor systems, handle incidents, maintain production

## Stage Walkthrough

1. Stage 1: Setup. Configure your development environment and install HVE Core tooling using the [Getting Started guide](../getting-started/install.md). Set up IaC project structure for your infrastructure repository.
2. Stage 3: Product Definition. Define infrastructure requirements, SLOs, and operational contracts. Use `@security-plan-creator` for infrastructure security planning.
3. Stage 6: Implementation. Write infrastructure code with auto-activated standards for Terraform (`*.tf`), Bicep (`bicep/**`), Bash (`*.sh`), and GitHub Actions (`*.yml`). Use `@task-implementor` for complex multi-file changes.
4. Stage 8: Delivery. Deploy infrastructure changes through CI/CD pipelines. Use `/git-commit` for conventional commits and `/pull-request` for infrastructure PRs with proper review.
5. Stage 9: Operations. Handle incidents with `/incident-response` runbooks. Investigate production issues with `@task-researcher` for structured root cause analysis.

## Starter Prompts

```text
/incident-response Create a runbook for {incident scenario}
```

```text
@task-researcher Investigate {production issue}
```

```text
@security-plan-creator Create a security plan for {infrastructure component}
```

```text
/pull-request Create a PR for infrastructure changes
```

```text
@task-implementor Implement infrastructure for {component}
```

## Key Agents and Workflows

| Agent                 | Purpose                                          | Invoke                   | Docs                                                   |
|-----------------------|--------------------------------------------------|--------------------------|--------------------------------------------------------|
| task-researcher       | Structured production issue investigation        | `@task-researcher`       | [Task Researcher](../rpi/task-researcher.md)           |
| task-implementor      | Infrastructure code implementation               | `@task-implementor`      | [Task Implementor](../rpi/task-implementor.md)         |
| task-reviewer         | Infrastructure code review                       | `@task-reviewer`         | [Task Reviewer](../rpi/task-reviewer.md)               |
| security-plan-creator | Infrastructure security planning                 | `@security-plan-creator` | Agent file                                             |
| pr-review             | Pull request review for infrastructure changes   | `@pr-review`             | Agent file                                             |
| memory                | Session context and preference persistence       | `@memory`                | Agent file                                             |

Prompts complement the agents for operational workflows:

| Prompt             | Purpose                                         | Invoke               |
|--------------------|--------------------------------------------------|-----------------------|
| incident-response  | Incident response runbook creation               | `/incident-response`  |
| git-commit         | Conventional commit message generation           | `/git-commit`         |
| pull-request       | Pull request creation                            | `/pull-request`       |
| git-merge          | Git merge and rebase workflow management         | `/git-merge`          |

Auto-activated instructions apply IaC standards based on file type: Terraform (`*.tf`, `*.tfvars`), Bicep (`bicep/**`), Bash (`*.sh`), and GitHub Actions workflows (`.github/workflows/*.yml`).

## Tips

| Do                                                            | Don't                                                         |
|---------------------------------------------------------------|---------------------------------------------------------------|
| Let IaC-specific instructions auto-activate by file type      | Manually enforce Terraform or Bicep standards                 |
| Create incident response runbooks before incidents occur      | Write runbooks reactively during active incidents              |
| Use `@task-researcher` for structured root cause analysis     | Debug production issues without systematic investigation      |
| Review infrastructure PRs with `@pr-review`                   | Merge infrastructure changes without code review              |
| Use `/git-commit` for consistent, conventional commit history | Write ad-hoc commit messages for infrastructure changes       |

## Related Roles

* SRE + Security Architect: Operational security, incident response, and monitoring connect security planning with production operations. Threat models inform operational controls. See the [Security Architect Guide](security-architect.md).
* SRE + Engineer: Production reliability requires collaboration between infrastructure operations and feature development. Deployment pipelines serve both roles. See the [Engineer Guide](engineer.md).
* SRE + Tech Lead: Infrastructure architecture decisions shape operational practices. IaC standards maintain consistency across environments. See the [Tech Lead Guide](tech-lead.md).

## Next Steps

> [!TIP]
> Explore IaC coding standards: [Coding Standards Collection](../../collections/coding-standards.collection.md)
> Set up incident response tools: [Security Planning Collection](../../collections/security-planning.collection.md)
> See how operations fits the project lifecycle: [AI-Assisted Project Lifecycle](../lifecycle/)

---

> [!NOTE]
> Automated runbook triggering (GAP-10), deployment orchestration, and SLO monitoring integration are planned improvements.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
