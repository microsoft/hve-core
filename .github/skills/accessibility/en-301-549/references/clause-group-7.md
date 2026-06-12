---
title: "Clause 7: ICT with Video"
description: "Clause 7 of EN 301 549 V3.2.1 covers accessibility requirements for ICT that plays back video content with synchronised audio."
---

# Clause 7: ICT with Video

Clause 7 of EN 301 549 V3.2.1 covers accessibility requirements for ICT that plays back video content with synchronised audio. It focuses on the playback path: how captions render, how audio description tracks are presented alongside the programme audio, and how the player exposes user controls for those alternative tracks. Authoring of captions and audio description for the underlying media falls under Clause 9 (web) and Clause 10 (non-web documents); Clause 7 governs the playback surface that exposes those tracks to the viewer.

Source: ETSI / CEN / CENELEC, EN 301 549 V3.2.1, Clause 7, <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>. Summaries below are paraphrased; consult the official document for normative wording.

## clause-7-1

**7.1 Captioning playback**

ICT that plays video with synchronised audio shall play back captions when the source media carries a caption track, render them synchronised with the corresponding audio, and preserve the visual styling and positioning that the caption author specified. The playback surface shall not strip, re-time, or visually obscure caption text during normal playback.

**Applies to**: Video playback.

**WCAG cross-reference**: [sc-1-2-2](../../wcag-22/references/guideline-1-2.md#sc-1-2-2), [sc-1-2-4](../../wcag-22/references/guideline-1-2.md#sc-1-2-4).

**Assessment heuristics**:

* Play a sample asset that carries a caption track and confirm captions render automatically when the user has captions enabled.
* Measure caption-to-audio synchronisation under normal and seek-resumed playback; flag drift greater than a few hundred milliseconds.
* Verify that author-specified caption positioning and styling (line breaks, speaker labels, italics) survive the playback pipeline.
* Confirm captions do not get cropped, overlapped by player chrome, or hidden behind on-screen controls.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/> (Clause 7.1).

## clause-7-2

**7.2 Audio description playback**

ICT that plays video with synchronised audio shall play back an audio description track when the source media provides one, mix it cleanly with the programme audio without clipping or muting the original soundtrack outside the described intervals, and keep the description timing aligned with the visual content it describes.

**Applies to**: Video playback.

**WCAG cross-reference**: [sc-1-2-3](../../wcag-22/references/guideline-1-2.md#sc-1-2-3), [sc-1-2-5](../../wcag-22/references/guideline-1-2.md#sc-1-2-5).

**Assessment heuristics**:

* Play media that carries both an audio description track and a standard track and confirm the player can select and mix the description channel.
* Confirm description narration falls in the intended pauses and does not collide with programme dialogue.
* Verify that selecting audio description does not silence or unduly attenuate the original programme audio outside the described intervals.
* Test that the description track remains available on platform-specific output paths (HDMI, Bluetooth, AirPlay) and not just on the local speaker.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/> (Clause 7.2).

## clause-7-3

**7.3 User controls for captions and audio description**

The video player UI shall expose discoverable controls that let the user turn captions and audio description on and off independently of one another, and those controls shall be as easy to reach as the player's primary playback controls (play, pause, volume). User preference for each track type shall persist so that the next time the user opens compatible media the same selection applies.

**Applies to**: Video player UI.

**WCAG cross-reference**: [sc-1-2-2](../../wcag-22/references/guideline-1-2.md#sc-1-2-2), [sc-1-2-3](../../wcag-22/references/guideline-1-2.md#sc-1-2-3).

**Assessment heuristics**:

* Open the player UI and confirm the caption toggle and the audio description toggle are reachable from the same surface and at the same depth as the play/pause and volume controls.
* Verify that the captions toggle and the audio description toggle operate independently — neither requires the other to be enabled or disabled.
* Toggle each control, close the player, reopen with a different compatible asset, and confirm the previous selection persists.
* Confirm the controls expose accessible names through the platform accessibility API so that screen readers and switch-access users can operate them.
* Where caption styling (font size, colour, background opacity) is configurable, confirm the styling controls are reachable from the same player UI surface and that the chosen styling persists across sessions.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/> (Clause 7.3).

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
