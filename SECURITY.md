---
title: Security
description: Security vulnerability reporting procedures and Microsoft's coordinated disclosure policy
author: Microsoft Security Response Center
ms.date: 2026-03-01
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

For comprehensive security documentation including threat models and security controls, see [Security Documentation](docs/security/README.md).

## Verifying Release Integrity

HVE Core releases are cryptographically signed using GitHub Artifact Attestations. This establishes provenance and allows you to verify that release artifacts were built from this repository's official CI/CD pipeline.

### Verification Steps

1. Install the GitHub CLI if not already available:

   ```bash
   # Windows (winget)
   winget install GitHub.cli

   # macOS (Homebrew)
   brew install gh
   ```

2. Download the release artifact (replace `<version>` with the release tag, e.g., `v1.2.0`):

   ```bash
   gh release download <version> -R microsoft/hve-core -p '*.vsix'
   ```

3. Verify the attestation:

   ```bash
   gh attestation verify hve-core-<version>.vsix -R microsoft/hve-core
   ```

A successful verification confirms:

* The artifact was built from the microsoft/hve-core repository
* The build occurred in GitHub Actions
* The artifact has not been modified since signing

### Verifying the SBOM

Each release includes a Software Bill of Materials (SBOM) in SPDX 2.3 JSON format. The SBOM lists every component bundled in the extension, including names, versions, and licenses. Like build provenance, the SBOM is cryptographically attested using Sigstore.

To verify the SBOM attestation for a downloaded VSIX:

```bash
gh attestation verify hve-core-<version>.vsix -R microsoft/hve-core \
  --predicate-type https://spdx.dev/Document/v2.3
```

A successful verification confirms:

* The component inventory was generated from the official CI/CD pipeline
* The SBOM has not been modified since signing
* The SBOM corresponds to the verified VSIX artifact

> [!TIP]
> Build provenance and SBOM are independent attestations. The default `gh attestation verify` command (without `--predicate-type`) verifies build provenance. Adding `--predicate-type https://spdx.dev/Document/v2.3` verifies the SBOM instead.

### Downloading and Inspecting the SBOM

Each release publishes two SBOM files:

* `hve-core-<version>.vsix.spdx.json` lists the components packaged inside the VSIX
* `dependencies.spdx.json` lists the npm dependency tree used during the build

Download the SBOM files from a release:

```bash
gh release download <version> -R microsoft/hve-core -p '*.spdx.json'
```

Inspect the SBOM contents with `jq`:

```bash
# View a summary
jq '{version: .spdxVersion, name: .name, created: .creationInfo.created, packages: (.packages | length)}' hve-core-<version>.vsix.spdx.json

# List all packages and versions
jq '.packages[] | {name, versionInfo}' hve-core-<version>.vsix.spdx.json

# List package licenses
jq '.packages[] | {name, licenseConcluded, licenseDeclared}' hve-core-<version>.vsix.spdx.json
```

### What Gets Signed

| Artifact               | Channel         | Signed                |
|------------------------|-----------------|-----------------------|
| VSIX extension package | GitHub Releases | Yes                   |
| Per-extension SBOM     | GitHub Releases | Yes                   |
| Dependency SBOM        | GitHub Releases | Yes                   |
| Dependency diff        | GitHub Releases | No                    |
| VS Code Marketplace    | Stable          | Marketplace signature |
| VS Code Marketplace    | Pre-Release     | Marketplace signature |

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
