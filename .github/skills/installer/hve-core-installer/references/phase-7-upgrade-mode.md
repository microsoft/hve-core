---
title: 'Phase 7 Upgrade Mode'
description: 'Upgrade workflow used when an existing .hve-tracking.json manifest is detected during Phase 7 of the hve-core installer.'
---

# Phase 7 Upgrade Mode

When `.hve-tracking.json` already exists, Phase 7 operates in upgrade mode.

## Upgrade Detection

At Phase 7 start, check for existing manifest.

**PowerShell:** Run [upgrade-detection.ps1](../scripts/upgrade-detection.ps1) with the `hveCoreBasePath` variable set.

**Bash:** Run [upgrade-detection.sh](../scripts/upgrade-detection.sh) with the HVE-Core base path as an argument.

## Upgrade Prompt

If upgrade mode with version change:

<!-- <upgrade-prompt> -->
```text
🔄 HVE-Core Agent Upgrade

Source: microsoft/hve-core v[SOURCE_VERSION]
Installed: v[INSTALLED_VERSION]

Checking file status...
```
<!-- </upgrade-prompt> -->

## File Status Check

Compare current files against manifest.

**PowerShell:** Run [file-status-check.ps1](../scripts/file-status-check.ps1).

**Bash:** Run [file-status-check.sh](../scripts/file-status-check.sh) to compare files against the manifest.

## Upgrade Summary Display

Present upgrade summary:

<!-- <upgrade-summary> -->
```text
📋 Upgrade Summary

Files to update (managed):
  ✅ .github/agents/hve-core/task-researcher.agent.md
  ✅ .github/agents/hve-core/task-planner.agent.md

Files requiring decision (modified):
  ⚠️ .github/agents/hve-core/task-implementor.agent.md

Files skipped (ejected):
  🔒 .github/agents/custom-agent.agent.md

For modified files, choose:
  [A] Accept upstream (overwrite your changes)
  [K] Keep local (skip this update)
  [E] Eject (never update this file again)
  [D] Show diff

Process file: task-implementor.agent.md?
```
<!-- </upgrade-summary> -->

## Diff Display

When user requests diff:

<!-- <diff-display> -->
```text
─────────────────────────────────────
File: .github/agents/hve-core/task-implementor.agent.md
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

## Status Transitions

After user decision, update manifest:

| Decision | Status Change           | Manifest Update           |
|----------|-------------------------|---------------------------|
| Accept   | `modified` → `managed`  | Update hash, version      |
| Keep     | `modified` → `modified` | No change (skip file)     |
| Eject    | `*` → `ejected`         | Add `ejectedAt` timestamp |

## Eject Implementation

When user ejects a file:

**PowerShell:** Run [eject.ps1](../scripts/eject.ps1) with the `FilePath` parameter.

**Bash:** Run [eject.sh](../scripts/eject.sh) with the file path as an argument.

## Upgrade Completion

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

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
