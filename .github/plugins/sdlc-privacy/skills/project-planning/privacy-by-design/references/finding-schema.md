---
title: Finding Schema
description: Structured output format for PbD assessment findings from consumers that explicitly load the privacy-by-design skill
---

# Finding Schema

Consumers that explicitly load `privacy-by-design` use this schema for consistent, machine-readable assessment results and potential review or backlog handoff. The schema does not establish automatic loading by existing agents or authorize tracker mutations.

## Finding record structure

Each finding is a discrete assessment result for one principle or sub-check.

```yaml
finding:
  id: "PBD-<principle_number>-<sequence>"  # e.g., PBD-01-001
  principle: "PbD-<number>"                # e.g., PbD-01
  principle_name: "<short name>"           # e.g., Proactive Not Reactive
  category: "<category>"                   # e.g., Prevention
  verdict: "PASS | PARTIAL | FAIL | INSUFFICIENT_EVIDENCE"
  evidence_status: "COMPLETE | INCOMPLETE"
  severity: "CRITICAL | HIGH | MEDIUM | LOW | N/A"
  title: "<concise finding title>"
  description: "<what was found>"
  evidence: "<what evidence supports this finding>"
  remediation: "<specific actionable fix>"  # Only for PARTIAL and FAIL; omit otherwise
  evidence_gaps: ["<missing evidence and how to obtain it>"]  # Empty when complete
  checklist_items_met: <count>
  checklist_items_not_met: <count>
  checklist_items_unknown: <count>
  checklist_items_total: <count>
  checklist_items_suppressed: <count>
  suppressed_checks: [{check: "<check>", reason: "<applicability evidence>"}]
  anti_patterns_detected: ["<pattern1>", "<pattern2>"]  # Empty array if none
  citations:
    pbd_principle: "PbD-<number> <name>"
    gdpr_article: "<Art. N>"               # Optional
    app_principle: "<APP N>"               # Optional
    ccpa_section: "<§section>"             # Optional
    retention_category: "<known category>" # Retention findings when known
    retention_gap: "<established gap>"     # Omit when no gap is established
  affected_principles: ["PbD-05"]         # Required for cross-jurisdictional findings
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
  overall_verdict: "COMPLIANT | PARTIALLY_COMPLIANT | NON_COMPLIANT | INCOMPLETE"
  evidence_status: "COMPLETE | INCOMPLETE"
  findings_count:
    pass: <count>
    partial: <count>
    fail: <count>
    insufficient_evidence: <count>
  severity_distribution:
    critical: <count>
    high: <count>
    medium: <count>
    low: <count>
    not_applicable: <count>
  top_priority_findings:
    - id: "<finding_id>"
      title: "<title>"
      severity: "<severity>"
      remediation: "<brief fix>"
  principles_assessed:
    - principle: "PbD-01"
      verdict: "PASS | PARTIAL | FAIL | INSUFFICIENT_EVIDENCE"
      evidence_status: "COMPLETE | INCOMPLETE"
      severity: "CRITICAL | HIGH | MEDIUM | LOW | N/A"
    - principle: "PbD-02"
      verdict: "PASS | PARTIAL | FAIL | INSUFFICIENT_EVIDENCE"
      evidence_status: "COMPLETE | INCOMPLETE"
      severity: "CRITICAL | HIGH | MEDIUM | LOW | N/A"
    # ... through PbD-07
  retention_assessment:
    conducted: true | false
    evidence_status: "COMPLETE | INCOMPLETE | NOT_APPLICABLE"
    categories_assessed: <count>
    categories_compliant: <count>
    categories_with_gaps: <count>
    categories_unknown: <count>
    gaps_identified: <count>
  cross_jurisdictional:
    jurisdictions_applicable: ["GDPR", "CCPA", "APP"]
    common_baseline_status: "MET | NOT_MET | INSUFFICIENT_EVIDENCE | NOT_APPLICABLE"
    jurisdiction_specific_gaps: <count>
```

## Overall verdict rules

Evaluate rows in order. These are assessment-rubric labels, not legal certification. Unknown evidence never becomes `null`, a false baseline, or an invented deficiency.

| Overall verdict     | Condition                                                                                          |
|---------------------|----------------------------------------------------------------------------------------------------|
| NON_COMPLIANT       | At least one principle FAIL, even if other evidence is incomplete                                  |
| INCOMPLETE          | No FAIL, but any principle or applicable retention/jurisdiction assessment has incomplete evidence |
| PARTIALLY_COMPLIANT | Complete evidence, no FAIL, and at least one PARTIAL                                               |
| COMPLIANT           | Complete evidence and all 7 principles PASS                                                        |

### Count and completeness invariants

- `checklist_items_total = checklist_items_met + checklist_items_not_met + checklist_items_unknown`. The total is the applicable denominator after justified suppressions; suppressed items are not MET or unknown.
- `suppressed_checks` records every excluded check and its reason; its length equals `checklist_items_suppressed`. No applicable checks yields INSUFFICIENT_EVIDENCE, INCOMPLETE evidence, and N/A severity, not PASS.
- `findings_count` counts each unique finding record once. Its four buckets sum to the number of records, which may exceed seven when sub-findings exist. Each record also occupies exactly one severity bucket, including `not_applicable` for N/A; both totals agree.
- `principles_assessed` contains exactly one entry for each of PbD-01 through PbD-07, derived from all applicable checks and sub-findings using the protocol. These rollups are not counted again in `findings_count`.
- PASS and INSUFFICIENT_EVIDENCE records have N/A severity and omit remediation. PARTIAL and FAIL record only established deficiencies, require remediation, and may also carry independent evidence gaps.
- Summary evidence is INCOMPLETE if any principle, applicable retention category or jurisdiction obligation is unresolved. A known FAIL still produces NON_COMPLIANT. Every incomplete result names its evidence gaps.
- `categories_assessed` counts all in-scope retention categories, including unknowns, and equals `categories_compliant + categories_with_gaps + categories_unknown`. Assign a category with any proven gap to `categories_with_gaps` even if other evidence is unknown; preserve its evidence gaps independently. `gaps_identified` counts distinct proven retention gaps, not categories or missing evidence.
- No stored personal data makes retention NOT_APPLICABLE with zero counts. Missing retention evidence for stored personal data makes it INCOMPLETE, not NOT_APPLICABLE.
- The common baseline is NOT_MET if a common applicable obligation is demonstrably unmet, otherwise INSUFFICIENT_EVIDENCE if any remains unknown, otherwise MET. Use NOT_APPLICABLE only when no common baseline applies, with a reason; retain jurisdiction-specific gaps and evidence requests separately.

## Evidence requests and priority ordering

List missing evidence and the smallest request that would resolve it in `evidence_gaps`; do not generate remediation backlog items for unknown-only results. `top_priority_findings` contains only PARTIAL/FAIL findings, ordered CRITICAL, HIGH, MEDIUM, LOW, with FAIL before PARTIAL within a tier. Preserve original severity when mapping to backlog priority.

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
  priority: "<mapped from severity: CRITICAL→P1, HIGH→P1, MEDIUM→P2, LOW→P3>"
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
  backup_included: true | false | "UNKNOWN"
  legal_hold_capable: true | false | "UNKNOWN"
  gap_type: "undefined_period | excessive_retention | no_disposal | no_backup_coverage | no_legal_hold" # Only for an established gap
```

These fields extend the base finding rather than replacing its verdict, severity, completeness, evidence and citations. Populate `retention_category` when known and `retention_gap` only for an established gap. Use "unknown" for unavailable period/method evidence; "undefined" or "none defined" asserts verified absence. Unknown backup or legal-hold capability does not mean false and does not justify a gap type. Record a supported legal-hold exception before concluding retention is excessive.

## Example finding

```yaml
finding:
  id: "PBD-02-001"
  principle: "PbD-02"
  principle_name: "Privacy as the Default"
  category: "Default Settings"
  verdict: "FAIL"
  evidence_status: "COMPLETE"
  severity: "HIGH"
  title: "Analytics tracking enabled by default without consent"
  description: "User analytics include individual behavioral tracking enabled by default. Users must navigate to Settings > Privacy > Analytics to disable tracking."
  evidence: "Configuration file analytics.config.json shows tracking.enabled: true as default. No consent prompt appears before tracking begins."
  remediation: "Set tracking.enabled to false by default. Implement an opt-in consent prompt before enabling individual behavioral tracking."
  checklist_items_met: 3
  checklist_items_not_met: 5
  checklist_items_unknown: 0
  checklist_items_total: 8
  checklist_items_suppressed: 0
  suppressed_checks: []
  evidence_gaps: []
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

Source principles: [IPC Ontario, Privacy by Design](https://www.ipc.on.ca/sites/default/files/legacy/2018/01/pbd.pdf). Schema and aggregation rules are repository-original planning guidance.
