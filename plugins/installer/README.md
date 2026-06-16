<!-- markdownlint-disable-file -->
# HVE Core Installer

Decision-driven installer skill for deploying HVE Core artifacts across workspace configurations

## Overview

Deploy HVE Core artifacts across workspace configurations with the hve-core-installer skill. This collection provides decision-driven setup for selecting and installing collections, agents, prompts, and instructions via the VS Code extension or clone-based methods.

## Included Artifacts

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

### Instructions

| Name                         | Description                                                                                                                                                                                                                                                 |
|------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **shared/hve-core-location** | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

### Skills

| Name                   | Description                                                                                                                                |
|------------------------|--------------------------------------------------------------------------------------------------------------------------------------------|
| **hve-core-installer** | Decision-driven HVE-Core installer with multiple clone-based and extension install methods, environment detection, and agent customization |

<!-- END AUTO-GENERATED ARTIFACTS -->

## Install

```bash
copilot plugin install installer@hve-core
```

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

