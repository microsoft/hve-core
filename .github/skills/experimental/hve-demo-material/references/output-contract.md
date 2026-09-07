---
description: "Working-directory, manifest, autonomy, prerequisite, and output contract for HVE demo-material deck and video production."
---

# Demo Material Output Contract

## Publication Boundary

A run produces artifacts into the level working directory and nothing else. It
never publishes, uploads, or distributes a deck or a video. Publication is a
separate human action in every autonomy mode, including `full`.

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

## Prerequisite Matrix

| Capability                         | Required prerequisite                                               | Deferred behavior                                                                                                                              |
|------------------------------------|---------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------|
| Build and deck operations          | `uv`, Python 3.11+, and PowerShell 7+                               | Record `uv` or runtime absence as `Deferred`; do not build the deck                                                                            |
| Deterministic deck frame export    | LibreOffice                                                         | Record `LibreOffice` absence as `Deferred`; do not claim the L100 or L200 visual evidence passed                                               |
| Azure neural narration             | `SPEECH_KEY` or `SPEECH_RESOURCE_ID`, plus `SPEECH_REGION`          | Record unavailable authentication or region approval as `Deferred`; do not generate substitute delivery narration                              |
| Vision slide check                 | GitHub Copilot CLI, authenticated                                   | Required before `validation.deck: pass`; record `Deferred` when unavailable, because property and geometry checks do not inspect rendered text |
| Approved neural voice              | A caller-named voice, otherwise `en-US-Andrew:DragonHDLatestNeural` | Record the selected voice in the manifest; under `manual` and `partial` confirm it, under `full` use the default without prompting             |
| MP4 assembly                       | FFmpeg and ffprobe on `PATH`                                        | Record the missing executable as `Deferred`; do not claim an MP4 exists                                                                        |
| Live capture, `capture: live` only | VS Code CLI plus Playwright MCP browser tools                       | Record the unavailable entrypoint by name as `Deferred`; do not replace an L300 or L400 live capture with deck export                          |
| Dynamic topic resolution           | The `rpi-research` skill                                            | Record its absence as `Deferred` for any topic other than `hve-core-general`; do not guess a source set                                        |

Establish live-capture availability by attempting a browser navigation, never by
inspecting tool names. MCP tool prefixes are derived from the server's
registration name and vary between hosts, so an unfamiliar prefix is not
evidence of absence. Record the prerequisite as unavailable only after an
attempt fails, and record what failed. VS Code's built-in browser tools are a
known case that reaches the page but cannot drive the VS Code Web workbench.

VS Code Web keeps user settings in browser IndexedDB, so a settings-based font
size never reaches a live capture. Raise rendered text size by setting
`document.body.style.zoom` through the Playwright evaluate tool, then measure the
result with the readability measurement procedure in `curriculum.md`.

## Manifest Schema

Read this schema and copy its structure into `output/manifest.yml`. Values in
angle brackets are placeholders, not literal output.

```yaml
schema_version: 3
level: L100
topic: <topic name, default hve-core-general>
autonomy: <full | partial | manual>
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
  narrated_pptx: output/hve-demo-L100-narrated.pptx
  mp4: output/hve-demo-L100.mp4
visuals:
  capture_profile: <live | deck-export> # deck-export at L300 or L400 only when the caller supplied it
  evidence:
    - capture_id: slide-001
      path: frames/slide-001.jpg
      rendered_font_size_pt: <measured number | not-applicable>
      source_resolution: <width>x<height | not-applicable>
narration:
  provider: Azure AI Speech
  voice: <approved neural voice name>
  speech_region: <approved region name>
  total_word_count: <number> # summed across the synthesized speaker notes
  measured_duration_minutes: <number> # measured from the produced MP4, for example with ffprobe
  contract_duration_minutes:
    min: <number>
    max: <number>
  audio_files:
    - audio/slide-001.wav
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
  azure_speech: <available | missing>
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
