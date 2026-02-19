---
title: Understanding Agents
description: How custom agents extend GitHub Copilot with specialized domain expertise
sidebar_position: 1
---


:::caution Draft Content
This documentation site is under active development. Content on this page is preliminary and subject to change.
:::

Agents are custom AI assistants that bring specialized knowledge and workflows to GitHub Copilot. Each agent is defined in a `.agent.md` file and can be configured with specific tools, handoffs, and domain expertise.

HVE Core ships with agents for task research, implementation planning, code review, and documentation operations. You can also create your own agents tailored to your team's workflows.

:::tip
Start by exploring the built-in agents in `.github/agents/` to understand the patterns, then create your own using the agent template.
:::

## What You'll Learn

- How agents are structured and configured
- Built-in agents and their capabilities
- Creating custom agents for your workflows
- Prompt engineering for effective agent instructions
