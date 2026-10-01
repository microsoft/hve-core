---
name: tts-voiceover
description: 'Text-to-speech voice-over generation from YAML speaker notes using Azure Speech SDK with SSML pronunciation control, or an offline Piper engine that needs no credentials'
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
---

# TTS Voice Over Skill

Generates per-slide WAV voice-over files from YAML `speaker_notes` using Azure Speech SDK with SSML pronunciation control, or a locally installed Piper engine.

## Overview

This skill reads `content.yaml` files from a PowerPoint skill content directory, extracts `speaker_notes` fields, applies acronym aliases for correct pronunciation of technical terms, and produces one WAV file per slide. Supports dry-run mode for SSML template verification without Azure credentials.

Two engines are available through `--engine`:

* `azure` (default) sends SSML to Azure AI Speech neural voices. Use it for published narration.
* `piper` runs a separately installed [Piper](https://github.com/OHF-Voice/piper1-gpl) executable on the local machine. It needs no credentials or network access after the voice is downloaded, which suits scheduled CI builds. Narration never leaves the host.

## Prerequisites

* **Azure Speech resource** — Free tier provides 500K characters per month.
* **Authentication** — Key-based (`SPEECH_KEY`) or Microsoft Entra ID (`SPEECH_RESOURCE_ID`).
* **Python 3.11+** with `uv` for virtual environment management.
* **Data handling note** — Speaker-notes content is transmitted to the configured `SPEECH_REGION` for synthesis. Operators must pin an approved region and avoid sending regulated or confidential narration.

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

### Piper Engine

Piper is not a dependency of this skill. It is licensed GPL-3.0-or-later, so the skill invokes it as an external executable, the same way other skills invoke FFmpeg or LibreOffice. Install it and download a voice separately:

```bash
uv tool install piper-tts
uvx --from piper-tts python -m piper.download_voices en_US-joe-medium --data-dir ~/.local/share/piper
export PIPER_DATA_DIR=~/.local/share/piper
```

To run Piper without installing it, also set:

```bash
export PIPER_COMMAND="uvx --from piper-tts piper"
```

| Variable         | Purpose                                                                  |
|:-----------------|:-------------------------------------------------------------------------|
| `PIPER_COMMAND`  | Command that runs Piper, split without a shell (default: `piper`)        |
| `PIPER_DATA_DIR` | Directory holding downloaded voices; `--piper-data-dir` takes precedence |

Voice models carry their own licenses, listed in each voice's `MODEL_CARD`. The default `en_US-joe-medium` is CC0. Check the model card before publishing narration from any other voice, because some Piper voices are non-commercial or require attribution.

## Quick Start

Verify SSML templates without generating audio:

```bash
uv run scripts/generate_voiceover.py --dry-run --content-dir path/to/content
```

Generate voice-over WAV files:

```bash
uv run scripts/generate_voiceover.py --content-dir path/to/content --output-dir voice-over
```

Generate voice-over offline with Piper:

```bash
uv run scripts/generate_voiceover.py --engine piper --collapse-newlines \
  --content-dir path/to/content --output-dir voice-over
```

Embed audio into a PPTX deck:

```bash
uv run scripts/embed_audio.py --input deck.pptx --audio-dir voice-over --output deck-narrated.pptx
```

## Parameters Reference

### generate_voiceover.py

| Parameter             | Type   | Default                             | Description                                                                                |
|:----------------------|:-------|:------------------------------------|:-------------------------------------------------------------------------------------------|
| `--dry-run`           | flag   | `false`                             | Print SSML (`azure`) or plain text (`piper`) without generating audio                      |
| `--engine`            | string | `azure`                             | Synthesis engine: `azure` or `piper`                                                       |
| `--voice`             | string | `en-US-Andrew:DragonHDLatestNeural` | Voice name; the `piper` default is `en_US-joe-medium`                                      |
| `--rate`              | string | `+10%`                              | Azure speech prosody rate; ignored by `piper`                                              |
| `--piper-data-dir`    | path   | `PIPER_DATA_DIR`                    | Directory holding downloaded Piper voices                                                  |
| `--content-dir`       | path   | `content`                           | Path to slide content directory                                                            |
| `--output-dir`        | path   | `voice-over`                        | Path to WAV output directory                                                               |
| `--lexicon`           | path   | *(auto-detect)*                     | Custom acronyms.yaml path                                                                  |
| `--collapse-newlines` | flag   | `false`                             | Collapse newlines and whitespace runs in speaker notes into single spaces before synthesis |
| `--verbose` / `-v`    | flag   | `false`                             | Enable verbose (DEBUG) logging output                                                      |

### embed_audio.py

Embeds WAV files into corresponding PPTX slides and adds narration timing
XML so PowerPoint recognizes the audio for video export via
**File > Export > Create a Video > Use Recorded Timings and Narrations**.

| Parameter          | Type | Default           | Description                           |
|:-------------------|:-----|:------------------|:--------------------------------------|
| `--input`          | path | *(required)*      | Source PPTX file path                 |
| `--audio-dir`      | path | `voice-over`      | Directory with slide-NNN.wav          |
| `--output`         | path | `*-narrated.pptx` | Output PPTX file path                 |
| `--verbose` / `-v` | flag | `false`           | Enable verbose (DEBUG) logging output |

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

Collapse newlines in speaker notes (recommended for block-scalar `|` notes,
whose line breaks are otherwise spoken as pauses):

```bash
uv run scripts/generate_voiceover.py \
  --content-dir content \
  --collapse-newlines
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

The `piper` engine has no SSML support, so it substitutes aliases directly into the text. Aliases written as spaced single letters are hyphenated first (`H V E Core` becomes `H-V-E Core`), because Piper reads hyphenated letters as one fluent run and spaced letters as slow separate words.

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

| Issue                                                | Solution                                                                                                                                                                  |
|:-----------------------------------------------------|:--------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `Set SPEECH_KEY ... or SPEECH_RESOURCE_ID`           | Export `SPEECH_KEY` (key auth) or `SPEECH_RESOURCE_ID` (Entra ID) with `SPEECH_REGION`.                                                                                   |
| 401 with Entra ID auth                               | Verify custom domain on the Speech resource and `Cognitive Services Speech User` role. RBAC propagation takes up to 5 minutes.                                            |
| Empty WAV files or skipped slides                    | Verify `speaker_notes:` is present and non-empty in `content.yaml`.                                                                                                       |
| Mispronounced acronyms                               | Add entries to `acronyms.yaml` with phonetic aliases.                                                                                                                     |
| `azure-cognitiveservices-speech package is required` | Run `uv sync` in the skill directory.                                                                                                                                     |
| `Piper executable not found`                         | Install Piper separately or set `PIPER_COMMAND`, for example `uvx --from piper-tts piper`.                                                                                |
| Piper cannot find the voice model                    | Download the voice with `piper.download_voices` and pass its directory through `--piper-data-dir` or `PIPER_DATA_DIR`.                                                    |
| Audio icon visible in PPTX                           | Reposition or resize the audio object in PowerPoint after embedding.                                                                                                      |
| Authored slide animations missing after embedding    | `embed_audio.py` replaces existing `p:timing` with narration timing; re-apply animations in PowerPoint after embedding audio.                                             |
| Slides no longer advance on click after embedding    | `embed_audio.py` sets `advClick="0"` for auto-advance. To re-enable, select all slides in PowerPoint and check **Advance Slide > On Mouse Click** in the Transitions tab. |
| Video export shows "No timings recorded"             | Re-embed audio with the updated `embed_audio.py` which adds narration timing XML automatically.                                                                           |

