<!-- markdownlint-disable-file -->
# HVE Core Installer

Decision-driven installer skill for deploying HVE Core artifacts across workspace configurations

## Overview

Deploy HVE Core artifacts across workspace configurations with the hve-core-installer skill. This collection provides decision-driven setup for selecting and installing collections, agents, prompts, and instructions via the VS Code extension or clone-based methods.

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

### Instructions

| Name | Description |
|------|-------------|
| **shared/hve-core-location** | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

### Skills

| Name | Description |
|------|-------------|
| **hve-core-installer** | Decision-driven installer for HVE-Core with 6 clone-based installation methods, extension quick-install, environment detection, and agent customization workflows |

<!-- END AUTO-GENERATED ARTIFACTS -->

## Install

```bash
copilot plugin install installer@hve-core
```

## Instructions

| Instruction                    | Description                                                                                                                                                                                                                                                 |
|--------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| hve-core-location.instructions | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

## Skills

| Skill              | Description                                                                                                                                                                                              |
|--------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| hve-core-installer | Decision-driven installer for HVE-Core with 6 clone-based installation methods, extension quick-install, environment detection, and agent customization workflows - Brought to you by microsoft/hve-core |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

