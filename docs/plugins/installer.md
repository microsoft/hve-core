---
title: HVE Core Installer
description: Decision-driven installer skill for deploying HVE Core artifacts across workspace configurations
sidebar_position: 10
author: Microsoft
ms.date: 2026-08-03
ms.topic: reference
---

Choose this package for workspace maintainers who need to deploy HVE Core artifacts across differing workspace configurations.

It provides a decision-driven installer skill with environment detection and selective component installation, plus shared repository-location guidance.

Lifecycle labels are disclosure metadata. In the channel model, Stable and PreRelease have equal active content, including components labeled stable, preview, and experimental; publication cadence and source ownership can differ.

## Included Artifacts

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

### Instructions

| Name                         | Maturity | Description                                                                                                                                                                                                                                                 |
|------------------------------|----------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **shared/hve-core-location** | stable   | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

### Skills

| Name                   | Maturity | Description                                                                                                                                             |
|------------------------|----------|---------------------------------------------------------------------------------------------------------------------------------------------------------|
| **hve-core-installer** | stable   | Decision-driven HVE-Core installer with multiple clone-based and extension install methods, environment detection, and selective component installation |

<!-- END AUTO-GENERATED ARTIFACTS -->

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
