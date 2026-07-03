---
description: "VEX generation rules: evidence requirements, confidence routing, forbidden transitions, report templates, and licensing posture for AI-assisted vulnerability triage - Brought to you by microsoft/hve-core"
applyTo: '.github/agents/security/sssc-reviewer.agent.md, .github/agents/security/subagents/cve-*.agent.md'
---

# VEX Generation Instructions

Rules governing AI-assisted VEX document generation. Agents producing or editing OpenVEX documents
must follow these instructions. For OpenVEX schema details, see the
`vex` skill (read its `SKILL.md`).

## Evidence requirements, confidence routing, and forbidden transitions

The canonical definitions for justification codes, evidence requirements per status,
confidence-routing bands, and forbidden transitions live in the `vex` skill reference
`references/vex-status-logic.md`.

Agents must follow the decision tree, evidence thresholds, and band routing defined in that
reference. The behavioral rules below supplement that reference with agent-specific constraints.

### Agent behavioral rules

* Every VEX status determination must be supported by evidence proportional to its assertion
  strength. Stronger assertions (especially `not_affected`) require stronger evidence.
* The agent must classify each finding into exactly one confidence band before drafting a VEX
  statement.
* When reachability or exploitability is uncertain, the only valid status is
  `under_investigation`.
* The agent is **forbidden** from drafting `not_affected` in the Low confidence band.
* In the Medium and Low bands, the agent must include structured questions for the human
  reviewer.

## Author-of-record contract

VEX documents require an accountable author for trust purposes.

| Role             | Description                                                                              |
|------------------|------------------------------------------------------------------------------------------|
| Drafter          | the AI agent. No trust requirement; the agent performs analysis and drafts the document. |
| Reviewer         | CODEOWNERS-required human approver who validates evidence and status determinations.     |
| Author of record | the merge commit author (the human approver). This is the accountable identity.          |
| Trust anchor     | Sigstore identity of the release workflow that attests the VEX document.                 |

The agent must never represent itself as the author of record. The `author` field in OpenVEX
documents must identify the maintainer team or organization, not the agent.

## Licensing posture

When drafting VEX content, follow these rules for external data:

| Source             | License                           | Permitted use                                                                                                                                  |
|--------------------|-----------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------|
| OSV.dev            | Mixed (varies by upstream source) | Check record provenance before paraphrasing. Only paraphrase CC0 or public domain records. Write original prose for CC-BY-4.0 sourced records. |
| NVD API 2.0        | US Gov public domain              | Use for CVSS vectors and CWE classification.                                                                                                   |
| GitHub Advisory DB | CC-BY-4.0                         | Identifiers, aliases, CVSS, severity, and affected ranges (factual metadata) plus reference URLs. Do not quote or closely paraphrase prose.    |

OSV.dev aggregates records from multiple databases. Check the record `id` prefix (`GHSA-` = CC-BY-4.0,
`RUSTSEC-` = CC0, `CVE-` from NVD = public domain) to determine the upstream license. When the
upstream license is unclear, write original prose and cite the record URL as a reference.

Write original remediation and impact prose. Do not copy from any external source.

## Identifier resolution and alias fallback

Each data source is keyed by a different identifier, so a single-id lookup misses records that exist
under an alias. OSV.dev and the GitHub Advisory Database are keyed by the native advisory id
(`GHSA-`, `PYSEC-`, and similar) and return `404` for a `CVE-` query; NVD is keyed by the `CVE-` id.

For each finding:

1. Collect every identifier: the scanner's primary id plus all `aliases`.
2. Query each source by the id it is keyed on (GitHub Advisory DB and OSV.dev by `GHSA-`/`PYSEC-`/native id; NVD by `CVE-`), and walk the aliases until a source resolves. The OSV package query resolves by package and version regardless of id.
3. Keep the first authoritative value per field (NVD for CVSS and CWE; OSV for affected ranges).
4. Treat advisory data as unavailable only after every identifier has been tried against every reachable source.

The GitHub Advisory Database (`api.github.com`) is reachable in the gh-aw sandbox by default, while
`api.osv.dev` and `services.nvd.nist.gov` require entries in the workflow `network:` allowlist. When
OSV.dev and NVD are unreachable, fall back to the GitHub Advisory Database for the CVE alias, CVSS
vector, severity, and affected packages.

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
* Set `timestamp` only on first issuance. Update `last_updated` to the current generation time.
* Set the `tooling` field to record document provenance: the drafting agent plus the human-reviewed, Sigstore-attested release process.
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
