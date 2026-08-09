---
name: privacy-pii-detector
description: "Automated PII/PI detection and privacy control verification for codebases. Scans for personal information processing patterns, classifies by sensitivity tier and industry, verifies protective controls exist, and raises findings when controls are missing. Use when you need to detect PII in code without privacy expertise."
license: mixed
user-invocable: true
metadata:
  authors: "Microsoft (detection taxonomy and control framework); NIST (PII definition from SP 800-122); GDPR (personal data definition from Art. 4); OAIC (Australian PI definition from Privacy Act 1988)"
  spec_version: "1.0"
  framework_revision: "1.0.0"
  last_updated: "2026-08-10"
  content_based_on: "https://doi.org/10.6028/NIST.SP.800-122; https://gdpr-info.eu/art-4-gdpr/; https://www.oaic.gov.au/privacy/your-privacy-rights/what-is-personal-information"
---

# Privacy PII Detector — Skill Entry

This `SKILL.md` is the **entrypoint** for the Privacy PII Detector skill.

The skill provides automated detection of Personal Information (PI) and Personally Identifiable Information (PII) in codebases, classifies detected data by sensitivity tier and industry context, verifies that appropriate privacy controls exist for each detected PII type, and produces structured findings when controls are missing. It requires zero privacy expertise from the user.

> [!NOTE]
> This skill is a planning and detection aid, not legal advice. Its detection patterns identify likely PII processing; they do not constitute a formal data inventory or replace qualified privacy counsel.

## Goal

Automatically detect PII/PI processing in a codebase, verify protective controls exist for each detected type, and produce actionable findings with backlog-ready items for any unprotected personal data.

## Success criteria

- All code paths processing personal data are identified with the PII type classified.
- Each detected PII type is mapped to a sensitivity tier and applicable industry overlay.
- For each detected PII type, expected controls are checked against actual implementation.
- Missing controls produce FAIL findings with specific remediation and backlog items.
- The user does not need privacy expertise — the skill drives the entire assessment.

## When to use this skill

Use when you need to:

- Scan a codebase for PII/PI processing without knowing what to look for
- Verify that detected personal data has appropriate privacy controls
- Generate a privacy control gap analysis for a project
- Produce backlog items for missing privacy protections
- Assess a PR or feature branch for new PII introduction
- Apply industry-specific PII detection (telco, healthcare, financial services)

Do not use for:

- Principle-level privacy assessment (use `privacy-by-design`)
- Standards mapping and DPIA thresholds (use `privacy-standards`)
- Security vulnerability detection (use OWASP skills)
- RAI assessment (use `rai-planner`)

## Stop rules

- Stop if the codebase contains no identifiable data processing (no models, APIs, databases, or data flows).
- Do not fabricate PII detections; only report what is evidenced by code patterns.
- Do not provide legal classification of data; frame findings as planning guidance.
- When detection confidence is LOW, report as NEEDS_REVIEW rather than FAIL.

## Normative references

1. [00 PII Taxonomy](references/00-pii-taxonomy.md) — core classification of PII types, sensitivity tiers, and regulatory anchors
2. [01 Detection Patterns](references/01-detection-patterns.md) — code-level patterns agents use to find PII processing
3. [02 Control Expectations](references/02-control-expectations.md) — required controls per PII tier with verification methods
4. [03 Finding Schema](references/03-finding-schema.md) — structured output format for detection results and backlog handoff

## Industry overlays

5. [10 Telco Overlay](references/10-industry-telco.md) — telecommunications-specific PII types and controls
6. [11 Healthcare Overlay](references/11-industry-healthcare.md) — health data PII types and controls
7. [12 Financial Services Overlay](references/12-industry-financial.md) — financial data PII types and controls

## Skill layout

- `SKILL.md` — this file (skill entrypoint).
- `references/` — detection taxonomy, patterns, control expectations, and industry overlays.
  - `00-pii-taxonomy.md` — PII type catalog with sensitivity tiers and regulatory anchors.
  - `01-detection-patterns.md` — language-agnostic and language-specific code patterns for PII detection.
  - `02-control-expectations.md` — required controls per tier with verification methods.
  - `03-finding-schema.md` — YAML-based structured output for findings and backlog items.
  - `10-industry-telco.md` — telecommunications industry overlay.
  - `11-industry-healthcare.md` — healthcare industry overlay.
  - `12-industry-financial.md` — financial services industry overlay.

## Assessment protocol

### Phase 1: Industry context

Determine which industry overlay applies. If the user specifies an industry, load that overlay. If not, infer from:
- Package dependencies (e.g., `hl7`, `fhir` → healthcare; `stripe`, `plaid` → financial)
- Domain terminology in code comments and documentation
- API endpoint naming patterns

If no industry context is determinable, use only the core PII taxonomy.

### Phase 2: Detection scan

For each file in scope:
1. Apply detection patterns from `01-detection-patterns.md`.
2. Apply industry-specific patterns from the applicable overlay.
3. Record each detection with location, PII type, confidence level, and evidence.

### Phase 3: Control verification

For each detected PII type:
1. Look up required controls from `02-control-expectations.md` based on sensitivity tier.
2. Search the codebase for evidence that each required control is implemented.
3. Record control status: PRESENT, ABSENT, or PARTIAL.

### Phase 4: Finding generation

For each ABSENT or PARTIAL control:
1. Generate a finding using the schema from `03-finding-schema.md`.
2. Include specific remediation guidance.
3. Map to a backlog item with priority based on sensitivity tier.

## Integration with other skills

| Skill | Relationship |
|-------|--------------|
| `privacy-by-design` | PII detector feeds into PbD assessment; detected PII informs principle evaluation |
| `privacy-standards` | Standards skill provides regulatory context for detected PII types |
| `security-planning` | Security controls overlap with PII protection; cross-reference rather than duplicate |
| `code-review` | PII detector can run as a perspective within code review workflow |

## Extensibility

Industry overlays follow a consistent structure. To add a new industry:
1. Create `references/1N-industry-<name>.md` following the overlay template.
2. Define industry-specific PII types with detection patterns.
3. Map to sensitivity tiers and specify additional controls beyond core requirements.
4. Add the overlay to the Industry overlays section in this file.

## Attribution and licensing posture

### NIST SP 800-122

- **Source**: <https://doi.org/10.6028/NIST.SP.800-122>
- **License**: Public domain (US Government work)
- **Usage**: PII definition and classification framework referenced with attribution

### GDPR Art. 4 (Personal Data Definition)

- **Source**: <https://gdpr-info.eu/art-4-gdpr/>
- **License**: Open legal text, paraphrased with attribution
- **Usage**: Personal data categories referenced for regulatory anchoring

### Australian Privacy Act 1988

- **Source**: <https://www.oaic.gov.au/privacy/your-privacy-rights/what-is-personal-information>
- **License**: Open legal text, paraphrased with attribution
- **Usage**: PI definition referenced for cross-jurisdictional anchoring
