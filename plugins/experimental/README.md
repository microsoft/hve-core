<!-- markdownlint-disable-file -->
# Experimental

Experimental and preview artifacts not yet promoted to stable collections

> **⚠️ Experimental** — This collection is experimental. Contents and behavior may change or be removed without notice.

## Overview

Experimental and preview artifacts not yet promoted to stable collections. Items in this collection may change or be removed without notice.

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

### Chat Agents

| Name                    | Description                                                                                                                                                       |
|-------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **experiment-designer** | Conversational coach that guides users through designing a Minimum Viable Experiment (MVE) with structured hypothesis formation, vetting, and experiment planning |
| **pptx**                | Creates, updates, and manages PowerPoint slide decks using YAML-driven content with python-pptx                                                                   |
| **pptx-subagent**       | Executes PowerPoint skill operations including content extraction, YAML creation, deck building, and visual validation                                            |

### Instructions

| Name                                 | Description                                                                                                                                                                                                                                                 |
|--------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **experimental/experiment-designer** | MVE domain knowledge and coaching conventions for the Experiment Designer agent                                                                                                                                                                             |
| **experimental/pptx**                | Shared conventions for PowerPoint Builder agent, subagent, and powerpoint skill                                                                                                                                                                             |
| **shared/hve-core-location**         | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

### Skills

| Name                     | Description                                                                                                                                  |
|--------------------------|----------------------------------------------------------------------------------------------------------------------------------------------|
| **customer-card-render** | Generate customer-card PowerPoint content YAML from Design Thinking canonical artifacts and build using the shared PowerPoint skill pipeline |
| **powerpoint**           | PowerPoint slide deck generation and management using python-pptx with YAML-driven content and styling                                       |
| **video-to-gif**         | Video-to-GIF conversion skill with FFmpeg two-pass optimization                                                                              |
| **vscode-playwright**    | VS Code screenshot capture using Playwright MCP with serve-web for slide decks and documentation                                             |

<!-- END AUTO-GENERATED ARTIFACTS -->

## Install

```bash
copilot plugin install experimental@hve-core
```

## Agents

| Agent               | Description                                                                                                                                                                                              |
|---------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| experiment-designer | Conversational coach that guides users through designing a Minimum Viable Experiment (MVE) with structured hypothesis formation, vetting, and experiment planning - Brought to you by microsoft/hve-core |
| pptx                | Creates, updates, and manages PowerPoint slide decks using YAML-driven content with python-pptx                                                                                                          |
| pptx-subagent       | Executes PowerPoint skill operations including content extraction, YAML creation, deck building, and visual validation                                                                                   |

## Instructions

| Instruction                      | Description                                                                                                                                                                                                                                                 |
|----------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| experiment-designer.instructions | MVE domain knowledge and coaching conventions for the Experiment Designer agent - Brought to you by microsoft/hve-core                                                                                                                                      |
| pptx.instructions                | Shared conventions for PowerPoint Builder agent, subagent, and powerpoint skill                                                                                                                                                                             |
| hve-core-location.instructions   | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

## Skills

| Skill                | Description                                                                                                                                                                         |
|----------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| customer-card-render | Generate customer-card PowerPoint content YAML from Design Thinking canonical artifacts and build using the shared PowerPoint skill pipeline - Brought to you by microsoft/hve-core |
| powerpoint           | PowerPoint slide deck generation and management using python-pptx with YAML-driven content and styling - Brought to you by microsoft/hve-core                                       |
| video-to-gif         | Video-to-GIF conversion skill with FFmpeg two-pass optimization - Brought to you by microsoft/hve-core                                                                              |
| vscode-playwright    | VS Code screenshot capture using Playwright MCP with serve-web for slide decks and documentation - Brought to you by microsoft/hve-core                                             |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

