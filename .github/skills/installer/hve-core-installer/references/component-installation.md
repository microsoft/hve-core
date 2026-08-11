---
title: Component Installation and Upgrade
description: Phase 7 component installation and the Phase 7 upgrade mode for the hve-core installer.
---
<!-- markdownlint-disable-file -->

## Phase 7: Component Installation (Optional)

> [!IMPORTANT]
> Generated scripts in this phase require PowerShell 7+ (`pwsh`). Windows PowerShell 5.1 is not supported. The Bash scripts require `jq`.

After Phase 6 completes, offer users the option to copy HVE-Core components into their target repository. This phase ONLY applies to clone-based installation methods (1-6), NOT to extension installation.

A component is one agent, prompt, instruction, or complete skill declared by exactly one package recipe in `.github/plugin/marketplace.json`. Every Phase 7 operation resolves against a single selected package, so the package is chosen before any profile or component. Component paths use marketplace form and map to canonical target paths without flattening:

<!-- <component-kind-map> -->
| Component path                           | Target path                                                          |
|------------------------------------------|----------------------------------------------------------------------|
| `agents/<subpath>/<name>.md`             | `<TargetRoot>/.github/agents/<subpath>/<name>.agent.md`              |
| `commands/<subpath>/<name>.md`           | `<TargetRoot>/.github/prompts/<subpath>/<name>.prompt.md`            |
| `rules/<subpath>/<name>.instructions.md` | `<TargetRoot>/.github/instructions/<subpath>/<name>.instructions.md` |
| `skills/<subpath>/<name>`                | `<TargetRoot>/.github/skills/<subpath>/<name>` (whole directory)     |
<!-- </component-kind-map> -->

Hooks are never copied by this phase. Skills copy as complete directories, minus local environment and cache directories (`tests`, `.venv`, `.hypothesis`, `node_modules`, `__pycache__`, `.ruff_cache`, `.pytest_cache`).

### Skip Condition

If user selected **Extension Quick Install** (Option 1) in Phase 2, skip Phase 7 entirely. Extension installation bundles all components automatically.

### Package Selection

Before any profile or component resolution, read `.github/plugin/marketplace.json` from the HVE-Core source at `$hveCoreBasePath` and present every `plugins[].name` with its `x-hve.displayName`. The user selects exactly one package name, recorded as `$selectedPackage`.

<!-- <package-selection-prompt> -->
```text
📦 Package Selection (required)

HVE-Core publishes several packages. Component installation resolves against one.

  • hve-core-all — every package component, and the only package declaring the starter profile
  • hve-core — the focused core package
  • [remaining catalog package names with display names]

Which package? (exact name)
```
<!-- </package-selection-prompt> -->

Match the response against catalog names exactly. Reject a name that is absent from the catalog, matches more than one entry, or is a guess, and re-prompt; never substitute a default package. Reject a later component that is not declared membership of `$selectedPackage`, and offer either a different component or a package reselection. Both rejections happen before collision detection and before the first write, matching the same failures the copy scripts raise.

### Checkpoint 6: Component Selection

Present the component selection prompt:

<!-- <component-selection-prompt> -->
```text
📂 Component Installation (Optional)

HVE-Core publishes agents, prompts, instructions, and skills.
Copying them into your repository enables local customization and offline use.

🔬 Starter profile (24 components, package hve-core-all)
  • RPI Agent, Documentation, and the RPI and HVE Builder subagents
  • RPI skills: research, plan, plan-critique, implement, review, walkthrough, quick, challenger
  • HVE Builder skills: builder, builder-tester, prompt-analyze, prompt-builder, prompt-refactor, vally-tests
  • Documentation skill, the /rpi prompt, and the tracking and builder instructions

Options:
  [1] Install the starter profile from hve-core-all (recommended)
  [2] Choose components from [selected package]
  [3] Skip component installation

Your choice? (1/2/3)
```
<!-- </component-selection-prompt> -->

User input handling:

* "1", "starter", "core", "recommended" → Set `$selectedPackage` to `hve-core-all` and resolve the `starter` profile
* "2", "choose", "custom", "components" → Proceed to the Custom Selection sub-flow
* "3", "skip", "none", "no" → Skip to the final success report
* Unclear response → Ask for clarification

### Custom Selection Sub-Flow

When the user selects option 2, read `.github/plugin/marketplace.json` from the HVE-Core source at `$hveCoreBasePath` and present the `$selectedPackage` entry's components grouped by kind. Show each component's `x-hve.componentMaturity` label from that entry, defaulting to `stable` when the entry declares none. Collect the user's component paths in marketplace form and reject any path outside that entry before resolution.

### Selection Resolution

Resolve the chosen profile or component list before any confirmation or write. Run the resolver from the HVE-Core clone:

<!-- <selection-resolution> -->
```powershell
Import-Module "$hveCoreBasePath/scripts/lib/Modules/MarketplaceHelpers.psm1" -Force
$catalog = Get-MarketplaceCatalog -Path "$hveCoreBasePath/.github/plugin/marketplace.json"
$entry = @($catalog['plugins']) | Where-Object { $_['name'] -eq $selectedPackage }
$agentIndex = Get-MarketplaceAgentIndex -Catalog $catalog -RepoRoot $hveCoreBasePath

# Only hve-core-all declares the starter profile; resolve it with $selectedPackage = 'hve-core-all'.
$selection = Resolve-MarketplaceComponentSelection -Entry $entry -RepoRoot $hveCoreBasePath -AgentIndex $agentIndex -ProfileName 'starter'

# Or an explicit selection
$selection = Resolve-MarketplaceComponentSelection -Entry $entry -RepoRoot $hveCoreBasePath -AgentIndex $agentIndex -Component $chosenComponents
```
<!-- </selection-resolution> -->

The resolver requires the `PowerShell-Yaml` module. If the import fails, tell the user to run `Install-Module PowerShell-Yaml -Scope CurrentUser` and retry.

Each resolved record carries `PackagePath`, `Kind`, `SourcePath`, `Maturity`, and `Origin`. `Origin` is `selected` for a chosen component and `dependency` for a component added by agent handoff closure or a literal `#file:` reference. The resolver fails when a selection is not membership of the selected package's recipe, when that package declares no such profile, or when a visible dependency does not resolve inside the same recipe.

### Collision Detection

Run the pre-write check with the resolved component list. It validates every path, reports canonical maturity, and reports component-level collisions. A file component collides on its full target path; a skill component collides on its target directory. Nothing is written.

**PowerShell:** Run [scripts/collision-detection.ps1](../scripts/collision-detection.ps1) with `-HveCoreBasePath`, `-TargetRoot`, `-PackageName` (`$selectedPackage`), and `-Component`.

**Bash:** Run [scripts/collision-detection.sh](../scripts/collision-detection.sh) with the HVE-Core base path, target root, package name, and component paths as arguments, in that order.

Output lines:

<!-- <collision-detection-output> -->
```text
COMPONENT=<path>|KIND=<kind>|MATURITY=<maturity>|TARGET=<target-relative path>|EXISTS=<true|false>
COLLISIONS_DETECTED=<true|false>
COLLISION_COMPONENTS=<comma-separated component paths>
COLLISION_TARGETS=<comma-separated target-relative paths>
```
<!-- </collision-detection-output> -->

### Confirmation Prompt

Present every selected and dependency-added component with its maturity before any write. Call out non-stable components explicitly.

<!-- <component-confirmation-prompt> -->
```text
📋 Components to install

| Component        | Kind   | Maturity   | Added by   |
|------------------|--------|------------|------------|
| [component path] | [kind] | [maturity] | selected   |
| [component path] | [kind] | [maturity] | dependency |

⚠️ [N] component(s) are labeled preview or experimental. They may change or be
   removed without notice.

Proceed with installation? (yes/no)
```
<!-- </component-confirmation-prompt> -->

User input handling:

* "yes", "y" → Continue to collision resolution when collisions exist, otherwise run the copy
* "no", "n" → Return to Checkpoint 6 without writing anything
* Unclear response → Ask for clarification

### Collision Resolution Prompt

If collisions are detected, present:

<!-- <collision-prompt> -->
```text
⚠️ Existing Components Detected

The following components already exist in your project:
  • [list COLLISION_COMPONENTS with their COLLISION_TARGETS]

Options:
  [O] Overwrite with the HVE-Core version
  [K] Keep existing (skip these components)
  [C] Compare (show diff for the first file)

Or for all conflicts:
  [OA] Overwrite all
  [KA] Keep all existing

Your choice?
```
<!-- </collision-prompt> -->

User input handling:

* "o", "overwrite" → Overwrite the current component, ask about the next
* "k", "keep" → Keep the current component, ask about the next
* "c", "compare" → Show diff, then re-prompt
* "oa", "overwrite all" → Overwrite every collision
* "ka", "keep all" → Keep every existing component

Keeping a skill keeps its whole target directory.

### Component Copy Execution

After confirmation and collision resolution, execute the copy.

**PowerShell:** Run [scripts/component-copy.ps1](../scripts/component-copy.ps1) with `-HveCoreBasePath`, `-TargetRoot`, `-PackageName` (`$selectedPackage`), `-SelectionName` (`starter` or `custom`), and `-Component`. Add `-KeepExisting -Collisions <component paths>` for kept components.

**Bash:** Run [scripts/component-copy.sh](../scripts/component-copy.sh) with the HVE-Core base path, target root, package name, selection name, and component paths as arguments, in that order. Set `KEEP_EXISTING=true` and `COLLISIONS_FILE=<newline-delimited component paths>` for kept components.

Both implementations validate membership, path safety, and the existing manifest schema before the first write, and produce equivalent paths, hashes, manifests, and output.

### Tracking Manifest

The copy writes `.hve-tracking.json` at the target root using schema version 2:

<!-- <tracking-manifest> -->
```json
{
  "schemaVersion": 2,
  "source": "microsoft/hve-core",
  "version": "3.3.106",
  "installed": "2026-08-02T00:00:00Z",
  "selection": {
    "package": "hve-core-all",
    "profile": "starter",
    "components": ["agents/hve-core/rpi-agent.md", "skills/rpi/rpi-plan"]
  },
  "files": {
    ".github/agents/hve-core/rpi-agent.agent.md": {
      "component": "agents/hve-core/rpi-agent.md",
      "kind": "agent",
      "maturity": "stable",
      "version": "3.3.106",
      "sha256": "<hash>",
      "status": "managed"
    }
  }
}
```
<!-- </tracking-manifest> -->

Files are keyed by target-relative path. The manifest records the selected package once under `selection.package`; file entries carry component ownership only, and no absolute target root is stored. There is no version 1 compatibility layer: a missing or unsupported `schemaVersion` fails before any target change with clean-reinstall guidance.

### Component Copy Success Report

Upon successful copy, display:

<!-- <component-copy-success> -->
```text
✅ Component Installation Complete!

Copied [N] components into .github/
Created .hve-tracking.json for upgrade tracking

📄 Installed components:
  • [component path] ([kind], [maturity])

🔄 Upgrade Workflow:
  Run this installer again to check for component updates.
  Modified files will prompt before overwriting.
  Use 'eject' to take ownership of any component.

Proceeding to final success report...
```
<!-- </component-copy-success> -->

## Phase 7 Upgrade Mode

When `.hve-tracking.json` already exists, Phase 7 operates in upgrade mode.

### Upgrade Detection

At Phase 7 start, check for an existing manifest.

**PowerShell:** Run [scripts/upgrade-detection.ps1](../scripts/upgrade-detection.ps1) with `-HveCoreBasePath` and optional `-TargetRoot`.

**Bash:** Run [scripts/upgrade-detection.sh](../scripts/upgrade-detection.sh) with the HVE-Core base path and optional target root as arguments.

Output keys: `UPGRADE_MODE`, and when a manifest exists, `INSTALLED_VERSION`, `SOURCE_VERSION`, `VERSION_CHANGED`, `INSTALLED_PACKAGE`, `INSTALLED_PROFILE`, and `INSTALLED_COMPONENTS`. `INSTALLED_PACKAGE` is the recorded `selection.package`, and is emitted as an empty value when a schema version 2 manifest records none. An unsupported `schemaVersion` fails with clean-reinstall guidance.

Replay the upgrade against `INSTALLED_PACKAGE`: pass it as `-PackageName` or the Bash package argument for collision detection and copy, and re-resolve `INSTALLED_COMPONENTS` through that package's entry so the upgrade reflects current dependency closure and maturity. When `INSTALLED_PACKAGE` is empty, stop and run Package Selection again so the user names one exact catalog package before any replay; infer nothing from the recorded profile or components.

### Upgrade Prompt

If upgrade mode with version change:

<!-- <upgrade-prompt> -->
```text
🔄 HVE-Core Component Upgrade

Source: microsoft/hve-core v[SOURCE_VERSION]
Installed: v[INSTALLED_VERSION]
Package: [INSTALLED_PACKAGE]
Selection: [INSTALLED_PROFILE]

Checking file status...
```
<!-- </upgrade-prompt> -->

### File Status Check

Compare current files against the manifest.

**PowerShell:** Run [scripts/file-status-check.ps1](../scripts/file-status-check.ps1) with optional `-TargetRoot`.

**Bash:** Run [scripts/file-status-check.sh](../scripts/file-status-check.sh) with an optional target root argument.

Each line reports one tracked file:

<!-- <file-status-output> -->
```text
FILE=<path>|COMPONENT=<component path>|KIND=<kind>|MATURITY=<maturity>|STATUS=<status>|ACTION=<action>
```
<!-- </file-status-output> -->

Statuses are `managed`, `modified`, `missing`, and `ejected`. Group the lines by `COMPONENT` when presenting them.

### Upgrade Summary Display

Present upgrade summary:

<!-- <upgrade-summary> -->
```text
📋 Upgrade Summary

Components to update (managed):
  ✅ agents/hve-core/rpi-agent.md
  ✅ skills/rpi/rpi-plan

Files requiring decision (modified):
  ⚠️ .github/agents/hve-core/rpi-agent.agent.md

Components skipped (ejected):
  🔒 agents/hve-core/documentation.md

For modified files, choose:
  [A] Accept upstream (overwrite your changes)
  [K] Keep local (skip this update)
  [E] Eject (never update this component again)
  [D] Show diff

Process file: .github/agents/hve-core/rpi-agent.agent.md?
```
<!-- </upgrade-summary> -->

### Upgrade Confirmation Gate

Write nothing to the target repository until the user confirms. After displaying the upgrade summary, stop and require an explicit confirmation to proceed with the listed updates. Present each `modified` file individually and require an explicit `A`, `K`, `E`, or `D` selection for it; never assume a default. Treat silence, an unrecognized answer, or a declined confirmation as `Keep local` and skip the write.

Never overwrite a `modified` or `ejected` file without an explicit per-file `Accept` selection for that file.

### Diff Display

When user requests diff:

<!-- <diff-display> -->
```text
─────────────────────────────────────
File: .github/agents/hve-core/rpi-agent.agent.md
Component: agents/hve-core/rpi-agent.md
Status: modified
─────────────────────────────────────

--- Local version
+++ HVE-Core version

@@ -10,3 +10,5 @@
 ## Role Definition

-Your local modifications here
+Updated behavior with new capabilities
+
+New section added in latest version
─────────────────────────────────────

[A] Accept upstream / [K] Keep local / [E] Eject
```
<!-- </diff-display> -->

### Status Transitions

After user decision, update the manifest:

| Decision | Status Change           | Manifest Update                         |
|----------|-------------------------|-----------------------------------------|
| Accept   | `modified` → `managed`  | Re-copy the component, update hash      |
| Keep     | `modified` → `modified` | No change (pass the component to keep)  |
| Eject    | `*` → `ejected`         | Add `ejectedAt` to every component file |

### Eject Implementation

Eject operates on a component. Every file of that component is marked `ejected`, stays on disk, and becomes owned by the user. Later copies skip ejected files and preserve their manifest entries.

**PowerShell:** Run [scripts/eject.ps1](../scripts/eject.ps1) with `-Component` and optional `-TargetRoot`.

**Bash:** Run [scripts/eject.sh](../scripts/eject.sh) with the component path and optional target root as arguments.

### Upgrade Completion

After processing all files:

<!-- <upgrade-success> -->
```text
✅ Upgrade Complete!

Updated: [N] files
Skipped: [M] files (kept local or ejected)
Version: v[OLD] → v[NEW]

Proceeding to final success report...
```
<!-- </upgrade-success> -->

