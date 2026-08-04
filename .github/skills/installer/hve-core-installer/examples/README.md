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

### Collision Detection

Report component maturity and target collisions before copying.

```powershell
./scripts/collision-detection.ps1 -HveCoreBasePath ./lib/hve-core -TargetRoot . -PackageName hve-core-all -Component @('agents/hve-core/rpi-agent.md', 'skills/rpi/rpi-plan')
```

```bash
./scripts/collision-detection.sh ./lib/hve-core . hve-core-all agents/hve-core/rpi-agent.md skills/rpi/rpi-plan
```

### Component Copy

Copy the resolved starter profile from the HVE-Core source into the target project.

```powershell
./scripts/component-copy.ps1 -HveCoreBasePath ./lib/hve-core -TargetRoot . -PackageName hve-core-all -SelectionName starter -Component @('agents/hve-core/rpi-agent.md', 'commands/hve-core/rpi.md', 'rules/hve-core/copilot-tracking.instructions.md', 'skills/rpi/rpi-plan')
```

```bash
./scripts/component-copy.sh ./lib/hve-core . hve-core-all starter agents/hve-core/rpi-agent.md commands/hve-core/rpi.md rules/hve-core/copilot-tracking.instructions.md skills/rpi/rpi-plan
```

Preserve components the user chose to keep during collision resolution.

```powershell
./scripts/component-copy.ps1 -HveCoreBasePath ./lib/hve-core -TargetRoot . -PackageName hve-core-all -SelectionName custom -Component @('agents/hve-core/rpi-agent.md', 'skills/rpi/rpi-plan') -KeepExisting -Collisions @('skills/rpi/rpi-plan')
```

```bash
printf 'skills/rpi/rpi-plan\n' > /tmp/collisions.txt
KEEP_EXISTING=true COLLISIONS_FILE=/tmp/collisions.txt \
  ./scripts/component-copy.sh ./lib/hve-core . hve-core-all custom agents/hve-core/rpi-agent.md skills/rpi/rpi-plan
```

### Upgrade Detection

Check whether an existing installation needs upgrading.

Output includes `INSTALLED_PACKAGE`, which replays the recorded package into collision detection and copy. It is empty when the manifest records no package; select a package explicitly before replaying.

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
