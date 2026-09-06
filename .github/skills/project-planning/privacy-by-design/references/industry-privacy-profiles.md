---
title: Industry Privacy Profiles
description: Industry-specific PbD principle emphasis, regulatory priorities, and assessment focus areas
---

# Industry Privacy Profiles

This reference maps the 7 PbD Foundation Principles to industry-specific contexts, highlighting which principles demand elevated attention, what industry-specific regulatory obligations apply, and which assessment checks should be prioritized per sector.

## How to use industry profiles

1. Identify the system's industry context (from `.pbd-config.yml` or package analysis).
2. Load the matching profile to adjust assessment weighting.
3. Apply industry-specific checks alongside the universal principle checklist.
4. Flag industry-mandatory controls that go beyond the universal requirements.

## Telecommunications

### Principle emphasis

| Principle           | Industry priority | Rationale                                                               |
|---------------------|-------------------|-------------------------------------------------------------------------|
| PbD-01 Proactive    | HIGH              | Metadata retention laws require privacy planning before system design   |
| PbD-02 Default      | CRITICAL          | Location and communication data must be protected by default (ePrivacy) |
| PbD-05 End-to-End   | CRITICAL          | CDR, location history, and content have mandated retention and disposal |
| PbD-06 Transparency | HIGH              | Subscribers must know what metadata is retained and for how long        |
| PbD-07 User-Centric | HIGH              | Opt-in required for location-based services beyond network operation    |

### Industry-specific checks

- Location data collection defaults to OFF for value-added services (PbD-02)
- CDR retention period matches regulatory mandate (not indefinite) (PbD-05)
- Subscriber consent mechanism exists for location-based services (PbD-07)
- Network metadata anonymized before analytics use (PbD-02)
- Roaming data sharing governed by transfer agreements (PbD-05)
- Lawful interception isolated from general access (PbD-03)
- Device identifiers (IMEI, IMSI) not correlated across services without purpose binding (PbD-03)

### Key regulations

- ePrivacy Directive (EU) — consent for location, confidentiality of communications
- Telecommunications Act 1997 (AU) — metadata retention, interception warrants
- CPNI Rules 47 CFR § 64.2001 (US) — customer network information protection

---

## Healthcare

### Principle emphasis

| Principle                 | Industry priority | Rationale                                                                        |
|---------------------------|-------------------|----------------------------------------------------------------------------------|
| PbD-02 Default            | CRITICAL          | Health data requires maximum protection by default (HIPAA minimum necessary)     |
| PbD-03 Embedded           | CRITICAL          | Privacy must be architectural (segmentation, de-identification, break-the-glass) |
| PbD-04 Full Functionality | HIGH              | Patients exercising rights must not lose care quality                            |
| PbD-05 End-to-End         | CRITICAL          | Health records have complex retention (clinical vs. research vs. billing)        |
| PbD-07 User-Centric       | HIGH              | Patient access rights (21st Century Cures), correction, consent withdrawal       |

### Industry-specific checks

- Minimum necessary principle applied to all health data disclosures (PbD-02)
- HIPAA de-identification method applied for research/analytics (Safe Harbor or Expert Determination) (PbD-03)
- Break-the-glass mechanism exists with mandatory post-access audit (PbD-03)
- 42 CFR Part 2 segmentation for substance use disorder and mental health records (PbD-03)
- Patient portal provides electronic access to health records (PbD-07)
- DICOM de-identification strips patient metadata from medical images (PbD-05)
- Genetic data handled with GINA non-discrimination controls (PbD-04)
- Clinical research consent separate from treatment consent (PbD-07)

### Key regulations

- HIPAA Privacy and Security Rules (US) — minimum necessary, patient rights, safeguards
- 42 CFR Part 2 (US) — substance use disorder record consent requirements
- My Health Records Act 2012 (AU) — digital health record controls
- GDPR Art. 9 (EU) — health data as special category

---

## Financial Services

### Principle emphasis

| Principle                 | Industry priority | Rationale                                                                                |
|---------------------------|-------------------|------------------------------------------------------------------------------------------|
| PbD-02 Default            | HIGH              | Default data minimization for KYC (collect only what regulation requires)                |
| PbD-03 Embedded           | CRITICAL          | PCI DSS requires privacy embedded in architecture (CDE isolation, tokenization)          |
| PbD-04 Full Functionality | HIGH              | Customers opting out of profiling must retain full service access (PSD2, CCPA §1798.125) |
| PbD-05 End-to-End         | CRITICAL          | Financial records have regulatory retention minimums AND deletion obligations            |
| PbD-06 Transparency       | HIGH              | Automated credit decisions require explainability (GDPR Art. 22, FCRA)                   |

### Industry-specific checks

- PCI DSS cardholder data environment (CDE) architecturally isolated (PbD-03)
- Card data tokenized outside payment processing (PbD-03)
- CVV never stored (even encrypted) (PbD-02)
- KYC documents retained only for regulatory minimum, then destroyed (PbD-05)
- Credit scoring logic transparent to consumers with dispute mechanism (PbD-06)
- No service degradation for customers who opt out of profiling (PbD-04)
- AML/CTF monitoring does not create overbroad surveillance beyond regulatory mandate (PbD-02)
- Transaction data segregated from marketing analytics (PbD-03)
- Strong customer authentication for payment initiation (PbD-05)

### Key regulations

- PCI DSS v4.0 (Global) — cardholder data protection architecture
- PSD2/SCA (EU) — strong customer authentication, open banking consent
- FCRA (US) — credit reporting accuracy, consumer rights
- APRA CPS 234 (AU) — information security for regulated entities
- AML/CTF Act 2006 (AU) — customer identification, transaction monitoring

---

## Profile configuration

Projects can specify their industry profile and override principle priorities in `.pbd-config.yml`:

```yaml
# .pbd-config.yml — placed at repository root
version: "1.0"

# Industry profile (loads matching section above)
industry: "telco"  # Options: telco, healthcare, financial

# Override principle priorities for your org
principle_overrides:
  - principle: "PbD-04"
    priority: "CRITICAL"
    justification: "Our telco offers essential services; accessibility during privacy exercise is mandatory"

# Additional industry-specific checks beyond the profile
custom_checks:
  - principle: "PbD-03"
    check: "5G network slice identifiers treated as subscriber PII"
    severity: "HIGH"

  - principle: "PbD-05"
    check: "eSIM profile data destroyed within 30 days of deactivation"
    severity: "MEDIUM"

# Suppress checks that don't apply
suppressions:
  - check: "DICOM de-identification"
    reason: "Not a healthcare system; no medical imaging"

  - check: "PCI DSS CDE isolation"
    reason: "No payment card processing; payments handled by external gateway"
```

## Configuration schema

### `version`

Required. Currently `"1.0"`.

### `industry`

Required. Activates the matching industry profile. Values: `telco`, `healthcare`, `financial`.

### `principle_overrides`

Optional. Override the default priority for a principle within the selected industry.

| Field           | Required | Description                                       |
|-----------------|----------|---------------------------------------------------|
| `principle`     | Yes      | PbD principle ID (e.g., `PbD-04`)                 |
| `priority`      | Yes      | New priority: `CRITICAL`, `HIGH`, `MEDIUM`, `LOW` |
| `justification` | Yes      | Why this override exists                          |

### `custom_checks`

Optional. Add org-specific checks beyond the industry profile.

| Field       | Required | Description                                                          |
|-------------|----------|----------------------------------------------------------------------|
| `principle` | Yes      | Which principle this check maps to                                   |
| `check`     | Yes      | Description of the check                                             |
| `severity`  | Yes      | Finding severity if check fails: `CRITICAL`, `HIGH`, `MEDIUM`, `LOW` |

### `suppressions`

Optional. Suppress checks that don't apply to this system.

| Field    | Required | Description                                  |
|----------|----------|----------------------------------------------|
| `check`  | Yes      | The check description or keyword to suppress |
| `reason` | Yes      | Why it doesn't apply                         |

## Assessment integration

When the Privacy Reviewer assesses a system:

1. Load `.pbd-config.yml` if present (or infer industry from codebase).
2. Adjust principle checklist weighting based on industry priority.
3. Add industry-specific checks to the assessment protocol.
4. Apply custom checks from the configuration.
5. Skip suppressed checks.
6. Report findings with industry context (which regulation triggers the requirement).

A principle marked CRITICAL in the industry profile that receives a FAIL verdict produces a CRITICAL-severity finding (elevated from the default tier-based severity).

---

Industry profiles are original content (CC BY 4.0) synthesized from sector-specific privacy engineering practices. Regulatory references are paraphrased with attribution for planning use, not legal interpretation.
