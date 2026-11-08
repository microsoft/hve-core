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

Rendering requires the packaged HVE Slides skill, Node.js 24+, `uv`, Python
3.11+, Chromium and FFmpeg. HTML is mandatory in repository and installed use.
L300/L400 live captures also require the VS Code CLI. Narrated output needs
approved Azure Speech authentication and region; `narration: none` needs neither.

## Example usage

Render an authored level from the repository root:

```bash
bash .github/skills/experimental/hve-demo-material/scripts/render-level.sh \
  --level L100 \
  --level-dir .copilot-tracking/demo-material/2026-09-24/L100 \
  --workspace "$PWD" \
  --slides-skill-root "$PWD/.github/skills/experimental/hve-slides"
```

For installed use, resolve HVE Slides by name and pass its loaded root instead
of the repository example path. Expect required HTML, raw/final MP4, WebVTT,
transcript, manifest6 and hash-bound HTML/frame evidence under the level's
output tree. Render-result2 must record passing machine checks, including T-10
for every level and T-11 for silent output. Machine success does not replace
visual review or the active autonomy mode's delivery approval.
