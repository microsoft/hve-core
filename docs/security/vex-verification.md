---
title: VEX Verification
description: Download, verify, and interpret the OpenVEX vulnerability exploitability document published with each HVE Core release
sidebar_position: 4
author: Microsoft
ms.date: 2026-07-03
ms.topic: how-to
keywords:
  - VEX
  - OpenVEX
  - vulnerability exploitability
  - SBOM
  - attestation
  - Sigstore
  - supply chain
  - Trivy
  - Grype
estimated_reading_time: 6
---

Every HVE Core release publishes a Vulnerability Exploitability eXchange (VEX) document in [OpenVEX](https://openvex.dev/) v0.2.0 JSON format alongside the Software Bill of Materials (SBOM). Where the SBOM tells you *what* components ship in a release, the VEX document tells you *whether a known vulnerability in one of those components actually affects HVE Core*. Like the SBOM, the VEX document is cryptographically attested with Sigstore so you can confirm it was produced by the official CI/CD pipeline.

## How VEX Complements the SBOM

A scanner run against the SBOM can report dozens of CVEs in transitive dependencies. Most are not exploitable in HVE Core: the vulnerable function is never called, the code path is unreachable, or the dependency is only used at build time. The VEX document records a per-vulnerability determination so you can separate real exposure from scanner noise.

| Artifact | Answers                                                     | Format              |
|----------|-------------------------------------------------------------|---------------------|
| SBOM     | Which components and versions ship in the release           | SPDX 2.3 JSON       |
| VEX      | Whether a known vulnerability affects this product, and why | OpenVEX v0.2.0 JSON |

The two are designed to be consumed together: a scanner reads the SBOM to find candidate vulnerabilities, then applies the VEX document to suppress the ones marked `not_affected`.

> [!NOTE]
> VEX status determinations are drafted with AI assistance and reviewed by a human before release. The accountable author of record is the human who merges the VEX update, never the automation. Treat the document as the maintainers' assessment, not a guarantee.

## Downloading the VEX Document

The VEX document is published as a release asset named `hve-core.openvex.json`. Download it with the GitHub CLI (replace `<version>` with the release tag, for example `v1.2.0`):

```bash
gh release download <version> -R microsoft/hve-core -p 'hve-core.openvex.json'
```

To download the VEX document together with its Sigstore companions:

```bash
gh release download <version> -R microsoft/hve-core \
  -p 'hve-core.openvex.json' -p 'hve-core.openvex.json.sigstore.json'
```

## Verifying the VEX Attestation

The release publishes two Sigstore attestations for the VEX document:

1. **Provenance of the VEX document**, so you can confirm the file itself came from the official pipeline. Verify it the same way as any other release artifact:

   ```bash
   gh attestation verify hve-core.openvex.json -R microsoft/hve-core
   ```

2. **VEX bound to the dependency SBOM**, where the VEX document is the in-toto *predicate* over the SBOM *subject* (the OpenVEX "encapsulating format"). This lets VEX-aware tooling resolve the exploitability assessment for the product's component inventory:

   ```bash
   gh attestation verify dependencies.spdx.json -R microsoft/hve-core \
     --predicate-type https://openvex.dev/ns/v0.2.0
   ```

A successful verification confirms the artifact was produced by the official HVE Core CI/CD pipeline and has not been modified since signing.

> [!TIP]
> The default `gh attestation verify` command verifies build provenance. Pass `--predicate-type <type>` to target a specific attestation: the OpenVEX predicate above, or `https://spdx.dev/Document/v2.3` for the SBOM. Run `gh attestation verify --help` for the full set of options.

## Interpreting VEX Status Values

Each statement in the VEX document assigns one of four OpenVEX status values to a vulnerability:

| Status                | Meaning                                                                          | What you should do                                                             |
|-----------------------|----------------------------------------------------------------------------------|--------------------------------------------------------------------------------|
| `not_affected`        | The vulnerability is present in a dependency but is not exploitable in HVE Core. | Safe to suppress or deprioritize. Read the `justification` and `status_notes`. |
| `affected`            | The vulnerability is exploitable. Remediation is planned or pending.             | Track the `action_statement`. Apply any documented mitigation.                 |
| `fixed`               | The vulnerability has been remediated in this release.                           | No action required for this version.                                           |
| `under_investigation` | Triage is in progress. Exploitability has not yet been determined.               | Treat as potentially exposed until a later release resolves the status.        |

A `not_affected` statement always carries a machine-readable `justification` explaining *why* the vulnerability does not apply:

| Justification code                                  | When it applies                                                      |
|-----------------------------------------------------|----------------------------------------------------------------------|
| `component_not_present`                             | The vulnerable component is not included in the product.             |
| `vulnerable_code_not_present`                       | The component is present but the vulnerable code is excluded.        |
| `vulnerable_code_not_in_execute_path`               | The vulnerable code exists but cannot be reached at runtime.         |
| `vulnerable_code_cannot_be_controlled_by_adversary` | The code is reachable but attacker-controlled input cannot reach it. |
| `inline_mitigations_already_exist`                  | Built-in protections prevent exploitation.                           |

Inspect the document with `jq`:

```bash
# Status for every statement
jq '.statements[] | {id: .vulnerability.name, status, justification}' hve-core.openvex.json

# Only the vulnerabilities still under investigation or affected
jq '.statements[] | select(.status == "affected" or .status == "under_investigation")' hve-core.openvex.json
```

## Consuming VEX Alongside the SBOM

VEX-aware scanners apply the VEX document to filter their findings, so vulnerabilities the maintainers have assessed as `not_affected` are suppressed automatically.

### Trivy

Pass the VEX document with the `--vex` flag when scanning the SBOM:

```bash
trivy sbom --vex hve-core.openvex.json hve-core-<version>.vsix.spdx.json
```

Findings whose status is `not_affected` or `fixed` in the VEX document are filtered from the results, and Trivy reports how many were suppressed.

### Grype

Grype consumes VEX through the same flag:

```bash
grype sbom:hve-core-<version>.vsix.spdx.json --vex hve-core.openvex.json
```

> [!TIP]
> Always verify the attestation (above) before feeding the VEX document into a scanner. An unverified VEX document could suppress findings you actually need to see.

## Related Resources

* [SBOM Verification](sbom-verification.md): Download and verify the Software Bill of Materials that pairs with the VEX document
* [Security Model](security-model.md): Security controls including VEX attestation (SC-9)
* [VEX capability](../agents/security/vex-capability.md): How HVE Core drafts its VEX determinations
* [OpenVEX specification](https://github.com/openvex/spec): The OpenVEX v0.2.0 format reference

---

🤖 *Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
