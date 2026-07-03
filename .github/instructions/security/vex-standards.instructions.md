---
description: "VEX document standards: canonical rule reference, licensing posture, author-of-record contract, and document mutation contract for OpenVEX management - Brought to you by microsoft/hve-core"
applyTo: '**/security/vex/**, **/.copilot-tracking/security/vex/**'
---

# VEX Standards

This file defines the authoritative conventions for OpenVEX document management in hve-core. All agents, prompts, and human contributors producing or reviewing VEX artifacts follow these rules.

## Scope

Applies to all files under `security/vex/` and `.copilot-tracking/security/vex/`. Governs confidence routing, status transitions, licensing compliance, and accountability for VEX statements.

## Canonical rules reference

The authoritative definitions for confidence routing, status determination, forbidden transitions,
evidence requirements, and justification codes live in the `vex` skill reference
`references/vex-status-logic.md`. Treat that
reference as the single source of truth. Do not duplicate or paraphrase those tables here, because
duplication causes drift.

The critical guard that governs every VEX document in this repository:

> When reachability or exploitability cannot be determined, the only valid status is
> `under_investigation`. A `not_affected` or `affected` determination requires the supporting
> evidence defined in the canonical reference. Vendor-disputed findings are no exception: record the
> dispute in `status_notes` and keep the status at `under_investigation` until evidence is gathered.

## Licensing posture

VEX documents reference vulnerability data from multiple sources. Each source carries distinct
licensing obligations.

| Source             | License                           | Usage guidance                                                                                                                                 |
|--------------------|-----------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------|
| OSV.dev            | Mixed (varies by upstream source) | Check record provenance before paraphrasing. Only paraphrase CC0 or public-domain records. Write original prose for CC-BY-4.0 sourced records. |
| NVD                | US Government public domain       | Use for CVSS vectors and CWE classifications.                                                                                                  |
| GitHub Advisory DB | CC-BY-4.0                         | Reference URLs and identifiers only. Do not quote GHSA prose, to avoid CC-BY-4.0 attribution obligations; link to the advisory URL instead.    |

OSV.dev aggregates records from multiple upstream databases, so its effective license varies per
record. Check the record `id` prefix (`GHSA-` = CC-BY-4.0, `RUSTSEC-` = CC0, `CVE-` from NVD =
public domain) to determine the upstream license. When the upstream license is unclear, write
original prose and cite the record URL as a reference. Write original remediation and impact prose;
do not copy text from any external source.

## Author-of-record contract

VEX documents in this repository follow a draft-and-merge accountability model.

The AI agent drafts VEX statements, including status determinations, justification codes, and supporting evidence. The human reviewer merges the pull request after validating the evidence and confirming the status determination.

The merge commit author is the accountable author of record for the VEX statement. The Sigstore identity attached by the release workflow serves as the trust anchor for published VEX documents.

## Document mutation contract

The canonical VEX document at `security/vex/hve-core.openvex.json` is a single rolling document.
Every pull request that adds or changes a statement must update the document metadata so consumers
can detect new revisions:

* Set `timestamp` (and `last_updated`, when present) to the current UTC time of issuance.
* Increment the integer `version` field by one.
* Regenerate `@id` so it is unique per revision (for example, embed the issuance date or version in the IRI).
* Set the `tooling` field to record document provenance: the AI agent that drafted the statements and the human-reviewed, Sigstore-attested release process that publishes them. This keeps provenance inside the document itself, not only in the external attestation.

Reviewers must reject any statement-changing PR that leaves `version`, `timestamp`, or `@id` stale, or that drops the `tooling` provenance field.
The foundation document ships with an empty `statements` array and therefore carries no product
identity until the first triage PR adds a product-bearing statement.

## Validation

Verify compliance with these standards by checking:

* Status determinations follow the canonical reference in `vex-status-logic.md` (no forbidden transitions)
* Data source licensing is respected (no quoted GHSA prose)
* Every merged VEX statement has an identifiable human author via merge commit
* `version`, `timestamp`, and `@id` were updated in any statement-changing PR
* `tooling` records the document provenance (AI-drafted, human-reviewed, attested at release)
