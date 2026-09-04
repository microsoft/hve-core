---
title: demo-video
description: Assemble ordered frames or clips with narration into a narrated MP4 via FFmpeg
sidebar_position: 4
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - skill
  - experimental
  - demo-video
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                        |
|-------------|------------------------------------------------------------------------------|
| Kind        | skill                                                                        |
| Source      | `.github/skills/experimental/demo-video`                                     |
| Invocation  | Invoked directly as `/demo-video`, or loaded on demand by referencing agents |
| Interactive | No                                                                           |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Assemble ordered frames or clips with narration into a narrated MP4 via FFmpeg
<!-- END AUTO-GENERATED: overview -->

## When to use it

<!-- asset-docs:stub -->
Use this skill to assemble a first-pass walkthrough from ordered prototype
frames or short screen-recording clips and matching narration WAV files. It is
particularly useful for Design Thinking demos: `vscode-playwright` can provide
the captured visuals and `tts-voiceover` can provide the narration that is
combined into the final MP4.

Choose a `frame` segment for a still image and a `clip` segment for motion. Use
the manifest when you need deterministic ordering, per-segment durations, or
shared output settings such as resolution and frame rate.

Reach for a dedicated video editor when the work needs a multi-track timeline,
transitions, color grading, or other production-editing features beyond
ordered assembly and narration.

## Example usage

<!-- asset-docs:stub -->
Create an `examples/segments.yml` manifest alongside the visual and audio
inputs:

```yaml
output: ./output/demo.mp4
resolution: 1280x720
fps: 24
segments:
  - type: frame
    visual: ./frames/intro.png
    narration: ./audio/intro.wav
    duration: 4.5
  - type: clip
    clip: ./clips/interaction.mp4
    narration: ./audio/interaction.wav
```

Run the assembler from the skill directory:

```bash
scripts/assemble-video.sh --manifest examples/segments.yml --output ./output/demo.mp4
```

The result is `output/demo.mp4`, a 1280x720 narrated MP4 assembled from the
ordered frame and clip segments. On Windows, use the equivalent PowerShell
wrapper:

```powershell
scripts/Invoke-AssembleVideo.ps1 -ManifestPath examples/segments.yml -OutputPath ./output/demo.mp4
```
