---
title: 'PbD-04: Full Functionality — Positive-Sum, Not Zero-Sum'
description: Privacy by Design reference for achieving both privacy and functionality without unnecessary trade-offs
---

# 04 Full Functionality

Identifier: PbD-04
Category: Positive-Sum

## Source mapping

- **Cavoukian Principle 4** — Full Functionality — Positive-Sum, Not Zero-Sum
- **GDPR Art. 25(1)** — Implement measures in an effective manner (privacy without degrading functionality)
- **APP 1.2** — Manage personal information in an open and transparent way (supporting both compliance and business functions)
- **CCPA §1798.100** — Consumer rights exercised without penalty to service quality

## Description

Privacy by Design seeks to accommodate all legitimate interests and objectives in a positive-sum manner, not through a zero-sum approach where unnecessary trade-offs are made. Privacy by Design avoids the pretense of false dichotomies such as privacy vs. security, or privacy vs. functionality. It demonstrates that it is possible to have both — full functionality and full privacy.

This principle rejects the notion that privacy must come at the cost of business utility, user experience, or security. Instead, it demands creative design solutions that satisfy multiple objectives simultaneously.

## Principle checklist

- Privacy controls do not degrade the core user experience or service functionality.
- Privacy and security are treated as complementary, not competing, requirements.
- Data subjects who exercise privacy rights (opt-out, deletion) receive equivalent service quality.
- Design alternatives are explored before declaring a privacy-functionality trade-off.
- Privacy-preserving approaches (aggregation, anonymization, federated processing) are considered before raw data collection.
- Business objectives and privacy objectives are documented as co-equal requirements.
- No feature is implemented with the assumption that "privacy makes it impossible."

## Controls and mitigations

1. For each feature requiring personal data, document the minimum data needed and explore privacy-preserving alternatives.
2. Ensure users who decline optional data collection still receive full core functionality.
3. When a trade-off appears necessary, conduct a formal analysis documenting why both objectives cannot be simultaneously met.
4. Use A/B testing or prototyping to validate that privacy-preserving designs meet functionality requirements.
5. Apply anonymization, aggregation, or synthetic data techniques when full identification is not required.
6. Prohibit service degradation or dark patterns targeting users who exercise privacy rights.
7. Document positive-sum outcomes in privacy impact assessments.

## Anti-patterns

- Features are gated behind unnecessary data collection ("give us your data or lose functionality").
- Privacy is framed as a blocker to business requirements without exploring alternatives.
- Users who opt out of tracking receive degraded service or reduced feature access.
- Security justifications are used to collect more personal data than necessary.
- The team assumes privacy and functionality are inherently at odds without testing alternatives.
- Dark patterns punish privacy-conscious choices (e.g., repeated consent prompts, friction).

## Regulatory cross-references

| Regulation | Reference  | Relevance                                                                       |
|------------|------------|---------------------------------------------------------------------------------|
| GDPR       | Art. 7(4)  | Consent must not be a condition for service where not necessary for performance |
| GDPR       | Art. 25(1) | Effective implementation of principles without undermining processing purposes  |
| APP        | APP 3.3    | Collection must be by lawful and fair means                                     |
| CCPA/CPRA  | §1798.125  | No discrimination against consumers exercising their rights                     |

---

Content paraphrased from Dr. Ann Cavoukian's 7 Foundation Principles of Privacy by Design (2009) with attribution. Regulatory mappings are planning references, not legal interpretations.
