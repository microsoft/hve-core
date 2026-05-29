---
title: "Clause 8: Hardware"
description: "Clause 8 of EN 301 549 V3.2.1 collects accessibility requirements that apply to hardware ICT (kiosks, payment terminals, ticket machines, telephones, set-top boxes, peripheral devices)."
---

# Clause 8: Hardware

Clause 8 of EN 301 549 V3.2.1 collects accessibility requirements that apply to hardware ICT (kiosks, payment terminals, ticket machines, telephones, set-top boxes, peripheral devices). It builds on the generic operable-parts and locking rules from Clause 5 and adds hardware-specific requirements for spoken output, stationary public-use ICT, mechanical locks and physical operable parts, and machine-readable cards used to identify or authenticate the user.

Source: ETSI / CEN / CENELEC, EN 301 549 V3.2.1, Clause 8, <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>. Summaries below are paraphrased; consult the official document for normative wording.

## clause-8-1

**8.1 General**

Hardware ICT shall meet the accessibility requirements that follow in Clause 8, in addition to the generic requirements in Clause 5 that apply whenever the hardware exposes operable parts, locking or toggle controls, key input, multi-action input, or accessibility activation. Clause 8 narrows the generic rules to physical product form factors and adds requirements that only make sense for hardware.

**Applies to**: All hardware ICT products and the hardware aspects of mixed hardware/software systems.

**Assessment heuristics**:

* Maintain a single conformance matrix that covers both the relevant Clause 5 rows and the Clause 8 rows for the hardware under test, so reviewers can see at a glance which generic and hardware-specific rules apply.
* Identify which hardware mode each Clause 8 subsection targets (speech output, stationary public ICT, mechanical controls, identification cards) and confirm the matrix marks each as "applicable", "not applicable with rationale", or "non-conformant with mitigation".
* Document the relationship between Clause 5 operable-parts findings and Clause 8.4 mechanical hardware findings so the same physical control is not double-counted or split between reports.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-8-2

**8.2 Hardware products with speech output**

Where hardware provides built-in speech output as part of an accessibility mode (for example, a self-service kiosk that speaks the on-screen content), the speech shall be in the same language as the visible content where that language is supported, the user shall be able to adjust the volume independently of any other audio, and a private listening option (such as a standard headphone jack) shall be provided so confidential content is not exposed to bystanders.

**Applies to**: Hardware ICT with built-in speech output, including ATMs, ticket machines, voting machines, and information kiosks.

**Assessment heuristics**:

* Verify the speech output language tracks the visible content language and that switching the on-screen language also switches the speech voice or pronunciation.
* Confirm an independent volume control for the speech channel, with at least one increment loud enough for a user with mild hearing loss in a noisy public environment.
* Confirm a standard headphone jack (or equivalent private listening surface) is present, reachable from the operating position, and routes the speech output without exposing it on the speaker.
* Test that the private listening surface mutes the public speaker automatically when the jack is engaged.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-8-3

**8.3 Stationary ICT**

Stationary ICT installed in public spaces (kiosks, ATMs, ticket machines, information terminals) shall be positioned and dimensioned so that users in wheelchairs and users of short stature can reach all operable parts, view all displays, and complete every essential task without assistance. Where the device displays text or symbols, the visual presentation shall meet the contrast requirements that apply to the relevant viewing distance.

**Applies to**: Kiosks and other stationary devices installed for public use.

**WCAG cross-reference**: [sc-1-4-3](../../wcag-22/references/guideline-1-4.md#sc-1-4-3).

**Assessment heuristics**:

* Verify that the highest operable part is within the forward or side reach range specified for seated users, and that the lowest operable part is reachable without forcing the user to crouch.
* Confirm clear floor space in front of the device for a wheelchair approach (frontal or parallel) and that the approach is not blocked by a kick plate, fixed bollard, or queue rail.
* Measure the contrast ratio of on-screen text and critical status indicators at the typical viewing distance and angle for a seated user.
* Confirm displays are tilted or mounted so glare from overhead lighting does not obscure content for a seated viewer.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-8-4

**8.4 Mechanical hardware (locks and operable parts)**

Mechanical hardware such as locks, latches, hinges, paper trays, card slots, and removable panels shall be operable without requiring tight grasping, pinching, or twisting of the wrist, shall be operable with one hand, and shall not require simultaneous activation of multiple operable parts. The activation force for any mechanical operable part shall stay within the ceiling defined for generic operable parts in Clause 5.5.

**Applies to**: Physical controls and mechanical operable parts on hardware ICT, including service-door locks, paper jam access panels, and consumable replacement mechanisms that an end user is expected to operate.

**WCAG cross-reference**: [sc-2-1-1](../../wcag-22/references/guideline-2-1.md#sc-2-1-1).

**Assessment heuristics**:

* Inspect each user-facing mechanical control and confirm it can be operated with a closed fist or single finger (no pinch, twist, or tight grasp required).
* Measure activation force against the Clause 5.5 ceiling and document any mechanism that requires more than the permitted force.
* Verify single-hand operation for each consumable replacement path (paper roll, card stack, receipt drawer) end to end.
* Confirm no maintenance task expected of the end user requires simultaneous activation of two separated controls.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-8-5

**8.5 Tickets, fare cards, and keycards**

Tickets, fare cards, keycards, and similar machine-readable identification media issued or accepted by ICT shall carry a tactile orientation feature (notch, raised edge, asymmetric shape) so users who are blind or have low vision can insert the card in the correct orientation without sighted assistance.

**Applies to**: Identification media that the user must insert, swipe, or tap with a specific orientation, including transit fare cards, hotel keycards, parking tickets, and access badges.

**Assessment heuristics**:

* Inspect each card design for a tactile orientation feature that is distinguishable from the card edge by touch alone.
* Confirm the tactile feature unambiguously indicates the correct insertion or tap orientation for every reader the card is used with.
* Test card orientation discovery with users who are blind or have low vision and confirm they can insert the card on the first attempt without sighted assistance.
* For systems that issue cards on demand (ticket machine), confirm the issued card preserves the tactile orientation feature regardless of which print path generated it.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
