---
id: "0009"
title: "Anchor VEX trust to the reusable VEX attestation workflow"
description: "Move the published VEX trust anchor from the release workflow to the dedicated reusable VEX attestation workflow so verification and governance use the same signer identity."
author: "HVE Core Maintainers"
ms.date: "2026-07-03"
ms.topic: "reference"
status: "accepted"
proposed_date: "2026-07-03"
accepted_date: "2026-07-03"
deciders:
  - "HVE Core Maintainers"
consulted:
  - "HVE Core security maintainers"
  - "@microsoft/edge-ai-core-dev"
informed:
  - "hve-core contributors"
  - "extension consumers"
affected_components:
  - ".github/instructions/security/vex-standards.instructions.md"
  - ".github/instructions/security/vex-generation.instructions.md"
  - ".github/skills/security/vex/SKILL.md"
  - "security/vex/hve-core.openvex.json"
  - "docs/security/vex-verification.md"
  - "SECURITY.md"
effort: "S"
tags:
  - "security"
  - "vex"
  - "attestation"
  - "governance"
supersedes: null
superseded-by: null
related: []
asr_triggers:
  - kind: "security"
    evidence: "The VEX attestation signer identity is part of the repository's release-integrity and trust-anchor contract."
    note: "The change makes the documented trust anchor match the attested workflow identity and strengthens verification."
  - kind: "compliance"
    evidence: "The VEX guidance and OpenVEX tooling field must remain consistent for downstream consumers and reviewers."
    note: "A single signer identity removes ambiguity for audit and verification workflows."
  - kind: "maintainability"
    evidence: "The VEX instructions and skill playbook previously described a generic release-attestation path."
    note: "The reusable workflow name becomes the single source of truth across docs, instructions, and data."
success_criteria:
  - metric: "trust-anchor-consistency"
    target: "100% of VEX docs, instructions, skill guidance, and tooling metadata reference the same reusable workflow identity"
    measurement_window: "for this change set"
    source: "docs/security/vex-verification.md, SECURITY.md, .github/instructions/security/vex-standards.instructions.md, .github/instructions/security/vex-generation.instructions.md, .github/skills/security/vex/SKILL.md, and security/vex/hve-core.openvex.json"
  - metric: "verification-clarity"
    target: "A consumer can verify the VEX artifact with a single signer-workflow command that matches the published trust model"
    measurement_window: "for each release"
    source: "gh attestation verify commands in docs/security/vex-verification.md and SECURITY.md"
decisionMetadata:
  driverToTriggerMap:
    "Security": "The VEX attestation signer identity is part of the release-integrity and trust-anchor contract, so naming the reusable workflow makes it explicit and verifiable for consumers and reviewers."
    "Compliance": "VEX guidance and the OpenVEX tooling field must stay consistent for downstream consumers and reviewers, and a single signer identity removes ambiguity for audit and verification."
    "Maintainability": "The reusable workflow name becomes the single source of truth across docs, instructions, the skill playbook, and the published OpenVEX data, which reduces drift."
---

## Context

The hve-core release pipeline publishes a VEX document and its OpenVEX-over-SBOM predicate attestations. The earlier trust model described the signer identity as the release workflow, but the attestation is now generated in a dedicated reusable workflow. That workflow is the correct builder identity for verification and for the published provenance record.

The VEX document under security/vex is owned by @microsoft/edge-ai-core-dev in CODEOWNERS, so the trust-anchor change also affects governance and reviewer expectations. The change needs a durable record because the signer identity is part of the author-of-record contract and the verification surface for consumers.

## Decision Drivers

* Security
* Compliance
* Maintainability

## Considered Options

* Option A: Keep the trust anchor as the release workflow and document the reusable workflow only as an implementation detail.
* Option B: Re-anchor the published VEX trust model to the dedicated reusable workflow `microsoft/hve-core/.github/workflows/vex-attest.yml` and use that identity everywhere.

## Decision Outcome

| Decision driver | Option A: keep release workflow as anchor | Option B: reusable vex-attest.yml as anchor |
|-----------------|-------------------------------------------|---------------------------------------------|
| Security        | Partial                                   | Yes                                         |
| Compliance      | Partial                                   | Yes                                         |
| Maintainability | No                                        | Yes                                         |

Chosen option: **Option B**, because it makes the attestation identity explicit, aligns every consumer-facing and maintainer-facing artifact with the actual attestation builder, and supports `gh attestation verify --signer-workflow` without ambiguity.

The reusable workflow name is now the authoritative signer identity for the published VEX document. The author of record remains the human merge approver, while the Sigstore identity attached by the reusable workflow serves as the published trust anchor.

### Consequences

* Good, because VEX verification commands, instructions, the skill playbook, and the OpenVEX `tooling` field now describe the same workflow identity.
* Good, because consumers can verify the VEX document against the specific reusable workflow that actually attested it.
* Bad, because existing references that mention the release workflow as the trust anchor must be updated and reviewed carefully for drift.
* Neutral, because the human reviewer remains the accountable author of record, and the workflow identity is an additional trust anchor rather than a replacement for that accountability.

### Confirmation

This decision is confirmed by the repository changes that now use the same workflow identity in the VEX verification commands, the security instructions, the VEX skill, and the published OpenVEX document. The change is also reflected in the ADR itself so future reviewers can see why the trust anchor moved.

## Affected Components

* .github/instructions/security/vex-standards.instructions.md
* .github/instructions/security/vex-generation.instructions.md
* .github/skills/security/vex/SKILL.md
* security/vex/hve-core.openvex.json
* docs/security/vex-verification.md
* SECURITY.md

## More Information

The trust-anchor change updates every artifact that names the VEX signer identity:

* .github/instructions/security/vex-standards.instructions.md carries the author-of-record and trust-anchor language.
* .github/instructions/security/vex-generation.instructions.md carries the trust-anchor row and tooling guidance.
* .github/skills/security/vex/SKILL.md carries the attestation playbook ownership.
* security/vex/hve-core.openvex.json carries the published `tooling` metadata field.
* docs/security/vex-verification.md carries the consumer verification commands.
* SECURITY.md carries the release-integrity verification guidance.

---

🤖 *Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
