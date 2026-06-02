---
title: 'Phase 7: Agent Customization (Optional)'
description: 'Optional agent file customization workflow for clone-based hve-core installations.'
---

# Phase 7: Agent Customization (Optional)

> [!IMPORTANT]
> Generated scripts in this phase require PowerShell 7+ (`pwsh`). Windows PowerShell 5.1 is not supported.

After Phase 6 completes, offer users the option to copy agent files into their target repository. This phase ONLY applies to clone-based installation methods (1-6), NOT to extension installation.

## Skip Condition

If user selected **Extension Quick Install** (Option 1) in Phase 2, skip Phase 7 entirely. Extension installation bundles agents automatically.

## Checkpoint 6: Agent Copy Decision

Present the agent selection prompt:

<!-- <agent-copy-prompt> -->
```text
📂 Agent Customization (Optional)

HVE-Core includes specialized agents for common workflows.
Copying agents enables local customization and offline use.

🔬 RPI Core (Research-Plan-Implement workflow)
  • task-researcher - Technical research and evidence gathering
  • task-planner - Implementation plan creation
  • task-implementor - Plan execution with tracking
  • task-reviewer - Implementation review and validation
  • rpi-agent - RPI workflow coordinator

📋 Planning & Documentation
  • adr-creation, agile-coach, brd-builder, doc-ops, prd-builder
  • product-manager-advisor, security-planner, ux-ui-designer

⚙️ Generators
  • arch-diagram-builder, gen-data-spec, gen-jupyter-notebook, gen-streamlit-dashboard

✅ Review & Testing
  • pr-review, prompt-builder, test-streamlit-dashboard

🧠 Utilities
  • memory - Conversation memory and session continuity

🔗 Platform-Specific
  • ado-prd-to-wit (Azure DevOps)
  • github-backlog-manager (GitHub)

Options:
  [1] Install RPI Core only (recommended)
  [2] Install by collection
  [3] Skip agent installation

Your choice? (1/2/3)
```
<!-- </agent-copy-prompt> -->

User input handling:

* "1", "rpi", "rpi core", "core" → Copy RPI Core bundle only
* "2", "collection", "by collection" → Proceed to Collection Selection sub-flow
* "3", "skip", "none", "no" → Skip to success report
* Unclear response → Ask for clarification

## Collection Selection Sub-Flow

When the user selects option 2, read collection manifests to present available collections.

### Step 1: Read collections and build collection agent counts

Read `collections/*.collection.yml` from the HVE-Core source (at `$hveCoreBasePath`). Derive collection options from collection `id` and `name`. For each selected collection, count agent items where `kind` equals `agent` and effective item maturity is `stable` (item `maturity` omitted defaults to `stable`; exclude `experimental` and `deprecated`).

### Step 2: Present collection options

<!-- <collection-selection-prompt> -->
```text
🎭 Collection Selection

Choose one or more collections to install agents tailored to your role, more to come in the future.

| # | Collection | Agents | Description                     |
|---|------------|--------|---------------------------------|
| 1 | Developer  | [N]    | Software engineers writing code |

Enter collection number(s) separated by commas (e.g., "1"):
```
<!-- </collection-selection-prompt> -->

Agent counts `[N]` include agents matching the collection with `stable` maturity.

User input handling:

* Single number (e.g., "1") → Select that collection
* Multiple numbers (e.g., "1, 3") → Combine agent sets from selected collections
* Collection name (e.g., "developer") → Match by identifier
* Unclear response → Ask for clarification

### Step 3: Build filtered agent list

For each selected collection identifier:

1. Iterate through `items` in the collection manifest
2. Include items where `kind` is `agent` AND `maturity` is `stable`
3. Deduplicate across multiple selected collections

### Step 4: Present filtered agents for confirmation

<!-- <collection-confirmation-prompt> -->
```text
📋 Agents for [Collection Name(s)]

The following [N] agents will be copied:

  • [agent-name-1] - tags: [tag-1, tag-2]
  • [agent-name-2] - tags: [tag-1, tag-2]
  ...

Proceed with installation? (yes/no)
```
<!-- </collection-confirmation-prompt> -->

User input handling:

* "yes", "y" → Proceed with copy using filtered agent list
* "no", "n" → Return to Checkpoint 6 for re-selection
* Unclear response → Ask for clarification

> [!NOTE]
> Collection filtering applies to agents only. Copying of related prompts, instructions, and skills based on collection is planned for a future release.

## Agent Bundle Definitions

| Bundle            | Agents                                                                    |
|-------------------|---------------------------------------------------------------------------|
| `hve-core`        | task-researcher, task-planner, task-implementor, task-reviewer, rpi-agent |
| `collection:<id>` | Stable agents matching the collection                                     |

## Collision Detection

Before copying, check for existing agent files with matching names.

**PowerShell:** Run [collision-detection.ps1](../scripts/collision-detection.ps1) with the `hveCoreBasePath`, `selection`, and optional `collectionAgents` variables set.

**Bash:** Run [collision-detection.sh](../scripts/collision-detection.sh) with the HVE-Core base path and file list as arguments.

## Collision Resolution Prompt

If collisions are detected, present:

<!-- <collision-prompt> -->
```text
⚠️ Existing Agents Detected

The following agents already exist in your project:
  • [list collision files]

Options:
  [O] Overwrite with HVE-Core version
  [K] Keep existing (skip these files)
  [C] Compare (show diff for first file)

Or for all conflicts:
  [OA] Overwrite all
  [KA] Keep all existing

Your choice?
```
<!-- </collision-prompt> -->

User input handling:

* "o", "overwrite" → Overwrite current file, ask about next
* "k", "keep" → Keep current file, ask about next
* "c", "compare" → Show diff, then re-prompt
* "oa", "overwrite all" → Overwrite all collisions
* "ka", "keep all" → Keep all existing files

## Agent Copy Execution

After selection and collision resolution, execute the copy operation.

**PowerShell:** Run [agent-copy.ps1](../scripts/agent-copy.ps1) with the required variables set.

**Bash:** Run [agent-copy.sh](../scripts/agent-copy.sh) with the HVE-Core base path, collection ID, and file list as arguments.

## Agent Copy Success Report

Upon successful copy, display:

<!-- <agent-copy-success> -->
```text
✅ Agent Installation Complete!

Copied [N] agents to .github/agents/
Created .hve-tracking.json for upgrade tracking

📄 Installed Agents:
  • [list of copied agent names]

🔄 Upgrade Workflow:
  Run this installer again to check for agent updates.
  Modified files will prompt before overwriting.
  Use 'eject' to take ownership of any file.

Proceeding to final success report...
```
<!-- </agent-copy-success> -->

When `.hve-tracking.json` already exists at Phase 7 start, run the upgrade workflow instead of the initial copy flow. See [phase-7-upgrade-mode.md](phase-7-upgrade-mode.md) for detection, status reconciliation, diff display, and eject handling.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
