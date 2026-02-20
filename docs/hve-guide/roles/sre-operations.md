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

> [!CAUTION]
> The security agents and prompts referenced in this guide are **assistive tools only**.
> They do not replace professional security tooling (SAST, DAST, SCA, penetration testing, compliance scanners) or qualified human review.
> All AI-generated security plans, threat models, risk registers, and incident response runbooks **must** be reviewed and validated by qualified security professionals before use.
> AI outputs may contain inaccuracies, miss critical threats, or produce recommendations that are incomplete or inappropriate for your environment.
> Never treat AI-generated security artifacts as authoritative without independent verification.

## Recommended Collections

> [!TIP]
> Install the [HVE Core extension](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core) from the VS Code Marketplace to get all stable artifacts with zero configuration.
>
> Your primary collections are `coding-standards` (IaC-specific instructions for Terraform, Bicep, Bash, and GitHub Actions), `security-planning` (incident response tooling), and `rpi` (structured investigation and remediation workflows). For clone-based setups, use the **hve-core-installer** agent with `install coding-standards security-planning rpi`.

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

1. Stage 1: Setup. Configure your development environment and install HVE Core tooling using the [Getting Started guide](../../getting-started/install.md). Set up IaC project structure for your infrastructure repository.
2. Stage 3: Product Definition. Define infrastructure requirements, SLOs, and operational contracts. Use the **security-plan-creator** agent for infrastructure security planning.
3. Stage 6: Implementation. Write infrastructure code with auto-activated standards for Terraform (`*.tf`), Bicep (`bicep/**`), Bash (`*.sh`), and GitHub Actions (`*.yml`). Use the **task-implementor** agent for complex multi-file changes.
4. Stage 8: Delivery. Deploy infrastructure changes through CI/CD pipelines. Use `/git-commit` for conventional commits and `/pull-request` for infrastructure PRs with proper review.
5. Stage 9: Operations. Handle incidents with `/incident-response` runbooks. Investigate production issues with the **task-researcher** agent for structured root cause analysis.

## Starter Prompts

```text
/incident-response Create an incident response runbook for a data breach
involving customer PII exposure through a misconfigured storage bucket.
Include containment steps, GDPR notification timelines, forensic evidence
preservation, and post-incident review process.
```

Select **task-researcher** agent:

```text
Investigate elevated 503 errors on the /api/orders endpoint. Error rate
increased from 0.1% to 12% starting at 14:30 UTC. The service runs on
3 Kubernetes pods in the production-east cluster. Check pod logs, recent
deployments, and upstream dependency health.
```

Select **security-plan-creator** agent:

```text
Create a security plan for the Kubernetes ingress controller cluster.
Cover TLS termination and certificate rotation automation, network policy
rules for namespace isolation, WAF configuration for OWASP Top 10
protection, and audit logging for ingress configuration changes.
```

```text
/pull-request Create a PR for infrastructure changes
```

Select **task-implementor** agent:

```text
Implement Terraform infrastructure for the Redis cache cluster in the
staging environment. Use existing module patterns in infra/modules/.
Configure a 3-node cluster with 6GB memory, automatic failover, and
encryption at rest. Output the connection string to the Vault KV store.
```

## Key Agents and Workflows

| Agent                     | Purpose                                        | Docs                                              |
|---------------------------|------------------------------------------------|---------------------------------------------------|
| **task-researcher**       | Structured production issue investigation      | [Task Researcher](../../rpi/task-researcher.md)   |
| **task-implementor**      | Infrastructure code implementation             | [Task Implementor](../../rpi/task-implementor.md) |
| **task-reviewer**         | Infrastructure code review                     | [Task Reviewer](../../rpi/task-reviewer.md)       |
| **security-plan-creator** | Infrastructure security planning               | Agent file                                        |
| **pr-review**             | Pull request review for infrastructure changes | Agent file                                        |
| **memory**                | Session context and preference persistence     | Agent file                                        |

Prompts complement the agents for operational workflows:

| Prompt            | Purpose                                  | Invoke               |
|-------------------|------------------------------------------|----------------------|
| incident-response | Incident response runbook creation       | `/incident-response` |
| git-commit        | Conventional commit message generation   | `/git-commit`        |
| pull-request      | Pull request creation                    | `/pull-request`      |
| git-merge         | Git merge and rebase workflow management | `/git-merge`         |

Auto-activated instructions apply IaC standards based on file type: Terraform (`*.tf`, `*.tfvars`), Bicep (`bicep/**`), Bash (`*.sh`), and GitHub Actions workflows (`.github/workflows/*.yml`).

## Tips

| Do                                                                   | Don't                                                    |
|----------------------------------------------------------------------|----------------------------------------------------------|
| Let IaC-specific instructions auto-activate by file type             | Manually enforce Terraform or Bicep standards            |
| Create incident response runbooks before incidents occur             | Write runbooks reactively during active incidents        |
| Use the **task-researcher** agent for structured root cause analysis | Debug production issues without systematic investigation |
| Review infrastructure PRs with the **pr-review** agent               | Merge infrastructure changes without code review         |
| Use `/git-commit` for consistent, conventional commit history        | Write ad-hoc commit messages for infrastructure changes  |

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

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
