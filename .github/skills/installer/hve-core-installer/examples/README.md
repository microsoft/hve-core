---
title: HVE-Core Installer Examples
description: Common usage examples for the hve-core-installer skill scripts
---

## Script Usage Examples

### Environment Detection

Detect whether the current environment is local, devcontainer, or Codespaces.

```powershell
./scripts/detect-environment.ps1
```

```bash
./scripts/detect-environment.sh
```

### Full Component Set

Phase 7 copies every component that the source's root `plugin.json` declares. Convert the declared paths to installer form first.

```powershell
$plugin = Get-Content ./lib/hve-core/plugin.json -Raw | ConvertFrom-Json
$components = @(
    $plugin.agents | ForEach-Object { $_ -replace '^\.github/agents/', 'agents/' -replace '\.agent\.md$', '.md' }
    $plugin.commands | ForEach-Object { $_ -replace '^\.github/prompts/', 'commands/' -replace '\.prompt\.md$', '.md' }
    $plugin.rules | ForEach-Object { $_ -replace '^\.github/instructions/', 'rules/' }
    $plugin.skills | ForEach-Object { $_ -replace '^\.github/', '' }
)
```

```bash
jq -r '(.agents[] | sub("^\\.github/agents/"; "agents/") | sub("\\.agent\\.md$"; ".md")),
  (.commands[] | sub("^\\.github/prompts/"; "commands/") | sub("\\.prompt\\.md$"; ".md")),
  (.rules[] | sub("^\\.github/instructions/"; "rules/")),
  (.skills[] | sub("^\\.github/"; ""))' ./lib/hve-core/plugin.json > /tmp/hve-components.txt
```

### Collision Detection

Report component types and target collisions before copying.

```powershell
./scripts/collision-detection.ps1 -HveCoreBasePath ./lib/hve-core -TargetRoot . -Component $components
```

```bash
xargs ./scripts/collision-detection.sh ./lib/hve-core . < /tmp/hve-components.txt
```

### Component Copy

Copy the full set from the HVE-Core source into the target project.

```powershell
./scripts/component-copy.ps1 -HveCoreBasePath ./lib/hve-core -TargetRoot . -SelectionName all -Component $components
```

```bash
xargs ./scripts/component-copy.sh ./lib/hve-core . all < /tmp/hve-components.txt
```

Preserve components the user chose to keep during collision resolution.

```powershell
./scripts/component-copy.ps1 -HveCoreBasePath ./lib/hve-core -TargetRoot . -SelectionName all -Component $components -KeepExisting -Collisions @('skills/rpi/rpi-plan')
```

```bash
printf 'skills/rpi/rpi-plan\n' > /tmp/collisions.txt
KEEP_EXISTING=true COLLISIONS_FILE=/tmp/collisions.txt \
  xargs ./scripts/component-copy.sh ./lib/hve-core . all < /tmp/hve-components.txt
```

### Upgrade Detection

Check whether an existing installation needs upgrading.

Output includes the installed profile and component paths. Replay those component paths through collision detection and copy after validating them against the current plugin manifest.

```powershell
./scripts/upgrade-detection.ps1 -HveCoreBasePath ./lib/hve-core
```

```bash
./scripts/upgrade-detection.sh ./lib/hve-core
```

### Validate Installation

Verify a clone-based installation for a specific method.

```powershell
./scripts/validate-installation.ps1 -BasePath ./my-project -Method 1
```

Validate a multi-root workspace installation (method 5).

```powershell
./scripts/validate-installation.ps1 -BasePath ./my-project -Method 5
```

### Validate Extension

Check whether the HVE-Core VS Code extension is installed.

```powershell
./scripts/validate-extension.ps1
```

Use an alternate VS Code CLI.

```powershell
./scripts/validate-extension.ps1 -CodeCli 'code-insiders'
```

### File Status Check

Compare installed file hashes against the tracking manifest.

```powershell
./scripts/file-status-check.ps1
```

```bash
./scripts/file-status-check.sh
```

### Eject a Component

Mark every file of a managed component as ejected so upgrades no longer overwrite it.

```powershell
./scripts/eject.ps1 -Component skills/rpi/rpi-plan
```

```bash
./scripts/eject.sh skills/rpi/rpi-plan
```

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
