---
title: Extension Packaging Guide
description: Developer guide for packaging and publishing the HVE Core VS Code extension
author: Microsoft
ms.date: 2026-08-06
ms.topic: reference
---

This folder contains the VS Code extension configuration for HVE Core.

## Structure

```plaintext
extension/
├── .github/              # Tracked package sources staged temporarily
├── docs/templates/       # Explicit shared resources staged temporarily
├── package.json          # Generated hve-core extension manifest
├── templates/            # Source templates for package generation
├── .vscodeignore         # Controls what gets packaged into the .vsix
├── README.md             # Extension marketplace description
├── LICENSE               # Copy of root LICENSE
├── CHANGELOG.md          # Copy of root CHANGELOG
└── PACKAGING.md          # This file
```

## Extension Configuration

### Extension Kind

The extension is configured with `"extensionKind": ["workspace", "ui"]` in `package.json` to support multiple execution contexts:

* In workspace mode, the extension runs in the workspace (remote) extension host and accesses its bundled files from the extension installation directory in the remote/workspace context (for example, the packaged `.github/` folder).
* In UI mode, the extension runs in the UI extension host on the user's local machine and accesses the same bundled extension files from the local installation directory.

Access to files in the user's project workspace always uses the standard VS Code workspace APIs and is independent of the extension kind. Both modes use the same packaged extension assets and differ only in execution context (local UI versus remote/workspace). This bundling approach ensures GitHub Copilot can reliably access instruction files and scripts regardless of cross-platform path resolution issues (for example, Windows/WSL environments).

This is a declarative extension: it contributes configuration and file paths, and VS Code (together with the GitHub Copilot extension) resolves those paths based on the selected extension host and the extension installation location; it does not implement any custom runtime fallback mechanism between workspace and bundled files.

## Prerequisites

Install project dependencies (includes the VS Code Extension Manager CLI):

```bash
npm ci
```

Packaging scripts invoke the repository-pinned `vsce` executable. They do not
download or install a fallback version.

Install the PowerShell-Yaml module (required for Prepare-Extension.ps1):

```powershell
Install-Module -Name PowerShell-Yaml -RequiredVersion 0.4.7 -Scope CurrentUser
```

## Automated CI/CD Workflows

The extension is automatically packaged and published through GitHub Actions:

| Workflow                                               | Trigger                            | Purpose                                                     |
|--------------------------------------------------------|------------------------------------|-------------------------------------------------------------|
| `.github/workflows/extension-package.yml`              | Reusable workflow                  | Packages a source-explicit extension                        |
| `.github/workflows/release-prerelease-prepare.yml`     | Merged PR to `main`; dispatch      | Opens the reviewed `main` to PreRelease promotion           |
| `.github/workflows/release-prerelease.yml`             | Merged PR to `release/prerelease`  | Prepares or publishes the managed odd-minor PreRelease      |
| `.github/workflows/release-stable.yml`                 | Published PreRelease; dispatch     | Opens the reviewed PreRelease to Stable promotion           |
| `.github/workflows/release-stable-publish.yml`         | Merged PR to `release/stable`      | Prepares or publishes the managed even-minor Stable release |
| `.github/workflows/release-marketplace-stable.yml`     | Published Stable release; dispatch | Publishes the Stable VSIX to VS Code Marketplace            |
| `.github/workflows/release-marketplace-prerelease.yml` | Published PreRelease; dispatch     | Publishes the PreRelease VSIX to VS Code Marketplace        |

`release-prerelease-prepare.yml` opens the reviewed, target-based `main` to
`release/prerelease` promotion. Its merge creates no tag and runs
`release-prerelease.yml` in PR-only mode. Release-please owns the later managed
PR. Merging that exact managed head selects tag-only mode and creates the draft
odd-minor release at its merge commit.

The PreRelease workflow verifies event, merge, release-please, and tag SHA
equality plus `release/prerelease` ancestry. It packages from the immutable
release tag, attaches and attests `plugin-release-evidence.json` plus signed
plugin ZIP, SBOM, Sigstore, and in-toto assets, and publishes the prerelease
with a release GitHub App token. That event triggers PreRelease Marketplace
publication and the workflow opens a reviewed main catalog and changelog PR.

`release-stable.yml` starts from the published PreRelease event or a recovery
dispatch and opens the reviewed `release/prerelease` to `release/stable`
promotion. Its merge creates no tag and runs `release-stable-publish.yml` in
PR-only mode. Merging the later managed Stable PR creates the draft even-minor
release at its merge commit.

Stable performs the same identity and ancestry checks on `release/stable`,
packages from the release tag, attaches and attests the same canonical evidence
and signed package assets, and publishes the release with an App token. The
resulting event triggers Stable Marketplace publication. Stable does not
synchronize metadata back to `main`.

Release catalogs set every plugin entry to the exact
`hve-core-v<version>` ref and retain reviewed, release-gated, SBOM-covered,
attested, and immutable delivery. The ref-less main catalog sources canonical
`.github` content. After a marketplace refresh and plugin update, `#main`
resolves current main bytes without a release gate, SBOM, or attestation
covering those bytes. This is accepted development-channel behavior.

Future `plugins-v` snapshot publication has stopped. Existing `plugins-v` tags
and catalogs remain immutable and supported for historical installations.

For ordinary promotions, PreRelease reads `release/prerelease` and returns the
same major, minor plus two, and patch zero. Stable reads the promoted
PreRelease version and returns its major, its minor plus one, and patch zero.
The ordinary sequence is `3.3.101` to `3.5.0` to `3.6.0`. Current Stable state
only rejects a non-advancing candidate. Neither channel classifies commits or
automatically selects a patch, minor, or major release class. Matching plugin
packages use the identical channel version. A major-line transition or Stable
patch or hotfix needs a separate explicit manifest and release-state decision.

## Packaging Pipeline Overview

Extension packaging is a two-step process: **Prepare** resolves the `hve-core`
recipe into VS Code contributions, then **Package** stages its tracked files,
runs the pinned `vsce`, and cleans up.

```mermaid
flowchart LR
    subgraph Prepare["Step 1 · Prepare-Extension.ps1"]
        P1[Load marketplace.json] --> P2[Select hve-core]
        P2 --> P3[Apply Lifecycle Policy]
        P3 --> P4[Resolve Agent Handoff Closure]
        P4 --> P5[Write package.json]
    end

    subgraph Package["Step 2 · Package-Extension.ps1"]
        K1[Resolve Version] --> K2["Stage Tracked Package Files<br/>to extension/"]
        K2 --> K3[vsce package]
        K3 --> K4[Cleanup & Restore]
    end

    Prepare --> Package --> VSIX[".vsix"]
```

### Package Projection and Resolution

The prepare step reads `.github/plugin/marketplace.json`, selects `hve-core`,
maps its standard component paths to canonical `.github` sources, applies
lifecycle policy, and resolves transitive agent handoffs through
the shared marketplace projection.

```mermaid
flowchart TB
    CAT["Marketplace Catalog<br/>.github/plugin/marketplace.json"] --> PKG[Select hve-core]
    CH[Channel: Stable / PreRelease] --> PKG
    PKG --> RECIPE[Resolve Standard Membership]
    RECIPE --> AG[Agents]
    RECIPE --> PR[Commands to Prompts]
    RECIPE --> IN[Rules to Instructions]
    RECIPE --> SK[Skills]
    AG --> HD[Resolve Agent Handoff Closure]
    PR --> FINAL[Canonical Source Set]
    IN --> FINAL
    SK --> FINAL
    HD --> FINAL
    FINAL --> UPD["Write VS Code Contributions<br/>chatAgents · chatPromptFiles<br/>chatInstructions · chatSkills"]
```

## Packaging the Extension

### Using the Automated Scripts (Recommended)

#### Step 1: Prepare the Extension

First, generate the extension manifest from the marketplace recipe:

```bash
# Discover components and update package.json (Stable channel)
pwsh ./scripts/extension/Prepare-Extension.ps1

# Or use npm script
npm run extension:prepare

# For PreRelease channel
pwsh ./scripts/extension/Prepare-Extension.ps1 -Channel PreRelease

# Or use npm script
npm run extension:prepare:prerelease
```

The preparation script automatically:

* Reads identity, display name, membership, lifecycle maturity, and documentation
    from `.github/plugin/marketplace.json`
* Resolves canonical source paths and transitive agent handoffs through the
    shared marketplace helper
* Generates the one HVE Core extension manifest
* Writes HVE Core's VS Code contribution paths
* Uses the existing template version without modifying its source

When invoked via the npm scripts (`extension:prepare` and `extension:prepare:prerelease`), a postprocess step also runs after preparation, auto-fixing markdown formatting in `extension/**/*.md`:

* `markdownlint-cli2 --fix`
* `markdown-table-formatter`

Running `pwsh ./scripts/extension/Prepare-Extension.ps1` directly skips this postprocess step.

#### Step 2: Package the Extension

Then package the extension:

```bash
# Package using version from package.json (Stable channel)
pwsh ./scripts/extension/Package-Extension.ps1

# Or use npm script
npm run extension:package

# Package for PreRelease channel
pwsh ./scripts/extension/Package-Extension.ps1 -PreRelease

# Or use npm script
npm run extension:package:prerelease

# Package with specific version
pwsh ./scripts/extension/Package-Extension.ps1 -Version "1.0.3"

# Package with dev patch number (e.g., 1.0.2-dev.123)
pwsh ./scripts/extension/Package-Extension.ps1 -DevPatchNumber "123"

# Package with version and dev patch number
pwsh ./scripts/extension/Package-Extension.ps1 -Version "1.1.0" -DevPatchNumber "456"
```

The packaging script automatically:

* Uses version from `package.json` (or specified version)
* Optionally appends dev patch number for pre-release builds
* Stages only git-tracked files beneath prepared contribution paths
* Adds the explicit shared resources required by the package
* Packages the extension using `vsce`
* Cleans up temporary files and restores all modified files

```mermaid
flowchart TB
    PKG["package.json"] -->|"Read & validate"| VER[Resolve Version]
    VER --> TMPVER{"Version<br/>changed?"}
    TMPVER -->|Yes| WRITE["Temporarily update<br/>package.json version"]
    TMPVER -->|No| PREP
    WRITE --> PREP[Prepare Extension Directory]

    PREP --> STAGE["Stage git-tracked contribution files<br/>+ explicit shared resources"]
    STAGE --> CHECK[Validate Every Contribution Path]
    CHECK --> RDM[Select Generated Package README]
    RDM --> VSCE

    VSCE["vsce package --no-dependencies"] --> VSIX[".vsix output"]

    VSIX --> CLEAN["Finally: Cleanup"]
    CLEAN --> R1["Restore package.json.bak"]
    CLEAN --> R2[Restore README.md]
    CLEAN --> R3[Remove Staged Resources]
    CLEAN --> R4["Restore original version"]
```

## Publishing the Extension

**Important:** Stable versions are managed by release-please on
`release/stable`; PreRelease versions are managed independently on
`release/prerelease`. Both managed PRs synchronize the package, lockfile,
extension template, marketplace catalog, channel manifest, and changelog for
their exact version. Both channels package from the immutable
`hve-core-v<version>` release tag created at the managed PR merge commit.

### Setup Personal Access Token (one-time)

Set your Azure DevOps PAT as an environment variable:

```bash
export VSCE_PAT=your-token-here
```

To get a PAT from your Azure DevOps organization:

1. Open **User settings → Personal access tokens → New Token**
2. Set scope to **Marketplace (Manage)**
3. Copy the token

### Publish command

```bash
# Publish the packaged extension (replace X.Y.Z with actual version)
vsce publish --packagePath "extension/hve-core-X.Y.Z.vsix"

# Or use the latest .vsix file
VSIX_FILE=$(ls -t extension/hve-core-*.vsix | head -1)
vsce publish --packagePath "$VSIX_FILE"
```

## What Gets Included

The generated manifest and tracked staging allowlist control what gets packaged.
The archive can include:

* Declared `.github/agents/**` agent definitions
* Declared `.github/prompts/**` prompt templates
* Declared `.github/instructions/**` instruction files
* Declared `.github/skills/**` skill packages
* Explicit shared resources such as `docs/templates/**`
* `package.json` - Extension manifest
* `README.md` - Extension description
* `LICENSE` - License file
* `CHANGELOG.md` - Version history

## Testing Locally

Install the packaged extension locally:

```bash
code --install-extension hve-core-*.vsix
```

## Version Management

### How Versions Are Managed

The Stable channel manifest is `.release-please-manifest.json` on
`release/stable`. The PreRelease channel manifest is
`.release-please-prerelease-manifest.json` on `release/prerelease`.
Promotion preparation writes an exact `release-as` for the intended even-minor
or odd-minor version. Release-please consumes that intent in its managed PR,
and postprocessing removes it before merge.

Ordinary release allocation uses the channel formulas rather than commit
classification. PreRelease advances from its current branch version by two
minor values and resets patch to zero. Stable advances from the promoted
PreRelease version by one minor value and resets patch to zero; current Stable
state only guards against non-advancement. A major-line transition or Stable
patch or hotfix remains a separate explicit manifest and release-state
decision.

Each managed PR synchronizes `package.json`, `package-lock.json`,
`extension/templates/package.template.json`, `.github/plugin/marketplace.json`,
the channel manifest, and `CHANGELOG.md` on its release branch.
`Prepare-Extension.ps1` generates `extension/package.json` from the template
before artifact discovery, and release packaging supplies the verified release
version and release tag explicitly.

Generated package files are ephemeral build artifacts (gitignored). They are created and consumed by `Prepare-Extension.ps1` and `Package-Extension.ps1` at build time.

### Development Builds

For pre-release or CI builds, use the dev patch number:

```bash
# Creates version like 1.0.2-dev.123
pwsh ./scripts/extension/Package-Extension.ps1 -DevPatchNumber "123"
```

This temporarily modifies the version during packaging but restores it afterward.

### Override Version at Package Time

You can override the version without modifying `package.json`:

```bash
# Package as 1.1.0 without updating package.json
pwsh ./scripts/extension/Package-Extension.ps1 -Version "1.1.0"
```

## Pre-Release Channel

The extension supports dual-channel publishing to VS Code Marketplace with separate stable and pre-release tracks.

### Even/Odd Versioning Policy

| Minor Version     | Channel    | Example      | Active Lifecycle Labels             |
|-------------------|------------|--------------|-------------------------------------|
| EVEN (0, 2, 4...) | Stable     | 1.0.0, 1.2.0 | `stable`, `preview`, `experimental` |
| ODD (1, 3, 5...)  | PreRelease | 1.1.0, 1.3.0 | `stable`, `preview`, `experimental` |

Users can switch between channels in VS Code via the "Switch to Pre-Release Version" button on the extension page.

Odd/even minor parity is repository policy aligned with VS Code Marketplace
guidance and behavior, not a requirement of `MAJOR.MINOR.PATCH` syntax. VS Code
selects the highest available numeric extension version. Users opted into
PreRelease can temporarily receive a higher Stable version and remain eligible
for a later, higher PreRelease version.

### Pre-Release Packaging

Package for the pre-release channel with the `-PreRelease` switch:

```bash
# Prepare the PreRelease channel
pwsh ./scripts/extension/Prepare-Extension.ps1 -Channel PreRelease
# Or use npm script
npm run extension:prepare:prerelease

# Package for the PreRelease channel
pwsh ./scripts/extension/Package-Extension.ps1 -Version "1.1.0" -PreRelease
# Or use npm script for default version
npm run extension:package:prerelease
```

The `-PreRelease` switch adds `--pre-release` to the vsce command, marking the package for the Marketplace pre-release track.

### Pre-Release Workflow

Use the reviewed two-PR workflow for publishing pre-releases:

1. Review the target-based `main` to `release/prerelease` promotion PR from
    `release-promotion--main--to--release-prerelease`.
2. Confirm `PR Validation Success` passes and the exact intent is odd-minor.
3. Merge the promotion. It creates no tag and runs release-please in PR-only
    mode.
4. Review the managed PR from
    `release-please--branches--release/prerelease`, including synchronized
    version fields, changelog, manifest, and exact `hve-core-v<version>` plugin
    ref.
5. Merge the managed PR. Verify the draft `hve-core-v<version>` release targets
    that merge commit and the workflow proves target-branch ancestry.
6. Verify extension and plugin packaging use the release tag and attach signed
    plugin ZIPs, `plugin-release-evidence.json`, SBOM, Sigstore, and in-toto
    assets for the same release SHA.
7. Verify the release GitHub App token publishes the prerelease, triggers
    `Pre-Release Marketplace Publish`, and opens the reviewed main catalog and
    changelog PR.

### Lifecycle Disclosure

Stable and PreRelease package the same active component set. Lifecycle labels disclose support posture and are not channel filters:

| Lifecycle Label | Stable | PreRelease |
|-----------------|--------|------------|
| `stable`        | Yes    | Yes        |
| `preview`       | Yes    | Yes        |
| `experimental`  | Yes    | Yes        |
| `deprecated`    | No     | No         |
| `removed`       | No     | No         |

See [Marketplace Packages](../docs/contributing/ai-artifacts-common.md#marketplace-packages) for contributor guidance.

## Marketplace Build

`.github/plugin/marketplace.json` defines the `hve-core` identity, display name, membership, lifecycle labels, and documentation. `Get-MarketplacePackageMatrix.ps1` emits exactly that identity for either channel.

Prepare and package one ID directly:

```powershell
pwsh ./scripts/extension/Prepare-Extension.ps1 -PackageId hve-core -Channel Stable
pwsh ./scripts/extension/Package-Extension.ps1 -PackageId hve-core
```

Preparation consumes the shared handoff-resolved projection. Packaging stages
only git-tracked contribution paths plus explicit shared resources and invokes
the repository-pinned `vsce`. No retired manifest reader, full-tree copy, or
installer fallback is used.

Remote release, asset, workflow, and installed-client checks in this guide are
authorized manual actions. Local packaging and documentation checks do not
execute or verify them.

To add a distributable component, update the `hve-core` recipe and [HVE Core](../docs/plugins/hve-core.md), then run marketplace validation and both extension preparation channels.

## Notes

* Selected tracked source files and shared resources are staged temporarily and removed after packaging
* `LICENSE` and `CHANGELOG.md` are copied from root during packaging and excluded from git
* Only declared package files and explicit shared resources are included
* Repo-specific instructions at the root of `.github/instructions/` are excluded from all builds
* Non-essential files are excluded (workflows, issue templates, agent installer, etc.)
* The root `package.json` contains development scripts for the repository

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
