---
title: Security
description: Security vulnerability reporting procedures and Microsoft's coordinated disclosure policy
author: Microsoft Security Response Center
ms.date: 2026-09-04
ms.topic: reference
keywords:
  - security
  - vulnerability reporting
  - MSRC
  - responsible disclosure
  - coordinated disclosure
  - SBOM
  - software bill of materials
  - SPDX
  - attestation
  - provenance
  - sigstore
  - in-toto
estimated_reading_time: 5
---

<!-- BEGIN MICROSOFT SECURITY.MD V0.0.9 BLOCK -->

Microsoft takes the security of our software products and services seriously, which includes all source code repositories managed through our GitHub organizations, which include [Microsoft](https://github.com/Microsoft), [Azure](https://github.com/Azure), [DotNet](https://github.com/dotnet), [AspNet](https://github.com/aspnet) and [Xamarin](https://github.com/xamarin).

If you believe you have found a security vulnerability in any Microsoft-owned repository that meets [Microsoft's definition of a security vulnerability](https://aka.ms/security.md/definition), please report it to us as described below.

## Reporting Security Issues

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, please report them to the Microsoft Security Response Center (MSRC) at [https://msrc.microsoft.com/create-report](https://aka.ms/security.md/msrc/create-report).

If you prefer to submit without logging in, send email to [secure@microsoft.com](mailto:secure@microsoft.com).  If possible, encrypt your message with our PGP key; please download it from the [Microsoft Security Response Center PGP Key page](https://aka.ms/security.md/msrc/pgp).

You should receive a response within 24 hours. If for some reason you do not, please follow up via email to ensure we received your original message. Additional information can be found at [microsoft.com/msrc](https://www.microsoft.com/msrc).

Please include the requested information listed below (as much as you can provide) to help us better understand the nature and scope of the possible issue:

* Type of issue (e.g. buffer overflow, SQL injection, cross-site scripting, etc.)
* Full paths of source file(s) related to the manifestation of the issue
* The location of the affected source code (tag/branch/commit or direct URL)
* Any special configuration required to reproduce the issue
* Step-by-step instructions to reproduce the issue
* Proof-of-concept or exploit code (if possible)
* Impact of the issue, including how an attacker might exploit the issue

This information will help us triage your report more quickly.

If you are reporting for a bug bounty, more complete reports can contribute to a higher bounty award. Please visit our [Microsoft Bug Bounty Program](https://aka.ms/security.md/msrc/bounty) page for more details about our active programs.

## Preferred Languages

We prefer all communications to be in English.

## Policy

Microsoft follows the principle of [Coordinated Vulnerability Disclosure](https://aka.ms/security.md/cvd).

<!-- END MICROSOFT SECURITY.MD BLOCK -->

## Security Documentation

For comprehensive security documentation including security models and security controls, see [Security Documentation](docs/security/README.md).

## Verifying Release Integrity

HVE Core publishes cryptographically attested assets under exact channel tags:

* PreRelease: `prerelease-v<version>`
* Stable: `v<version>`

### Verification Steps

1. Install the GitHub CLI if not already available:

   ```bash
   # Windows (winget)
   winget install GitHub.cli

   # macOS (Homebrew)
   brew install gh
   ```

2. Download assets from the exact channel tag you intend to verify:

   ```bash
   # PreRelease
   gh release download prerelease-v<version> -R microsoft/hve-core \
     -p '*.vsix' -p '*.vsix.spdx.json' -p '*.vsix.sigstore.json' \
     -p '*.vsix.intoto.jsonl' -p 'dependencies.spdx.json'

   # Stable
   gh release download v<version> -R microsoft/hve-core \
     -p '*.vsix' -p '*.vsix.spdx.json' -p '*.vsix.sigstore.json' \
     -p '*.vsix.intoto.jsonl' \
     -p 'hve-core.openvex.json' -p 'dependencies.spdx.json'
   ```

3. Verify each primary package with its channel and artifact signer:

   ```bash
   # Stable VSIX
   gh attestation verify hve-core-<version>.vsix -R microsoft/hve-core \
    --signer-workflow microsoft/hve-core/.github/workflows/extension-provenance-signer.yml \
    --signer-digest 3a09401536cef0c4559db1aa64b7d1010638fd67

   # PreRelease VSIX
   gh attestation verify hve-core-<version>.vsix -R microsoft/hve-core \
    --signer-workflow microsoft/hve-core/.github/workflows/extension-provenance-signer.yml \
    --signer-digest 3a09401536cef0c4559db1aa64b7d1010638fd67
   ```

The GitHub Release is the canonical verification surface for SLSA and Sigstore
provenance. `release-vsix-publish.yml` is the sole post-tag producer. It runs
only for pushes of exact `v<version>` or `prerelease-v<version>` tags and
validates the protected tag, source, channel branch, committed release state,
and matching draft before producing assets. Marketplace publication remains a
separate path that consumes only the published release VSIX. VS Code separately
verifies the Marketplace signature during installation.

A successful verification confirms:

* The artifact was built from the microsoft/hve-core repository
* The build occurred in GitHub Actions
* The artifact has not been modified since signing

The release gate first authenticates the attestation cryptographically with the
exact subject digest, signer workflow and revision, source ref and revision,
and a hosted-runner restriction. It then applies fail-closed semantic policy to
the authenticated statement. The policy requires the exact subject and digest,
SLSA provenance v1, GitHub Actions `workflow/v1`, the `push` event, a
GitHub-hosted runner, the expected external parameters, one resolved source
dependency, and the expected builder identity. Missing, additional, or
mismatched policy fields fail verification.

`extension-provenance-signer.yml` provides the signer identity and separates duties.
Its `contents: read` package job installs dependencies and packages the VSIX.
The dependent privileged attestation job receives fixed-name artifacts through
digest-checked transfers and never installs dependencies or packages the
extension. No job both packages and signs.

> [!IMPORTANT]
> HVE Core does not claim SLSA Build Level 3. Future Stable and PreRelease
> releases still require successful runtime evidence, active governance
> evidence, platform assurance mapping, and qualified human review before such
> a claim can be made.

Tag governance is a mandatory activation prerequisite and is not yet active or
proven. The intended `release-tags-creation-by-release-app` ruleset restricts
creation only and gives the Release App its only bypass. The separate
`release-tags-immutable` ruleset restricts updates, deletion, and force pushes
with no bypass. This documentation does not imply that either ruleset is
installed.

Post-tag recovery begins by classifying the tag and release state. When both
the tag and matching draft or published release exist, recovery reruns the
original immutable tag-push workflow. A tag-only state first requires
release-please to create the missing exact draft; a draft-only state first
requires release-please to materialize the tag. Partial assets may be replaced
only while the release remains draft, and publication remains blocked until
asset and provenance verification succeeds. Do not move, delete, or recreate
the tag, create a replacement release identity, or convert a published release
back to draft. The producer has no default `workflow_dispatch` recovery path.
Its bounded discovery window fails closed but does not guarantee draft
visibility.

### Verifying the SBOM

Both channels publish a per-VSIX SPDX SBOM and `dependencies.spdx.json`.
These documents are attached as SPDX predicates over the VSIX subject. Because
the per-artifact and dependency predicates share the SPDX 2.3
predicate type, one verification can match more than one attestation. For
commands and inspection guidance, see the [SBOM Verification Guide](docs/security/sbom-verification.md).

### Verifying the VEX Document

The Stable release publishes `hve-core.openvex.json`; the current PreRelease
workflow does not. The Stable `vex-attest.yml` workflow emits two attestations:
build provenance for the OpenVEX file as a subject, and an OpenVEX predicate
over `dependencies.spdx.json` as a subject.

```bash
gh attestation verify hve-core.openvex.json -R microsoft/hve-core \
  --signer-workflow microsoft/hve-core/.github/workflows/vex-attest.yml

gh attestation verify dependencies.spdx.json -R microsoft/hve-core \
  --signer-workflow microsoft/hve-core/.github/workflows/vex-attest.yml \
  --predicate-type https://openvex.dev/ns/v0.2.0
```

For download, verification, status interpretation, and how to apply it with Trivy or Grype, see the [VEX Verification Guide](docs/security/vex-verification.md).

### Release Artifact Formats

Attested primary artifacts can have these companion files:

| Suffix           | Format                 | Purpose                                        |
|------------------|------------------------|------------------------------------------------|
| `.spdx.json`     | SPDX 2.3 JSON          | Software Bill of Materials                     |
| `.sigstore.json` | Sigstore bundle (JSON) | Cryptographic attestation envelope             |
| `.intoto.jsonl`  | in-toto DSSE envelope  | Provenance statement extracted from the bundle |
| `.openvex.json`  | OpenVEX v0.2.0 JSON    | Vulnerability exploitability statements (VEX)  |

The `.sigstore.json` bundle contains the full Sigstore verification material. The `.intoto.jsonl` file is the DSSE envelope extracted from the bundle for tools that consume in-toto provenance directly.

### Attestation Topology

| Subject or predicate payload           | Channel               | Signer workflow                   |
|----------------------------------------|-----------------------|-----------------------------------|
| VSIX subject                           | Stable and PreRelease | `extension-provenance-signer.yml` |
| SPDX predicates over the VSIX          | Stable and PreRelease | `extension-provenance-signer.yml` |
| OpenVEX document subject               | Stable only           | `vex-attest.yml`                  |
| OpenVEX predicate over dependency SBOM | Stable only           | `vex-attest.yml`                  |

Per-artifact SBOM files are predicate payloads, not independently attested
subjects. `dependencies.spdx.json` is an SPDX predicate payload on both
channels and is additionally a Stable subject for the OpenVEX predicate.

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
