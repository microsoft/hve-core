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

Check for existing agent files before copying.

```powershell
./scripts/collision-detection.ps1 -Selection hve-core
```

Use a custom collection with explicit agent paths.

```powershell
./scripts/collision-detection.ps1 -Selection my-collection -CollectionAgents @('my-collection/custom.agent.md')
```

### Agent Copy

Copy agents from the HVE-Core source into the target project.

```powershell
./scripts/agent-copy.ps1 -HveCoreBasePath ./lib/hve-core -CollectionId hve-core -FilesToCopy @('hve-core/task-researcher.agent.md', 'hve-core/task-planner.agent.md')
```

Preserve existing files during an upgrade.

```powershell
./scripts/agent-copy.ps1 -HveCoreBasePath ./lib/hve-core -CollectionId hve-core -FilesToCopy @('hve-core/task-researcher.agent.md') -KeepExisting -Collisions @('.github/agents/task-researcher.agent.md')
```

### Upgrade Detection

Check whether an existing installation needs upgrading.

```powershell
./scripts/upgrade-detection.ps1 -HveCoreBasePath ./lib/hve-core
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

### Eject a File

Mark a managed file as ejected so upgrades no longer overwrite it.

```powershell
./scripts/eject.ps1 -FilePath .github/agents/task-researcher.agent.md
```
