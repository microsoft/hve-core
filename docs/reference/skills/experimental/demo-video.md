---
title: demo-video
description: Assemble ordered frames or clips with narration into a narrated MP4 via FFmpeg
sidebar_position: 4
author: Microsoft
ms.date: 2026-09-09
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

Use this skill when ordered screenshots or clips and matching WAV narration are
ready to assemble into a walkthrough MP4. It normalizes segments with FFmpeg and
concatenates them; it does not capture the screens or generate the voiceover.
Use `vscode-playwright` for capture, `tts-voiceover` for narration, or `video-to-gif`
when the desired output is a silent animated GIF.

FFmpeg and ffprobe must be on PATH. Manifest-relative paths make the visual and
audio inputs portable as one local package.

## Example usage

Ask: `/demo-video Assemble this sample segments.yml into output/walkthrough.mp4
at 1280x720 and 24 fps.` The illustrative manifest contains an introductory `frame`
with `visual: frames/intro.png` and `narration: audio/intro.wav`, followed by a
`clip` with `clip: clips/search.mp4` and its matching narration WAV. Paths resolve
relative to the manifest; a segment's optional `duration` overrides inferred timing.

Expect normalized clips and a final MP4 in the requested order. Success is a
playback review confirming readable frames, correct narration alignment, and the
intended duration, not merely an output file's existence. Use approved media with
no visible credentials or personal data. Offline synthetic speech can support a
no-network smoke test, but the source recommends neural narration for shareable
output; generating it is a separate service-backed step.
