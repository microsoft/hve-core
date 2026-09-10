---
title: Finding Schema
description: Structured output format for PbD assessment findings used by Privacy Reviewer and Privacy Planner agents
---

# Finding Schema

This document defines the structured output format for Privacy by Design assessment findings. Agents use this schema to produce consistent, machine-readable results that integrate with the hve-core review and backlog handoff workflow.

## Finding record structure

Each finding is a discrete assessment result for one principle or sub-check.

```yaml
finding:
  id: "PBD-<principle_number>-<sequence>"  # e.g., PBD-01-001
  principle: "PbD-<number>"                # e.g., PbD-01
  principle_name: "<short name>"           # e.g., Proactive Not Reactive
  category: "<category>"                   # e.g., Prevention
  verdict: "PASS | PARTIAL | FAIL"
  severity: "HIGH | MEDIUM | LOW"
  title: "<concise finding title>"
  description: "<what was found>"
  evidence: "<what evidence supports this finding>"
  remediation: "<specific actionable fix>"  # Required for PARTIAL and FAIL
  checklist_items_met: <count>
  checklist_items_total: <count>
  anti_patterns_detected: ["<pattern1>", "<pattern2>"]  # Empty array if none
  citations:
    pbd_principle: "PbD-<number> <name>"
    gdpr_article: "<Art. N>"               # Optional
    app_principle: "<APP N>"               # Optional
    ccpa_section: "<§section>"             # Optional
  jurisdiction_flags: ["GDPR", "CCPA", "APP"]  # Which apply
```

## Assessment summary structure

The summary aggregates all principle findings into a top-level report.

```yaml
assessment_summary:
  system_name: "<name of assessed system>"
  assessment_date: "<ISO 8601 date>"
  scope: "<boundary description>"
  jurisdictions: ["<jurisdiction1>", "<jurisdiction2>"]
  overall_verdict: "COMPLIANT | PARTIALLY_COMPLIANT | NON_COMPLIANT"
  findings_count:
    pass: <count>
    partial: <count>
    fail: <count>
  severity_distribution:
    high: <count>
    medium: <count>
    low: <count>
  top_priority_findings:
    - id: "<finding_id>"
      title: "<title>"
      severity: "<severity>"
      remediation: "<brief fix>"
  principles_assessed:
    - principle: "PbD-01"
      verdict: "PASS | PARTIAL | FAIL"
      severity: "HIGH | MEDIUM | LOW | N/A"
    - principle: "PbD-02"
      verdict: "PASS | PARTIAL | FAIL"
      severity: "HIGH | MEDIUM | LOW | N/A"
    # ... through PbD-07
  retention_assessment:
    conducted: true | false
    categories_assessed: <count>
    categories_compliant: <count>
    gaps_identified: <count>
  cross_jurisdictional:
    jurisdictions_applicable: ["GDPR", "CCPA", "APP"]
    common_baseline_met: true | false
    jurisdiction_specific_gaps: <count>
```

## Overall verdict rules

| Overall verdict     | Condition                                          |
|---------------------|----------------------------------------------------|
| COMPLIANT           | All 7 principles are PASS                          |
| PARTIALLY_COMPLIANT | No principles are FAIL but one or more are PARTIAL |
| NON_COMPLIANT       | One or more principles are FAIL                    |

## Finding ID conventions

- Format: `PBD-<NN>-<SSS>` where NN is the principle number (01–07) and SSS is a sequence within that principle.
- Retention findings use: `PBD-05-R<SSS>` (R prefix distinguishes retention sub-findings).
- Cross-jurisdictional findings use: `PBD-CJ-<SSS>` for findings that span multiple principles.

## Integration with backlog handoff

Each FAIL or PARTIAL finding maps to a potential backlog item:

```yaml
backlog_item:
  source_finding: "<finding_id>"
  title: "[Privacy] <remediation title>"
  description: |
    **Finding**: <finding description>
    **Principle**: <principle name>
    **Severity**: <severity>
    **Remediation**: <actionable fix>
    **Regulatory reference**: <citation>
  priority: "<mapped from severity: HIGH→P1, MEDIUM→P2, LOW→P3>"
  labels: ["privacy", "pbd", "compliance"]
  acceptance_criteria:
    - "<specific condition that resolves the finding>"
```

## Retention-specific finding extensions

Retention findings under PbD-05 include additional fields:

```yaml
retention_finding:
  id: "PBD-05-R001"
  data_category: "<category name>"
  current_retention: "<current period or 'undefined'>"
  required_retention: "<justified period>"
  disposal_method: "<current method or 'none defined'>"
  backup_included: true | false
  legal_hold_capable: true | false
  gap_type: "undefined_period | excessive_retention | no_disposal | no_backup_coverage | no_legal_hold"
```

## Example finding

```yaml
finding:
  id: "PBD-02-001"
  principle: "PbD-02"
  principle_name: "Privacy as the Default"
  category: "Default Settings"
  verdict: "FAIL"
  severity: "HIGH"
  title: "Analytics tracking enabled by default without consent"
  description: "User analytics include individual behavioral tracking enabled by default. Users must navigate to Settings > Privacy > Analytics to disable tracking."
  evidence: "Configuration file analytics.config.json shows tracking.enabled: true as default. No consent prompt appears before tracking begins."
  remediation: "Set tracking.enabled to false by default. Implement an opt-in consent prompt before enabling individual behavioral tracking."
  checklist_items_met: 3
  checklist_items_total: 8
  anti_patterns_detected:
    - "Pre-checked consent boxes or opt-out rather than opt-in consent"
    - "Analytics track individual behavior by default"
  citations:
    pbd_principle: "PbD-02 Privacy as the Default"
    gdpr_article: "Art. 25(2)"
    ccpa_section: "§1798.120"
  jurisdiction_flags: ["GDPR", "CCPA"]
```

---

Schema design follows the finding and backlog patterns established by the security-reviewer and RAI Planner skills within hve-core, adapted for privacy principle assessment.
