---
name: demo-video
description: 'Assemble ordered frames or clips with narration into a narrated MP4 via FFmpeg'
license: MIT
compatibility: 'Requires FFmpeg on PATH'
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-07-06"
---

# Demo Video Assembly Skill

This skill assembles a narrated demo video from ordered visual segments and matching narration audio. It is designed for first-pass walkthrough videos that combine captured prototype frames or clips with per-segment voiceover WAV files.

## Overview

The workflow takes a manifest that describes each segment, resolves the visual source, and uses FFmpeg to render each segment into a normalized video clip before concatenating them into a final MP4. The narration track is muxed from WAV files so the output can be reviewed as a polished walkthrough without requiring a separate video-editing tool.

## Manifest Schema

Use a `segments.yml` manifest with an ordered list of segments. Each entry describes a visual source and the narration audio to combine for that portion of the video.

```yaml
segments:
  - type: frame
    visual: ./frames/intro.png
    narration: ./audio/intro.wav
    duration: 4.5
  - type: clip
    clip: ./clips/interaction.mp4
    narration: ./audio/interaction.wav
```

### Segment fields

* `type` identifies whether the segment is a still image (`frame`) or a motion clip (`clip`)
* `visual` points to an image file for a frame segment
* `clip` points to a motion clip file for a clip segment
* `narration` points to the WAV file generated from narration text (the script also accepts `narration_wav` as an alias)
* `duration` is optional and overrides the inferred duration when you want a fixed segment length

## Quick Start

Use the planned bash or PowerShell wrappers to invoke the assembler from the skill directory.

```bash
scripts/assemble-video.sh --manifest examples/segments.yml --output ./output/demo.mp4
```

```powershell
scripts/Invoke-AssembleVideo.ps1 -ManifestPath examples/segments.yml -OutputPath ./output/demo.mp4
```

## Parameters Reference

The assembly step accepts the following high-level controls:

* `--manifest` or `-ManifestPath` selects the YAML manifest to process
* `--output` or `-OutputPath` sets the destination MP4 path
* `--fps` or `-Fps` controls the output frame rate for rendered segments
* `--resolution` or `-Resolution` controls the output width and height in the form `WIDTHxHEIGHT`
* `duration` per segment lets you override the inferred length when narration timing is known in advance

## Reuse Bridge

This skill is intentionally designed to fit into the existing media workflow:

* `tts-voiceover` provides the narration WAV files that this skill muxes into the final output
* `vscode-playwright` provides the frame-capture source for prototype walkthroughs and screen-based demos

## Prerequisites

FFmpeg and ffprobe must be available on your PATH.

### Linux

```bash
sudo apt update && sudo apt install ffmpeg
```

### macOS

```bash
brew install ffmpeg
```

### Windows

```powershell
winget install FFmpeg.FFmpeg
```
