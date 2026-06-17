---
title: WCAG 2.2 framework reference
description: Web Content Accessibility Guidelines (WCAG) 2.2 success criteria packaged as an accessibility assessment knowledge base for the Accessibility Planner and Skill Assessor subagent
---

# WCAG 2.2 framework reference

This `SKILL.md` is the entrypoint for the **Web Content Accessibility Guidelines (WCAG) 2.2** framework skill used by the Accessibility Planner and the Accessibility Skill Assessor subagent.

WCAG 2.2 is published by the W3C Web Accessibility Initiative as a W3C Recommendation. It organises 86 active success criteria (plus 1 obsolete criterion, SC 4.1.1 Parsing) under four foundational principles (Perceivable, Operable, Understandable, Robust) and 13 guidelines. Each success criterion is assigned one of three conformance levels: A, AA, or AAA.

Source: W3C Web Content Accessibility Guidelines (WCAG) 2.2, <https://www.w3.org/TR/WCAG22/>.

## Licensing posture

WCAG 2.2 is published under the W3C Document License. This skill paraphrases success-criterion intent rather than reproducing normative text verbatim, in line with the paraphrase-preferred posture defined in [accessibility-license-posture.instructions.md](../../../instructions/accessibility/accessibility-license-posture.instructions.md). Every per-guideline reference file cites the canonical W3C URL for each success criterion, and any future verbatim quotation must carry the W3C copyright attribution line specified in that instruction file.

## Success-criterion roll-up

The table below lists every WCAG 2.2 success criterion. The `Reference` column links into the per-guideline reference file using an anchor that matches the section header for that criterion.

| SC     | Title                                                | Level      | Principle      | Reference                                                           |
|--------|------------------------------------------------------|------------|----------------|---------------------------------------------------------------------|
| 1.1.1  | Non-text Content                                     | A          | Perceivable    | [guideline-1-1.md#sc-1-1-1](references/guideline-1-1.md#sc-1-1-1)   |
| 1.2.1  | Audio-only and Video-only (Prerecorded)              | A          | Perceivable    | [guideline-1-2.md#sc-1-2-1](references/guideline-1-2.md#sc-1-2-1)   |
| 1.2.2  | Captions (Prerecorded)                               | A          | Perceivable    | [guideline-1-2.md#sc-1-2-2](references/guideline-1-2.md#sc-1-2-2)   |
| 1.2.3  | Audio Description or Media Alternative (Prerecorded) | A          | Perceivable    | [guideline-1-2.md#sc-1-2-3](references/guideline-1-2.md#sc-1-2-3)   |
| 1.2.4  | Captions (Live)                                      | AA         | Perceivable    | [guideline-1-2.md#sc-1-2-4](references/guideline-1-2.md#sc-1-2-4)   |
| 1.2.5  | Audio Description (Prerecorded)                      | AA         | Perceivable    | [guideline-1-2.md#sc-1-2-5](references/guideline-1-2.md#sc-1-2-5)   |
| 1.2.6  | Sign Language (Prerecorded)                          | AAA        | Perceivable    | [guideline-1-2.md#sc-1-2-6](references/guideline-1-2.md#sc-1-2-6)   |
| 1.2.7  | Extended Audio Description (Prerecorded)             | AAA        | Perceivable    | [guideline-1-2.md#sc-1-2-7](references/guideline-1-2.md#sc-1-2-7)   |
| 1.2.8  | Media Alternative (Prerecorded)                      | AAA        | Perceivable    | [guideline-1-2.md#sc-1-2-8](references/guideline-1-2.md#sc-1-2-8)   |
| 1.2.9  | Audio-only (Live)                                    | AAA        | Perceivable    | [guideline-1-2.md#sc-1-2-9](references/guideline-1-2.md#sc-1-2-9)   |
| 1.3.1  | Info and Relationships                               | A          | Perceivable    | [guideline-1-3.md#sc-1-3-1](references/guideline-1-3.md#sc-1-3-1)   |
| 1.3.2  | Meaningful Sequence                                  | A          | Perceivable    | [guideline-1-3.md#sc-1-3-2](references/guideline-1-3.md#sc-1-3-2)   |
| 1.3.3  | Sensory Characteristics                              | A          | Perceivable    | [guideline-1-3.md#sc-1-3-3](references/guideline-1-3.md#sc-1-3-3)   |
| 1.3.4  | Orientation                                          | AA         | Perceivable    | [guideline-1-3.md#sc-1-3-4](references/guideline-1-3.md#sc-1-3-4)   |
| 1.3.5  | Identify Input Purpose                               | AA         | Perceivable    | [guideline-1-3.md#sc-1-3-5](references/guideline-1-3.md#sc-1-3-5)   |
| 1.3.6  | Identify Purpose                                     | AAA        | Perceivable    | [guideline-1-3.md#sc-1-3-6](references/guideline-1-3.md#sc-1-3-6)   |
| 1.4.1  | Use of Color                                         | A          | Perceivable    | [guideline-1-4.md#sc-1-4-1](references/guideline-1-4.md#sc-1-4-1)   |
| 1.4.2  | Audio Control                                        | A          | Perceivable    | [guideline-1-4.md#sc-1-4-2](references/guideline-1-4.md#sc-1-4-2)   |
| 1.4.3  | Contrast (Minimum)                                   | AA         | Perceivable    | [guideline-1-4.md#sc-1-4-3](references/guideline-1-4.md#sc-1-4-3)   |
| 1.4.4  | Resize Text                                          | AA         | Perceivable    | [guideline-1-4.md#sc-1-4-4](references/guideline-1-4.md#sc-1-4-4)   |
| 1.4.5  | Images of Text                                       | AA         | Perceivable    | [guideline-1-4.md#sc-1-4-5](references/guideline-1-4.md#sc-1-4-5)   |
| 1.4.6  | Contrast (Enhanced)                                  | AAA        | Perceivable    | [guideline-1-4.md#sc-1-4-6](references/guideline-1-4.md#sc-1-4-6)   |
| 1.4.7  | Low or No Background Audio                           | AAA        | Perceivable    | [guideline-1-4.md#sc-1-4-7](references/guideline-1-4.md#sc-1-4-7)   |
| 1.4.8  | Visual Presentation                                  | AAA        | Perceivable    | [guideline-1-4.md#sc-1-4-8](references/guideline-1-4.md#sc-1-4-8)   |
| 1.4.9  | Images of Text (No Exception)                        | AAA        | Perceivable    | [guideline-1-4.md#sc-1-4-9](references/guideline-1-4.md#sc-1-4-9)   |
| 1.4.10 | Reflow                                               | AA         | Perceivable    | [guideline-1-4.md#sc-1-4-10](references/guideline-1-4.md#sc-1-4-10) |
| 1.4.11 | Non-text Contrast                                    | AA         | Perceivable    | [guideline-1-4.md#sc-1-4-11](references/guideline-1-4.md#sc-1-4-11) |
| 1.4.12 | Text Spacing                                         | AA         | Perceivable    | [guideline-1-4.md#sc-1-4-12](references/guideline-1-4.md#sc-1-4-12) |
| 1.4.13 | Content on Hover or Focus                            | AA         | Perceivable    | [guideline-1-4.md#sc-1-4-13](references/guideline-1-4.md#sc-1-4-13) |
| 2.1.1  | Keyboard                                             | A          | Operable       | [guideline-2-1.md#sc-2-1-1](references/guideline-2-1.md#sc-2-1-1)   |
| 2.1.2  | No Keyboard Trap                                     | A          | Operable       | [guideline-2-1.md#sc-2-1-2](references/guideline-2-1.md#sc-2-1-2)   |
| 2.1.3  | Keyboard (No Exception)                              | AAA        | Operable       | [guideline-2-1.md#sc-2-1-3](references/guideline-2-1.md#sc-2-1-3)   |
| 2.1.4  | Character Key Shortcuts                              | A          | Operable       | [guideline-2-1.md#sc-2-1-4](references/guideline-2-1.md#sc-2-1-4)   |
| 2.2.1  | Timing Adjustable                                    | A          | Operable       | [guideline-2-2.md#sc-2-2-1](references/guideline-2-2.md#sc-2-2-1)   |
| 2.2.2  | Pause, Stop, Hide                                    | A          | Operable       | [guideline-2-2.md#sc-2-2-2](references/guideline-2-2.md#sc-2-2-2)   |
| 2.2.3  | No Timing                                            | AAA        | Operable       | [guideline-2-2.md#sc-2-2-3](references/guideline-2-2.md#sc-2-2-3)   |
| 2.2.4  | Interruptions                                        | AAA        | Operable       | [guideline-2-2.md#sc-2-2-4](references/guideline-2-2.md#sc-2-2-4)   |
| 2.2.5  | Re-authenticating                                    | AAA        | Operable       | [guideline-2-2.md#sc-2-2-5](references/guideline-2-2.md#sc-2-2-5)   |
| 2.2.6  | Timeouts                                             | AAA        | Operable       | [guideline-2-2.md#sc-2-2-6](references/guideline-2-2.md#sc-2-2-6)   |
| 2.3.1  | Three Flashes or Below Threshold                     | A          | Operable       | [guideline-2-3.md#sc-2-3-1](references/guideline-2-3.md#sc-2-3-1)   |
| 2.3.2  | Three Flashes                                        | AAA        | Operable       | [guideline-2-3.md#sc-2-3-2](references/guideline-2-3.md#sc-2-3-2)   |
| 2.3.3  | Animation from Interactions                          | AAA        | Operable       | [guideline-2-3.md#sc-2-3-3](references/guideline-2-3.md#sc-2-3-3)   |
| 2.4.1  | Bypass Blocks                                        | A          | Operable       | [guideline-2-4.md#sc-2-4-1](references/guideline-2-4.md#sc-2-4-1)   |
| 2.4.2  | Page Titled                                          | A          | Operable       | [guideline-2-4.md#sc-2-4-2](references/guideline-2-4.md#sc-2-4-2)   |
| 2.4.3  | Focus Order                                          | A          | Operable       | [guideline-2-4.md#sc-2-4-3](references/guideline-2-4.md#sc-2-4-3)   |
| 2.4.4  | Link Purpose (In Context)                            | A          | Operable       | [guideline-2-4.md#sc-2-4-4](references/guideline-2-4.md#sc-2-4-4)   |
| 2.4.5  | Multiple Ways                                        | AA         | Operable       | [guideline-2-4.md#sc-2-4-5](references/guideline-2-4.md#sc-2-4-5)   |
| 2.4.6  | Headings and Labels                                  | AA         | Operable       | [guideline-2-4.md#sc-2-4-6](references/guideline-2-4.md#sc-2-4-6)   |
| 2.4.7  | Focus Visible                                        | AA         | Operable       | [guideline-2-4.md#sc-2-4-7](references/guideline-2-4.md#sc-2-4-7)   |
| 2.4.8  | Location                                             | AAA        | Operable       | [guideline-2-4.md#sc-2-4-8](references/guideline-2-4.md#sc-2-4-8)   |
| 2.4.9  | Link Purpose (Link Only)                             | AAA        | Operable       | [guideline-2-4.md#sc-2-4-9](references/guideline-2-4.md#sc-2-4-9)   |
| 2.4.10 | Section Headings                                     | AAA        | Operable       | [guideline-2-4.md#sc-2-4-10](references/guideline-2-4.md#sc-2-4-10) |
| 2.4.11 | Focus Not Obscured (Minimum)                         | AA         | Operable       | [guideline-2-4.md#sc-2-4-11](references/guideline-2-4.md#sc-2-4-11) |
| 2.4.12 | Focus Not Obscured (Enhanced)                        | AAA        | Operable       | [guideline-2-4.md#sc-2-4-12](references/guideline-2-4.md#sc-2-4-12) |
| 2.4.13 | Focus Appearance                                     | AAA        | Operable       | [guideline-2-4.md#sc-2-4-13](references/guideline-2-4.md#sc-2-4-13) |
| 2.5.1  | Pointer Gestures                                     | A          | Operable       | [guideline-2-5.md#sc-2-5-1](references/guideline-2-5.md#sc-2-5-1)   |
| 2.5.2  | Pointer Cancellation                                 | A          | Operable       | [guideline-2-5.md#sc-2-5-2](references/guideline-2-5.md#sc-2-5-2)   |
| 2.5.3  | Label in Name                                        | A          | Operable       | [guideline-2-5.md#sc-2-5-3](references/guideline-2-5.md#sc-2-5-3)   |
| 2.5.4  | Motion Actuation                                     | A          | Operable       | [guideline-2-5.md#sc-2-5-4](references/guideline-2-5.md#sc-2-5-4)   |
| 2.5.5  | Target Size (Enhanced)                               | AAA        | Operable       | [guideline-2-5.md#sc-2-5-5](references/guideline-2-5.md#sc-2-5-5)   |
| 2.5.6  | Concurrent Input Mechanisms                          | AAA        | Operable       | [guideline-2-5.md#sc-2-5-6](references/guideline-2-5.md#sc-2-5-6)   |
| 2.5.7  | Dragging Movements                                   | AA         | Operable       | [guideline-2-5.md#sc-2-5-7](references/guideline-2-5.md#sc-2-5-7)   |
| 2.5.8  | Target Size (Minimum)                                | AA         | Operable       | [guideline-2-5.md#sc-2-5-8](references/guideline-2-5.md#sc-2-5-8)   |
| 3.1.1  | Language of Page                                     | A          | Understandable | [guideline-3-1.md#sc-3-1-1](references/guideline-3-1.md#sc-3-1-1)   |
| 3.1.2  | Language of Parts                                    | AA         | Understandable | [guideline-3-1.md#sc-3-1-2](references/guideline-3-1.md#sc-3-1-2)   |
| 3.1.3  | Unusual Words                                        | AAA        | Understandable | [guideline-3-1.md#sc-3-1-3](references/guideline-3-1.md#sc-3-1-3)   |
| 3.1.4  | Abbreviations                                        | AAA        | Understandable | [guideline-3-1.md#sc-3-1-4](references/guideline-3-1.md#sc-3-1-4)   |
| 3.1.5  | Reading Level                                        | AAA        | Understandable | [guideline-3-1.md#sc-3-1-5](references/guideline-3-1.md#sc-3-1-5)   |
| 3.1.6  | Pronunciation                                        | AAA        | Understandable | [guideline-3-1.md#sc-3-1-6](references/guideline-3-1.md#sc-3-1-6)   |
| 3.2.1  | On Focus                                             | A          | Understandable | [guideline-3-2.md#sc-3-2-1](references/guideline-3-2.md#sc-3-2-1)   |
| 3.2.2  | On Input                                             | A          | Understandable | [guideline-3-2.md#sc-3-2-2](references/guideline-3-2.md#sc-3-2-2)   |
| 3.2.3  | Consistent Navigation                                | AA         | Understandable | [guideline-3-2.md#sc-3-2-3](references/guideline-3-2.md#sc-3-2-3)   |
| 3.2.4  | Consistent Identification                            | AA         | Understandable | [guideline-3-2.md#sc-3-2-4](references/guideline-3-2.md#sc-3-2-4)   |
| 3.2.5  | Change on Request                                    | AAA        | Understandable | [guideline-3-2.md#sc-3-2-5](references/guideline-3-2.md#sc-3-2-5)   |
| 3.2.6  | Consistent Help                                      | A          | Understandable | [guideline-3-2.md#sc-3-2-6](references/guideline-3-2.md#sc-3-2-6)   |
| 3.3.1  | Error Identification                                 | A          | Understandable | [guideline-3-3.md#sc-3-3-1](references/guideline-3-3.md#sc-3-3-1)   |
| 3.3.2  | Labels or Instructions                               | A          | Understandable | [guideline-3-3.md#sc-3-3-2](references/guideline-3-3.md#sc-3-3-2)   |
| 3.3.3  | Error Suggestion                                     | AA         | Understandable | [guideline-3-3.md#sc-3-3-3](references/guideline-3-3.md#sc-3-3-3)   |
| 3.3.4  | Error Prevention (Legal, Financial, Data)            | AA         | Understandable | [guideline-3-3.md#sc-3-3-4](references/guideline-3-3.md#sc-3-3-4)   |
| 3.3.5  | Help                                                 | AAA        | Understandable | [guideline-3-3.md#sc-3-3-5](references/guideline-3-3.md#sc-3-3-5)   |
| 3.3.6  | Error Prevention (All)                               | AAA        | Understandable | [guideline-3-3.md#sc-3-3-6](references/guideline-3-3.md#sc-3-3-6)   |
| 3.3.7  | Redundant Entry                                      | A          | Understandable | [guideline-3-3.md#sc-3-3-7](references/guideline-3-3.md#sc-3-3-7)   |
| 3.3.8  | Accessible Authentication (Minimum)                  | AA         | Understandable | [guideline-3-3.md#sc-3-3-8](references/guideline-3-3.md#sc-3-3-8)   |
| 3.3.9  | Accessible Authentication (Enhanced)                 | AAA        | Understandable | [guideline-3-3.md#sc-3-3-9](references/guideline-3-3.md#sc-3-3-9)   |
| 4.1.1  | Parsing (Obsolete and removed)                       | Deprecated | Robust         | [guideline-4-1.md#sc-4-1-1](references/guideline-4-1.md#sc-4-1-1)   |
| 4.1.2  | Name, Role, Value                                    | A          | Robust         | [guideline-4-1.md#sc-4-1-2](references/guideline-4-1.md#sc-4-1-2)   |
| 4.1.3  | Status Messages                                      | AA         | Robust         | [guideline-4-1.md#sc-4-1-3](references/guideline-4-1.md#sc-4-1-3)   |

## Assessment heuristics

Per-criterion assessment heuristics, common failure patterns, and scope notes live inside the per-guideline reference files in `references/`. The Accessibility Skill Assessor subagent consumes the appropriate `guideline-<n>-<m>.md#sc-<n>-<m>-<k>` section when evaluating a finding against a specific success criterion.

## Skill layout

* `SKILL.md` — this file (skill entrypoint and roll-up table).
* `references/` — one markdown file per WCAG 2.2 guideline. Each file contains the guideline statement, a paraphrased intent for every success criterion under that guideline, and a canonical W3C source URL.

## Guideline 1.1 — Text Alternatives

Guideline 1.1 (Text Alternatives) requires that every non-text element in the experience carry a text alternative that conveys the same purpose, so that the content can be re-rendered in any form that the user needs — large print, braille, speech, symbols, or simpler language.

Source: W3C Web Content Accessibility Guidelines (WCAG) 2.2, Guideline 1.1, <https://www.w3.org/TR/WCAG22/#text-alternatives>.

### sc-1-1-1

**SC 1.1.1 Non-text Content (Level A)**

Every non-text element exposed in the user interface needs a programmatically associated text alternative that serves the same purpose. Decorative or formatting-only elements may carry an empty or ignorable alternative so that assistive technology skips them, and time-based media, tests, sensory experiences, CAPTCHAs, and pure decoration each have their own narrower exception described in the W3C source.

**Applies to**: Images, icons, image buttons, image maps, charts, complex graphics, video and audio (for the placeholder text-equivalent), form controls, audio-only and video-only content (placeholder text), CAPTCHAs, and any embedded object exposed to the user.

**Assessment heuristics**:

* Confirm that every image conveying meaning carries a non-empty `alt`, `aria-label`, or `aria-labelledby` that paraphrases the information conveyed by the image, not the file name.
* Confirm that decorative images carry `alt=""` or `role="presentation"` so assistive technology skips them.
* Confirm that image buttons announce the action (for example, "Submit application") rather than the icon name.
* Confirm that complex graphics carry a short text equivalent plus a longer description accessible via link or `aria-describedby`.
* Confirm that CAPTCHAs offer at least two alternative modalities (visual plus audio, plus a non-cognitive option where feasible).

Source: <https://www.w3.org/TR/WCAG22/#non-text-content>

## Guideline 1.2 — Time-based Media

Guideline 1.2 (Time-based Media) requires alternatives for prerecorded and live audio and video content so that users who cannot hear or cannot see the media can still receive the same information through captions, transcripts, audio description, or sign-language interpretation.

Source: W3C Web Content Accessibility Guidelines (WCAG) 2.2, Guideline 1.2, <https://www.w3.org/TR/WCAG22/#time-based-media>.

### sc-1-2-1

**SC 1.2.1 Audio-only and Video-only (Prerecorded) (Level A)**

For prerecorded audio-only media, provide a text transcript that conveys the same information. For prerecorded video-only media, provide either a text or audio alternative that conveys the equivalent information.

**Assessment heuristics**:

* Confirm a transcript is available adjacent to or linked from the audio-only player.
* Confirm video-only media has either a narrated audio track or a text description that captures the visual narrative.
* Confirm the transcript identifies speakers and describes meaningful non-speech sounds when present.

Source: <https://www.w3.org/TR/WCAG22/#audio-only-and-video-only-prerecorded>

### sc-1-2-2

**SC 1.2.2 Captions (Prerecorded) (Level A)**

Synchronised captions accompany all prerecorded audio content that is part of synchronised media, except when the media itself is a media alternative for text and is clearly labelled as such.

**Assessment heuristics**:

* Confirm captions are synchronised with speech, identify speakers, and capture meaningful non-speech audio.
* Confirm captions are an actual caption track (closed or open) rather than auto-generated speech-to-text without human review.
* Confirm caption playback controls are reachable by keyboard.

Source: <https://www.w3.org/TR/WCAG22/#captions-prerecorded>

### sc-1-2-3

**SC 1.2.3 Audio Description or Media Alternative (Prerecorded) (Level A)**

For prerecorded synchronised media, provide either an audio description of the video track or a full text alternative that conveys the same information as the combined audio plus video.

**Assessment heuristics**:

* Confirm either an audio-described version of the media is offered or a transcript that includes visual description is linked.
* Confirm the alternative covers actions, characters, scene changes, and on-screen text that are not in the dialogue.

Source: <https://www.w3.org/TR/WCAG22/#audio-description-or-media-alternative-prerecorded>

### sc-1-2-4

**SC 1.2.4 Captions (Live) (Level AA)**

Synchronised captions accompany all live audio content delivered as part of synchronised media (for example, live webinars, town halls, and streaming events).

**Assessment heuristics**:

* Confirm live captioning is staffed by a human captioner or a vetted real-time captioning service for any scheduled live event.
* Confirm captions are visible on the same surface as the video and remain legible against the underlying picture.

Source: <https://www.w3.org/TR/WCAG22/#captions-live>

### sc-1-2-5

**SC 1.2.5 Audio Description (Prerecorded) (Level AA)**

Audio description of the video track is provided for all prerecorded synchronised media; a text-only alternative is no longer sufficient at Level AA.

**Assessment heuristics**:

* Confirm an audio-described track is offered either as the default audio or as a selectable secondary track.
* Confirm the audio description fits within natural pauses in the dialogue or that an extended description (SC 1.2.7) is offered.

Source: <https://www.w3.org/TR/WCAG22/#audio-description-prerecorded>

### sc-1-2-6

**SC 1.2.6 Sign Language (Prerecorded) (Level AAA)**

Sign-language interpretation accompanies prerecorded audio content in synchronised media.

**Assessment heuristics**:

* Confirm a sign-language interpreter video is offered in a regional sign language relevant to the audience.
* Confirm the interpreter window is large enough to read facial expressions and hand shape.

Source: <https://www.w3.org/TR/WCAG22/#sign-language-prerecorded>

### sc-1-2-7

**SC 1.2.7 Extended Audio Description (Prerecorded) (Level AAA)**

Where pauses in foreground audio are insufficient for standard audio description, an extended audio-described version (pausing the video to allow description) is provided.

**Assessment heuristics**:

* Confirm the extended description pauses the video where needed and resumes synchronisation cleanly.
* Confirm a control is provided to skip or speed through extended descriptions for users who have already heard them.

Source: <https://www.w3.org/TR/WCAG22/#extended-audio-description-prerecorded>

### sc-1-2-8

**SC 1.2.8 Media Alternative (Prerecorded) (Level AAA)**

A full text alternative is provided for all prerecorded synchronised media and for prerecorded video-only media, covering both dialogue and visual content.

**Assessment heuristics**:

* Confirm a full transcript is available that includes speaker tags, non-speech audio cues, and visual scene descriptions.
* Confirm the transcript is reachable from the same surface as the media.

Source: <https://www.w3.org/TR/WCAG22/#media-alternative-prerecorded>

### sc-1-2-9

**SC 1.2.9 Audio-only (Live) (Level AAA)**

An alternative for live audio-only content that conveys equivalent information is provided (for example, a live human transcription or sign-language interpretation).

**Assessment heuristics**:

* Confirm live audio-only programmes (radio-style streams, telephony bridges) offer a real-time captioning or transcription channel.

Source: <https://www.w3.org/TR/WCAG22/#audio-only-live>

## Guideline 1.3 — Adaptable

Guideline 1.3 (Adaptable) requires that content can be presented in different ways without losing information or structure, so assistive technology can convey relationships, sequence, and meaning that sighted users perceive visually.

Source: W3C Web Content Accessibility Guidelines (WCAG) 2.2, Guideline 1.3, <https://www.w3.org/TR/WCAG22/#adaptable>.

### sc-1-3-1

**SC 1.3.1 Info and Relationships (Level A)**

Information, structure, and relationships conveyed through presentation can be programmatically determined or are available in text.

**Assessment heuristics**:

* Confirm headings use semantic heading elements with a sensible nesting order rather than styled paragraphs.
* Confirm data tables use `<th>` with appropriate `scope` or `headers`/`id` association rather than visual layout alone.
* Confirm lists, fieldsets, and landmarks use their native semantic markup.
* Confirm form controls have programmatically associated labels (label-for, `aria-labelledby`, or wrapping label).
* Confirm visual groupings (boxes, columns, bold headings) carry equivalent programmatic structure.

Source: <https://www.w3.org/TR/WCAG22/#info-and-relationships>

### sc-1-3-2

**SC 1.3.2 Meaningful Sequence (Level A)**

When the sequence of content affects its meaning, the reading order is programmatically determinable.

**Assessment heuristics**:

* Confirm DOM order matches the visual reading order on left-to-right and right-to-left locales.
* Confirm CSS positioning (`float`, `flex-direction: row-reverse`, `order`) does not desynchronise visual order from DOM order in a way that changes meaning.
* Confirm tabular and multi-column layouts read in a logical sequence when CSS is disabled.

Source: <https://www.w3.org/TR/WCAG22/#meaningful-sequence>

### sc-1-3-3

**SC 1.3.3 Sensory Characteristics (Level A)**

Instructions do not rely solely on sensory characteristics such as shape, colour, size, visual location, orientation, or sound.

**Assessment heuristics**:

* Confirm instructions like "click the red button" are accompanied by a text label ("click Submit").
* Confirm instructions that reference shape ("the round icon") add a non-sensory identifier.
* Confirm spatial instructions ("the menu on the right") include an alternative identifier.

Source: <https://www.w3.org/TR/WCAG22/#sensory-characteristics>

### sc-1-3-4

**SC 1.3.4 Orientation (Level AA)**

Content does not restrict its view to a single display orientation (portrait or landscape) unless a specific orientation is essential.

**Assessment heuristics**:

* Confirm the app, page, or media does not lock to one orientation through CSS, `screen.orientation.lock()`, or platform manifest entries except where essential (for example, a piano keyboard).
* Confirm orientation changes do not lose user input or context.

Source: <https://www.w3.org/TR/WCAG22/#orientation>

### sc-1-3-5

**SC 1.3.5 Identify Input Purpose (Level AA)**

The purpose of each input field that collects information about the user can be programmatically determined when the field corresponds to one of the WCAG-defined input purposes.

**Assessment heuristics**:

* Confirm fields collecting personal data (name, email, phone, address, payment) use the `autocomplete` attribute with the appropriate token.
* Confirm `autocomplete` values match the WCAG input-purpose vocabulary.
* Confirm autofill works as the user expects with the browser's stored data.

Source: <https://www.w3.org/TR/WCAG22/#identify-input-purpose>

### sc-1-3-6

**SC 1.3.6 Identify Purpose (Level AAA)**

The purpose of user-interface components, icons, and regions can be programmatically determined (for example, through ARIA landmark roles, `aria-label`, or microdata).

**Assessment heuristics**:

* Confirm landmarks (`<main>`, `<nav>`, `<aside>`, `<header>`, `<footer>` or equivalent ARIA roles) cover the page.
* Confirm icons that act as controls expose a programmatic name and role.
* Confirm symbolic UI controls (icons) carry consistent and machine-readable purpose metadata.

Source: <https://www.w3.org/TR/WCAG22/#identify-purpose>

## Guideline 1.4 — Distinguishable

Guideline 1.4 (Distinguishable) requires that content be easy to see and hear, including separating foreground from background, supporting text resizing and reflow, and providing sufficient contrast for text and non-text UI elements.

Source: W3C Web Content Accessibility Guidelines (WCAG) 2.2, Guideline 1.4, <https://www.w3.org/TR/WCAG22/#distinguishable>.

### sc-1-4-1

**SC 1.4.1 Use of Color (Level A)**

Colour is not used as the only visual means of conveying information, indicating an action, prompting a response, or distinguishing a visual element.

**Assessment heuristics**:

* Confirm required form fields are indicated by text or icon in addition to colour.
* Confirm errors, warnings, and status callouts carry an icon or text label, not just a colour.
* Confirm chart legends, link styling, and stateful UI elements use a non-colour cue (underline, pattern, icon, text).

Source: <https://www.w3.org/TR/WCAG22/#use-of-color>

### sc-1-4-2

**SC 1.4.2 Audio Control (Level A)**

If audio plays automatically for more than 3 seconds, either provide a mechanism to pause or stop the audio or a mechanism to control its volume independently from the overall system volume.

**Assessment heuristics**:

* Confirm autoplaying audio carries a visible pause/stop control that is keyboard reachable within the first three seconds.
* Confirm a media player provides an independent volume control rather than relying solely on OS volume.

Source: <https://www.w3.org/TR/WCAG22/#audio-control>

### sc-1-4-3

**SC 1.4.3 Contrast (Minimum) (Level AA)**

The visual presentation of text and images of text has a contrast ratio of at least 4.5:1, except for large text (3:1), incidental text, and logotypes.

**Assessment heuristics**:

* Confirm body text reaches 4.5:1 against its background using a contrast tool.
* Confirm large text (18pt regular or 14pt bold) reaches at least 3:1.
* Confirm placeholder text and disabled-looking states that still convey information meet 4.5:1.
* Confirm text over images, gradients, or video uses a backplate or shadow that brings effective contrast to 4.5:1.

Source: <https://www.w3.org/TR/WCAG22/#contrast-minimum>

### sc-1-4-4

**SC 1.4.4 Resize Text (Level AA)**

Text can be resized up to 200 per cent without loss of content or functionality, except for captions and images of text.

**Assessment heuristics**:

* Confirm zooming the browser to 200% does not clip content, hide controls, or create horizontal scrolling on text blocks.
* Confirm text is sized in relative units (`rem`, `em`, `%`) rather than fixed pixels for body copy.

Source: <https://www.w3.org/TR/WCAG22/#resize-text>

### sc-1-4-5

**SC 1.4.5 Images of Text (Level AA)**

Text is used to convey information rather than images of text, unless the image is essential (for example, a logotype) or fully customisable by the user.

**Assessment heuristics**:

* Confirm marketing banners, navigation labels, and instructional content use HTML text styled with CSS rather than baked-in image text.
* Confirm logotype images are the only allowed image-of-text exception.

Source: <https://www.w3.org/TR/WCAG22/#images-of-text>

### sc-1-4-6

**SC 1.4.6 Contrast (Enhanced) (Level AAA)**

Text and images of text have a contrast ratio of at least 7:1 (4.5:1 for large text).

**Assessment heuristics**:

* Confirm body text reaches 7:1 contrast for AAA-targeted experiences.

Source: <https://www.w3.org/TR/WCAG22/#contrast-enhanced>

### sc-1-4-7

**SC 1.4.7 Low or No Background Audio (Level AAA)**

Prerecorded audio that contains primarily speech in the foreground has no background sound, the background sound can be turned off, or the background is at least 20 dB lower than the foreground speech.

**Assessment heuristics**:

* Confirm narration tracks reduce or remove background music during speech.
* Confirm an alternative track with no background music is offered when background sound is desired.

Source: <https://www.w3.org/TR/WCAG22/#low-or-no-background-audio>

### sc-1-4-8

**SC 1.4.8 Visual Presentation (Level AAA)**

For blocks of text, users can select foreground and background colours, line width does not exceed 80 characters, text is not justified, line and paragraph spacing reach defined minimums, and text resizes to 200% without horizontal scroll.

**Assessment heuristics**:

* Confirm a high-contrast or user-themed mode is offered for long-form text.
* Confirm line length stays below 80 characters in the default presentation.

Source: <https://www.w3.org/TR/WCAG22/#visual-presentation>

### sc-1-4-9

**SC 1.4.9 Images of Text (No Exception) (Level AAA)**

Images of text are used only for decoration or where a particular presentation of text is essential (no general customisation exemption).

**Assessment heuristics**:

* Confirm even customisable imagery rendered with text is replaced with live text for AAA scope.

Source: <https://www.w3.org/TR/WCAG22/#images-of-text-no-exception>

### sc-1-4-10

**SC 1.4.10 Reflow (Level AA)**

Content can be presented without loss of information or functionality, and without requiring scrolling in two dimensions, at a viewport width of 320 CSS pixels (or 256 CSS pixels height for vertical scrolling content), except for parts that require two-dimensional layout.

**Assessment heuristics**:

* Confirm a 320-pixel-wide viewport (or 400% zoom on a 1280-pixel viewport) does not produce horizontal scrolling on text content.
* Confirm tables, code blocks, and large images may scroll horizontally only when two-dimensional layout is essential.

Source: <https://www.w3.org/TR/WCAG22/#reflow>

### sc-1-4-11

**SC 1.4.11 Non-text Contrast (Level AA)**

Visual presentation of user-interface components and graphical objects required to understand the content has a contrast ratio of at least 3:1 against adjacent colours.

**Assessment heuristics**:

* Confirm form-control borders, focus indicators, and active/selected states reach 3:1 against adjacent colours.
* Confirm icons that convey information reach 3:1 against their background.
* Confirm chart elements distinguishable by shape rely on 3:1 contrast for those shape outlines.

Source: <https://www.w3.org/TR/WCAG22/#non-text-contrast>

### sc-1-4-12

**SC 1.4.12 Text Spacing (Level AA)**

No loss of content or functionality when users override line height (1.5x font), paragraph spacing (2x font), letter spacing (0.12x font), and word spacing (0.16x font).

**Assessment heuristics**:

* Confirm injecting the WCAG text-spacing CSS does not clip text, overlap content, or hide controls.
* Confirm container heights do not constrain text such that the spacing override truncates content.

Source: <https://www.w3.org/TR/WCAG22/#text-spacing>

### sc-1-4-13

**SC 1.4.13 Content on Hover or Focus (Level AA)**

Additional content triggered by hover or focus is dismissible, hoverable (the pointer can move into it without dismissing), and persistent (remains visible until dismissed or no longer relevant).

**Assessment heuristics**:

* Confirm tooltips, popovers, and submenus can be dismissed with the Escape key without moving focus.
* Confirm hover-triggered overlays do not disappear when the pointer moves over the overlay itself.
* Confirm the overlay persists until the triggering condition ends or the user dismisses it.

Source: <https://www.w3.org/TR/WCAG22/#content-on-hover-or-focus>

## Guideline 2.1 — Keyboard Accessible

Guideline 2.1 (Keyboard Accessible) requires that all functionality be available through a keyboard interface, without time-based input dependencies, so users who cannot use a mouse can operate the experience.

Source: W3C Web Content Accessibility Guidelines (WCAG) 2.2, Guideline 2.1, <https://www.w3.org/TR/WCAG22/#keyboard-accessible>.

### sc-2-1-1

**SC 2.1.1 Keyboard (Level A)**

All functionality of the content is operable through a keyboard interface without requiring specific timings for individual keystrokes, except where the underlying function requires input that depends on the path of the user's movement (for example, freehand drawing).

**Assessment heuristics**:

* Confirm every interactive control receives focus via Tab order and activates with Enter or Space (or the role-appropriate key).
* Confirm drag-and-drop, hover-only menus, swipe gestures, and right-click context menus have a keyboard-operable equivalent.
* Confirm custom controls (`role="button"`, `role="checkbox"`) implement the expected key handling.

Source: <https://www.w3.org/TR/WCAG22/#keyboard>

### sc-2-1-2

**SC 2.1.2 No Keyboard Trap (Level A)**

When keyboard focus can be moved to a component, focus can also be moved away using only the keyboard, and the user is told how if a non-standard key is required.

**Assessment heuristics**:

* Confirm modal dialogs trap focus while open but release it on close (Escape or close button).
* Confirm embedded iframes, plugins, or third-party widgets allow Tab and Shift+Tab to exit them.
* Confirm any non-standard exit key is documented in the surrounding UI.

Source: <https://www.w3.org/TR/WCAG22/#no-keyboard-trap>

### sc-2-1-3

**SC 2.1.3 Keyboard (No Exception) (Level AAA)**

All functionality of the content is operable through a keyboard interface without exception for path-dependent input.

**Assessment heuristics**:

* Confirm freehand signature, drawing, or gesture inputs each provide a fully keyboard-driven equivalent path.

Source: <https://www.w3.org/TR/WCAG22/#keyboard-no-exception>

### sc-2-1-4

**SC 2.1.4 Character Key Shortcuts (Level A)**

If a keyboard shortcut is implemented using only letter (including upper- and lower-case letters), punctuation, number, or symbol characters, then at least one of: the shortcut can be turned off, the shortcut can be remapped, or the shortcut is active only when the relevant component has focus.

**Assessment heuristics**:

* Confirm single-key shortcuts are scoped to focused components, remappable, or have an off switch.
* Confirm modifier-key combinations (Ctrl, Alt, Cmd) used as shortcuts are not affected by this criterion but are still documented.

Source: <https://www.w3.org/TR/WCAG22/#character-key-shortcuts>

## Guideline 2.2 — Enough Time

Guideline 2.2 (Enough Time) requires that users have enough time to read and use content, including adjustable time limits and pause/stop/hide controls for moving content.

Source: W3C Web Content Accessibility Guidelines (WCAG) 2.2, Guideline 2.2, <https://www.w3.org/TR/WCAG22/#enough-time>.

### sc-2-2-1

**SC 2.2.1 Timing Adjustable (Level A)**

For each time limit set by the content, at least one of: the user can turn off the limit, the user can adjust it to at least 10 times the default, the user is warned before the limit expires and can extend it with a simple action, the limit is essential (auction, real-time event), or the limit is longer than 20 hours.

**Assessment heuristics**:

* Confirm session-timeout warnings appear before expiry with an option to extend by a simple action.
* Confirm timed quizzes and forms offer an accessibility-aware extension or alternative.

Source: <https://www.w3.org/TR/WCAG22/#timing-adjustable>

### sc-2-2-2

**SC 2.2.2 Pause, Stop, Hide (Level A)**

For moving, blinking, scrolling, or auto-updating information that starts automatically, lasts more than 5 seconds, and is presented in parallel with other content, the user has a mechanism to pause, stop, or hide it (or to control its update frequency).

**Assessment heuristics**:

* Confirm auto-rotating carousels and tickers carry a pause control reachable by keyboard.
* Confirm animated content longer than 5 seconds can be stopped without disabling the rest of the page.

Source: <https://www.w3.org/TR/WCAG22/#pause-stop-hide>

### sc-2-2-3

**SC 2.2.3 No Timing (Level AAA)**

Timing is not an essential part of the event or activity presented, except for non-interactive synchronised media and real-time events.

**Assessment heuristics**:

* Confirm any non-essential time limits are removed for AAA targets.

Source: <https://www.w3.org/TR/WCAG22/#no-timing>

### sc-2-2-4

**SC 2.2.4 Interruptions (Level AAA)**

Interruptions (notifications, alerts, banners) can be postponed or suppressed by the user, except interruptions involving an emergency.

**Assessment heuristics**:

* Confirm users can configure or pause non-emergency push notifications.

Source: <https://www.w3.org/TR/WCAG22/#interruptions>

### sc-2-2-5

**SC 2.2.5 Re-authenticating (Level AAA)**

When an authenticated session expires, the user can continue the activity without loss of data after re-authentication.

**Assessment heuristics**:

* Confirm forms preserve user-entered data through a re-authentication flow.

Source: <https://www.w3.org/TR/WCAG22/#re-authenticating>

### sc-2-2-6

**SC 2.2.6 Timeouts (Level AAA)**

Users are warned about the duration of any user inactivity that could cause data loss, unless the data is preserved for more than 20 hours when the user does not take any actions.

**Assessment heuristics**:

* Confirm a clearly visible warning describes the inactivity timeout duration.
* Confirm draft-saving behaviour is documented to the user.

Source: <https://www.w3.org/TR/WCAG22/#timeouts>

## Guideline 2.3 — Seizures and Physical Reactions

Guideline 2.3 (Seizures and Physical Reactions) requires that content not be designed in a way known to cause seizures or physical reactions, especially through flashing content.

Source: W3C Web Content Accessibility Guidelines (WCAG) 2.2, Guideline 2.3, <https://www.w3.org/TR/WCAG22/#seizures-and-physical-reactions>.

### sc-2-3-1

**SC 2.3.1 Three Flashes or Below Threshold (Level A)**

Web pages do not contain anything that flashes more than three times in any one-second period, or the flash is below the general flash and red flash thresholds defined by WCAG.

**Assessment heuristics**:

* Confirm video, animations, and decorative effects do not exceed three flashes per second.
* Confirm flashing red content is checked against the WCAG red-flash threshold using a recognised tool such as PEAT.

Source: <https://www.w3.org/TR/WCAG22/#three-flashes-or-below-threshold>

### sc-2-3-2

**SC 2.3.2 Three Flashes (Level AAA)**

Web pages do not contain anything that flashes more than three times in any one-second period (no general or red flash exception threshold).

**Assessment heuristics**:

* Confirm AAA-targeted experiences contain no content that flashes more than three times per second under any luminance condition.

Source: <https://www.w3.org/TR/WCAG22/#three-flashes>

### sc-2-3-3

**SC 2.3.3 Animation from Interactions (Level AAA)**

Motion animation triggered by interaction can be disabled, unless the animation is essential to the functionality or the information being conveyed.

**Assessment heuristics**:

* Confirm a `prefers-reduced-motion` media query disables decorative motion.
* Confirm the user can disable scroll-linked or parallax animations through a setting where the OS preference is unavailable.

Source: <https://www.w3.org/TR/WCAG22/#animation-from-interactions>

## Guideline 2.4 — Navigable

Guideline 2.4 (Navigable) requires that users have ways to navigate, find content, and determine where they are within the experience, through bypass mechanisms, titles, focus order, link purpose, headings, and visible focus indicators.

Source: W3C Web Content Accessibility Guidelines (WCAG) 2.2, Guideline 2.4, <https://www.w3.org/TR/WCAG22/#navigable>.

### sc-2-4-1

**SC 2.4.1 Bypass Blocks (Level A)**

A mechanism is available to bypass blocks of content that are repeated on multiple pages.

**Assessment heuristics**:

* Confirm a skip-to-main-content link is the first focusable element on the page and becomes visible on focus.
* Confirm landmarks (`<main>`, `<nav>`, `<aside>`) are used so assistive technology users can jump between regions.

Source: <https://www.w3.org/TR/WCAG22/#bypass-blocks>

### sc-2-4-2

**SC 2.4.2 Page Titled (Level A)**

Pages have titles that describe their topic or purpose.

**Assessment heuristics**:

* Confirm `<title>` reflects the page topic and updates on client-side navigation in single-page applications.
* Confirm titles disambiguate similar pages (for example, "Cart - 3 items" rather than just "Cart").

Source: <https://www.w3.org/TR/WCAG22/#page-titled>

### sc-2-4-3

**SC 2.4.3 Focus Order (Level A)**

If content can be navigated sequentially and the order affects meaning or operation, focusable components receive focus in an order that preserves meaning and operability.

**Assessment heuristics**:

* Confirm Tab order follows the visual reading order and does not jump unexpectedly across the page.
* Confirm `tabindex` values greater than zero are avoided.
* Confirm modals move focus into the dialog when opened and back to the trigger when closed.

Source: <https://www.w3.org/TR/WCAG22/#focus-order>

### sc-2-4-4

**SC 2.4.4 Link Purpose (In Context) (Level A)**

The purpose of each link is determined from the link text alone or from the link text together with its programmatically determined link context.

**Assessment heuristics**:

* Confirm link text is meaningful on its own or with adjacent text (avoid "click here", "read more" alone).
* Confirm icon-only links carry an accessible name via `aria-label` or visually hidden text.

Source: <https://www.w3.org/TR/WCAG22/#link-purpose-in-context>

### sc-2-4-5

**SC 2.4.5 Multiple Ways (Level AA)**

More than one way is available to locate a page within a set of pages, except where the page is the result of, or a step in, a process.

**Assessment heuristics**:

* Confirm the site provides at least two of: site map, search, table of contents, navigation menu, or related-links list.

Source: <https://www.w3.org/TR/WCAG22/#multiple-ways>

### sc-2-4-6

**SC 2.4.6 Headings and Labels (Level AA)**

Headings and labels describe the topic or purpose of the section or control they identify.

**Assessment heuristics**:

* Confirm heading text concisely describes the section content.
* Confirm form labels describe the input rather than restating the placeholder.

Source: <https://www.w3.org/TR/WCAG22/#headings-and-labels>

### sc-2-4-7

**SC 2.4.7 Focus Visible (Level AA)**

Any keyboard-operable interface has a mode of operation where the keyboard focus indicator is visible.

**Assessment heuristics**:

* Confirm the default browser focus ring is preserved or replaced with a custom indicator of equal or greater visibility.
* Confirm focus indicators meet the SC 1.4.11 non-text contrast threshold against adjacent colours.

Source: <https://www.w3.org/TR/WCAG22/#focus-visible>

### sc-2-4-8

**SC 2.4.8 Location (Level AAA)**

Information about the user's location within a set of pages is available.

**Assessment heuristics**:

* Confirm breadcrumbs, current-page indicators in navigation, or site-map highlights are present.

Source: <https://www.w3.org/TR/WCAG22/#location>

### sc-2-4-9

**SC 2.4.9 Link Purpose (Link Only) (Level AAA)**

A mechanism is available to allow the purpose of each link to be identified from the link text alone, except where the purpose is ambiguous to users in general.

**Assessment heuristics**:

* Confirm link text is fully self-describing without surrounding context.

Source: <https://www.w3.org/TR/WCAG22/#link-purpose-link-only>

### sc-2-4-10

**SC 2.4.10 Section Headings (Level AAA)**

Section headings are used to organise content where applicable.

**Assessment heuristics**:

* Confirm long-form content uses headings at appropriate levels to segment topics.

Source: <https://www.w3.org/TR/WCAG22/#section-headings>

### sc-2-4-11

**SC 2.4.11 Focus Not Obscured (Minimum) (Level AA)**

When a user-interface component receives keyboard focus, the component is not entirely hidden by author-created content.

**Assessment heuristics**:

* Confirm sticky headers, footers, cookie banners, or chat widgets do not entirely cover the currently focused control.
* Confirm scrolling brings the focused control into a visible position when overlays are present.

Source: <https://www.w3.org/TR/WCAG22/#focus-not-obscured-minimum>

### sc-2-4-12

**SC 2.4.12 Focus Not Obscured (Enhanced) (Level AAA)**

When a user-interface component receives keyboard focus, no part of the component is hidden by author-created content.

**Assessment heuristics**:

* Confirm overlays leave the entire focused control visible, not just a portion.

Source: <https://www.w3.org/TR/WCAG22/#focus-not-obscured-enhanced>

### sc-2-4-13

**SC 2.4.13 Focus Appearance (Level AAA)**

The keyboard focus indicator meets defined minimum size, contrast, and area requirements (an outline at least 2 CSS pixels thick with 3:1 contrast against unfocused state, and no obscuring of the focused component).

**Assessment heuristics**:

* Confirm focus indicators are at least 2 CSS pixels thick on the perimeter or equivalent area.
* Confirm 3:1 contrast between focused and unfocused states.

Source: <https://www.w3.org/TR/WCAG22/#focus-appearance>

## Guideline 2.5 — Input Modalities

Guideline 2.5 (Input Modalities) requires that users can operate functionality through various inputs beyond the keyboard, including pointer, touch, motion, and voice, with adequate target size and cancellation.

Source: W3C Web Content Accessibility Guidelines (WCAG) 2.2, Guideline 2.5, <https://www.w3.org/TR/WCAG22/#input-modalities>.

### sc-2-5-1

**SC 2.5.1 Pointer Gestures (Level A)**

All functionality that uses multipoint or path-based gestures can be operated with a single pointer without a path-based gesture, unless a multipoint or path-based gesture is essential.

**Assessment heuristics**:

* Confirm swipe, pinch, and rotate gestures have a single-tap or single-click alternative.
* Confirm path-based interactions (drag along a curve) have an equivalent tap-based path.

Source: <https://www.w3.org/TR/WCAG22/#pointer-gestures>

### sc-2-5-2

**SC 2.5.2 Pointer Cancellation (Level A)**

For functionality operated using a single pointer, at least one of the following is true: no down-event activates the function, the function completes on up-event and a mechanism is available to abort or undo, the up-event reverses the down-event, or completing on down-event is essential.

**Assessment heuristics**:

* Confirm clicks fire on pointerup or mouseup rather than on pointerdown for non-essential actions.
* Confirm dragging off a button before release cancels the activation.

Source: <https://www.w3.org/TR/WCAG22/#pointer-cancellation>

### sc-2-5-3

**SC 2.5.3 Label in Name (Level A)**

For user-interface components with labels that include text or images of text, the accessible name contains the text that is presented visually.

**Assessment heuristics**:

* Confirm `aria-label` strings include the visible text exactly rather than rephrasing it.
* Confirm speech-input users can activate a control by saying its visible label.

Source: <https://www.w3.org/TR/WCAG22/#label-in-name>

### sc-2-5-4

**SC 2.5.4 Motion Actuation (Level A)**

Functionality that can be operated by device motion or user motion can also be operated by user-interface components, and response to motion can be disabled to prevent accidental actuation, except when motion is essential or the motion is used through an accessibility-supported interface.

**Assessment heuristics**:

* Confirm shake-to-undo and tilt-based controls have an on-screen equivalent.
* Confirm a setting disables motion-triggered actions for users with motor impairments.

Source: <https://www.w3.org/TR/WCAG22/#motion-actuation>

### sc-2-5-5

**SC 2.5.5 Target Size (Enhanced) (Level AAA)**

The size of the target for pointer inputs is at least 44 by 44 CSS pixels, except where the target is inline, user-agent-controlled, essential, or has an equivalent target meeting the size requirement.

**Assessment heuristics**:

* Confirm touch targets are at least 44x44 CSS pixels in the dominant interaction surface.

Source: <https://www.w3.org/TR/WCAG22/#target-size-enhanced>

### sc-2-5-6

**SC 2.5.6 Concurrent Input Mechanisms (Level AAA)**

Web content does not restrict the use of input modalities available on a platform except where the restriction is essential, required to ensure security of the content, or required to respect user settings.

**Assessment heuristics**:

* Confirm switching between touch, mouse, and keyboard within a session does not disable input modalities.

Source: <https://www.w3.org/TR/WCAG22/#concurrent-input-mechanisms>

### sc-2-5-7

**SC 2.5.7 Dragging Movements (Level AA)**

All functionality that uses a dragging movement for operation can be achieved by a single pointer without dragging, unless dragging is essential or determined by the user agent.

**Assessment heuristics**:

* Confirm drag-to-reorder lists offer up/down buttons or keyboard shortcuts as alternatives.
* Confirm slider controls accept tap-and-arrow input as an alternative to drag.

Source: <https://www.w3.org/TR/WCAG22/#dragging-movements>

### sc-2-5-8

**SC 2.5.8 Target Size (Minimum) (Level AA)**

The size of the target for pointer inputs is at least 24 by 24 CSS pixels, with defined exceptions for spacing, inline targets, user-agent controls, and essential presentations.

**Assessment heuristics**:

* Confirm touch targets are at least 24x24 CSS pixels or that smaller targets carry sufficient surrounding space so the effective target reaches 24x24.

Source: <https://www.w3.org/TR/WCAG22/#target-size-minimum>

## Guideline 3.1 — Readable

Guideline 3.1 (Readable) requires that text content be readable and understandable, including identifying the language of the page and unusual content, and providing reading-level support where needed.

Source: W3C Web Content Accessibility Guidelines (WCAG) 2.2, Guideline 3.1, <https://www.w3.org/TR/WCAG22/#readable>.

### sc-3-1-1

**SC 3.1.1 Language of Page (Level A)**

The default human language of each web page can be programmatically determined.

**Assessment heuristics**:

* Confirm the root `<html>` element carries a `lang` attribute with a valid BCP 47 language tag.
* Confirm single-page applications set the language attribute to reflect the current content language when locale changes.

Source: <https://www.w3.org/TR/WCAG22/#language-of-page>

### sc-3-1-2

**SC 3.1.2 Language of Parts (Level AA)**

The human language of each passage or phrase in the content can be programmatically determined, except for proper names, technical terms, words of indeterminate language, and words or phrases that have become part of the surrounding text's vernacular.

**Assessment heuristics**:

* Confirm passages in a different language carry a `lang` attribute on the enclosing element.
* Confirm inline language switches (quotations, terms) use a `<span lang="...">`.

Source: <https://www.w3.org/TR/WCAG22/#language-of-parts>

### sc-3-1-3

**SC 3.1.3 Unusual Words (Level AAA)**

A mechanism is available for identifying specific definitions of words or phrases used in an unusual or restricted way, including idioms and jargon.

**Assessment heuristics**:

* Confirm jargon and idioms link to a glossary entry or expose a tooltip-style definition.

Source: <https://www.w3.org/TR/WCAG22/#unusual-words>

### sc-3-1-4

**SC 3.1.4 Abbreviations (Level AAA)**

A mechanism for identifying the expanded form or meaning of abbreviations is available.

**Assessment heuristics**:

* Confirm abbreviations are expanded on first use or exposed via `<abbr title>` or a glossary.

Source: <https://www.w3.org/TR/WCAG22/#abbreviations>

### sc-3-1-5

**SC 3.1.5 Reading Level (Level AAA)**

When text requires a reading ability more advanced than the lower secondary education level, supplemental content or a simpler version is available.

**Assessment heuristics**:

* Confirm long-form content has a plain-language summary or a simpler variant.

Source: <https://www.w3.org/TR/WCAG22/#reading-level>

### sc-3-1-6

**SC 3.1.6 Pronunciation (Level AAA)**

A mechanism is available for identifying specific pronunciation of words where pronunciation is essential to understanding meaning.

**Assessment heuristics**:

* Confirm homographs or pronunciation-sensitive terms include pronunciation hints (audio, IPA, or ruby annotation).

Source: <https://www.w3.org/TR/WCAG22/#pronunciation>

## Guideline 3.2 — Predictable

Guideline 3.2 (Predictable) requires that web pages appear and operate in predictable ways, with consistent navigation and identification across the experience and no unexpected context changes.

Source: W3C Web Content Accessibility Guidelines (WCAG) 2.2, Guideline 3.2, <https://www.w3.org/TR/WCAG22/#predictable>.

### sc-3-2-1

**SC 3.2.1 On Focus (Level A)**

When any user-interface component receives focus, it does not initiate a change of context.

**Assessment heuristics**:

* Confirm receiving focus does not auto-submit forms, open new windows, or navigate to a new URL.
* Confirm focus on a dropdown does not open a menu unless the user explicitly opts in (then via Enter or arrow key, not focus alone).

Source: <https://www.w3.org/TR/WCAG22/#on-focus>

### sc-3-2-2

**SC 3.2.2 On Input (Level A)**

Changing the setting of any user-interface component does not automatically cause a change of context unless the user has been advised of the behaviour before using the component.

**Assessment heuristics**:

* Confirm selecting an option in a dropdown does not auto-submit a form without prior warning.
* Confirm typing into a text field does not navigate away from the page.

Source: <https://www.w3.org/TR/WCAG22/#on-input>

### sc-3-2-3

**SC 3.2.3 Consistent Navigation (Level AA)**

Navigational mechanisms that are repeated on multiple pages occur in the same relative order each time, unless a change is initiated by the user.

**Assessment heuristics**:

* Confirm the main navigation appears in the same place and same order on every page of the site.

Source: <https://www.w3.org/TR/WCAG22/#consistent-navigation>

### sc-3-2-4

**SC 3.2.4 Consistent Identification (Level AA)**

Components that have the same functionality within a set of pages are identified consistently.

**Assessment heuristics**:

* Confirm "Search", "Submit", and other recurring controls use the same label and icon across the site.

Source: <https://www.w3.org/TR/WCAG22/#consistent-identification>

### sc-3-2-5

**SC 3.2.5 Change on Request (Level AAA)**

Changes of context are initiated only by user request, or a mechanism is available to turn off such changes.

**Assessment heuristics**:

* Confirm automatic redirects, refresh, or modal pop-ups are user-initiated or can be disabled.

Source: <https://www.w3.org/TR/WCAG22/#change-on-request>

### sc-3-2-6

**SC 3.2.6 Consistent Help (Level A)**

If a page includes a help mechanism (contact info, contact link, self-help, FAQ, or human contact mechanism), the help mechanism appears in the same relative order across the set of pages.

**Assessment heuristics**:

* Confirm help links or contact widgets appear in a consistent location across all pages where they exist.

Source: <https://www.w3.org/TR/WCAG22/#consistent-help>

## Guideline 3.3 — Input Assistance

Guideline 3.3 (Input Assistance) requires that users be helped to avoid and correct mistakes, including error identification, labels, instructions, error suggestions, error prevention, accessible authentication, and redundant entry support.

Source: W3C Web Content Accessibility Guidelines (WCAG) 2.2, Guideline 3.3, <https://www.w3.org/TR/WCAG22/#input-assistance>.

### sc-3-3-1

**SC 3.3.1 Error Identification (Level A)**

When an input error is automatically detected, the item in error is identified and the error is described to the user in text.

**Assessment heuristics**:

* Confirm error messages identify the field by name and explain what is wrong in text rather than relying on colour or icon.
* Confirm validation errors are exposed to assistive technology (for example, through `aria-invalid` and an `aria-describedby` link to the message).

Source: <https://www.w3.org/TR/WCAG22/#error-identification>

### sc-3-3-2

**SC 3.3.2 Labels or Instructions (Level A)**

Labels or instructions are provided when content requires user input.

**Assessment heuristics**:

* Confirm every form control has a visible label, instructions, or an `aria-label`.
* Confirm complex inputs (date format, password rules) carry instructions before submission, not only on error.

Source: <https://www.w3.org/TR/WCAG22/#labels-or-instructions>

### sc-3-3-3

**SC 3.3.3 Error Suggestion (Level AA)**

If an input error is automatically detected and suggestions for correction are known, the suggestions are provided to the user, unless doing so would jeopardise the security or purpose of the content.

**Assessment heuristics**:

* Confirm format-specific errors (date, email, phone) include an example or suggestion.
* Confirm sensitive inputs (passwords) provide rule-based feedback rather than the specific failing characters.

Source: <https://www.w3.org/TR/WCAG22/#error-suggestion>

### sc-3-3-4

**SC 3.3.4 Error Prevention (Legal, Financial, Data) (Level AA)**

For pages that cause legal commitments or financial transactions, that modify or delete user-controllable data, or that submit user test responses, at least one of the following is true: submissions are reversible, data is checked for input errors with an opportunity to correct, or a mechanism for review and confirmation is provided.

**Assessment heuristics**:

* Confirm checkout, contract acceptance, and data deletion flows offer review-and-confirm steps.
* Confirm financial transactions surface a confirmation summary before final submission.

Source: <https://www.w3.org/TR/WCAG22/#error-prevention-legal-financial-data>

### sc-3-3-5

**SC 3.3.5 Help (Level AAA)**

Context-sensitive help is available.

**Assessment heuristics**:

* Confirm complex forms surface inline help text or links to a topic-specific help article.

Source: <https://www.w3.org/TR/WCAG22/#help>

### sc-3-3-6

**SC 3.3.6 Error Prevention (All) (Level AAA)**

For all pages that require the user to submit information, submissions are reversible, data is checked for input errors with an opportunity to correct, or a mechanism for review and confirmation is provided.

**Assessment heuristics**:

* Confirm review-and-confirm steps apply to all submission flows in AAA-targeted experiences.

Source: <https://www.w3.org/TR/WCAG22/#error-prevention-all>

### sc-3-3-7

**SC 3.3.7 Redundant Entry (Level A)**

Information previously entered by or provided to the user that is required to be entered again in the same process is either auto-populated or available for the user to select, except when re-entering the information is essential, the information is required to ensure security, or previously entered information is no longer valid.

**Assessment heuristics**:

* Confirm multi-step forms pre-populate values the user already provided.
* Confirm address fields offer a "same as billing" or saved-address selection.

Source: <https://www.w3.org/TR/WCAG22/#redundant-entry>

### sc-3-3-8

**SC 3.3.8 Accessible Authentication (Minimum) (Level AA)**

A cognitive function test (such as remembering a password or solving a puzzle) is not required for any step in an authentication process unless an alternative is provided, the test is one that recognises objects or non-text content the user provided, or the test is supported by a mechanism that assists the user.

**Assessment heuristics**:

* Confirm passwordless flows (magic link, passkey), password-manager support (`autocomplete="current-password"`), or biometric login is offered.
* Confirm CAPTCHAs offer a non-cognitive alternative such as device-based attestation or accessible audio.

Source: <https://www.w3.org/TR/WCAG22/#accessible-authentication-minimum>

### sc-3-3-9

**SC 3.3.9 Accessible Authentication (Enhanced) (Level AAA)**

A cognitive function test is not required for any step in an authentication process unless the test is to recognise objects or non-text content the user provided.

**Assessment heuristics**:

* Confirm AAA flows do not include puzzle-based or transcription-based authentication challenges.

Source: <https://www.w3.org/TR/WCAG22/#accessible-authentication-enhanced>

## Guideline 4.1 — Compatible

Guideline 4.1 (Compatible) requires that content be robust enough to work with current and future user agents and assistive technologies. Note that SC 4.1.1 Parsing has been removed in WCAG 2.2 (marked obsolete) and is included here only for traceability.

Source: W3C Web Content Accessibility Guidelines (WCAG) 2.2, Guideline 4.1, <https://www.w3.org/TR/WCAG22/#compatible>.

### sc-4-1-1

**SC 4.1.1 Parsing (Obsolete in WCAG 2.2)**

This success criterion has been removed in WCAG 2.2 because modern user agents recover from the kinds of parsing issues it covered. Existing audits referencing this criterion should be retargeted to the responsible robustness criteria (notably SC 4.1.2).

**Assessment heuristics**:

* Do not raise new findings against SC 4.1.1; treat outstanding 2.1 findings as resolved when the underlying behaviour now passes 4.1.2.

Source: <https://www.w3.org/TR/WCAG22/#parsing>

### sc-4-1-2

**SC 4.1.2 Name, Role, Value (Level A)**

For all user-interface components, the name and role can be programmatically determined; states, properties, and values that can be set by the user can be programmatically set; and notification of changes to these items is available to user agents and assistive technologies.

**Assessment heuristics**:

* Confirm every interactive element exposes a non-empty accessible name (via label, `aria-label`, or `aria-labelledby`).
* Confirm custom controls implement the appropriate ARIA role and corresponding required ARIA properties.
* Confirm state changes (expanded, checked, selected, pressed) are reflected in ARIA attributes synchronously with the visual state.

Source: <https://www.w3.org/TR/WCAG22/#name-role-value>

### sc-4-1-3

**SC 4.1.3 Status Messages (Level AA)**

Status messages can be programmatically determined through role or properties so they can be presented to the user by assistive technology without receiving focus.

**Assessment heuristics**:

* Confirm form-validation summaries, toast notifications, and async loading messages use ARIA live regions (`role="status"`, `role="alert"`, or `aria-live`).
* Confirm status updates do not steal focus and that polite vs. assertive live-region policies match the urgency of the message.

Source: <https://www.w3.org/TR/WCAG22/#status-messages>

