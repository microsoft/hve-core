---
title: Extension Packaging Guide
description: Developer guide for packaging and publishing the HVE Core VS Code extension
author: Microsoft
ms.date: 2026-02-10
ms.topic: reference
---

This folder contains the VS Code extension configuration for HVE Core.

## Structure

```plaintext
extension/
├── .github/              # Temporarily copied during packaging (removed after)
├── docs/templates/       # Temporarily copied during packaging (removed after)
├── scripts/dev-tools/    # Temporarily copied during packaging (removed after)
├── package.json          # Extension manifest with VS Code configuration
├── .vscodeignore         # Controls what gets packaged into the .vsix
├── README.md             # Extension marketplace description
├── LICENSE               # Copy of root LICENSE
├── CHANGELOG.md          # Copy of root CHANGELOG
└── PACKAGING.md          # This file
```

## Extension Configuration

### Extension Kind

The extension is configured with `"extensionKind": ["workspace", "ui"]` in `package.json` to support multiple execution contexts:

* **Workspace mode**: Extension runs in the workspace (remote) extension host. In this mode, the extension accesses its bundled files from the extension installation directory in the remote/workspace context (for example, the packaged `.github/` and `scripts/dev-tools/` folders).
* **UI mode**: Extension runs in the UI extension host on the user's local machine and accesses the same bundled extension files from the local installation directory.

Access to files in the user's project workspace always uses the standard VS Code workspace APIs and is independent of the extension kind. Both modes use the same packaged extension assets and differ only in execution context (local UI versus remote/workspace). This bundling approach ensures GitHub Copilot can reliably access instruction files and scripts regardless of cross-platform path resolution issues (for example, Windows/WSL environments).

This is a declarative extension: it contributes configuration and file paths, and VS Code (together with the GitHub Copilot extension) resolves those paths based on the selected extension host and the extension installation location; it does not implement any custom runtime fallback mechanism between workspace and bundled files.

## Prerequisites

Install the VS Code Extension Manager CLI:

```bash
npm install -g @vscode/vsce
```

Install the PowerShell-Yaml module (required for Prepare-Extension.ps1):

```powershell
Install-Module -Name PowerShell-Yaml -Scope CurrentUser
```

## Automated CI/CD Workflows

The extension is automatically packaged and published through GitHub Actions:

| Workflow                                  | Trigger           | Purpose                                     |
|-------------------------------------------|-------------------|---------------------------------------------|
| `.github/workflows/extension-package.yml` | Reusable workflow | Packages extension with flexible versioning |
| `.github/workflows/extension-publish.yml` | Release/manual    | Publishes to VS Code Marketplace            |
| `.github/workflows/main.yml`              | Push to main      | Includes extension packaging in CI          |

## Packaging Pipeline Overview

Extension packaging is a two-step process: **Prepare** discovers and filters artifacts into `package.json`, then **Package** copies files, runs `vsce`, and cleans up.

```mermaid
flowchart LR
    subgraph Prepare["Step 1 · Prepare-Extension.ps1"]
        P1[Load Registry] --> P2[Discover Artifacts]
        P2 --> P3["Filter by Maturity<br/>+ Collection"]
        P3 --> P4[Resolve Dependencies]
        P4 --> P5[Write package.json]
    end

    subgraph Package["Step 2 · Package-Extension.ps1"]
        K1[Resolve Version] --> K2["Copy Assets<br/>to extension/"]
        K2 --> K3[vsce package]
        K3 --> K4[Cleanup & Restore]
    end

    Prepare --> Package --> VSIX[".vsix"]
```

### Artifact Discovery and Resolution

The prepare step discovers all artifact files on disk, filters them through the registry, and optionally narrows the set to a specific persona collection. Dependency resolution ensures transitive handoff and requires references pull in all needed artifacts.

```mermaid
flowchart TB
    REG[ai-artifacts-registry.json] -->|Get-RegistryData| INPUTS
    CH[Channel: Stable / PreRelease] -->|Get-AllowedMaturities| INPUTS
    CM["Collection Manifest<br/>optional"] -->|Get-CollectionManifest| INPUTS

    INPUTS[Resolve Inputs] --> DISC[Discover Artifact Files from .github/]

    DISC --> AG["Agents<br/>.github/agents/*.agent.md"]
    DISC --> PR["Prompts<br/>.github/prompts/*.prompt.md"]
    DISC --> IN["Instructions<br/>.github/instructions/*.instructions.md"]
    DISC --> SK["Skills<br/>.github/skills/*/SKILL.md"]

    AG -->|Filter by maturity| FM[Maturity-Filtered Set]
    PR -->|Filter by maturity| FM
    IN -->|"Filter by maturity<br/>+ exclude hve-core/"| FM
    SK -->|Filter by maturity| FM

    FM --> CF{"Collection<br/>specified?"}
    CF -->|No| FINAL[Final Artifact Set]
    CF -->|Yes| PA["Filter by persona + globs<br/>Get-CollectionArtifacts"]
    PA --> HD["Resolve Handoff Closure<br/>BFS through agent frontmatter"]
    HD --> RD["Resolve Requires Dependencies<br/>BFS through registry requires"]
    RD --> INT["Intersect with<br/>discovered artifacts"]
    INT --> FINAL

    FINAL --> UPD["Update package.json contributes<br/>chatAgents · chatPromptFiles<br/>chatInstructions · chatSkills"]
```

## Packaging the Extension

### Using the Automated Scripts (Recommended)

#### Step 1: Prepare the Extension

First, update `package.json` with discovered agents, prompts, and instructions:

```bash
# Discover components and update package.json (Stable channel)
pwsh ./scripts/extension/Prepare-Extension.ps1

# Or use npm script
npm run extension:prepare

# For PreRelease channel (includes preview and experimental artifacts)
pwsh ./scripts/extension/Prepare-Extension.ps1 -Channel PreRelease

# Or use npm script
npm run extension:prepare:prerelease
```

The preparation script automatically:

* Discovers and registers all chat agents from `.github/agents/`
* Discovers and registers all prompts from `.github/prompts/`
* Discovers and registers all instruction files from `.github/instructions/`
* Updates `package.json` with discovered components
* Uses existing version from `package.json` (does not modify it)

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
* Copies required directories into `extension/` (or only filtered artifacts in collection mode)
* Packages the extension using `vsce`
* Cleans up temporary files and restores all modified files

```mermaid
flowchart TB
    PKG["package.json"] -->|"Read & validate"| VER[Resolve Version]
    VER --> TMPVER{"Version<br/>changed?"}
    TMPVER -->|Yes| WRITE["Temporarily update<br/>package.json version"]
    TMPVER -->|No| PREP
    WRITE --> PREP[Prepare Extension Directory]

    PREP --> MODE{"Collection<br/>mode?"}
    MODE -->|"Full (default)"| FULL["Copy entire .github/<br/>+ scripts/dev-tools/<br/>+ scripts/lib/Modules/CIHelpers.psm1<br/>+ docs/templates/<br/>+ .github/skills/"]
    MODE -->|Collection| COLL["Copy only artifacts listed<br/>in package.json contributes<br/>+ scripts/dev-tools/<br/>+ scripts/lib/Modules/CIHelpers.psm1<br/>+ docs/templates/"]

    FULL --> RDM{"Persona<br/>README?"}
    COLL --> RDM
    RDM -->|Yes| SWAP["Swap README.md<br/>with README.{id}.md"]
    RDM -->|No| VSCE
    SWAP --> VSCE

    VSCE["vsce package --no-dependencies"] --> VSIX[".vsix output"]

    VSIX --> CLEAN["Finally: Cleanup"]
    CLEAN --> R1["Restore package.json.bak"]
    CLEAN --> R2["Restore README.md.bak"]
    CLEAN --> R3["Remove .github/ docs/ scripts/"]
    CLEAN --> R4["Restore original version"]
```

### Manual Packaging (Legacy)

If you need to package manually:

```bash
cd extension
rm -rf .github scripts && cp -r ../.github . && mkdir -p scripts && cp -r ../scripts/dev-tools scripts/ && vsce package && rm -rf .github scripts
```

## Publishing the Extension

**Important:** Update version in `extension/package.json` before publishing.

**Setup Personal Access Token (one-time):**

Set your Azure DevOps PAT as an environment variable:

```bash
export VSCE_PAT=your-token-here
```

To get a PAT:

1. Go to <https://dev.azure.com>
2. User settings → Personal access tokens → New Token
3. Set scope to **Marketplace (Manage)**
4. Copy the token

**Publish command:**

```bash
# Publish the packaged extension (replace X.Y.Z with actual version)
vsce publish --packagePath "extension/hve-core-X.Y.Z.vsix"

# Or use the latest .vsix file
VSIX_FILE=$(ls -t extension/hve-core-*.vsix | head -1)
vsce publish --packagePath "$VSIX_FILE"
```

## What Gets Included

The `extension/.vscodeignore` file controls what gets packaged. Currently included:

* `.github/agents/**` - All custom agent definitions
* `.github/prompts/**` - All prompt templates
* `.github/instructions/**` - All instruction files
* `docs/templates/**` - Document templates used by agents (ADR, BRD, Security Plan)
* `scripts/dev-tools/**` - Developer utilities (PR reference generation)
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

### Update Version in `package.json`

1. Manually update version in `extension/package.json`
2. Run `scripts/extension/Prepare-Extension.ps1` to update agents/prompts/instructions
3. Run `scripts/extension/Package-Extension.ps1` to create the `.vsix` file

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

### EVEN/ODD Versioning Strategy

| Minor Version     | Channel     | Example      | Agent Maturity Included             |
|-------------------|-------------|--------------|-------------------------------------|
| EVEN (0, 2, 4...) | Stable      | 1.0.0, 1.2.0 | `stable` only                       |
| ODD (1, 3, 5...)  | Pre-Release | 1.1.0, 1.3.0 | `stable`, `preview`, `experimental` |

Users can switch between channels in VS Code via the "Switch to Pre-Release Version" button on the extension page.

### Pre-Release Packaging

Package for the pre-release channel with the `-PreRelease` switch:

```bash
# Prepare with PreRelease channel filtering
pwsh ./scripts/extension/Prepare-Extension.ps1 -Channel PreRelease
# Or use npm script
npm run extension:prepare:prerelease

# Package for pre-release channel (includes experimental agents)
pwsh ./scripts/extension/Package-Extension.ps1 -Version "1.1.0" -PreRelease
# Or use npm script for default version
npm run extension:package:prerelease
```

The `-PreRelease` switch adds `--pre-release` to the vsce command, marking the package for the Marketplace pre-release track.

### Pre-Release Workflow

Use the manual workflow for publishing pre-releases:

1. Go to **Actions** > **Publish Pre-Release Extension**
2. Enter an ODD minor version (e.g., `1.1.0`, `1.3.0`)
3. Optionally enable dry-run to test packaging without publishing
4. Run the workflow

The workflow validates the version is ODD before proceeding.

### Agent Maturity Filtering

When packaging, artifacts are filtered by their `maturity` field in `.github/ai-artifacts-registry.json`:

| Channel    | Included Maturity Levels            |
|------------|-------------------------------------|
| Stable     | `stable`                            |
| PreRelease | `stable`, `preview`, `experimental` |

See [Agent Maturity Levels](../docs/contributing/ai-artifacts-common.md#maturity-field-requirements) for contributor guidance on setting maturity levels.

## Collection-Based Packaging

The extension supports building persona-specific collection packages from a single codebase.

### Available Collections

Collection manifests are defined in `extension/collections/`:

| Collection | Manifest                       | Description                            |
|------------|--------------------------------|----------------------------------------|
| Full       | `hve-core-all.collection.json` | All artifacts regardless of persona    |
| Developer  | `developer.collection.json`    | Software engineering focused artifacts |

### Persona Template Files

Each persona collection has a corresponding `package.{collection-id}.json` template file in `extension/`. These files contain static metadata (name, display name, description, publisher) for the persona edition. The `contributes` section is empty because `Prepare-Extension.ps1` populates it dynamically at build time.

| Template                 | Collection | Purpose                           |
| ------------------------ | ---------- | --------------------------------- |
| `package.json`           | Full       | Canonical manifest (hve-core-all) |
| `package.developer.json` | Developer  | Developer edition metadata        |

The canonical `extension/package.json` serves double duty: it is both the default build target and the `hve-core-all` template. No separate `package.hve-core-all.json` file exists.

When building a persona collection, `Prepare-Extension.ps1`:

1. Backs up `package.json` to `package.json.bak`
2. Copies the persona template (`package.developer.json`) over `package.json`
3. Generates `contributes` into the copied file
4. Serializes the result as `package.json`

After packaging, `Package-Extension.ps1` restores the canonical `package.json` from backup in its `finally` block.

#### Version Synchronization

Template files contain a `version` field managed by `release-please`. The `release-please-config.json` file includes `extra-files` entries for each template, ensuring versions stay synchronized across all persona templates and the canonical `package.json`.

### Building Collection Packages

To build a specific collection package:

```bash
# Build the full collection (default, no template copy)
pwsh ./scripts/extension/Prepare-Extension.ps1
pwsh ./scripts/extension/Package-Extension.ps1

# Build a persona-specific collection (copies persona template)
pwsh ./scripts/extension/Prepare-Extension.ps1 -Collection extension/collections/developer.collection.json
pwsh ./scripts/extension/Package-Extension.ps1 -Collection extension/collections/developer.collection.json
```

When `-Collection` targets a persona other than `hve-core-all`, the prepare script copies the persona template to `package.json` before generating `contributes`. The packaging script restores the canonical `package.json` after building.

### Inner Dev Loop

For rapid iteration without running the full build pipeline, copy the persona template manually:

```bash
# 1. Copy the developer template
cp extension/package.developer.json extension/package.json

# 2. Run prepare to generate contributes
pwsh ./scripts/extension/Prepare-Extension.ps1 -Collection extension/collections/developer.collection.json

# 3. Inspect the result
cat extension/package.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['name'], len(d.get('contributes',{}).get('chatAgents',[])),'agents')"

# 4. Restore canonical package.json
git checkout extension/package.json
```

The template file stays clean. Use `git checkout extension/package.json` to restore the canonical state at any time.

### Collection Resolution

When building a collection, the system applies a multi-stage filter pipeline: persona matching, maturity gating, optional glob patterns, and two rounds of dependency resolution.

```mermaid
flowchart TB
    REG["Registry Entry<br/>personas · maturity · requires"] --> PF{"Persona match?<br/>empty personas = universal"}
    CM["Collection Manifest<br/>personas array"] --> PF
    CH["Channel<br/>Stable / PreRelease"] --> MF

    PF -->|Yes| MF{"Maturity<br/>allowed?"}
    PF -->|No| EXCLUDE[Excluded]

    MF -->|Yes| GLOB{"Passes include/exclude<br/>glob filter?"}
    MF -->|No| EXCLUDE

    GLOB -->|Yes| SEED[Seed Artifact]
    GLOB -->|No| EXCLUDE

    SEED --> HANDOFF["Resolve Handoff Closure<br/>BFS through agent frontmatter<br/>handoff targets bypass maturity filter"]
    HANDOFF --> REQUIRES["Resolve Requires Dependencies<br/>BFS through registry requires blocks<br/>across agents · prompts · instructions · skills"]
    REQUIRES --> FINAL[Final Collection Artifact Set]
```

Key behaviors:

* Artifacts with an empty `personas` array are universal and included in every collection
* Handoff targets bypass maturity filtering by design (an agent must be able to hand off to its declared targets)
* The `requires` block supports transitive resolution: if agent A requires agent B, and B requires instruction C, all three are included
* Optional `include` and `exclude` glob arrays in the collection manifest provide fine-grained control per artifact type

### Testing Collection Builds Locally

To verify artifact inclusion before publishing:

```bash
# 1. Prepare with collection filtering
pwsh ./scripts/extension/Prepare-Extension.ps1 -Collection extension/collections/developer.collection.json -Verbose

# 2. Check package.json for included artifacts
cat extension/package.json | jq '.contributes.chatAgents'

# 3. Validate the registry
npm run lint:registry

# 4. Build the package (dry run)
pwsh ./scripts/extension/Package-Extension.ps1 -Version "1.0.0-test" -WhatIf
```

### Troubleshooting Collection Builds

**Missing artifacts in collection:**

1. Verify the artifact has a registry entry in `.github/ai-artifacts-registry.json`
2. Check the `personas` array includes the collection's persona or `hve-core-all`
3. Run `npm run lint:registry` to validate registry consistency

**Dependency not included:**

1. Check the parent artifact's `requires` field in the registry
2. Ensure dependent artifacts exist and have valid registry entries
3. Dependencies are included regardless of persona filter

**Validation errors:**

```bash
# Run full registry validation
npm run lint:registry

# Check for orphaned artifacts (in registry but no file)
npm run lint:registry -- --verbose
```

### Collection Manifest Schema

Collection manifests follow this structure:

```json
{
    "$schema": "../../scripts/linting/schemas/collection.schema.json",
    "id": "developer",
    "name": "hve-developer",
    "displayName": "HVE Core - Developer Edition",
    "description": "AI-powered coding agents curated for software engineers",
    "maturity": "stable",
    "personas": ["developer"]
}
```

| Field         | Required | Description                                                           |
|---------------|----------|-----------------------------------------------------------------------|
| `id`          | Yes      | Unique identifier for the collection                                  |
| `name`        | Yes      | Extension package name                                                |
| `displayName` | Yes      | Marketplace display name                                              |
| `description` | Yes      | Marketplace description text                                          |
| `maturity`    | No       | Release channel eligibility (`stable`, `preview`, `experimental`, `deprecated`). Defaults to `stable` |
| `personas`    | Yes      | Array of persona identifiers to include                               |

#### Collection Maturity and Channel Eligibility

The `maturity` field controls which release channels include the collection:

| Collection Maturity | PreRelease Channel | Stable Channel |
| ------------------- | ------------------ | -------------- |
| `stable`            | Yes                | Yes            |
| `preview`           | Yes                | Yes            |
| `experimental`      | Yes                | No             |
| `deprecated`        | No                 | No             |

Collection-level maturity is independent of artifact-level maturity. A `stable` collection can contain `preview` artifacts, which are filtered by the existing artifact-level channel logic. The collection maturity gates the entire package, while artifact maturity gates individual files within it.

Omitting the `maturity` field defaults to `stable`, maintaining backward compatibility with existing manifests.

### Adding New Collections

To create a new persona collection:

1. Create a new manifest in `extension/collections/`:

    ```json
    {
        "$schema": "../../scripts/linting/schemas/collection.schema.json",
        "id": "my-persona",
        "name": "hve-my-persona",
        "displayName": "HVE Core - My Persona Edition",
        "description": "Description of artifacts included for this persona",
        "maturity": "experimental",
        "personas": ["my-persona"]
    }
    ```

2. Add the persona to the registry's `personas` section
3. Tag relevant artifacts with the new persona in the registry
4. Test the build locally with `-Collection my-persona`
5. Submit PR with the new collection manifest

> [!TIP]
> New collections should start with `"maturity": "experimental"` until validated. Change to `"stable"` when the collection is ready for production.

## Notes

* The `.github`, `docs/templates`, and `scripts/dev-tools` folders are temporarily copied during packaging (not permanently stored)
* `LICENSE` and `CHANGELOG.md` are copied from root during packaging and excluded from git
* Only essential extension files are included (agents, prompts, instructions, templates, dev-tools)
* Repo-specific instructions under `.github/instructions/hve-core/` are excluded from all builds
* Non-essential files are excluded (workflows, issue templates, agent installer, etc.)
* The root `package.json` contains development scripts for the repository

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
