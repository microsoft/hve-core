---
title: Finding Schema
description: Structured output format for PII detection results, control gap findings, and backlog handoff
---

# Finding Schema

## Detection record

Each detected PII instance produces a detection record:

```yaml
detection:
  id: "DET-<sequence>"
  pii_type: "PII-<NNN>"
  pii_name: "<human-readable name>"
  tier: "T1 | T2 | T3"
  industry_overlay: "<overlay name or 'core'>"
  location:
    file: "<relative file path>"
    line: <line number>
    element: "<field/variable/column name>"
  context: "<brief description of how PII is used>"
  confidence: "HIGH | MEDIUM | LOW"
  evidence: "<code snippet or pattern that triggered detection>"
```

## Control gap finding

For each missing control on a detected PII type:

```yaml
finding:
  id: "PII-GAP-<sequence>"
  detection_ref: "DET-<sequence>"
  pii_type: "PII-<NNN>"
  pii_name: "<name>"
  tier: "T1 | T2 | T3"
  missing_control: "<control name>"
  severity: "CRITICAL | HIGH | MEDIUM | LOW"
  title: "<concise gap description>"
  description: "<what is missing and why it matters>"
  evidence_searched: "<what was looked for and not found>"
  remediation: "<specific actionable fix>"
  regulatory_risk: "<which regulation this violates>"
  citations:
    pii_id: "PII-<NNN>"
    gdpr_article: "<Art. N>"
    ccpa_section: "<§section>"
    app_principle: "<APP N>"
```

## Severity mapping

| Tier | Missing required control | Severity |
|------|--------------------------|----------|
| T3 (Special Category) | Any required control | CRITICAL |
| T2 (Sensitive) | Encryption, consent, audit logging | HIGH |
| T2 (Sensitive) | Other required controls | HIGH |
| T1 (Identifier) | Encryption, access control | MEDIUM |
| T1 (Identifier) | Logging masking, retention | MEDIUM |
| Any | Recommended control missing | LOW |

## Assessment summary

```yaml
pii_assessment:
  scan_date: "<ISO 8601>"
  scope: "<files/directories scanned>"
  industry_overlays_applied: ["<overlay1>", "<overlay2>"]
  detection_summary:
    total_detections: <count>
    by_tier:
      t1_identifiers: <count>
      t2_sensitive: <count>
      t3_special_category: <count>
    by_confidence:
      high: <count>
      medium: <count>
      low: <count>
    unique_pii_types: <count>
  control_assessment:
    total_controls_checked: <count>
    controls_present: <count>
    controls_absent: <count>
    controls_partial: <count>
  findings_summary:
    total_findings: <count>
    by_severity:
      critical: <count>
      high: <count>
      medium: <count>
      low: <count>
  overall_verdict: "PROTECTED | GAPS_FOUND | UNPROTECTED"
  top_priority_items:
    - finding_id: "<id>"
      title: "<title>"
      severity: "<severity>"
```

## Overall verdict rules

| Verdict | Condition |
|---------|-----------|
| PROTECTED | All detected PII has all required controls present |
| GAPS_FOUND | Some controls are missing but no CRITICAL findings |
| UNPROTECTED | One or more CRITICAL findings (T3 data without required controls) |

## Backlog item template

Each finding with severity MEDIUM or above maps to a backlog item:

```yaml
backlog_item:
  source_finding: "PII-GAP-<sequence>"
  title: "[Privacy] <remediation title>"
  description: |
    **Detected PII**: <pii_name> (<pii_type>)
    **Location**: <file>:<line>
    **Sensitivity**: Tier <N>
    **Missing control**: <control_name>
    **Risk**: <regulatory_risk>
    **Remediation**: <actionable fix>
  priority: "<CRITICAL→P0, HIGH→P1, MEDIUM→P2, LOW→P3>"
  labels: ["privacy", "pii-detection", "control-gap"]
  acceptance_criteria:
    - "<specific condition that resolves the finding>"
    - "Verification: re-run PII detector shows control PRESENT"
```

## Example output

```yaml
detection:
  id: "DET-001"
  pii_type: "PII-002"
  pii_name: "Email address"
  tier: "T1"
  industry_overlay: "core"
  location:
    file: "src/models/user.py"
    line: 15
    element: "email"
  context: "User model stores email for authentication"
  confidence: "HIGH"
  evidence: "email = Column(String(255), unique=True)"

finding:
  id: "PII-GAP-001"
  detection_ref: "DET-001"
  pii_type: "PII-002"
  pii_name: "Email address"
  tier: "T1"
  missing_control: "Output masking in logs"
  severity: "MEDIUM"
  title: "Email address logged in plaintext during authentication"
  description: "User email is written to application logs during login events without masking"
  evidence_searched: "Searched logging calls in auth.py; found logger.info(f'Login: {user.email}')"
  remediation: "Replace raw email in log with masked version or user_id reference"
  regulatory_risk: "GDPR Art. 5(1)(f) integrity and confidentiality; log exposure risk"
  citations:
    pii_id: "PII-002"
    gdpr_article: "Art. 5(1)(f)"
```

---

Schema is original content (CC BY 4.0) following the finding and backlog patterns established by the security-reviewer and privacy-by-design skills within hve-core.
