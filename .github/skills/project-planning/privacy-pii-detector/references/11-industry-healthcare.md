---
title: Healthcare Industry Overlay
description: Health data PII types, detection patterns, and control expectations for healthcare systems
---

# Healthcare Industry Overlay

This overlay extends the core PII taxonomy with healthcare-specific personal information types. Apply when the codebase processes patient data, clinical records, or health-adjacent information.

## Industry detection triggers

Apply this overlay when the codebase contains:
- Dependencies: `hl7`, `fhir`, `pydicom`, `hapi-fhir`, `openehr`, `cda`
- Terminology: patient, diagnosis, ICD, SNOMED, encounter, admission, discharge, provider, NPI
- API patterns: `/api/patients`, `/api/encounters`, `/api/observations`, `/fhir/`
- Domain: `.health.`, `.clinical.`, `.ehr.`, `.emr.` in package names or configs

## Healthcare-specific PII types

| ID | PII Type | Description | Tier | Regulatory anchor |
|----|----------|-------------|------|-------------------|
| PII-200 | Medical record number (MRN) | Facility-assigned patient identifier | T2 | HIPAA §164.514, My Health Records Act |
| PII-201 | Diagnosis/condition | ICD codes, SNOMED terms, clinical descriptions | T3 | HIPAA, GDPR Art. 9 (health data) |
| PII-202 | Medication/prescription | Drug names, dosages, prescribing provider | T2 | HIPAA |
| PII-203 | Lab result | Test values, reference ranges, interpretations | T2 | HIPAA |
| PII-204 | Clinical note | Free-text clinician documentation | T3 | HIPAA (may contain any PII) |
| PII-205 | Medical image | X-ray, MRI, CT with embedded patient metadata (DICOM) | T2 | HIPAA, DICOM de-identification |
| PII-206 | Genetic/genomic data | DNA sequences, variants, pharmacogenomics | T3 | GDPR Art. 9, GINA, state genetic privacy laws |
| PII-207 | Mental health record | Psychiatric notes, therapy records | T3 | Enhanced confidentiality (42 CFR Part 2) |
| PII-208 | Substance abuse record | Addiction treatment, rehabilitation | T3 | 42 CFR Part 2 (US), enhanced protections |
| PII-209 | Insurance/payer ID | Health plan member ID, group number | T2 | HIPAA |
| PII-210 | Provider NPI | National Provider Identifier (treating clinician) | T1 | Public data but links to patient context |
| PII-211 | Consent/advance directive | Patient treatment preferences, DNR status | T2 | Varies by jurisdiction |
| PII-212 | Disability information | Functional limitations, accommodation needs | T2 | ADA, GDPR Art. 9 |

## Healthcare detection patterns

### Naming conventions

| Pattern | Maps to | Confidence |
|---------|---------|------------|
| `*mrn*`, `*medicalRecordNumber*`, `*patientId*` | PII-200 MRN | HIGH |
| `*diagnosis*`, `*icdCode*`, `*icd10*`, `*snomedCode*`, `*condition*` | PII-201 Diagnosis | HIGH |
| `*medication*`, `*prescription*`, `*rxName*`, `*drugCode*`, `*ndc*` | PII-202 Medication | HIGH |
| `*labResult*`, `*testValue*`, `*observation*`, `*loincCode*` | PII-203 Lab Result | HIGH |
| `*clinicalNote*`, `*progressNote*`, `*dischargeNote*` | PII-204 Clinical Note | HIGH |
| `*dicom*`, `*medicalImage*`, `*xray*`, `*mri*` | PII-205 Medical Image | HIGH |
| `*genetic*`, `*genomic*`, `*dna*`, `*variant*`, `*snp*` | PII-206 Genetic | HIGH |
| `*mentalHealth*`, `*psychiatric*`, `*therapy*` | PII-207 Mental Health | HIGH |
| `*substanceAbuse*`, `*addiction*`, `*rehabilitation*` | PII-208 Substance Abuse | HIGH |
| `*insuranceId*`, `*memberId*`, `*payerId*`, `*healthPlan*` | PII-209 Insurance | HIGH |
| `*npi*`, `*providerNumber*`, `*practitionerId*` | PII-210 Provider NPI | MEDIUM |

### FHIR resource detection

When FHIR resources are present, map to PII types:

| FHIR Resource | Contains PII types |
|---------------|-------------------|
| `Patient` | PII-001 (name), PII-002 (email), PII-003 (phone), PII-005 (DOB), PII-200 (MRN) |
| `Condition` | PII-201 (diagnosis) |
| `MedicationRequest` | PII-202 (medication) |
| `Observation` | PII-203 (lab result) |
| `DocumentReference` | PII-204 (clinical note), PII-205 (image) |
| `MolecularSequence` | PII-206 (genetic) |
| `Claim` | PII-209 (insurance) |

## Healthcare-specific control requirements

Beyond core tier controls:

| Control | Applies to | Rationale |
|---------|-----------|-----------|
| Minimum necessary | All health PII | HIPAA minimum necessary standard — disclose only what is needed |
| Break-the-glass audit | PII-201–PII-208 | Emergency access override with mandatory post-access review |
| Segmentation (42 CFR Part 2) | PII-207, PII-208 | Substance abuse and mental health records require explicit consent for each disclosure |
| DICOM de-identification | PII-205 | Medical images must strip patient metadata per DICOM PS3.15 |
| Research de-identification | All | HIPAA Safe Harbor (18 identifiers removed) or Expert Determination |
| Patient portal access | PII-200–PII-204 | Patients must have electronic access to their records (21st Century Cures) |
| Genetic non-discrimination | PII-206 | GINA prohibits use in employment/insurance decisions |
| Cross-facility consent | All | Inter-organizational health information exchange requires patient consent |

## Healthcare regulatory context

| Regulation | Jurisdiction | Key requirement |
|-----------|--------------|-----------------|
| HIPAA Privacy Rule | US | Minimum necessary, patient rights, covered entity obligations |
| HIPAA Security Rule | US | Administrative, physical, and technical safeguards |
| 42 CFR Part 2 | US | Enhanced consent for substance abuse records |
| GINA | US | Genetic non-discrimination in employment and insurance |
| My Health Records Act 2012 | Australia | Digital health record controls, secondary use restrictions |
| Health Records Act 2001 | Australia (VIC) | State-level health privacy protections |
| GDPR Art. 9 | EU | Health data as special category requiring explicit consent |
| 21st Century Cures Act | US | Patient access, information blocking prohibition |

---

Healthcare overlay is original content (CC BY 4.0) synthesized from health privacy engineering practices. Regulatory references are paraphrased with attribution, not legal interpretations.
