---
title: tts-voiceover
description: Text-to-speech voice-over generation from YAML speaker notes using Azure Speech SDK with SSML pronunciation control
sidebar_position: 7
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - experimental
  - tts-voiceover
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                           |
|-------------|---------------------------------------------------------------------------------|
| Kind        | skill                                                                           |
| Source      | `.github/skills/experimental/tts-voiceover`                                     |
| Invocation  | Invoked directly as `/tts-voiceover`, or loaded on demand by referencing agents |
| Interactive | No                                                                              |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Text-to-speech voice-over generation from YAML speaker notes using Azure Speech SDK with SSML pronunciation control
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill to produce per-slide WAV narration from PowerPoint content YAML's
`speaker_notes`, with SSML aliases for technical terms. Choose dry-run to inspect
SSML without Azure credentials or audio generation. Live synthesis requires
Python 3.11+, `uv`, an Azure Speech resource, authentication, and an approved region.

Speaker notes are transmitted to the configured `SPEECH_REGION`. Do not send
confidential or regulated narration, and keep authentication values out of chat.
Use `demo-video` to assemble audio with visuals after narration is ready.

## Example usage

Ask: `/tts-voiceover Dry-run the synthetic speaker notes in content/ using
content/acronyms.yaml. Inspect SSML only; do not synthesize audio.` Provide slide
directories such as `slide-001/content.yaml` with nonempty `speaker_notes` and a
lexicon mapping `CI/CD` to a spoken alias. Expect SSML with the intended voice,
rate, and substitutions. Success at this stage is correct template output, not
a generated WAV or verified pronunciation.

After region and authentication are configured separately, an authorized synthesis
request can produce matching `slide-NNN.wav` files. Listen for pronunciation and
pauses; `--collapse-newlines` is useful when block-scalar wrapping should not become
spoken pauses. Embedding into a separate narrated PPTX is another step: the script
replaces existing timing and disables click advancement, so review animations and
playback rather than overwriting an authored deck without checking.
