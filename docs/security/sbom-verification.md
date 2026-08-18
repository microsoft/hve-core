---
title: SBOM Verification
description: Verify, download, and inspect the Software Bill of Materials published with each HVE Core release
sidebar_position: 3
author: Microsoft
ms.date: 2026-08-13
ms.topic: how-to
keywords:
  - SBOM
  - software bill of materials
  - SPDX
  - attestation
  - Sigstore
  - supply chain
  - verification
estimated_reading_time: 5
---

Stable and PreRelease HVE Core releases publish Software Bill of Materials
(SBOM) files in SPDX 2.3 JSON format. The per-artifact SBOM describes the VSIX.
`dependencies.spdx.json` describes the dependency tree used during
the build.

## What Gets Published

Each channel release publishes:

| Asset                               | Channel               | Attestation topology                 |
|-------------------------------------|-----------------------|--------------------------------------|
| `hve-core-<version>.vsix.spdx.json` | Stable and PreRelease | SPDX predicate over the VSIX subject |
| `dependencies.spdx.json`            | Stable and PreRelease | SPDX predicate over the VSIX subject |
| `hve-core.openvex.json`             | Stable only           | Separate VEX subject attestation     |

The SBOM files are predicate payloads in the channel package workflows. They
are not independently attested SPDX subjects. Stable additionally uses
`dependencies.spdx.json` as the subject of an OpenVEX predicate.

## Verifying the SBOM Attestation

SBOM attestation verification uses the GitHub CLI. Install it if you have not already:

```bash
# Windows (winget)
winget install GitHub.cli

# macOS (Homebrew)
brew install gh
```

Download assets from the exact channel tag:

```bash
# PreRelease
gh release download prerelease-v<version> -R microsoft/hve-core \
  -p '*.vsix' -p '*.vsix.spdx.json' -p 'dependencies.spdx.json'

# Stable
gh release download v<version> -R microsoft/hve-core \
  -p '*.vsix' -p '*.vsix.spdx.json' -p 'dependencies.spdx.json'
```

Verify SPDX predicates through their primary artifact subjects:

```bash
# Stable VSIX
gh attestation verify hve-core-<version>.vsix -R microsoft/hve-core \
  --signer-workflow microsoft/hve-core/.github/workflows/extension-provenance.yml \
  --predicate-type https://spdx.dev/Document/v2.3

# PreRelease VSIX
gh attestation verify hve-core-<version>.vsix -R microsoft/hve-core \
  --signer-workflow microsoft/hve-core/.github/workflows/extension-provenance.yml \
  --predicate-type https://spdx.dev/Document/v2.3

```

These commands can match both the per-artifact and dependency SBOM
attestations because both use the SPDX 2.3 predicate type. Inspect the returned
attestation statements when you need to distinguish the predicate payloads.

Do not verify `dependencies.spdx.json` as an SPDX subject. On both channels it
is an SPDX predicate payload over the VSIX subject. Stable also
uses it as a subject for an OpenVEX predicate; PreRelease does not.

A successful verification confirms:

* An SPDX predicate was attached to the selected primary artifact
* The predicate was produced by the specified channel workflow
* The attestation has not been modified since signing

> [!TIP]
> Build provenance and SPDX predicates are independent attestations. Omit
> `--predicate-type` to verify build provenance. Use
> `https://spdx.dev/Document/v2.3` to match SPDX predicates.

## Downloading and Inspecting

Inspect a downloaded per-artifact SBOM:

```bash
jq '{
  version: .spdxVersion,
  name: .name,
  created: .creationInfo.created,
  packages: (.packages | length)
}' hve-core-<version>.vsix.spdx.json

# Package list with versions
jq '.packages[] | {name, versionInfo}' hve-core-<version>.vsix.spdx.json

# License information
jq '.packages[] | {name, licenseConcluded, licenseDeclared}' hve-core-<version>.vsix.spdx.json
```

Inspect `dependencies.spdx.json` as data while verifying its SPDX content
through the primary VSIX subject:

```bash
jq '{
  version: .spdxVersion,
  name: .name,
  created: .creationInfo.created,
  packages: (.packages | length)
}' dependencies.spdx.json
```

## Key SPDX Fields

The SBOM follows the SPDX 2.3 specification. These fields are most relevant for security and compliance review:

| Field              | Description                                          |
|--------------------|------------------------------------------------------|
| `spdxVersion`      | Specification version (SPDX-2.3)                     |
| `name`             | Document name identifying the scanned artifact       |
| `creationInfo`     | Timestamp and tool that generated the document       |
| `packages`         | Array of components with name, version, and supplier |
| `licenseConcluded` | License determined through analysis                  |
| `licenseDeclared`  | License stated by the package author                 |
| `relationships`    | Dependency graph between components                  |

## Consuming the SBOM

You can feed the SPDX JSON file into security and compliance tooling:

| Use Case               | Description                                                                                                                   |
|------------------------|-------------------------------------------------------------------------------------------------------------------------------|
| Vulnerability scanning | Import into tools like Grype, Trivy, or Dependabot to check for known CVEs in bundled components.                             |
| License compliance     | Parse `licenseConcluded` and `licenseDeclared` fields to validate that all included licenses meet your organization's policy. |
| Inventory tracking     | Use the package list to maintain an accurate record of third-party components in your environment.                            |

## Related Resources

* [SECURITY.md](https://github.com/microsoft/hve-core/blob/main/SECURITY.md): Build provenance verification and vulnerability reporting
* [Security Model](security-model.md): Security controls including SBOM attestation (SC-7)

---

🤖 *Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
