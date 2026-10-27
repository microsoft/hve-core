---
title: PII Taxonomy
description: Core classification of PII/PI types by sensitivity tier with regulatory anchors and detection identifiers
---

# PII Taxonomy

This reference defines the core Personal Information (PI) and Personally Identifiable Information (PII) types that the detector scans for, organized by sensitivity tier.

## Sensitivity tiers

| Tier | Label            | Risk level | Example                                   | Regulatory trigger                                                            |
|------|------------------|------------|-------------------------------------------|-------------------------------------------------------------------------------|
| T1   | Identifier       | Medium     | Email, phone, name                        | Standard GDPR/CCPA obligations                                                |
| T2   | Sensitive        | High       | Financial, national ID, credential        | Enhanced protections; DPIA likely                                             |
| T3   | Special Category | Critical   | Health, biometric, genetic, racial origin | Explicit consent or another documented lawful condition; maximum restrictions |

## Core PII catalog (all industries)

### Tier 1: Identifiers

| ID      | PII Type          | Description                                            | Regulatory anchor                  |
|---------|-------------------|--------------------------------------------------------|------------------------------------|
| PII-001 | Full name         | Given name, surname, or combined                       | GDPR Art. 4(1), CCPA §1798.140(v)  |
| PII-002 | Email address     | Personal or work email                                 | GDPR Art. 4(1), APP 6              |
| PII-003 | Phone number      | Mobile, landline, or VoIP                              | GDPR Art. 4(1)                     |
| PII-004 | Postal address    | Street address, city, postcode                         | GDPR Art. 4(1)                     |
| PII-005 | Date of birth     | Full DOB or partial (year, month-year)                 | GDPR Art. 4(1)                     |
| PII-006 | IP address        | IPv4 or IPv6, static or dynamic                        | GDPR Recital 30, CCPA §1798.140(v) |
| PII-007 | Device identifier | Cookie ID, advertising ID, browser fingerprint         | GDPR Recital 30, ePrivacy          |
| PII-008 | Username          | Login identifier or display name if linked to identity | Contextual                         |
| PII-009 | Photo/avatar      | Facial image or profile photo                          | GDPR Art. 4(14) when biometric     |
| PII-010 | Location data     | GPS coordinates, geofence events                       | GDPR Art. 4(1), ePrivacy Art. 9    |

### Tier 2: Sensitive

| ID      | PII Type                  | Description                                  | Regulatory anchor            |
|---------|---------------------------|----------------------------------------------|------------------------------|
| PII-020 | National ID               | SSN, TFN, Aadhaar, passport number           | NIST SP 800-122, APP 9       |
| PII-021 | Driver license            | License number or document                   | Jurisdiction-specific        |
| PII-022 | Financial account         | Bank account, IBAN, BSB                      | PCI DSS, CCPA                |
| PII-023 | Payment card              | PAN, CVV, expiry                             | PCI DSS                      |
| PII-024 | Income/salary             | Compensation data                            | Employment privacy laws      |
| PII-026 | Medication                | Prescriptions, medication names              | HIPAA                        |
| PII-027 | Insurance ID              | Policy number, member ID                     | HIPAA, jurisdiction-specific |
| PII-029 | Authentication credential | Password hash, MFA secret, security question | NIST SP 800-63               |

### Tier 3: Special Category

| ID      | PII Type               | Description                                  | Regulatory anchor     |
|---------|------------------------|----------------------------------------------|-----------------------|
| PII-025 | Health condition       | Diagnosis, symptoms, treatment               | GDPR Art. 9(1), HIPAA |
| PII-028 | Biometric data         | Fingerprint, iris, voiceprint, face template | GDPR Art. 9(1), BIPA  |
| PII-040 | Racial/ethnic origin   | Self-identified or inferred                  | GDPR Art. 9(1)        |
| PII-041 | Political opinion      | Party affiliation, voting record             | GDPR Art. 9(1)        |
| PII-042 | Religious belief       | Faith, congregation membership               | GDPR Art. 9(1)        |
| PII-043 | Trade union membership | Union affiliation                            | GDPR Art. 9(1)        |
| PII-044 | Genetic data           | DNA sequence, genetic markers                | GDPR Art. 9(1), GINA  |
| PII-045 | Sexual orientation     | Orientation or gender identity               | GDPR Art. 9(1)        |
| PII-046 | Criminal record        | Convictions, charges, proceedings            | GDPR Art. 10          |
| PII-047 | Child data             | Data of individuals under 13/16              | COPPA, GDPR Art. 8    |

GDPR Art. 9(1) covers biometric data processed to uniquely identify a person. Classify PII-028 as T3 by default, and as T2 only when code evidence shows the data is not used to identify anyone (for example, a stored image with no matching or template extraction).

## Derived and inferred PII

These are not directly collected but inferred from other data:

| ID      | PII Type           | Derived from                        | Regulatory note               |
|---------|--------------------|-------------------------------------|-------------------------------|
| PII-060 | Behavioral profile | Clickstream, purchase history       | GDPR Art. 4(4) profiling      |
| PII-061 | Location history   | Repeated GPS/IP geolocation         | Movement patterns = sensitive |
| PII-062 | Social graph       | Contact lists, interaction patterns | Contextual sensitivity        |
| PII-063 | Inferred health    | Fitness data, purchase patterns     | May trigger GDPR Art. 9       |
| PII-064 | Credit score       | Payment history, financial behavior | Automated decision-making     |

## Classification rules

When classifying detected data:

1. **Direct PII** — data that directly identifies an individual (name, email, national ID). Use the catalog ID.
2. **Indirect PII** — data that identifies when combined with other data (ZIP + DOB + gender). Flag with confidence MEDIUM.
3. **Derived PII** — inferred from behavioral patterns. Flag with confidence LOW and mark as NEEDS_REVIEW.
4. **Pseudonymized data** — data with identifiers replaced by tokens. Still PII under GDPR Art. 4(5); flag but note pseudonymization as a control.
5. **Anonymized data** — data that cannot be re-identified. Not PII; do not flag.

### Resolution order

When more than one type could apply to a field, resolve in this order and report one type per field:

1. **Suppressions** from `.pii-config.yml` — skip the field.
2. **Custom types** from `.pii-config.yml`.
3. **Industry overlay types** — whether the industry comes from `.pii-config.yml` or is inferred in Phase 1.
4. **Core types** from this catalog.
5. **Tier overrides** from `.pii-config.yml` apply to the resolved type, including overlay types.

The first step with a match wins. Within a step, the most specific name match wins as defined in [Matching rules](01-detection-patterns.md#matching-rules). An overlay type that matches a field supersedes any core type that matches the same field, so report only the overlay type.

Example: with the healthcare overlay active, `diagnosisCode` matches core PII-025 and healthcare PII-201; report only PII-201. With the financial overlay active, `cardNumber` reports PII-300, not PII-023; `creditScore` reports PII-306, not PII-064.

## Industry extension points

The core catalog covers universal PII. Industry overlays add domain-specific types:

- **Telco** → `10-industry-telco.md` adds IMEI, IMSI, MSISDN, CDR, cell tower data
- **Healthcare** → `11-industry-healthcare.md` adds MRN, diagnoses, medications, genetic markers
- **Financial** → `12-industry-financial.md` adds PAN, account numbers, transaction data, KYC

Each overlay defines additional PII types using IDs in the range `PII-1xx` (telco), `PII-2xx` (healthcare), `PII-3xx` (financial).

## Official sources

* [NIST SP 800-122](https://doi.org/10.6028/NIST.SP.800-122)
* [General Data Protection Regulation](https://eur-lex.europa.eu/eli/reg/2016/679/oj)
* [California Consumer Privacy Act](https://oag.ca.gov/privacy/ccpa)
* [Australian Privacy Principles](https://www.oaic.gov.au/privacy/australian-privacy-principles)
* [PCI Data Security Standard](https://www.pcisecuritystandards.org/standards/)
* [HIPAA Privacy Rule](https://www.hhs.gov/hipaa/for-professionals/privacy/index.html)
* [Illinois Biometric Information Privacy Act](https://www.ilga.gov/legislation/ilcs/ilcs3.asp?ActID=3004&ChapterID=57)
* [Genetic Information Nondiscrimination Act](https://www.eeoc.gov/statutes/genetic-information-nondiscrimination-act-2008)
* [Children's Online Privacy Protection Rule](https://www.ftc.gov/legal-library/browse/rules/childrens-online-privacy-protection-rule-coppa)

---

Taxonomy synthesized from NIST SP 800-122 (public domain), GDPR Art. 4 (paraphrased with attribution), and Australian Privacy Act 1988. Provided as a detection planning reference.
