---
name: tts-voiceover
description: 'Text-to-speech voice-over generation from YAML speaker notes using Azure Speech SDK with SSML pronunciation control - Brought to you by microsoft/hve-core'
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
---

# TTS Voice Over Skill

Generates per-slide WAV voice-over files from YAML `speaker_notes` using Azure Speech SDK with SSML pronunciation control.

## Overview

This skill reads `content.yaml` files from a PowerPoint skill content directory, extracts `speaker_notes` fields, applies SSML acronym aliases for correct pronunciation of technical terms, and produces one WAV file per slide. Supports dry-run mode for SSML template verification without Azure credentials.

## Prerequisites

- **Azure Speech resource** — Free tier provides 500K characters per month.
- **Authentication** — Key-based (`SPEECH_KEY`) or Microsoft Entra ID (`SPEECH_RESOURCE_ID`).
- **Python 3.11+** with `uv` for virtual environment management.

### Key-Based Auth

```bash
export SPEECH_KEY="your-speech-key"
export SPEECH_REGION="eastus"
```

### Microsoft Entra ID Auth

Requires a custom domain on the Speech resource and `Cognitive Services Speech User` role.

```bash
export SPEECH_RESOURCE_ID="/subscriptions/.../Microsoft.CognitiveServices/accounts/your-resource"
export SPEECH_REGION="eastus"
```

Install dependencies:

```bash
# run from this skill folder
uv sync
```

## Quick Start

Verify SSML templates without generating audio:

```bash
uv run scripts/generate_voiceover.py --dry-run --content-dir path/to/content
```

Generate voice-over WAV files:

```bash
uv run scripts/generate_voiceover.py --content-dir path/to/content --output-dir voice-over
```

Embed audio into a PPTX deck:

```bash
uv run scripts/embed_audio.py --input deck.pptx --audio-dir voice-over --output deck-narrated.pptx
```

## Parameters Reference

### generate_voiceover.py

| Parameter       | Type   | Default                             | Description                                   |
|:----------------|:-------|:------------------------------------|:----------------------------------------------|
| `--dry-run`     | flag   | `false`                             | Print SSML templates without generating audio |
| `--voice`       | string | `en-US-Andrew:DragonHDLatestNeural` | Azure TTS voice name                          |
| `--rate`        | string | `+10%`                              | Speech prosody rate                           |
| `--content-dir` | path   | `content`                           | Path to slide content directory               |
| `--output-dir`  | path   | `voice-over`                        | Path to WAV output directory                  |
| `--lexicon`     | path   | *(auto-detect)*                     | Custom acronyms.yaml path                     |

### embed_audio.py

Embeds WAV files into corresponding PPTX slides and adds narration timing
XML so PowerPoint recognizes the audio for video export via
**File > Export > Create a Video > Use Recorded Timings and Narrations**.

| Parameter     | Type | Default           | Description                  |
|:--------------|:-----|:------------------|:-----------------------------|
| `--input`     | path | *(required)*      | Source PPTX file path        |
| `--audio-dir` | path | `voice-over`      | Directory with slide-NNN.wav |
| `--output`    | path | `*-narrated.pptx` | Output PPTX file path        |

## Script Reference

Generate with custom voice and rate:

```bash
uv run scripts/generate_voiceover.py \
  --content-dir content \
  --output-dir voice-over \
  --voice "en-US-Jenny:DragonHDLatestNeural" \
  --rate "+5%"
```

Use a custom lexicon:

```bash
uv run scripts/generate_voiceover.py \
  --content-dir content \
  --lexicon custom-acronyms.yaml
```

Embed generated audio:

```bash
uv run scripts/embed_audio.py \
  --input slide-deck/presentation.pptx \
  --audio-dir voice-over \
  --output slide-deck/presentation-narrated.pptx
```

## Acronym Lexicon

The lexicon controls SSML `<sub alias>` replacements for acronyms and technical terms. Create an `acronyms.yaml` file:

```yaml
acronyms:
  HVE-Core: "H V E Core"
  OWASP: "Oh wasp"
  SBOM: "S Bomb"
  SLSA: "Salsa"
  CI/CD: "C I C D"
```

Lexicon resolution order:

1. Path specified via `--lexicon` argument.
2. `acronyms.yaml` in the content directory.
3. Built-in defaults covering common technical acronyms.

## SSML Template

Each slide produces an SSML document:

```xml
<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis"
 xmlns:mstts="http://www.w3.org/2001/mstts" xml:lang="en-US">
  <voice name="en-US-Andrew:DragonHDLatestNeural">
    <prosody rate="+10%">
      Text with <sub alias="Oh wasp">OWASP</sub> aliases applied.
    </prosody>
  </voice>
</speak>
```

## Integration with PowerPoint Skill

This skill reads from the PowerPoint skill's content directory structure:

```text
content/
├── slide-001/
│   └── content.yaml    # Must include speaker_notes: field
├── slide-002/
│   └── content.yaml
└── ...
```

Each `content.yaml` should contain a `speaker_notes:` field with the narration text. The generated WAV files are named `slide-NNN.wav` matching the directory names.

## Troubleshooting

| Issue                                                | Solution                                                                                                                       |
|:-----------------------------------------------------|:-------------------------------------------------------------------------------------------------------------------------------|
| `Set SPEECH_KEY ... or SPEECH_RESOURCE_ID`           | Export `SPEECH_KEY` (key auth) or `SPEECH_RESOURCE_ID` (Entra ID) with `SPEECH_REGION`.                                        |
| 401 with Entra ID auth                               | Verify custom domain on the Speech resource and `Cognitive Services Speech User` role. RBAC propagation takes up to 5 minutes. |
| Empty WAV files or skipped slides                    | Verify `speaker_notes:` is present and non-empty in `content.yaml`.                                                            |
| Mispronounced acronyms                               | Add entries to `acronyms.yaml` with phonetic aliases.                                                                          |
| `azure-cognitiveservices-speech package is required` | Run `uv sync` in the skill directory.                                                                                          |
| Audio icon visible in PPTX                           | Reposition or resize the audio object in PowerPoint after embedding.                                                           |
| Video export shows "No timings recorded"             | Re-embed audio with the updated `embed_audio.py` which adds narration timing XML automatically.                                |

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*

> Brought to you by microsoft/hve-core
