---
title: Component Installation and Upgrade
description: Phase 7 component installation and the Phase 7 upgrade mode for the hve-core installer.
---
<!-- markdownlint-disable-file -->

## Phase 7: Component Installation

> [!IMPORTANT]
> Generated scripts in this phase require PowerShell 7+ (`pwsh`). Windows PowerShell 5.1 is not supported. The Bash scripts require `jq`.

Phase 7 carries out native repository adoption. After Phase 5 validates the source clone, copy every HVE-Core component into the project's `.github/agents`, `.github/skills`, and `.github/instructions` folders. Phase 7 copies the full set because agents load skills and instructions by name, and a partial set can leave an agent without what it needs to start. Copilot discovers the copies natively, and the repository owns them. The source clone stays unconnected to Copilot. When this phase finishes, proceed to Phase 6.

A component is one agent, prompt, instruction, or complete skill declared by root `plugin.json`. Every Phase 7 operation validates its component paths against that manifest before writing. The manifest uses repository-relative `.github/...` paths; component selections use installer form and map to canonical target paths without flattening:

<!-- <component-kind-map> -->
| Component path                           | Target path                                                          |
|------------------------------------------|----------------------------------------------------------------------|
| `agents/<subpath>/<name>.md`             | `<TargetRoot>/.github/agents/<subpath>/<name>.agent.md`              |
| `commands/<subpath>/<name>.md`           | `<TargetRoot>/.github/prompts/<subpath>/<name>.prompt.md`            |
| `rules/<subpath>/<name>.instructions.md` | `<TargetRoot>/.github/instructions/<subpath>/<name>.instructions.md` |
| `skills/<subpath>/<name>`                | `<TargetRoot>/.github/skills/<subpath>/<name>` (whole directory)     |
<!-- </component-kind-map> -->

Hooks are never copied by this phase. Skills copy as complete directories, minus local environment and cache directories (`tests`, `.venv`, `.hypothesis`, `node_modules`, `__pycache__`, `.ruff_cache`, `.pytest_cache`).

The Copilot harness does not load prompt files (`.prompt.md`), so a copied prompt has no effect in Copilot sessions. HVE-Core's entry points are skills used as slash commands.

### Skip Condition

Skip Phase 7 for the plugin, team default, extension, and clone routes. Those routes already deliver HVE-Core, and copying components as well would install the same content through a second route.

### Checkpoint 6: Component Selection

Present the component selection prompt:

<!-- <component-selection-prompt> -->
```text
📂 Component Installation

I'll copy every HVE-Core agent, instruction, and skill into your
repository's .github folders. Copilot discovers the copies natively,
and your repository owns them.

Options:
  [1] Install every component declared by the HVE Core plugin
  [2] Skip component installation

Your choice? (1/2)
```
<!-- </component-selection-prompt> -->

User input handling:

* "1", "all", "complete" → Select every agent, prompt, instruction, and skill declared by root `plugin.json`; set the selection name to `all`
* "2", "skip", "none", "no" → Skip to Phase 6 without copying anything
* A request to pick individual components → Explain that Phase 7 copies the full set because a partial set can leave agents without the skills and instructions they load, then offer the two options again
* Unclear response → Ask for clarification

### Selection Resolution

Resolve the component list before any confirmation or write. For a new install, and for an upgrade of the `all` profile, read root `plugin.json` from the HVE-Core source at `$hveCoreBasePath` and take every declared component, so an upgrade also copies components added since the recorded install. Upgrade Detection covers other recorded profiles. Convert canonical repository-relative manifest paths to installer paths with these deterministic conversions before collision detection or component copy:

| Manifest declaration                                          | Installer component path                 |
|---------------------------------------------------------------|------------------------------------------|
| `agents/<subpath>/<name>.agent.md`                            | `agents/<subpath>/<name>.md`             |
| `commands` entry `prompts/<subpath>/<name>.prompt.md`         | `commands/<subpath>/<name>.md`           |
| `rules` entry `instructions/<subpath>/<name>.instructions.md` | `rules/<subpath>/<name>.instructions.md` |
| `skills/<subpath>/<name>`                                     | `skills/<subpath>/<name>`                |

Reject a component that is absent from the converted manifest membership before collision detection and before the first write. The copy scripts repeat the same membership check during preflight.

### Upstream Source Verification

For Methods 3 (Mounted) and 5 (Multi-Root), and for a clone the user already had, verify the pre-existing clone before collision detection or component copy. This is an advisory trust signal, not proof of repository integrity, and it must not silently reject an intentional fork or local development clone.

Run the read-only check against the resolved HVE-Core source path:

```bash
git -C <HveCoreBasePath> remote get-url origin
```

Treat these `github.com/microsoft/hve-core` forms as expected, with an optional `.git` suffix and optional trailing slash where the URL form permits it:

* `https://github.com/microsoft/hve-core.git`
* `git@github.com:microsoft/hve-core.git`
* `ssh://git@github.com/microsoft/hve-core.git`

When `origin` is missing or does not match an expected HTTPS, SCP-like SSH, or `ssh://` form, display the observed value when available and warn that copied components may come from a fork or substituted local source. Ask `Continue using this HVE-Core source? (yes/no)`. Continue to collision detection only after an explicit `yes`; on `no` or an unclear answer, stop before any target-repository write.

### Collision Detection

Run the pre-write check with the resolved component list. It validates every path and reports component-level collisions. A file component collides on its full target path; a skill component collides on its target directory. Nothing is written.

**PowerShell:** Run [scripts/collision-detection.ps1](../scripts/collision-detection.ps1) with `-HveCoreBasePath`, `-TargetRoot`, and `-Component`.

**Bash:** Run [scripts/collision-detection.sh](../scripts/collision-detection.sh) with the HVE-Core base path, target root, and component paths as arguments, in that order.

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

Present every component before any write.

<!-- <component-confirmation-prompt> -->
```text
📋 Components to install

| Component        | Kind   |
|------------------|--------|
| [component path] | [kind] |

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

**PowerShell:** Run [scripts/component-copy.ps1](../scripts/component-copy.ps1) with `-HveCoreBasePath`, `-TargetRoot`, `-SelectionName` (`all` for a new install and for every upgrade), and `-Component`. Add `-KeepExisting -Collisions <component paths>` for kept components.

**Bash:** Run [scripts/component-copy.sh](../scripts/component-copy.sh) with the HVE-Core base path, target root, selection name, and component paths as arguments, in that order. Set `KEEP_EXISTING=true` and `COLLISIONS_FILE=<newline-delimited component paths>` for kept components.

Both implementations validate membership, path safety, and the existing manifest schema before the first write, and produce equivalent paths, hashes, manifests, and output.

### Tracking Manifest

The copy writes `.hve-tracking.json` at the target root using schema version 2:

<!-- <tracking-manifest> -->
```json
{
  "schemaVersion": 2,
  "source": "microsoft/hve-core",
  "version": "3.2.2",
  "installed": "2026-08-13T00:00:00Z",
  "selection": {
    "profile": "custom",
    "components": ["agents/hve-core/rpi-agent.md", "skills/rpi/rpi-plan"]
  },
  "files": {
    ".github/agents/hve-core/rpi-agent.agent.md": {
      "component": "agents/hve-core/rpi-agent.md",
      "kind": "agent",
      "maturity": "stable",
      "version": "3.2.2",
      "sha256": "<hash>",
      "status": "managed"
    }
  }
}
```
<!-- </tracking-manifest> -->

Files are keyed by target-relative path. New installs record the `all` profile with every component path. Installs from earlier installer versions may record `custom` with the components picked then, as in the example. Upgrade mode doesn't replay that list; it offers the full current set instead. The `selection` object records only the profile label and installed component paths; file entries carry component ownership, and no package identity or absolute target root is stored. There is no version 1 compatibility layer: a missing or unsupported `schemaVersion` fails before any target change with clean-reinstall guidance.

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

Proceeding to post-installation setup...
```
<!-- </component-copy-success> -->

## Phase 7 Upgrade Mode

When `.hve-tracking.json` already exists, Phase 7 operates in upgrade mode.

### Upgrade Detection

At Phase 7 start, check for an existing manifest.

**PowerShell:** Run [scripts/upgrade-detection.ps1](../scripts/upgrade-detection.ps1) with `-HveCoreBasePath` and optional `-TargetRoot`.

**Bash:** Run [scripts/upgrade-detection.sh](../scripts/upgrade-detection.sh) with the HVE-Core base path and optional target root as arguments.

Output keys: `UPGRADE_MODE`, and when a manifest exists, `INSTALLED_VERSION`, `SOURCE_VERSION`, `VERSION_CHANGED`, `INSTALLED_PROFILE`, and `INSTALLED_COMPONENTS`. An unsupported `schemaVersion` fails with clean-reinstall guidance.

Validate each path in `INSTALLED_COMPONENTS` against the current root `plugin.json` membership, and list any recorded component that is no longer declared before writing. Then resolve the upgrade set from `INSTALLED_PROFILE`:

* `all`: take every component the current manifest declares, including components added since the recorded install, and pass `all` as `-SelectionName` or the Bash selection-name argument.
* Any other profile, such as `custom`: don't replay the recorded list. Agents preload skills and load instructions by name, and a release can add skills that an earlier partial list can't include, so a replayed list can leave agents unable to start. Stop before writing, explain this, and offer to upgrade to the full current set with the `all` profile or to skip the upgrade.

### Upgrade Prompt

If upgrade mode with version change:

<!-- <upgrade-prompt> -->
```text
🔄 HVE-Core Component Upgrade

Source: microsoft/hve-core v[SOURCE_VERSION]
Installed: v[INSTALLED_VERSION]
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

Proceeding to post-installation setup...
```
<!-- </upgrade-success> -->
