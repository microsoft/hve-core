---
title: "Clause 13: ICT Providing Relay or Emergency Services"
description: "Clause 13 of EN 301 549 V3.2.1 covers ICT that provides telecommunications relay services (bridging users with different communication modes) and ICT that provides access to public emergency services."
---

# Clause 13: ICT Providing Relay or Emergency Services

Clause 13 of EN 301 549 V3.2.1 covers ICT that provides telecommunications relay services (bridging users with different communication modes) and ICT that provides access to public emergency services. The sub-clauses bind both the relay or emergency endpoint and the originating ICT to interoperability obligations so that users who depend on text, video, or assistive communication paths reach the same services on the same terms as voice users.

Source: ETSI / CEN / CENELEC, EN 301 549 V3.2.1, Clause 13, <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>. Summaries below are paraphrased; consult the official document for normative wording.

## clause-13-1-1

**13.1.1 Access to relay services**

ICT that initiates voice communication shall provide a means by which users can reach available relay services (text relay, video relay, captioned telephony) using the same call-origination affordances as a standard voice call. The path to the relay endpoint shall not impose extra steps, separate apps, or non-accessible address books on users who depend on it.

**Applies to**: Relay service access from any ICT capable of initiating two-way voice communication, including handsets, softphones, web calling clients, and embedded calling features.

**WCAG cross-reference**: n/a (relay-service interoperability requirement rather than a web success criterion).

**Assessment heuristics**:

* Confirm the dial UI accepts the published relay service identifier (number, SIP URI, or equivalent) in the same field as a normal destination.
* Verify the relay endpoint is reachable from the contacts, recents, and speed-dial surfaces, not only from a hidden settings screen.
* Test that user-selected relay modality (TTY, VRS, IP CTS) persists as a per-contact or default preference where the platform supports it.
* Walk the relay call flow with assistive technology (screen reader, switch control) to confirm initiation, in-call indicators, and termination are all operable.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/> (Clause 13.1.1).

## clause-13-1-2

**13.1.2 Access to emergency services**

ICT that supports two-way voice communication shall let users reach the relevant public emergency service using the platform's standard call-origination path. The emergency endpoint shall be reachable without first navigating an inaccessible menu, completing identity steps that block urgent calls, or installing additional software.

**Applies to**: Emergency service access from any ICT capable of initiating two-way voice communication, including mobile handsets, VoIP clients, in-vehicle systems, and connected room or kiosk telephony.

**WCAG cross-reference**: n/a (emergency-service interoperability requirement rather than a web success criterion).

**Assessment heuristics**:

* Place test emergency calls (against a test endpoint or in a regulator-approved test environment) from each supported originating modality and confirm completion.
* Verify the emergency call path is reachable from a lock screen or restricted state where regulation permits, and that AT cues (screen reader announcements, haptics) accompany the connection state.
* Confirm that account-state restrictions (no SIM, prepaid balance, parental controls) do not block emergency dialling.
* Document how the ICT routes emergency calls when multiple SIPs, eSIMs, or carriers are configured, so dispatch routing remains predictable.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/> (Clause 13.1.2).

## clause-13-2-1

**13.2.1 Real-time text emergency communication**

ICT that provides access to emergency services shall accept and transmit real-time text (RTT) for emergency calls, so that users who cannot use voice can convey emergency information character-by-character with no perceptible delay. RTT shall interwork with the receiving public-safety answering point either directly or through a designated text relay path.

**Applies to**: Emergency RTT origination and transport in ICT that originates or carries emergency calls, including handsets, calling clients, carrier networks, and emergency-call gateways.

**WCAG cross-reference**: n/a (emergency-service interoperability requirement rather than a web success criterion).

**Assessment heuristics**:

* Confirm the ICT exposes an explicit RTT mode in the emergency call UI, not buried under accessibility submenus.
* Verify RTT and voice can run on the same emergency call where the dispatch endpoint accepts both, so callers can shift modality mid-call.
* Test interworking with the regulator-mandated text relay path when direct RTT delivery to dispatch is unavailable.
* Validate that character transmission latency, capitalisation, and special-character handling meet the regional emergency-RTT profile (for example ETSI TS 134 109 or comparable national profile).

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/> (Clause 13.2.1).

## clause-13-2-2

**13.2.2 Caller location for emergency**

ICT that provides access to emergency services shall convey caller location information to the receiving emergency centre with the same accuracy and timeliness as is provided for voice callers, regardless of whether the call was initiated by voice, text, RTT, or video. Location data shall accompany the call without requiring the caller to read coordinates or address details aloud.

**Applies to**: Emergency caller location data in ICT that originates or routes emergency calls, including handsets, calling clients, network elements, and emergency-call gateways.

**WCAG cross-reference**: n/a (emergency-service interoperability requirement rather than a web success criterion).

**Assessment heuristics**:

* Confirm the location payload (cell-based, GNSS, Wi-Fi, advanced mobile location) attaches to text and video emergency calls, not only to voice.
* Verify the receiving endpoint can render the supplied location with the precision the originating ICT advertises.
* Test location delivery in low-coverage and indoor scenarios to confirm graceful fallback rather than silent failure.
* Audit privacy posture so emergency-only location release does not leak into non-emergency contexts.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/> (Clause 13.2.2).

## clause-13-2-3

**13.2.3 Video relay for emergency**

ICT that provides access to emergency services shall support video communication for emergency calls where a sign-language video relay path is available in the relevant jurisdiction, so that deaf and hard-of-hearing users who sign can place emergency calls in their first language. The ICT shall route the video emergency call to the designated relay or dispatch endpoint without imposing extra setup steps not required for voice emergency calls.

**Applies to**: Emergency video relay origination and transport in ICT that originates or carries emergency calls, including handsets, calling clients, carrier networks, and emergency-call gateways.

**WCAG cross-reference**: n/a (emergency-service interoperability requirement rather than a web success criterion).

**Assessment heuristics**:

* Confirm the emergency UI surfaces a video-relay option whenever the device camera and network bandwidth permit it.
* Verify video and audio media streams negotiate the codecs the receiving relay or dispatch endpoint accepts, with documented fallback to RTT if video fails.
* Test camera, frame rate, and lighting handling against the signed-emergency-call quality targets in the regional profile.
* Walk the flow with a signing user to confirm orientation cues, mute indicators, and in-call status are perceivable without audio.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/> (Clause 13.2.3).

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
