---
description: "Trigger, scene, asset, recording, and validation contract for optional original-character animation in demo material."
---

# Character Animation Contract

## Activation

Read and apply this reference only when `animation: characters` is active. That
mode activates when the caller supplies it or directly requests animated
characters, animated comic figures, or character dialogue scenes. Do not
activate it from the topic, audience, level, transition request, or autonomy
mode. A request for static comic-style artwork does not activate animation.

## Scene Contract

Create `animation/character-sheet.md` before authoring scenes. Record each
character's name, visual description, role, approved voice, asset paths, source,
and reuse rights. Use original figures rather than a real person's likeness or
a protected character.

Store each self-contained browser scene under `animation/scene-<number>/` and
its recording under `clips/`. Each scene has:

* One primary speaker and optional listening characters
* Distinct idle and speaking states, with visible speaking motion
* Dialogue copied from that scene's canonical speaker notes
* A stable 16:9 stage that remains readable at the target video resolution
* No network dependency during playback or recording
* A source-register mapping for every factual claim

After authoring the scenes, synthesize each scene's canonical narration using
its approved voice and measure the generated WAV with FFprobe. The measured
WAV duration, not a word-count estimate, supplies the recorder's duration.
Complete this narration step before validating a speaking sample or recording
the remaining scenes.

Set `data-animation-ready="true"` on the scene body when local assets and state
are ready, and define `window.startAnimation()` to reset speaking motion and
scene timers to time zero. Do not start narrative motion during loading.
Invoke the `vscode-playwright` skill's scripted browser-video recorder
with the scene HTML, output WebM path, narration duration, and target resolution.
The recorder blocks network requests and creates a silent clip. Pair that clip
with the scene's narration WAV in `output/segments.yml`; `demo-video` supplies
audio and trims or loops the raw browser recording to the narration duration.

Keep one authored content item, narration WAV, and video segment per scene. This
one-to-one mapping allows caption timing, transcript generation, and transition
validation to remain deterministic.

### Per-scene Voice Recipe

Persist `narration.speaker_voices` and `narration.scene_audio` in the level
manifest, including canonical slide number, speaker, selected voice, WAV path,
and measured duration. Synthesize selected slides separately into the same
audio directory; `--slide` prevents a later speaker's pass from touching prior
WAVs. Use the resolved installed TTS skill root and caller-approved voices:

```bash
uv run --directory "$TTS_SKILL_ROOT" python scripts/generate_voiceover.py \
	--engine piper --collapse-newlines --content-dir "$LEVEL_DIR/content" \
	--output-dir "$LEVEL_DIR/audio" --slide 1 --voice "$CASEY_VOICE"
uv run --directory "$TTS_SKILL_ROOT" python scripts/generate_voiceover.py \
	--engine piper --collapse-newlines --content-dir "$LEVEL_DIR/content" \
	--output-dir "$LEVEL_DIR/audio" --slide 2 --voice "$MORGAN_VOICE"
```

Repeat `--slide` for all scenes assigned to that voice, then measure every WAV.
For Azure, select `--engine azure` with the approved Azure voices and region.
The recipe never changes the caller's selected narration engine.

## Handoff Pattern

Use character scenes to frame or connect evidence, not to replace it. A typical
sequence is:

1. A character introduces the user problem.
2. Another character asks how the product helps.
3. The first character announces a demonstration.
4. The video crossfades into product footage while narration continues.
5. A closing character scene summarizes the evidenced outcome.

Place each character scene and product capture in `output/segments.yml` in
storyboard order. Use the shared half-second transition profile for opening,
scene, audio, and closing fades.
The assembler supplies silent audio handles and matching held-picture handles;
crossfades and endpoint fades affect silence, not spoken instructions.

Assemble character runs through the builder's clip-aware workflow and
`demo-video`, not the deck-frame `render-level.sh` path. Preserve the authored
clip segments through finalization.

## Validation

Before recording all scenes, validate one speaking scene and one transition into
product footage. Confirm that:

* Characters and speech are visible without clipping or overlap
* Speaking motion corresponds to the active speaker
* Dialogue audio, captions, and transcript text match
* The character-to-product handoff preserves narrative continuity
* Assets render offline and carry recorded provenance

If the browser cannot record the scene, a required asset lacks clear rights, or
an approved dialogue voice is unavailable, set the level to `Deferred`. Do not
silently switch to `animation: none`.