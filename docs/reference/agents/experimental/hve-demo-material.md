---
title: HVE Demo Material Builder
description: "Orchestrates levelled L100-L400 training decks and narrated MP4 demos for any repository topic, attended or unattended, with HVE Core as the default in the hve-core repository. Use when producing levelled repository demo material."
sidebar_position: 2
author: Microsoft
ms.date: 2026-09-28
ms.topic: reference
keywords:
  - agent
  - experimental
  - hve-demo-material
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                              |
|-------------|--------------------------------------------------------------------|
| Kind        | agent                                                              |
| Source      | `.github/agents/experimental/hve-demo-material.agent.md`           |
| Invocation  | Selected from the chat agent picker as `HVE Demo Material Builder` |
| Interactive | Yes                                                                |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Orchestrates levelled L100-L400 training decks and narrated MP4 demos for any repository topic, attended or unattended, with HVE Core as the default in the hve-core repository. Use when producing levelled repository demo material.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use HVE Demo Material Builder to produce a levelled training deck and narrated
video for HVE Core or another named repository topic, from an L100 introduction
for first-time users to an L400 deep dive for maintainers. It sources every
claim from repository documentation, keeps the house style, and scores each
level against its duration and accessibility criteria. Use PowerPoint Builder
for a single deck without narration or level contracts, and a documentation
workflow when you need written reference rather than presentation material.

## How to use it

1. Select `HVE Demo Material Builder` and name the levels, the topic (default
   `hve-core-general`), and the autonomy mode (`manual`, `partial`, or `full`).
2. Choose the narration engine. Azure AI Speech is the default and needs Speech
   credentials; pass `narration: piper` for the offline Piper voice.
3. Review the storyboard and speaker notes when the autonomy mode asks for it.
   The notes are also the captions and the transcript, so they voice every
   on-screen claim.
4. Inspect the deck, the captioned MP4, the transcript page, and the manifest
   in the level's `output/` folder. The agent never publishes; publication
   happens by hand or through the repository's Demo Material Render workflow.

## Example usage

Ask: "Create the L100 demo deck and narrated video for HVE Core with Piper
narration, and show me the storyboard before rendering."

Expect `hve-demo-L100.pptx`, a captioned `hve-demo-L100.mp4`, a `.vtt` captions
file, a transcript page, and `manifest.yml` under
`.copilot-tracking/demo-material/<date>/L100/output/`. Success means every
criterion in the manifest records `pass` and the measured video length falls
inside the level's 4 to 6 minute contract.
