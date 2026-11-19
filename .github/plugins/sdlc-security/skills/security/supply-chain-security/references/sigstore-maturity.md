---
description: Sigstore (cosign) adoption maturity levels from not adopted through advanced
---

# Sigstore (cosign) Standards

Assess Sigstore adoption maturity using cosign as the canonical signing tool:

* Not adopted: No signing or attestation in place
* Basic: Build provenance via `actions/attest-build-provenance` (cosign-backed)
* Intermediate: Build provenance + SBOM attestation via `actions/attest`
* Advanced: Tag signing via gitsign + cosign artifact signing + build provenance + SBOM attestation + verification workflow

Document current level and steps to advance.

## Attribution

Sigstore maturity data derived from the Sigstore project, licensed under Apache 2.0. Source: <https://www.sigstore.dev/>
