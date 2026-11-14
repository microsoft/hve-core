---
title: 'PbD-02: Privacy as the Default Setting'
description: Privacy by Design reference for ensuring personal data is automatically protected in any system without requiring individual action
---

# 02 Privacy as the Default

Identifier: PbD-02
Category: Default Settings

## Source mapping

- **Cavoukian Principle 2** — Privacy as the Default Setting
- **GDPR Art. 25(2)** — Data protection by default
- **APP 3** — Collection of solicited personal information (purpose limitation)
- **APP 5** — Notification of collection of personal information
- CCPA §1798.100(c): Collection, use, retention and sharing must be necessary and proportionate to disclosed purposes

## Description

Evaluate the system before a user changes any settings. Default collection, disclosure and retention should be limited to what the service needs, so optional processing does not start merely because a person has not found an opt-out control.

This principle mandates that only data necessary for the specific purpose is collected, used, and retained. Default settings must be the most privacy-protective options, with users explicitly opting in to less private configurations rather than having to opt out of invasive ones.

## Principle checklist

- Default settings collect only the minimum data necessary for the stated purpose.
- Users do not need to take action to protect their privacy; protection is automatic.
- Data collection forms and APIs default to the least-invasive option.
- Optional data fields are clearly distinguished from required fields.
- Consent mechanisms default to "not consented" (opt-in, not opt-out).
- Data sharing with third parties is disabled by default.
- Retention periods are set to the minimum necessary by default, not maximum allowed.
- Analytics and telemetry default to aggregated or anonymized collection.

## Controls and mitigations

1. Implement opt-in consent for any data collection beyond what is strictly necessary for service delivery.
2. Configure data retention policies to automatically delete or anonymize data at the earliest permissible point.
3. Set API default parameters to return minimal data (e.g., pagination limits, field filtering).
4. Design user interfaces so that the most privacy-protective option requires the least effort.
5. Disable telemetry identifiers, tracking cookies, and behavioral profiling by default.
6. Require explicit user action to enable data sharing, public profiles, or social features.
7. Review and document default settings in privacy documentation and release notes.

## Anti-patterns

- Pre-checked consent boxes or opt-out rather than opt-in consent.
- Default data collection includes fields not needed for the primary purpose.
- User profiles are public by default.
- Analytics track individual behavior by default with anonymization available only as an opt-in setting.
- Maximum retention periods are the default rather than minimum necessary.
- Third-party data sharing is enabled without explicit user consent.
- Dark patterns that make privacy-protective choices harder to find or select.

## Regulatory cross-references

| Regulation | Reference    | Relevance                                                                              |
|------------|--------------|----------------------------------------------------------------------------------------|
| GDPR       | Art. 25(2)   | Only personal data necessary for each specific purpose is processed by default         |
| GDPR       | Art. 5(1)(c) | Data minimization principle                                                            |
| APP        | APP 3.1–3.2  | Collection must be reasonably necessary for entity functions                           |
| APP        | APP 5        | Notification obligations at time of collection                                         |
| CCPA/CPRA  | §1798.100(c) | Collection, use, retention and sharing limited to necessary and proportionate purposes |
| CCPA/CPRA  | §1798.135    | Right to opt-out of sale; opt-out link required                                        |

---

Content paraphrased from Dr. Ann Cavoukian's 7 Foundation Principles of Privacy by Design (2009) with attribution. Regulatory mappings are planning references, not legal interpretations.

Official sources: [IPC Ontario](https://www.ipc.on.ca/sites/default/files/legacy/2018/01/pbd.pdf), [GDPR](https://eur-lex.europa.eu/eli/reg/2016/679/oj), [APPs](https://www.oaic.gov.au/privacy/australian-privacy-principles/read-the-australian-privacy-principles), and [CCPA](https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=CIV&sectionNum=1798.100).
