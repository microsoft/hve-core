---
title: TTS Voice-Over Skill
description: Generate per-slide WAV voice-over files from YAML speaker notes using Azure Speech SDK
sidebar_position: 5
author: Microsoft
ms.date: 2026-04-23
ms.topic: how-to
keywords:
  - tts
  - voice-over
  - azure speech
  - ssml
  - powerpoint
estimated_reading_time: 5
---

The `tts-voiceover` skill generates per-slide WAV voice-over files from YAML speaker notes using the Azure Speech SDK with SSML pronunciation control for technical acronyms.

## Overview

This skill reads `content.yaml` files produced by the PowerPoint skill, extracts `speaker_notes` fields, applies SSML acronym aliases for correct pronunciation, and produces one WAV file per slide. An optional embedding step adds the WAV files back into the PPTX deck as auto-play media objects.

## Prerequisites

| Requirement           | Details                                                               |
|:----------------------|:----------------------------------------------------------------------|
| Azure Speech resource | Free tier provides 500K characters per month                          |
| Python 3.11+          | With [uv](https://docs.astral.sh/uv/) for environment management      |
| Authentication        | Key-based (`SPEECH_KEY`) or Microsoft Entra ID (`SPEECH_RESOURCE_ID`) |

## Setup

### Install Dependencies

```bash
cd .github/skills/experimental/tts-voiceover
uv sync
```

### Configure Authentication

Key-based authentication (simplest):

```bash
export SPEECH_KEY="your-speech-key"
export SPEECH_REGION="eastus"
```

Microsoft Entra ID authentication (requires a custom domain on the Speech resource and `Cognitive Services Speech User` role):

```bash
export SPEECH_RESOURCE_ID="/subscriptions/.../Microsoft.CognitiveServices/accounts/your-resource"
export SPEECH_REGION="eastus"
```

## Usage

### 1. Verify SSML Templates (Dry Run)

Preview the SSML that will be sent to Azure without generating audio:

```bash
uv run scripts/generate_voiceover.py --dry-run --content-dir path/to/content
```

### 2. Generate Voice-Over WAV Files

```bash
uv run scripts/generate_voiceover.py --content-dir path/to/content --output-dir voice-over
```

### 3. Embed Audio into PPTX

Embedding adds WAV files as media objects and injects narration timing XML so
PowerPoint recognizes the audio for video export.

```bash
uv run scripts/embed_audio.py --input deck.pptx --audio-dir voice-over
```

After embedding, use **File > Export > Create a Video > Use Recorded Timings and Narrations** in PowerPoint to produce an MP4 with synchronized audio.

## Cross-Platform Wrappers

Bash and PowerShell wrappers manage the Python virtual environment automatically.

### Bash

```bash
./scripts/generate-voiceover.sh --dry-run --content-dir content
./scripts/embed-audio.sh --input deck.pptx --audio-dir voice-over
```

### PowerShell

```powershell
./scripts/Invoke-GenerateVoiceover.ps1 -DryRun -ContentDir content
./scripts/Invoke-EmbedAudio.ps1 -InputPath deck.pptx -AudioDir voice-over
```

Both wrappers accept `--skip-venv-setup` / `-SkipVenvSetup` to skip `uv sync` when the environment is already initialized.

## Acronym Lexicon

The skill ships with built-in SSML aliases for common technical acronyms (OWASP, SBOM, SLSA, CI/CD, and others). To customize pronunciation, create an `acronyms.yaml` file:

```yaml
acronyms:
  HVE-Core: "H V E Core"
  OWASP: "Oh wasp"
  SBOM: "S Bomb"
```

Lexicon resolution order:

1. `--lexicon` argument
2. `acronyms.yaml` in the content directory
3. Built-in defaults

## Content Directory Structure

The skill expects the same directory structure produced by the PowerPoint skill:

```text
content/
├── slide-001/
│   └── content.yaml    # Must include speaker_notes: field
├── slide-002/
│   └── content.yaml
└── ...
```

## Troubleshooting

| Issue                                      | Solution                                                                  |
|:-------------------------------------------|:--------------------------------------------------------------------------|
| `Set SPEECH_KEY ... or SPEECH_RESOURCE_ID` | Export authentication environment variables                               |
| 401 with Entra ID auth                     | Verify custom domain and `Cognitive Services Speech User` role assignment |
| Empty WAV files                            | Verify `speaker_notes:` is present and non-empty in `content.yaml`        |
| Mispronounced acronyms                     | Add entries to `acronyms.yaml` with phonetic aliases                      |
| Video export shows "No timings recorded"   | Re-embed audio with the latest `embed_audio.py`                           |

## Related Resources

* [SKILL.md](https://github.com/microsoft/hve-core/blob/main/.github/skills/experimental/tts-voiceover/SKILL.md): Full skill reference with parameters and SSML template details
* [Contributing Skills](../contributing/skills.md): Guidelines for contributing skills to HVE Core

---

> Brought to you by microsoft/hve-core

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
