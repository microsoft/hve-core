<!-- markdownlint-disable-file -->
# Experimental

Experimental and preview artifacts not yet promoted to stable collections

> **⚠️ Experimental** — This collection is experimental. Contents and behavior may change or be removed without notice.

## Overview

Experimental and preview artifacts not yet promoted to stable collections. Items in this collection may change or be removed without notice.

## Included Artifacts

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

### Chat Agents

| Name                    | Description                                                                                                                                                       |
|-------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **experiment-designer** | Conversational coach that guides users through designing a Minimum Viable Experiment (MVE) with structured hypothesis formation, vetting, and experiment planning |
| **pptx**                | Creates, updates, and manages PowerPoint slide decks using YAML-driven content with python-pptx                                                                   |
| **pptx-subagent**       | Executes PowerPoint skill operations including content extraction, YAML creation, deck building, and visual validation                                            |

### Prompts

| Name               | Description                                                                                          |
|--------------------|------------------------------------------------------------------------------------------------------|
| **cspell-config**  | Creates or updates the project cspell configuration with project-specific words and ignores          |
| **graph-research** | Research a codebase using an existing graphify knowledge graph, with audit-tagged evidence reporting |

### Instructions

| Name                                           | Description                                                                                                                                                                                                                                                 |
|------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **experimental/experiment-designer**           | MVE domain knowledge and coaching conventions for the Experiment Designer agent                                                                                                                                                                             |
| **experimental/graphify**                      | Conventions for consuming graphify-out/ knowledge-graph evidence inside the RPI workflow                                                                                                                                                                    |
| **experimental/mural/mural-bootstrap**         | Fresh-session Mural bootstrap requirements for doctor checks, credential backend selection, and safe escalation before Mural tool use.                                                                                                                      |
| **experimental/mural/mural-destinations**      | Open destination registry for Mural extractor writeback: registered adapters, intent axis, and per-destination loop-closure metrics.                                                                                                                        |
| **experimental/mural/mural-human-record**      | Mural is the durable record of human conversation; AI never silently authors decisions and AI contribution must remain visible somewhere durable.                                                                                                           |
| **experimental/mural/mural-log-hygiene**       | Operator log-hygiene contract for Mural customizations: never echo raw URLs, Azure SAS query strings, OAuth tokens, or Authorization headers; the skill _redact() is a defense-in-depth backstop, not a license to log.                                     |
| **experimental/mural/mural-seeding-patterns**  | Cross-cutting Mural seeding conventions: duplicate-then-populate, source-artifact-to-area binding, anchor inheritance, probe-before-bulk, z-order visibility (detection-only), layout primitives applied across DT, RAI, and UX/UI workflows.               |
| **experimental/mural/mural-writeback-hygiene** | Writeback hygiene rules for Mural: tags, hyperlinks, and parentId are the only stable channels; reserved tags are protected; tag manifests are re-applied defensively.                                                                                      |
| **experimental/mural/mural-writing-style**     | Asymmetric writing style for Mural: outbound (writing into Mural) is sticky-concise; inbound (extracting from Mural) is context-hydrated.                                                                                                                   |
| **experimental/pptx**                          | Shared conventions for PowerPoint Builder agent, subagent, and powerpoint skill                                                                                                                                                                             |
| **shared/hve-core-location**                   | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

### Skills

| Name                     | Description                                                                                                                                                                           |
|--------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **customer-card-render** | Generate customer-card PowerPoint content YAML from Design Thinking canonical artifacts and build using the shared PowerPoint skill pipeline                                          |
| **mural**                | Mural workspace, room, mural, and widget workflows via the Mural REST API exposed through a Python CLI. Use when you need to read or write Mural content or automate widget creation. |
| **powerpoint**           | PowerPoint slide deck generation and management using python-pptx with YAML-driven content and styling                                                                                |
| **tts-voiceover**        | Text-to-speech voice-over generation from YAML speaker notes using Azure Speech SDK with SSML pronunciation control                                                                   |
| **video-to-gif**         | Video-to-GIF conversion skill with FFmpeg two-pass optimization                                                                                                                       |
| **vscode-playwright**    | VS Code screenshot capture using Playwright MCP with serve-web for slide decks and documentation                                                                                      |

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

## Commands

| Command        | Description                                                                                                                                 |
|----------------|---------------------------------------------------------------------------------------------------------------------------------------------|
| cspell-config  | Creates or updates the project cspell configuration with project-specific words and ignores                                                 |
| graph-research | Research a codebase using an existing graphify knowledge graph, with audit-tagged evidence reporting - Brought to you by microsoft/hve-core |

## Instructions

| Instruction                          | Description                                                                                                                                                                                                                                                 |
|--------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| experiment-designer.instructions     | MVE domain knowledge and coaching conventions for the Experiment Designer agent - Brought to you by microsoft/hve-core                                                                                                                                      |
| graphify.instructions                | Conventions for consuming graphify-out/ knowledge-graph evidence inside the RPI workflow - Brought to you by microsoft/hve-core                                                                                                                             |
| pptx.instructions                    | Shared conventions for PowerPoint Builder agent, subagent, and powerpoint skill                                                                                                                                                                             |
| mural-bootstrap.instructions         | Fresh-session Mural bootstrap requirements for doctor checks, credential backend selection, and safe escalation before Mural tool use.                                                                                                                      |
| mural-destinations.instructions      | Open destination registry for Mural extractor writeback: registered adapters, intent axis, and per-destination loop-closure metrics.                                                                                                                        |
| mural-human-record.instructions      | Mural is the durable record of human conversation; AI never silently authors decisions and AI contribution must remain visible somewhere durable.                                                                                                           |
| mural-log-hygiene.instructions       | Operator log-hygiene contract for Mural customizations: never echo raw URLs, Azure SAS query strings, OAuth tokens, or Authorization headers; the skill _redact() is a defense-in-depth backstop, not a license to log.                                     |
| mural-seeding-patterns.instructions  | Cross-cutting Mural seeding conventions: duplicate-then-populate, source-artifact-to-area binding, anchor inheritance, probe-before-bulk, z-order visibility (detection-only), layout primitives applied across DT, RAI, and UX/UI workflows.               |
| mural-writeback-hygiene.instructions | Writeback hygiene rules for Mural: tags, hyperlinks, and parentId are the only stable channels; reserved tags are protected; tag manifests are re-applied defensively.                                                                                      |
| mural-writing-style.instructions     | Asymmetric writing style for Mural: outbound (writing into Mural) is sticky-concise; inbound (extracting from Mural) is context-hydrated.                                                                                                                   |
| hve-core-location.instructions       | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

## Skills

| Skill                | Description                                                                                                                                                                                                                  |
|----------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| customer-card-render | Generate customer-card PowerPoint content YAML from Design Thinking canonical artifacts and build using the shared PowerPoint skill pipeline - Brought to you by microsoft/hve-core                                          |
| powerpoint           | PowerPoint slide deck generation and management using python-pptx with YAML-driven content and styling - Brought to you by microsoft/hve-core                                                                                |
| tts-voiceover        | Text-to-speech voice-over generation from YAML speaker notes using Azure Speech SDK with SSML pronunciation control - Brought to you by microsoft/hve-core                                                                   |
| video-to-gif         | Video-to-GIF conversion skill with FFmpeg two-pass optimization - Brought to you by microsoft/hve-core                                                                                                                       |
| vscode-playwright    | VS Code screenshot capture using Playwright MCP with serve-web for slide decks and documentation - Brought to you by microsoft/hve-core                                                                                      |
| mural                | Mural workspace, room, mural, and widget workflows via the Mural REST API exposed through a Python CLI. Use when you need to read or write Mural content or automate widget creation. - Brought to you by microsoft/hve-core |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

