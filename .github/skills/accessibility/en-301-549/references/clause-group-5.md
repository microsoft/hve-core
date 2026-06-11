---
title: "Clause 5: Generic Requirements"
description: "Clause 5 of EN 301 549 V3.2.1 collects ICT-wide generic requirements that apply across product categories (web, software, hardware, voice, video)."
---

# Clause 5: Generic Requirements

Clause 5 of EN 301 549 V3.2.1 collects ICT-wide generic requirements that apply across product categories (web, software, hardware, voice, video). It covers functional performance, accessibility activation, biometrics, preservation of accessibility metadata, operable parts, locking and toggle controls, key repeat and double-strike handling, simultaneous user actions, and privacy of assistive technology output. These clauses set the baseline that more specialised clauses (6 through 13) build on or refine.

Source: ETSI / CEN / CENELEC, EN 301 549 V3.2.1, Clause 5, <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>. Summaries below are paraphrased; consult the official document for normative wording.

## clause-5-1

**5.1 Functional performance**

ICT shall provide closed functionality that lets people with the full range of disabilities (visual, hearing, speech, cognitive, manual dexterity) use the product without requiring them to attach personal assistive technology. Where assistive technology is required, the ICT shall expose information and operability through accessibility services so that AT can mediate the interaction.

**Applies to**: All ICT, especially closed systems (kiosks, fixed-function devices) that cannot accept personal AT and must satisfy accessibility through built-in alternative modes.

**WCAG cross-reference**: n/a (clause expresses outcome-oriented functional performance rather than a WCAG SC).

**Assessment heuristics**:

* Enumerate every closed-function mode (operation without vision, operation with limited vision, operation without hearing, operation without speech, operation with limited manipulation, operation with limited reach) and verify each is supported.
* For products that depend on external AT, confirm the platform accessibility API surface (UIA, AT-SPI, ATK, AXAPI) is implemented end-to-end.
* Capture the closed-functionality test plan as part of the product accessibility conformance report.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-5-2

**5.2 Activation of accessibility features**

Where the ICT has documented accessibility features, those features shall be activatable without requiring the user to first use a feature that is itself inaccessible.

**Applies to**: All ICT that ships with accessibility settings (high-contrast, screen-reader mode, sticky keys, captioning toggle, magnification).

**WCAG cross-reference**: n/a.

**Assessment heuristics**:

* Walk through first-run setup with each accessibility persona and verify the user can turn on the relevant feature without dependence on another inaccessible feature.
* Provide at least one always-available activation surface (hardware button, voice command, OS shortcut) for the most critical features.
* Document the activation paths in the support documentation referenced by Clause 12.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-5-3

**5.3 Biometrics**

Where biometric authentication is offered, the ICT shall not rely on a single biological characteristic as the only means of authentication; an accessible non-biometric alternative or a second biometric modality shall be provided so users who cannot present that characteristic can still authenticate.

**Applies to**: Devices and services that offer fingerprint, face, iris, voice, or other biometric authentication.

**WCAG cross-reference**: n/a.

**Assessment heuristics**:

* Verify that at least one alternative authentication path (PIN, hardware token, alternative biometric) is offered alongside the primary biometric.
* Confirm that the alternative is described in setup flows and is reachable without first completing biometric enrolment.
* Test the fallback flow with users who have conditions affecting the relevant biometric (low-vision face capture, amputation, voice impairment).

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-5-4

**5.4 Preservation of accessibility information during conversion**

When ICT converts information from one form, format, or medium to another (for example, exporting a document, re-encoding a video, copying captions), it shall preserve the accessibility metadata (alternative text, captions, semantic structure, language tags) unless the target format cannot represent it.

**Applies to**: Conversion, export, transcoding, and synchronisation tools across document, media, and communication ICT.

**WCAG cross-reference**: n/a.

**Assessment heuristics**:

* For each export path, diff the source accessibility metadata against the exported artifact and confirm parity (or document the unavoidable loss in user-visible release notes).
* Cover captions, audio descriptions, alt text, heading structure, table semantics, and language tags in the regression test plan.
* Confirm that lossy conversions issue a clear warning at the time of conversion.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-5-5

**5.5 Operable parts**

Operable parts (buttons, switches, dials, latches) shall be discernible by touch without activation, shall not require tight grasp, pinch, or twist of the wrist, and shall be operable with one hand and with a force of no more than 22.2 N.

**Applies to**: Hardware ICT with physical controls (kiosks, payment terminals, ticket machines, telephones).

**WCAG cross-reference**: [sc-2-5-5](../../wcag-22/references/guideline-2-5.md#sc-2-5-5).

**Assessment heuristics**:

* Confirm tactile discernibility of each operable part by haptic inspection (raised symbols, distinct shape, separation gaps).
* Measure activation force with a calibrated gauge against the 22.2 N ceiling.
* Verify single-hand operation for the full task path (insert card → enter PIN → confirm → take receipt).

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-5-6

**5.6 Locking or toggle controls**

Locking and toggle controls (Caps Lock, Num Lock, Scroll Lock and equivalents on hardware) shall have a discernible non-visual indicator (audible tone, tactile state, or both) so blind users can determine the control state.

**Applies to**: Keyboards, hardware keypads, and physical toggle switches.

**WCAG cross-reference**: n/a.

**Assessment heuristics**:

* Verify each toggle exposes either an audible state cue or a tactile-state cue (raised LED with tactile cap, mechanical detent).
* For software-controlled hardware (laptop Caps Lock LEDs), confirm the state can also be read through the platform accessibility API.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-5-7

**5.7 Key repeat**

Where ICT keyboards offer key-repeat behaviour, users shall be able to disable the feature or adjust both the delay before repeat and the repeat rate.

**Applies to**: Keyboards, on-screen keyboards, and other key-based input methods.

**WCAG cross-reference**: n/a.

**Assessment heuristics**:

* Confirm settings expose a "disable repeat" option and adjustable delay/rate sliders.
* Verify the settings persist across sessions and across user accounts where applicable.
* Test with users who have tremor or limited dexterity to confirm the configuration meaningfully reduces accidental repeats.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-5-8

**5.8 Double-strike key acceptance**

Where ICT accepts keyboard input, users shall be able to configure a minimum interval between presses of the same key before a second activation is registered, so that involuntary double-strikes do not produce duplicate input.

**Applies to**: Keyboards, on-screen keyboards, and key-based input modes on operating systems.

**WCAG cross-reference**: n/a.

**Assessment heuristics**:

* Confirm the OS or application provides a "filter keys" or "bounce keys" style configuration with adjustable threshold.
* Test that the configured threshold meaningfully suppresses accidental double-strikes without introducing perceived input lag.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-5-9

**5.9 Simultaneous user actions**

Operation of the ICT shall not require simultaneous actions (chorded key combinations, multi-touch gestures, simultaneous press-and-hold) unless an equivalent single-action alternative is provided.

**Applies to**: All input surfaces including hardware keys, touch screens, and pointer gestures.

**WCAG cross-reference**: n/a (related to Clause 9.2.1 keyboard requirements).

**Assessment heuristics**:

* Inventory every gesture or key combination that requires simultaneity (Ctrl+Alt+Del, two-finger pinch, two-button hold) and confirm an equivalent sequential path exists.
* Verify the sequential alternative is documented in the help content.
* Test with single-hand and switch-access users.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-5-10

**5.10 Privacy**

Accessibility features that present information audibly or otherwise differently from the default mode (such as screen-reader speech or visual captioning on a kiosk) shall offer the same degree of privacy as the default mode — for example, audio output should be available through a headphone jack so that sensitive content (PINs, balance information) is not exposed publicly.

**Applies to**: ICT that exposes private information when accessibility modes are active, especially public-use ICT such as kiosks, ATMs, and ticket machines.

**WCAG cross-reference**: n/a.

**Assessment heuristics**:

* Confirm a private audio channel (headphone jack, Bluetooth pairing) is offered alongside speaker-based screen reader output.
* Confirm that the visual presentation of private content does not unintentionally become more exposed (large-font rendering on a public screen) when accessibility modes are enabled.
* Document the privacy preservation approach as part of the conformance report.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
