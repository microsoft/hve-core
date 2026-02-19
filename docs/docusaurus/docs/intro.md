---
title: Introduction to HVE Core
description: HVE Core brings AI assistance to every phase of the software development lifecycle through GitHub Copilot customizations.
sidebar_position: 1
sidebar_label: Introduction
author: Microsoft
ms.date: 2026-02-19
ms.topic: overview
---


:::caution Draft Content
This documentation site is under active development. Content on this page is preliminary and subject to change.
:::

HVE Core (HyperVelocity Engineering Core) is a collection of GitHub Copilot customizations — agents, prompts, instructions, and skills — that bring AI assistance to every phase of the software development lifecycle. Rather than limiting AI to code generation, HVE Core provides structured workflows for research, planning, architecture, implementation, review, and deployment.

## How It Works

HVE Core operates through four layers of Copilot customization:

- **Agents** provide conversational, multi-turn workflows for complex tasks like architecture decisions and code review
- **Prompts** offer single-invocation actions for focused tasks like generating commit messages or PR descriptions
- **Instructions** apply automatically based on file patterns to enforce coding standards and conventions
- **Skills** bundle executable scripts with documentation for specific capabilities

## The Value Delivery Loop

The following diagram illustrates how HVE Core supports the full development lifecycle:

```mermaid
graph LR
    A["① Research"] --> B["② Plan"]
    B --> C["③ Implement"]
    C --> D["④ Review"]
    D --> E["⑤ Deploy"]
    E --> F["⑥ Measure"]
    F -->|"Feedback"| A

    style A fill:#E3F2FD,stroke:#0078D4,color:#000
    style B fill:#E3F2FD,stroke:#0078D4,color:#000
    style C fill:#E3F2FD,stroke:#0078D4,color:#000
    style D fill:#E3F2FD,stroke:#0078D4,color:#000
    style E fill:#E3F2FD,stroke:#0078D4,color:#000
    style F fill:#E3F2FD,stroke:#0078D4,color:#000
```

Each phase has dedicated agents and prompts. Explore the [Getting Started](getting-started/overview) section to begin using HVE Core, or visit [Workflows](workflows/overview) to learn about specific development workflows.

🤖 *Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
