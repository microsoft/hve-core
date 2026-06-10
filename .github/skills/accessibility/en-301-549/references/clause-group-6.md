---
title: "Clause 6: ICT with Two-Way Voice Communication"
description: "Clause 6 of EN 301 549 V3.2.1 covers accessibility requirements that apply when ICT enables real-time, bidirectional voice conversation between two or more users."
---

# Clause 6: ICT with Two-Way Voice Communication

Clause 6 of EN 301 549 V3.2.1 covers accessibility requirements that apply when ICT enables real-time, bidirectional voice conversation between two or more users. Its sub-clauses address audio bandwidth for intelligible speech, real-time text (RTT) as a parallel channel to voice, caller identification across modalities, accessible alternatives to voice-only services, the picture quality of video used to support sign-language communication, and the obligation to interoperate with emergency services for users who cannot rely on voice alone. These requirements build on the generic provisions in Clause 5 and apply to voice telephony, internet calling, unified-communications clients, and video-conferencing endpoints.

Source: ETSI / CEN / CENELEC, EN 301 549 V3.2.1, Clause 6, <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>. Summaries below are paraphrased; consult the official document for normative wording.

## clause-6-1

**6.1 Audio bandwidth for speech**

Where ICT provides two-way voice communication, the audio path shall carry a frequency range wide enough to preserve the intelligibility cues of human speech, including the consonant frequencies that users with hearing loss depend on. Narrowband telephony alone is not sufficient; the clause expects wideband or super-wideband speech coding when the underlying network and endpoints support it.

**Applies to**: Voice communication endpoints and services, including IP telephony, mobile clients, unified-communications applications, and video-conferencing tools whose voice path is used as a substitute for in-person speech.

**WCAG cross-reference**: n/a (audio-channel quality requirement with no WCAG equivalent).

**Assessment heuristics**:

* Measure the end-to-end frequency response of the voice path and confirm it extends at least into the wideband range expected by the negotiated codec.
* Verify that wideband-capable codecs (for example G.722, Opus, EVS) are advertised and negotiated whenever both endpoints support them rather than silently downgrading to narrowband.
* Test intelligibility with hard-of-hearing users on representative network conditions to confirm consonant clarity in noisy environments.
* Document any conditions (network fallback, gateway transcoding) that force a narrowband downgrade and surface them in the conformance report.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/> (Clause 6.1).

## clause-6-2

**6.2 Real-time text functionality**

Where ICT supports real-time text alongside voice, characters shall be transmitted as soon as they are entered so that the conversation flows in step with speech rather than after a send action. RTT shall be available in parallel with the voice channel so that a user can switch between or combine speaking and typing within the same call, and the implementation shall align with the recognised RTT transport profiles (for example RFC 4103 for SIP-based calls).

**Applies to**: Voice ICT that offers a text channel intended to complement or substitute for speech during a call, including softphones, mobile dialer apps, unified-communications clients, and gateways that bridge voice and text users.

**WCAG cross-reference**: n/a (real-time communication modality with no direct WCAG SC mapping).

**Assessment heuristics**:

* Confirm that text is transmitted character-by-character (or in small bursts) with sub-second latency end-to-end rather than buffered until the user presses send.
* Verify that voice and RTT can be active simultaneously within the same session and that switching between them does not tear down the call.
* Test interoperability with at least one independent RTT-capable endpoint to confirm conformance with the negotiated transport profile.
* Confirm that incoming RTT is presented visibly while a call is ringing, in progress, and being torn down.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/> (Clause 6.2).

## clause-6-3

**6.3 Caller identification**

Where ICT presents caller identification (incoming-call display, in-call participant list, missed-call log), the information shall be available in both visual and auditory forms so that users who cannot rely on a screen and users who cannot rely on audio cues both receive it. The same applies to other call-status cues that the system signals through caller-ID metadata, such as withheld-number indications or organisation labels.

**Applies to**: Voice communication endpoints and services that display or announce caller-identity information for incoming, in-progress, or historical calls.

**WCAG cross-reference**: n/a (multi-modal output requirement bound to the voice-ICT context).

**Assessment heuristics**:

* Verify that incoming caller-ID information can be rendered as on-screen text and as spoken or otherwise audible output, with the user able to enable either channel.
* Confirm that the in-call participant list and missed-call log expose the same identity information through the platform accessibility API so screen readers can announce it.
* Test the auditory presentation in realistic ambient conditions to confirm it is loud and clear enough to be perceived during a typical call setup.
* Confirm that withheld, blocked, or unknown-caller states are surfaced through the same dual-channel path as identified callers.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/> (Clause 6.3).

## clause-6-4

**6.4 Alternatives to voice-based services**

Where a service depends on a voice interaction to be completed (for example interactive voice response menus, voicemail retrieval, voice-only support hotlines), the provider shall offer an equivalent non-voice channel so that users who cannot speak or hear can reach the same outcome. The alternative channel shall provide comparable functionality and timeliness rather than being limited to a deferred email response.

**Applies to**: Voice-driven services exposed to end users, including IVR systems, contact centres, voicemail, and any service whose primary completion path is a spoken interaction.

**WCAG cross-reference**: n/a (service-design requirement rather than an interface-level WCAG SC).

**Assessment heuristics**:

* Inventory every user-facing service that uses voice as the primary completion path and confirm at least one functionally equivalent non-voice channel exists (RTT, text chat, web form with real-time agent, video relay).
* Verify that the alternative channel can complete the same set of tasks (menu navigation, authentication, account changes, escalation) as the voice path.
* Confirm that response timeliness on the alternative channel is comparable to the voice channel during the same operating hours.
* Document the alternative channel in the support documentation referenced by Clause 12 so users can discover it without already using the inaccessible voice path.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/> (Clause 6.4).

## clause-6-5

**6.5 Video communication**

Where ICT supports real-time video as part of a two-way voice call (for example to enable sign-language conversation or lip-reading), the video stream shall meet the resolution, frame rate, dynamic range, and audio-video synchronisation needed for those visual cues to be perceived. The clause is concerned with the picture quality of the live video itself rather than with prerecorded captions or descriptions, but it shares failure modes with the WCAG synchronised-media criteria, which is why the roll-up cross-references the prerecorded-captions and audio-description success criteria as related context.

**Applies to**: Video calls within voice-communication ICT, including video-relay services, video-conferencing endpoints used for accessibility purposes, and any product that offers a video lane alongside voice.

**WCAG cross-reference**: [sc-1-2-2](../../wcag-22/references/guideline-1-2.md#sc-1-2-2), [sc-1-2-5](../../wcag-22/references/guideline-1-2.md#sc-1-2-5).

**Assessment heuristics**:

* Confirm the negotiated video profile delivers a frame rate and resolution sufficient for sign-language perception (commonly cited as at least 20 frames per second at a resolution that preserves hand and facial detail).
* Measure end-to-end audio-video synchronisation and verify lip-reading remains viable within the tolerance the codec advertises.
* Test the call under typical network conditions (constrained uplink, packet loss) and confirm the system degrades gracefully rather than dropping frame rate below the sign-language threshold without warning.
* Verify the user can choose to enable the video lane without losing the voice or RTT channels in the same call.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/> (Clause 6.5).

## clause-6-6

**6.6 Interoperability with emergency services**

Where ICT enables real-time communication to emergency services, it shall support the modalities required for users who cannot rely on voice, including RTT (and, where the system supports real-time video, the video lane) end-to-end through the call path. The clause is concerned with the call reaching an equipped public-safety answering point with the chosen modality intact rather than being silently transcoded or dropped to voice-only.

**Applies to**: Voice and unified-communications ICT that can place calls to national or regional emergency services (for example 112 in the EU, 999, 911).

**WCAG cross-reference**: n/a (network-interoperability requirement with no WCAG equivalent).

**Assessment heuristics**:

* Place test calls to the regional emergency service using each supported modality (voice, RTT, video where offered) and confirm the call is delivered to an appropriately equipped answering point.
* Verify that the modality chosen at call setup is preserved end-to-end and that no gateway downgrades RTT or video to a less accessible form without surfacing the change to the user.
* Confirm that location and caller-identification metadata required by the local emergency framework accompanies the call across every supported modality.
* Document the supported emergency modalities, the regions in which they have been validated, and any known network conditions in which fallback occurs.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/> (Clause 6.6).

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
