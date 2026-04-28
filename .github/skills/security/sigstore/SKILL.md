---
name: sigstore
description: Sigstore signing, verification, and transparency knowledge base for assessing supply chain artifact integrity controls (cosign, Fulcio, Rekor) under the SSSC Planner framework - Brought to you by microsoft/hve-core.
license: Apache-2.0
user-invocable: false
metadata:
  authors: "Sigstore project (Linux Foundation, OpenSSF)"
  spec_version: "1.0"
  framework_revision: "1.0"
  last_updated: "2026-04-17"
  skill_based_on: "https://github.com/chris-buckley/agnostic-prompt-standard"
  content_based_on: "https://docs.sigstore.dev/"
---

# Sigstore — Skill Entry

This `SKILL.md` is the **entrypoint** for the Sigstore framework skill.

The skill encodes Sigstore signing, verification, and transparency controls as
machine-readable per-control YAML items consumed by the SSSC Planner during the
`standards-mapping`, `gap-analysis`, and `backlog-generation` phases.

## Sigstore Maturity (verbatim from `sssc-standards.instructions.md`)

Assess Sigstore adoption maturity:

* **Not adopted**: No signing or attestation in place
* **Basic**: Build provenance via `actions/attest-build-provenance`
* **Intermediate**: Build provenance + SBOM attestation via `actions/attest`
* **Advanced**: Tag signing via gitsign + build provenance + SBOM attestation + verification workflow

Document current level and steps to advance.

## Controls

Each control is a separate YAML item under `items/` and validates against
`scripts/linting/schemas/planner-framework-control.schema.json`.

| Control id           | Title                                          | Risk |
|----------------------|------------------------------------------------|------|
| `cosign-sign`        | Artifact signing via cosign (keyless or keyed) | high |
| `cosign-verify`      | Verification policy applied at consume time    | high |
| `fulcio-issuance`    | OIDC-based short-lived certificate issuance    | high |
| `rekor-transparency` | Inclusion proof in transparency log            | high |

## Phase Mapping

`index.yml` maps each control to the SSSC Planner phases that consume it. The
loading contract from research Decision 5c-final restricts the planner to
reading only the controls listed for the active phase.

## Skill Layout

* `SKILL.md` — this file (skill entrypoint).
* `index.yml` — framework roll-up with `framework`, `version`, and `phaseMap`.
* `items/` — per-control items.
  * `cosign-sign.yml` — Artifact signing via cosign.
  * `cosign-verify.yml` — Verification policy.
  * `fulcio-issuance.yml` — OIDC-based short-lived cert issuance.
  * `rekor-transparency.yml` — Inclusion proof in transparency log.

## Third-Party Attribution

Sigstore content is derived from the Sigstore project documentation, licensed
under Apache 2.0 (<https://www.apache.org/licenses/LICENSE-2.0>).
Source: <https://docs.sigstore.dev/>
Modifications: Sigstore concepts restructured into per-control YAML items
with phase mapping, gates, and evidence hints for SSSC Planner consumption.
The "Sigstore Maturity" tiers above are reproduced verbatim from
`.github/instructions/security/sssc-standards.instructions.md`.

Sigstore is a project of the OpenSSF® and the Linux Foundation. OpenSSF® is a
registered trademark of the Linux Foundation. Use does not imply endorsement.

---
