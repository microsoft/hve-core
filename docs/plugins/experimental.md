---
title: Experimental
description: Experimental and preview artifacts not yet promoted to stable packages
sidebar_position: 5
author: Microsoft
ms.date: 2026-08-03
ms.topic: reference
---

Choose this package when you are deliberately evaluating capabilities that have not been promoted to stable packages.

It contains experiment design, presentation, Mural, knowledge-graph, voice-over, video, and VS Code visual-validation capabilities.

> [!WARNING]
> Experimental: components in this package are labeled experimental to disclose their lifecycle posture.

Lifecycle labels are disclosure metadata. In the channel model, both Stable and PreRelease include the same active stable, preview, and experimental content; publication cadence and source ownership can differ.

## Included Artifacts

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

### Chat Agents

| Name                    | Maturity     | Description                                                                                                                                           |
|-------------------------|--------------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| **experiment-designer** | experimental | Coach for designing a Minimum Viable Experiment (MVE) with hypothesis formation, vetting, and experiment planning                                     |
| **pptx**                | experimental | Creates, updates, and manages PowerPoint slide decks using YAML-driven content with python-pptx                                                       |
| **pptx-subagent**       | experimental | Executes PowerPoint skill operations including content extraction, YAML creation, deck building, and visual validation                                |
| **rpi-researcher**      | stable       | Executes one delegated internal, external, or hybrid RPI research lane and progressively writes owned evidence. Use for independent research threads. |

### Prompts

| Name               | Maturity     | Description                                                                                                               |
|--------------------|--------------|---------------------------------------------------------------------------------------------------------------------------|
| **cspell-config**  | experimental | Create or update the project cspell configuration with project words and ignores                                          |
| **graph-research** | experimental | Research a codebase through rpi-research using an existing graphify knowledge graph, with audit-tagged evidence reporting |

### Instructions

| Name                                           | Maturity     | Description                                                                                                                                                                                                                                                 |
|------------------------------------------------|--------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **experimental/experiment-designer**           | experimental | MVE tracking-artifact conventions for session directories, artifact names, and file hygiene; routes MVE methodology to the experiment-design skill                                                                                                          |
| **experimental/graphify**                      | experimental | Conventions for consuming graphify-out/ knowledge-graph evidence inside the RPI workflow                                                                                                                                                                    |
| **experimental/mural/mural-bootstrap**         | experimental | Fresh-session Mural bootstrap requirements for doctor checks, credential backend selection, and safe escalation before Mural tool use.                                                                                                                      |
| **experimental/mural/mural-destinations**      | experimental | Open destination registry for Mural extractor writeback: registered adapters, intent axis, and per-destination loop-closure metrics.                                                                                                                        |
| **experimental/mural/mural-human-record**      | experimental | Mural is the durable record of human conversation; AI never silently authors decisions and AI contribution must remain visible somewhere durable.                                                                                                           |
| **experimental/mural/mural-log-hygiene**       | experimental | Operator log-hygiene contract for Mural customizations: never echo raw URLs, Azure SAS query strings, OAuth tokens, or Authorization headers; the skill _redact() is a defense-in-depth backstop, not a license to log.                                     |
| **experimental/mural/mural-seeding-patterns**  | experimental | Cross-cutting Mural seeding conventions: duplicate-then-populate, source-artifact-to-area binding, anchor inheritance, probe-before-bulk, z-order visibility (detection-only), layout primitives applied across DT, RAI, and UX/UI workflows.               |
| **experimental/mural/mural-writeback-hygiene** | experimental | Writeback hygiene rules for Mural: tags, hyperlinks, and parentId are the only stable channels; reserved tags are protected; tag manifests are re-applied defensively.                                                                                      |
| **experimental/mural/mural-writing-style**     | experimental | Asymmetric writing style for Mural: outbound (writing into Mural) is sticky-concise; inbound (extracting from Mural) is context-hydrated.                                                                                                                   |
| **experimental/pptx**                          | experimental | Shared conventions for PowerPoint Builder agent, subagent, and powerpoint skill                                                                                                                                                                             |
| **shared/hve-core-location**                   | stable       | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

### Skills

| Name                     | Maturity     | Description                                                                                                                                                                                                                                                                                                                              |
|--------------------------|--------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **caveman**              | experimental | Ultra-compressed response style that reduces output token count while preserving technical accuracy, with intensity levels and auto-clarity safety rules                                                                                                                                                                                 |
| **copilot-otel-metrics** | experimental | Set up GitHub Copilot OpenTelemetry capture: configure the VS Code export settings, generate a local Grafana stack and dashboard, or generate the Azure collector, infrastructure, and dashboard for an organization.                                                                                                                    |
| **customer-card-render** | experimental | Generate customer-card PowerPoint content YAML from Design Thinking canonical artifacts and build using the shared PowerPoint skill pipeline                                                                                                                                                                                             |
| **demo-video**           | experimental | Assemble ordered frames or clips with narration into a narrated MP4 via FFmpeg                                                                                                                                                                                                                                                           |
| **experiment-design**    | experimental | Experiment design reference for Minimum Viable Experiment coaching, hypothesis formation, vetting and red flags, and experiment readiness. Use when framing, vetting, scoping, or evaluating an experiment of any kind, including data feasibility, architecture, LLM, performance, use-case, UX, prototyping, and hardware experiments. |
| **mural**                | experimental | Mural workspace, room, mural, and widget workflows via the Mural REST API exposed through a Python CLI. Use when you need to read or write Mural content or automate widget creation.                                                                                                                                                    |
| **powerpoint**           | experimental | PowerPoint slide deck generation and management using python-pptx with YAML-driven content and styling                                                                                                                                                                                                                                   |
| **rpi-research**         | stable       | Research-only RPI playbook that gathers task evidence, writes dated research artifacts under .copilot-tracking/research/, and hands off planning-ready findings. Use when the user needs evidence, alternatives, or task framing first.                                                                                                  |
| **tts-voiceover**        | experimental | Text-to-speech voice-over generation from YAML speaker notes using Azure Speech SDK with SSML pronunciation control                                                                                                                                                                                                                      |
| **video-to-gif**         | experimental | Video-to-GIF conversion with FFmpeg two-pass optimization                                                                                                                                                                                                                                                                                |
| **vscode-playwright**    | experimental | VS Code screenshot capture using Playwright MCP with serve-web for slide decks and documentation                                                                                                                                                                                                                                         |

<!-- END AUTO-GENERATED ARTIFACTS -->

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
