---
title: Architecture Diagrams Skill
description: Use the portable architecture-diagrams skill to generate ASCII or Mermaid architecture diagrams from infrastructure source files
sidebar_position: 4
author: Microsoft
ms.date: 2026-06-29
ms.topic: how-to
---

The [architecture-diagrams skill](pathname://../../../.github/skills/hve-core/architecture-diagrams/SKILL.md) is the recommended way to generate ASCII or Mermaid architecture diagrams from infrastructure source files. It is especially useful for ADRs, onboarding guides, and design reviews when you want a quick, text-based view of a system's structure.

## When to Use This Skill

Use the skill when you need to:

* inspect Terraform, Bicep, ARM, Kubernetes YAML, Docker Compose, or shell scripts
* show service boundaries, data flow, ingress paths, and network zones
* produce a diagram directly in chat without relying on a dedicated agent
* choose ASCII or Mermaid output to match the document or review format

## Suggested Workflow

1. Identify the infrastructure files and the architectural scope you want to visualize.
2. Ask for a diagram that emphasizes the layer or flow you care about most, such as networking, compute, or data.
3. Review the draft and refine it with follow-up prompts until the diagram matches the discussion.

## Example Prompt

```text
Analyze the Terraform and Bicep files in this repository and create an ASCII architecture diagram for the application platform. Show the public ingress path, app services, data stores, and any shared platform services.
```

## Tips

* Keep the scope narrow so the diagram stays readable.
* Re-run the skill after infrastructure changes to keep the diagram current.
* Copy the resulting ASCII output into ADRs or design notes when you want a stable artifact.

## Related Documentation

* [Project Planning Agents](README.md)
* [ADR Creator](adr-creation)

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
