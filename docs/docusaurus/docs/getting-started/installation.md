---
title: Installation
description: How to install and configure HVE Core in your project.
sidebar_position: 2
---


:::caution Draft Content
This documentation site is under active development. Content on this page is preliminary and subject to change.
:::

HVE Core can be installed using several methods depending on your workflow preferences. Each method brings the same set of agents, prompts, instructions, and skills into your project.

## Quick Install

The fastest way to get started is by copying the HVE Core configuration files into your repository's `.github/` directory.

```bash
# Clone the HVE Core repository
git clone https://github.com/microsoft/hve-core.git

# Copy the customization files to your project
cp -r hve-core/.github/agents your-project/.github/
cp -r hve-core/.github/prompts your-project/.github/
cp -r hve-core/.github/instructions your-project/.github/
```

## VS Code Extension

HVE Core is also available as a VS Code extension that packages the customizations for easy installation and updates.

See the [HVE Core repository](https://github.com/microsoft/hve-core) for detailed installation instructions and additional setup methods.

## Verify Installation

After installation, open GitHub Copilot Chat in VS Code and type `@` to see the available agents. You should see HVE Core agents listed alongside any existing agents.
