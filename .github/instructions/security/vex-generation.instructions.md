---
description: "VEX generation rules: evidence requirements, confidence routing, forbidden transitions, report templates, and licensing posture for AI-assisted vulnerability triage - Brought to you by microsoft/hve-core"
applyTo: '.github/agents/security/vex-*.agent.md, .github/agents/security/subagents/cve-*.agent.md'
---

# VEX Generation Instructions

Rules governing AI-assisted VEX document generation. Agents producing or editing OpenVEX documents
must follow these instructions. For OpenVEX schema details, see the
`openvex-spec` skill at `.github/skills/security/openvex-spec/SKILL.md`.

## Evidence requirements

Every VEX status determination must be supported by evidence proportional to its assertion
strength. Stronger assertions (especially `not_affected`) require stronger evidence.

### not_affected

Requires at least one of:

* Code citation: file path and line range demonstrating the vulnerable function is unreachable
  (no import path, dead code, or excluded by build configuration).
* Mitigation reference: specific control or configuration that prevents exploitation, with
  explanation of why it cannot be bypassed.

The justification code must match the evidence type:

| Evidence type              | Justification code                                    |
|----------------------------|-------------------------------------------------------|
| Component absent from tree | `component_not_present`                               |
| Code excluded at build     | `vulnerable_code_not_present`                         |
| No runtime call path       | `vulnerable_code_not_in_execute_path`                 |
| Input not attacker-controlled | `vulnerable_code_cannot_be_controlled_by_adversary` |
| Built-in mitigation        | `inline_mitigations_already_exist`                    |

### affected

Requires:

* Reachable execution path or runtime invocation evidence demonstrating the vulnerable code is
  exercised.
* An `action_statement` describing recommended remediation or mitigation steps.

### fixed

Requires:

* Version reference identifying the release where the fix was applied.
* Dependency update reference, patch citation, or commit hash.

### under_investigation

* No evidence required. This is the safe default for uncertain cases.
* Include `status_notes` describing what is being investigated.

## Confidence-routing rules

The agent must classify each finding into exactly one confidence band before drafting a VEX
statement. The band determines what the agent is allowed to draft.

| Band              | Criteria                                                                                                   | Agent action                                                                              | Human action                                    |
|-------------------|------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------|-------------------------------------------------|
| High not_affected | Vulnerable symbol provably unreachable (no import path, dead code, or guarded by mitigation)               | Draft `not_affected` with justification code and code citations                           | Approve PR (skim evidence)                      |
| High affected     | Vulnerable symbol on a reachable execution path                                                            | Draft `affected` with link to remediation issue                                           | Approve PR and triage remediation               |
| Medium            | Symbol reachable in some configurations but ambiguous (feature flags, optional codepaths, runtime conditionals) | Draft `under_investigation` with structured questions for human reviewer                  | Decide final status, edit PR                    |
| Low               | Cannot determine reachability (closed-source dep, dynamic dispatch, native code)                           | Draft `under_investigation` only. **Forbidden** from drafting `not_affected`.             | Manual analysis, may downgrade                  |
| Vendor-disputed   | OSV/NVD shows dispute or CVSS < 4.0 with no known exploit                                                 | Draft `not_affected` with `inline_mitigations_already_exist` only with code citation      | Approve PR                                      |

## Forbidden transitions

These transitions are never permitted regardless of context.

| From state              | To state       | Reason                                                               |
|-------------------------|----------------|----------------------------------------------------------------------|
| Unknown reachability    | `not_affected` | Cannot assert non-exploitability without reachability evidence.      |
| Unknown reachability    | `affected`     | Cannot assert exploitability without reachability evidence.          |
| No analysis performed   | `not_affected` | Absence of evidence is not evidence of absence.                      |
| No analysis performed   | `affected`     | Vulnerability presence alone does not confirm exploitability.        |

**Default rule**: when reachability or exploitability is uncertain, the only valid status is
`under_investigation`.

## Author-of-record contract

VEX documents require an accountable author for trust purposes.

| Role | Description |
|------|-------------|
| Drafter | the AI agent. No trust requirement; the agent performs analysis and drafts the document. |
| Reviewer | CODEOWNERS-required human approver who validates evidence and status determinations. |
| Author of record | the merge commit author (the human approver). This is the accountable identity. |
| Trust anchor | Sigstore identity of the release workflow that attests the VEX document. |

The agent must never represent itself as the author of record. The `author` field in OpenVEX
documents must identify the maintainer team or organization, not the agent.

## Licensing posture

When drafting VEX content, follow these rules for external data:

| Source              | License                           | Permitted use                                                    |
|---------------------|-----------------------------------|------------------------------------------------------------------|
| OSV.dev             | Mixed (varies by upstream source) | Check record provenance before paraphrasing. Only paraphrase CC0 or public domain records. Write original prose for CC-BY-4.0 sourced records. |
| NVD API 2.0         | US Gov public domain              | Use for CVSS vectors and CWE classification.                    |
| GitHub Advisory DB   | CC-BY-4.0                        | Reference URLs and identifiers only. Do not quote or closely paraphrase prose. |

OSV.dev aggregates records from multiple databases. Check the record `id` prefix (`GHSA-` = CC-BY-4.0,
`RUSTSEC-` = CC0, `CVE-` from NVD = public domain) to determine the upstream license. When the
upstream license is unclear, write original prose and cite the record URL as a reference.

Write original remediation and impact prose. Do not copy from any external source.

## Report templates

Agent-generated VEX triage output consists of three sections.

### Executive summary

Brief overview for human reviewers. Include:

* Total CVEs analyzed.
* Counts by status (`not_affected`, `affected`, `fixed`, `under_investigation`).
* Counts by confidence band.
* Highlight any `affected` findings requiring immediate action.

### Technical report

Per-CVE detailed findings. For each CVE include:

* CVE identifier, severity (CVSS score and vector), and CWE classification.
* Affected package and version range.
* Confidence band assignment with rationale.
* Reachability analysis: call path trace or explanation of why code is unreachable.
* Evidence citations (file paths, line ranges, dependency tree output).
* Recommended VEX status and justification code.
* Structured questions for human reviewer (Medium and Low confidence only).

### OpenVEX JSON

The generated `hve-core.openvex.json` document containing all VEX statements. Must:

* Validate against the OpenVEX v0.2.0 schema (see `openvex-schema.md` reference).
* Increment the document `version` field.
* Update `timestamp` and `last_updated` to the generation time.
* Preserve existing statements that were not re-analyzed.
* Use PURL format for all product identifiers.

## SBOM input precedence

When multiple scan sources are available, prefer them in this order:

1. Trivy JSON output (richest vulnerability metadata).
2. OSV-Scanner JSON output.
3. SPDX-JSON SBOM (dependency list only, requires separate vulnerability lookup).

## Maturity

All VEX generation artifacts ship at `experimental` maturity. Promote to `stable` after validation
across three or more codebases with a false-positive rate of 5% or less on `not_affected`
determinations.
