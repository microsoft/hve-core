---
title: video-to-gif
description: Video-to-GIF conversion with FFmpeg two-pass optimization
sidebar_position: 8
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - experimental
  - video-to-gif
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                          |
|-------------|--------------------------------------------------------------------------------|
| Kind        | skill                                                                          |
| Source      | `.github/skills/experimental/video-to-gif`                                     |
| Invocation  | Invoked directly as `/video-to-gif`, or loaded on demand by referencing agents |
| Interactive | No                                                                             |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Video-to-GIF conversion with FFmpeg two-pass optimization
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill for a short, silent animation of an existing video, such as a UI
interaction for documentation. Its default two-pass process generates and applies
a palette; single-pass trades color quality for speed. Frame rate, width, time
range, dithering, and loop behavior are configurable. Use `demo-video` instead
when narration and an MP4 are required.

FFmpeg must be available, with ffprobe used for HDR detection. Explicit input and
output paths avoid selecting the wrong similarly named recording.

## Example usage

Ask: `/video-to-gif Convert seconds 5 through 15 of the attached synthetic UI
recording to output/search-demo.gif, 640 pixels wide at 10 fps. Keep two-pass
palette generation.` On Windows, these inputs map to the skill's `convert.ps1`
parameters `-InputPath`, `-OutputPath`, `-Start 5`, `-Duration 10`, `-Width 640`,
and `-Fps 10`.

Expect a linked GIF with proportional height and the selected interaction only.
Success includes visual inspection for readable text, acceptable colors, timing,
and file size. HDR footage is tone-mapped; `-Tonemap` can select a different
algorithm when needed. Keep recordings free of secrets and personal information,
confirm before replacing an existing output, and do not promise a fixed compression
ratio before inspecting the result.
