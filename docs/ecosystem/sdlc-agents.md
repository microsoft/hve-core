---
title: SDLC Agents Ecosystem
description: Enterprise-grade SDLC automation agents that complement HVE Core workflows
author: Microsoft
ms.date: 2026-02-05
ms.topic: reference
keywords:
  - sdlc agents
  - enterprise automation
  - design review
  - tech debt
  - regression oracle
estimated_reading_time: 3
---

# SDLC Agents - Enterprise Automation

For teams looking to extend HVE Core with enterprise SDLC automation, the [SDLC Agents](https://github.com/azure-core/sdlc_agents) catalog provides **22 specialized agents** covering the full software development lifecycle.

## Why SDLC Agents?

While HVE Core provides excellent prompt engineering and workflow methodologies, many enterprise teams need additional automation for:

- **Pre-commit validation** - Catch design issues before code review
- **Technical debt management** - Systematic identification and prioritization
- **Regression prediction** - Learn from bug history to focus testing
- **Innovation governance** - Structured intake and evaluation of AI/ML initiatives

## Featured Agents

| Agent | Purpose | Maturity |
|-------|---------|----------|
| **Design Review Agent** | 22+ validation rules for architecture, security, API contracts | Stable |
| **Regression Oracle** | Predicts high-risk changes using historical bug data | Preview |
| **Tech Debt Scanner** | Finds TODOs, stale branches, outdated dependencies | Stable |
| **AI Incubation Suite** | Innovation intake → evaluation → show & tell → metrics | Stable |
| **Safety Compliance** | License auditing, vulnerability scanning, policy checks | Stable |
| **KPI Insights** | Engineering metrics and team performance analytics | Preview |

## Integration with HVE Core

SDLC Agents complement HVE Core's RPI workflow:

```text
┌─────────────────────────────────────────────────────────────┐
│                    HVE Core RPI Workflow                     │
├─────────────────┬─────────────────┬─────────────────────────┤
│    Research     │      Plan       │      Implement          │
│                 │                 │                         │
│  ┌───────────┐  │  ┌───────────┐  │  ┌─────────────────┐   │
│  │ SDLC:     │  │  │ SDLC:     │  │  │ SDLC:           │   │
│  │ Design    │  │  │ Tech Debt │  │  │ Regression      │   │
│  │ Review    │  │  │ Scanner   │  │  │ Oracle          │   │
│  └───────────┘  │  └───────────┘  │  └─────────────────┘   │
└─────────────────┴─────────────────┴─────────────────────────┘
```

- **Research phase**: Use Design Review Agent to validate architectural decisions
- **Plan phase**: Use Tech Debt Scanner to identify cleanup opportunities
- **Implement phase**: Use Regression Oracle to predict test coverage needs

## Getting Started

### Option 1: Use via Octane CLI

[Octane](https://github.com/azure-core/octane) provides Copilot-integrated scenarios:

```bash
# Install Octane
pip install octane

# Run design review
octane run design-review --repo ./my-project

# Scan for tech debt
octane run tech-debt-discovery --repo ./my-project
```

### Option 2: Use the Python SDK

Working implementations are available in [ms-agents-poc](https://github.com/azure-core/ms-agents-poc):

```bash
# Install the agent SDK
pip install git+https://github.com/azure-core/ms-agents-poc.git

# Use CLI
skills-agent design-review analyze ./src
skills-agent techdebt-scanner scan ./
```

## Resources

| Resource | Description |
|----------|-------------|
| [Agent Catalog](https://github.com/azure-core/sdlc_agents) | Full specifications for all 22 agents |
| [Working Implementations](https://github.com/azure-core/ms-agents-poc) | Python SDK with CLI and examples |
| [Octane Integration](https://github.com/azure-core/octane) | Copilot-native scenario runner |

## Governance Model

SDLC Agents follow a maturity model similar to HVE Core:

- **Experimental** → Initial development, APIs may change
- **Preview** → Feature complete, gathering feedback
- **Stable** → Production ready, backward compatible
- **Deprecated** → Scheduled for removal

See the [Governance documentation](https://github.com/azure-core/sdlc_agents/blob/main/docs/governance.md) for promotion criteria, SLOs, and security requirements.

## Contact

For questions or collaboration:

- **Maintainer**: @mosiddi
- **Team**: Maya Stewart, Requasi
- **Issues**: [azure-core/sdlc_agents/issues](https://github.com/azure-core/sdlc_agents/issues)
