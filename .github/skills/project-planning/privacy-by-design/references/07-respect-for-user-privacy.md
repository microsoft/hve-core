---
title: 'PbD-07: Respect for User Privacy — Keep It User-Centric'
description: Privacy by Design reference for keeping individual privacy interests paramount through user-centric design
---

# 07 Respect for User Privacy

Identifier: PbD-07
Category: User-Centricity

## Source mapping

- **Cavoukian Principle 7** — Respect for User Privacy — Keep It User-Centric
- **GDPR Art. 12–22** — Data subject rights (access, rectification, erasure, portability, objection)
- **APP 6** — Use or disclosure of personal information
- **APP 12–13** — Access to and correction of personal information
- **CCPA §1798.120** — Consumer right to opt-out of sale
- **CCPA §1798.185** — Consumer right to limit use of sensitive personal information

## Description

Above all, Privacy by Design requires architects and operators to keep the interests of the individual uppermost by offering strong privacy defaults, appropriate notice, and empowering user-friendly options. Keep it user-centric — give individuals a strong role in the management of their own data.

This principle places the data subject at the center of system design. Individuals are not passive recipients of data processing; they are active participants with meaningful control over their personal information. Systems must empower users with choice, access, correction, and deletion capabilities.

## Principle checklist

- Users have granular control over what personal data is collected and how it is used.
- Consent is specific, informed, unambiguous, and revocable.
- Users can access, correct, and delete their personal data through self-service mechanisms.
- Data portability is supported — users can export their data in a structured, machine-readable format.
- Preference centers allow users to manage communication, sharing, and processing choices.
- Withdrawal of consent is as easy as giving consent.
- User interfaces are designed to empower privacy choices, not to overwhelm or confuse.
- Automated decision-making is disclosed with mechanisms to request human review.

## Controls and mitigations

1. Implement a privacy preference center where users manage consent, communication, and data sharing choices.
2. Provide data export/portability in standard machine-readable formats (JSON, CSV).
3. Implement self-service account deletion that triggers cascading data removal.
4. Ensure consent withdrawal is a single-action operation with immediate effect.
5. Design consent flows that are specific (per-purpose) rather than all-or-nothing.
6. Disclose automated profiling and decision-making with opt-out or human review options.
7. User-test privacy interfaces to ensure they are genuinely usable and not dark patterns.
8. Provide accessible mechanisms for individuals with disabilities to exercise their privacy rights.

## Anti-patterns

- Users cannot delete their accounts or personal data without contacting support.
- Consent is bundled (all-or-nothing) rather than granular per purpose.
- Withdrawal of consent requires more steps than granting it.
- No data export or portability mechanism exists.
- Privacy settings are buried in inaccessible menus.
- Automated decisions affecting users have no transparency or appeal mechanism.
- User interfaces are designed to nudge users toward less private options.
- Users with disabilities cannot access privacy controls due to inaccessible interfaces.

## Regulatory cross-references

| Regulation | Reference  | Relevance                                                                   |
|------------|------------|-----------------------------------------------------------------------------|
| GDPR       | Art. 7(3)  | Right to withdraw consent at any time; withdrawal as easy as giving consent |
| GDPR       | Art. 15–16 | Right of access and rectification                                           |
| GDPR       | Art. 17    | Right to erasure                                                            |
| GDPR       | Art. 20    | Right to data portability                                                   |
| GDPR       | Art. 21    | Right to object                                                             |
| GDPR       | Art. 22    | Automated individual decision-making including profiling                    |
| APP        | APP 6      | Use or disclosure limited to collected purpose or exceptions                |
| APP        | APP 12     | Access to personal information on request                                   |
| APP        | APP 13     | Correction of personal information                                          |
| CCPA/CPRA  | §1798.105  | Right to deletion                                                           |
| CCPA/CPRA  | §1798.106  | Right to correction                                                         |
| CCPA/CPRA  | §1798.120  | Right to opt-out of sale or sharing                                         |
| CCPA/CPRA  | §1798.185  | Right to limit use of sensitive personal information                        |

---

Content paraphrased from Dr. Ann Cavoukian's 7 Foundation Principles of Privacy by Design (2009) with attribution. Regulatory mappings are planning references, not legal interpretations.
