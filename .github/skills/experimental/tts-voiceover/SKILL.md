---
name: tts-voiceover
description: 'Text-to-speech voice-over generation from YAML speaker notes using Azure AI Speech neural voices with SSML pronunciation control'
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
---

# TTS Voice Over Skill

Generates per-slide WAV voice-over files from YAML `speaker_notes` using Azure AI Speech neural voices with SSML pronunciation control.

## Overview

This skill reads `content.yaml` files from a PowerPoint skill content directory, extracts `speaker_notes` fields, applies acronym aliases for correct pronunciation of technical terms, and produces one WAV file per slide. Supports dry-run mode for SSML template verification without Azure credentials.

Synthesis uses Azure AI Speech neural voices, including the HD voices such as `en-US-Andrew:DragonHDLatestNeural`. HD voices are offered in a subset of Azure regions; check the [Speech service regions](https://learn.microsoft.com/azure/ai-services/speech-service/regions) before choosing `SPEECH_REGION`.

Narration produced by this skill is synthetic. Tell listeners that the voice is AI-generated, following Microsoft's [disclosure design guidelines for synthetic voices](https://learn.microsoft.com/azure/foundry/responsible-ai/speech-service/text-to-speech/concepts-disclosure-guidelines).

## Prerequisites

* **Azure Speech resource**: see [Azure AI Speech pricing](https://azure.microsoft.com/pricing/details/speech/) for the free-tier allowance and HD voice rates.
* **Authentication**: Microsoft Entra ID (`SPEECH_RESOURCE_ID`, recommended) or a resource key (`SPEECH_KEY`).
* **Region**: `SPEECH_REGION` is required for synthesis and has no default. Dry-run mode does not need it.
* **Python 3.11+** with `uv` for virtual environment management.
* **Data handling note**: Speaker-notes content is transmitted to the configured `SPEECH_REGION` for synthesis. For prebuilt neural voices, Microsoft states that neither the input text nor the output audio is stored in Microsoft logs; see [Data, privacy, and security for text to speech](https://learn.microsoft.com/azure/foundry/responsible-ai/speech-service/text-to-speech/data-privacy-security). Operators must still set an approved region and avoid sending regulated or confidential narration.

### Microsoft Entra ID Auth (Recommended)

Entra ID avoids storing a long-lived key. It requires a custom domain on the Speech resource and the `Cognitive Services Speech User` role for the signed-in identity. The script resolves the identity through `DefaultAzureCredential`, so an `az login` session, a managed identity, or a GitHub Actions OIDC login through `azure/login` all work.

```bash
export SPEECH_RESOURCE_ID="/subscriptions/.../Microsoft.CognitiveServices/accounts/your-resource"
export SPEECH_REGION="eastus"
```

### Key-Based Auth

```bash
export SPEECH_KEY="your-speech-key"
export SPEECH_REGION="eastus"
```

When both `SPEECH_KEY` and `SPEECH_RESOURCE_ID` are set, the script warns and uses the key. Unset `SPEECH_KEY` to use Entra ID.

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

| Parameter             | Type   | Default                             | Description                                                                                |
|:----------------------|:-------|:------------------------------------|:-------------------------------------------------------------------------------------------|
| `--dry-run`           | flag   | `false`                             | Print SSML without generating audio                                                        |
| `--voice`             | string | `en-US-Andrew:DragonHDLatestNeural` | Azure AI Speech voice name                                                                 |
| `--rate`              | string | `+10%`                              | Speech prosody rate                                                                        |
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

Each WAV file maps to a slide by the number in its name, so `slide-1.wav` and `slide-001.wav` both map to slide 1. When two files map to the same slide, embedding stops with an error and writes no output. WAV files numbered past the last slide are ignored with a warning. An unreadable WAV file is reported, its slide is left unchanged, and the remaining slides are still embedded.

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
| `SPEECH_REGION must be set`                          | Export `SPEECH_REGION` with an approved Azure region. Synthesis has no default region.                                                                                    |
| `Multiple WAV files map to slide N`                  | Remove the duplicate WAV files (for example `slide-1.wav` beside `slide-001.wav`) and rerun `embed_audio.py`.                                                             |
| 401 with Entra ID auth                               | Verify custom domain on the Speech resource and `Cognitive Services Speech User` role. RBAC propagation takes up to 5 minutes.                                            |
| Empty WAV files or skipped slides                    | Verify `speaker_notes:` is present and non-empty in `content.yaml`.                                                                                                       |
| Mispronounced acronyms                               | Add entries to `acronyms.yaml` with phonetic aliases.                                                                                                                     |
| `azure-cognitiveservices-speech package is required` | Run `uv sync` in the skill directory.                                                                                                                                     |
| Audio icon visible in PPTX                           | Reposition or resize the audio object in PowerPoint after embedding.                                                                                                      |
| Authored slide animations missing after embedding    | `embed_audio.py` replaces existing `p:timing` with narration timing; re-apply animations in PowerPoint after embedding audio.                                             |
| Slides no longer advance on click after embedding    | `embed_audio.py` sets `advClick="0"` for auto-advance. To re-enable, select all slides in PowerPoint and check **Advance Slide > On Mouse Click** in the Transitions tab. |
| Video export shows "No timings recorded"             | Re-embed audio with the updated `embed_audio.py` which adds narration timing XML automatically.                                                                           |

