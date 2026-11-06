---
title: hve-demo-material
description: "Create levelled demo decks and narrated MP4s for any repository topic, with HVE Core as the default in the hve-core repository. Use when training or demo material is needed for L100 through L400 audiences."
sidebar_position: 6
author: Microsoft
ms.date: 2026-10-02
ms.topic: reference
keywords:
  - skill
  - experimental
  - hve-demo-material
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                               |
|-------------|-------------------------------------------------------------------------------------|
| Kind        | skill                                                                               |
| Source      | `.github/skills/experimental/hve-demo-material`                                     |
| Invocation  | Invoked directly as `/hve-demo-material`, or loaded on demand by referencing agents |
| Interactive | No                                                                                  |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Create levelled demo decks and narrated MP4s for any repository topic, with HVE Core as the default in the hve-core repository. Use when training or demo material is needed for L100 through L400 audiences.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill when training or demo material is needed at a defined depth: it
holds the L100 to L400 level contracts, the pinned sources and topic resolution
rules, the house style, the output contract, and the criterion templates each
level is scored against. The HVE Demo Material Builder agent applies it
interactively; `scripts/render-level.sh` applies it without an agent, which is
how the repository's weekly workflows rebuild the published material.

Rendering needs `uv`, Python 3.11+, LibreOffice, and FFmpeg, plus either Azure
Speech credentials or the Piper executable and voice. L300 and L400 live
captures also need the VS Code CLI and Chromium. In the hve-core repository the
script also builds a single-file HTML slide deck, which needs Node.js 24.

## Example usage

Render an authored level from the repository root:

```bash
bash .github/skills/experimental/hve-demo-material/scripts/render-level.sh \
  --level L100 \
  --level-dir .copilot-tracking/demo-material/2026-09-24/L100 \
  --workspace "$PWD" \
  --narration piper
```

Expect the deck, a captioned MP4, a WebVTT file, a transcript page, and, in
this repository, `hve-demo-L100.html` under the level's `output/` folder, plus
`output/render-result.json`. Success means `"ok": true`, with every scored
criterion from `T-04` through `T-10` recording `pass`.
