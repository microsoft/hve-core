---
description: "Working-directory, manifest, autonomy, prerequisite, and output contract for HVE demo-material deck and video production."
---

# Demo Material Output Contract

## Publication Boundary

A run produces artifacts into the level working directory and nothing else. It
never publishes, uploads, or distributes a deck or a video in any autonomy mode,
including `full`. Publication is a human decision. A human either publishes the
artifacts by hand or configures a deterministic pipeline that publishes them
outside the agent. The repository's Demo Material Render workflow is such a
pipeline: it publishes a level only after that level's machine-verifiable
criteria pass.

## Working Directory

Use this canonical structure for every requested level:

```text
.copilot-tracking/demo-material/{{YYYY-MM-DD}}/{{level}}/
  research/
  content/
  content/global/
  frames/
  audio/
  clips/
  animation/ # present only under animation: characters
  changes/
  output/
```

`output/segments.yml` paths resolve relative to that manifest file, not the level
directory. Reference sibling directories as `../frames/...` and `../audio/...`,
and set `output` to `./<name>.mp4`. Level-root-relative paths resolve inside
`output/` and fail assembly with a missing-narration error.

The level directory is deliberately passed as the `PowerPoint Subagent` working
directory. It is `.copilot-tracking/ppt`-shaped internally because it contains
the `content/`, `content/global/`, and `changes/` surfaces that the subagent
requires, without duplicating its outputs into a second tracking tree. Pass
`content/`, `content/global/style.yaml`, the level research file, and a
`changes/` execution-log path explicitly on each dispatch.

Store the deck at `output/hve-demo-{{level}}.pptx`, its narrated version at
`output/hve-demo-{{level}}-narrated.pptx` when produced, and the video at
`output/hve-demo-{{level}}.mp4`. Store the manifest at
`output/manifest.yml`.

A scripted render in the hve-core repository also stores a single-file HTML
slide deck at `output/hve-demo-{{level}}.html`, with its offline browser result
in `output/html-deck-check.json`. The deck is generated from the same
`content/` as the PPTX, so the two never diverge. It uses the HVE Slides theme
and presenter controls rather than the house palette, which governs the PPTX and
the video frames.

## Prerequisite Matrix

Azure Speech is the default narration engine outside CI. Piper requires an
explicit local selection. CI selects `narration: none` and needs no voice model,
speech service, or speech credentials; mark both speech prerequisites
`not-required`. Silent runs retain text alternatives and do not claim audio
description or a narrated PPTX.

| Capability                                      | Required prerequisite                                                                                            | Deferred behavior                                                                                                                              |
|-------------------------------------------------|------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------|
| Build and deck operations                       | `uv`, Python 3.11+, and PowerShell 7+                                                                            | Record `uv` or runtime absence as `Deferred`; do not build the deck                                                                            |
| Deterministic deck frame export                 | LibreOffice                                                                                                      | Record `LibreOffice` absence as `Deferred`; do not claim the L100 or L200 visual evidence passed                                               |
| Azure neural narration, `narration: azure` only | `SPEECH_KEY` or `SPEECH_RESOURCE_ID`, plus `SPEECH_REGION`                                                       | Record unavailable authentication or region approval as `Deferred`; do not switch to Piper                                                     |
| Local narration, `narration: piper` only        | The Piper executable (`PIPER_COMMAND` or `piper` on `PATH`) and a downloaded voice                               | Record the missing executable or voice as `Deferred`; do not switch to Azure                                                                   |
| Vision slide check                              | GitHub Copilot CLI, authenticated                                                                                | Required before `validation.deck: pass`; record `Deferred` when unavailable, because property and geometry checks do not inspect rendered text |
| Approved narration voice                        | A caller-named voice, otherwise `en-US-Andrew:DragonHDLatestNeural` for Azure or `en_US-norman-medium` for Piper | Record the selected voice in the manifest; under `manual` and `partial` confirm it, under `full` use the default without prompting             |
| MP4 assembly and visible captions               | Discoverable FFmpeg and ffprobe; FFmpeg exposes the libass-backed `subtitles` filter and `libx264` encoder       | Offer approval-gated setup under attended modes; otherwise record `Deferred` and do not claim an accessible MP4 exists                         |
| Scripted live capture, `capture: live` only     | VS Code CLI, `uv`, the `vscode-playwright` environment, and Playwright Chromium; no MCP server                   | Record the unavailable entrypoint as `Deferred`; preserve live capture and do not substitute deck export                                       |
| Interactive live capture, `capture: live` only  | VS Code CLI, Playwright MCP browser tools, and `curl`                                                            | Defer when the selected interactive path cannot run; missing MCP does not prevent scripted live capture                                        |
| Character animation, `animation: characters`    | Original known-rights character assets, approved dialogue voices, and browser video recording through Playwright | Record the missing capability as `Deferred`; do not silently replace requested animation with `none`                                           |
| Dynamic topic resolution                        | The `rpi-research` skill                                                                                         | Record its absence as `Deferred` for any topic other than `hve-core-general`; do not guess a source set                                        |
| HTML slide deck, scripted renders only          | The hve-core HVE Slides starter, Node.js 24 with npm, and Chromium through `vscode-playwright`                   | Without the starter, skip the deck and record `html_deck: not-applicable`; a missing Node.js or Chromium fails `T-10`                          |

Run the bundled resolver before rendering:

```bash
bash "$DEMO_SKILL_ROOT/scripts/finalize-accessible-video.sh" --check-prerequisites
```

It checks `FFMPEG_COMMAND` and `FFPROBE_COMMAND`, searches `PATH`, and recognizes
the installed skill root rather than requiring an executable script bit.
Set `DEMO_SKILL_ROOT` to the resolved `hve-demo-material` skill directory.
Use Bash on macOS/Linux or WSL2 on Windows with Linux paths and tools; native
PowerShell alone does not run this finalizer. A Windows-native finalization
path is not supported or claimed as tested.

The resolver recognizes
Homebrew's keg-only `ffmpeg-full` locations. On macOS, Homebrew's standard
`ffmpeg` formula omits libass, so use:

```bash
brew install ffmpeg-full
```

On Linux, the resolver selects guidance for `apt-get`, `dnf`, `apk`, or
`pacman` when present. On Windows, open the supported WSL2 Linux distribution
and use its package manager to install Linux FFmpeg and ffprobe, for example
`sudo apt-get update && sudo apt-get install ffmpeg` on Ubuntu/Debian.
Windows-native tools installed through `winget` are not this execution path.
Confirm that the selected build exposes libass subtitles and `libx264`. Under
`manual` and `partial`, run a package-manager command only after explicit
approval, then rerun the resolver and resume. Under `full`, record the
applicable command and set the level to `Deferred` instead of changing the host.

Select the `vscode-playwright` scripted path for unattended or repeatable live
capture. Check its VS Code CLI, `uv`, Playwright environment, and Chromium;
it does not require MCP. Pass the approved plan, workspace, and level output
root to the capture script and record its measured font size and resolution.

For interactive capture, establish availability by attempting browser
navigation, never by inspecting tool names. MCP prefixes vary between hosts,
so an unfamiliar prefix is not evidence of absence. Record an observed failure
and rerun condition without ruling out the supported scripted path. VS Code's
built-in browser tools can reach the page without driving the Web workbench.

For the interactive path, VS Code Web keeps user settings in browser IndexedDB.
Raise rendered text size by setting
`document.body.style.zoom` through the Playwright evaluate tool, then measure the
result with the readability measurement procedure in `curriculum.md`.

## Manifest Schema

Read this schema and copy its structure into `output/manifest.yml`. Values in
angle brackets are placeholders, not literal output.

```yaml
schema_version: 4
level: L100
topic: <topic name; hve-core-general is the default only in the hve-core repository>
source_roots: <researched folders | not-applicable> # not-applicable for a pinned topic
autonomy: <full | partial | manual>
animation: <none | characters> # defaults to none; characters requires explicit caller intent
state: <Complete | Deferred | Blocked> # See State Rules; the Complete condition depends on autonomy
audience: <audience>
target_duration_minutes: <number>
source_resolution: <pinned | dynamic>
research_artifact: <rpi-research artifact path | not-applicable>
sources:
  - path: docs/README.md
    resolution: <pinned | dynamic>
    slide_numbers: [1]
    claim: <supported claim>
    untrusted_content_note: <one-line note | none>
deliverables:
  pptx: output/hve-demo-L100.pptx
  narrated_pptx: <output/hve-demo-L100-narrated.pptx | not-applicable> # not-applicable for none
  mp4: output/hve-demo-L100.mp4 # shows open captions and carries an English selectable caption track
  raw_assembly: output/hve-demo-L100.raw.mp4 # retained clean input; never burn captions over a finalized MP4
  captions: output/hve-demo-L100.vtt
  transcript_page: output/index.html
  open_caption_evidence: output/open-captions.json
  html_deck: <output/hve-demo-L100.html | not-applicable> # scripted renders with the HVE Slides starter
visuals:
  capture_profile: <live | deck-export> # deck-export at L300 or L400 only when the caller supplied it
  transition:
    type: crossfade
    duration_seconds: 0.5
    fade_in: true
    fade_out: true
  animation_evidence: <not-applicable | animation/character-sheet.md and recorded clip paths>
  evidence:
    - capture_id: slide-001
      path: frames/slide-001.jpg
      rendered_font_size_pt: <measured number | not-applicable>
      source_resolution: <width>x<height | not-applicable>
narration:
  engine: <azure | piper | none> # default azure outside CI; CI explicitly selects none
  provider: <Azure AI Speech | Piper | none>
  voice: <approved voice name | not-applicable> # not-applicable for none
  timing_basis: <speech-wav | notes-word-count> # notes-word-count for none
  speaker_voices: # characters only; omit for animation none
    Casey: <approved Casey voice>
    Morgan: <approved Morgan voice>
  scene_audio: # characters only; one entry per canonical content item
    - slide: 1
      speaker: Casey
      voice: <approved Casey voice>
      wav: audio/slide-001.wav
      duration_seconds: <measured WAV duration>
  speech_region: <approved region name | not-applicable> # only applicable under azure
  total_word_count: <number> # summed across authored speaker notes
  measured_duration_minutes: <number> # measured from the produced MP4, for example with ffprobe
  contract_duration_minutes:
    min: <number>
    max: <number>
  audio_files:
    - audio/slide-001.wav # internal silent timing only when engine is none; not published
validation:
  deck: <pass | fail | deferred>
  video: <pass | fail | deferred>
  acceptance_criteria:
    - id: <instantiated criterion ID>
      template: <criterion template ID from curriculum>
      criterion: <atomic criterion instantiated for this topic>
      evidence: <slide number, source-register claim, capture ID, or segment path>
      result: <pass | fail | deferred | not-applicable> # not-applicable only in the case the curriculum permits
prerequisites:
  uv: <available | missing>
  libreoffice: <available | missing | not-required>
  ffmpeg: <available | missing>
  azure_speech: <available | missing | not-required>
  piper: <available | missing | not-required>
  playwright: <available | missing | not-required>
  rpi_research: <available | missing | not-required>
approvals:
  storyboard: <approved | auto | pending>
  capture_plan: <approved | auto | not-required | pending>
  delivery: <approved | auto-accepted | pending> # approved means a human approved; auto-accepted means full autonomy accepted on evidence alone
deferred_items: []
blocked_items: []
evidence:
  research: research/source-register.md
  execution_logs: []
  video_manifest: output/segments.yml
```

## State Rules

* Assemble to the retained raw MP4, then invoke the finalizer through Bash.
  It stages WebVTT, the finalized MP4, evidence bound to the raw source, and
  transcript before installing a complete delivery with rollback on failure.
  Missing raw input requires reassembly; missing evidence never permits
  burning over an existing finalized picture.
* Finalization supports canonical content/WAV order and full WAV durations.
  Other assembler segment orders, narration sources, or trimmed durations
  require a different caption timeline and are rejected here. Silent handles
  are added by the assembler; do not manually pad canonical narration WAVs.
* Under `manual` and `partial`, use `Complete` only when every requested
  deliverable is present, every acceptance criterion records `pass` or a
  permitted `not-applicable` with recorded evidence, and `approvals.delivery:
  approved` came from a human.
* Under `full`, use `Complete` only when every requested deliverable exists,
  every instantiated acceptance criterion for the level records `pass` or a
  permitted `not-applicable`, `validation.deck` and `validation.video` both
  record `pass`, and `approvals.delivery: auto-accepted`. Machine-verifiable
  acceptance replaces the human delivery approval here; it never claims one
  occurred. A `deferred` or `fail` validation result cannot satisfy `Complete`
  under `full`, because no human is present to notice it.
* Record `narration.total_word_count`, `narration.measured_duration_minutes`,
  and `narration.contract_duration_minutes` for every produced level. The
  measured duration is the evidence `T-07` scores against the contract range,
  and the word count paired with it is what lets a later run recompute the
  speaking rate from produced evidence instead of re-deriving it.
* Record `not-applicable` as an acceptance-criterion result only for `T-05` and
  `T-06` at a level the caller moved to `capture: deck-export`, and name that
  downgrade as the reason. It is never valid under `capture: live`, where an
  unmet live-capture criterion records `fail` or `deferred`. It is never valid
  for `T-07` or `T-08` under any profile, because every level produces both an
  MP4 and a deck. Honesty holds because `visuals.capture_profile: deck-export`
  and the visibly not-applicable criteria keep a downgraded run distinguishable
  from a live capture run.
* Never record `approvals.delivery: approved` without a human decision. The
  `auto-accepted` value exists so an unattended `full` run can never be mistaken
  for a human-reviewed deliverable.
* Record `visuals.capture_profile` as the profile actually in force. A level
  never lowers its own capture profile; only a caller-supplied `capture` value
  changes it. When `live` is in force and the live-capture prerequisite is
  missing, use `Deferred` and name the unavailable entrypoint in
  `deferred_items` rather than exporting deck frames in its place.
* Use `Deferred` when a prerequisite, a resolvable source set, or a required
  human approval is missing but the work can resume without discarding completed
  evidence. Under `manual` and `partial`, a pending delivery approval requires
  `Deferred`; resume by obtaining final delivery approval and updating
  `approvals.delivery` to `approved`. Under `full`, any criterion that records
  neither `pass` nor a permitted `not-applicable` requires `Deferred` with the
  shortfall named in `deferred_items`.
* Use `Blocked` when evidence contradicts the planned content, a validation
  error remains unresolved, or a capture cannot be reproduced.
* Keep credential values out of the manifest. Record only the selected
  authentication posture and prerequisite state.
