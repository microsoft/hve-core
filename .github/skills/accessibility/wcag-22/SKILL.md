---
name: wcag-22
description: "WCAG 2.2 success criteria knowledge base for accessibility assessment"
---

# WCAG 2.2 - Skill Entry

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

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
