---
title: 'Phase 4: Installation Methods'
description: 'Installation workflow steps for each supported hve-core installation method.'
---

# Phase 4: Installation Methods

Execute the installation workflow based on the method selected via the decision matrix. For detailed documentation, see the [installation methods documentation](https://github.com/microsoft/hve-core/blob/main/docs/getting-started/methods/).

## Method Configuration

| Method         | Documentation                                                                                                 | Target Location        | Settings Path Prefix   | Best For                            |
|----------------|---------------------------------------------------------------------------------------------------------------|------------------------|------------------------|-------------------------------------|
| 1. Peer Clone  | [peer-clone.md](https://github.com/microsoft/hve-core/blob/main/docs/getting-started/methods/peer-clone.md)   | `../hve-core`          | `../hve-core`          | Local VS Code, solo developers      |
| 2. Git-Ignored | [git-ignored.md](https://github.com/microsoft/hve-core/blob/main/docs/getting-started/methods/git-ignored.md) | `.hve-core/`           | `.hve-core`            | Devcontainer, isolation             |
| 3. Mounted*    | [mounted.md](https://github.com/microsoft/hve-core/blob/main/docs/getting-started/methods/mounted.md)         | `/workspaces/hve-core` | `/workspaces/hve-core` | Devcontainer + host clone           |
| 4. Codespaces  | [codespaces.md](https://github.com/microsoft/hve-core/blob/main/docs/getting-started/methods/codespaces.md)   | `/workspaces/hve-core` | `/workspaces/hve-core` | Codespaces                          |
| 5. Multi-Root  | [multi-root.md](https://github.com/microsoft/hve-core/blob/main/docs/getting-started/methods/multi-root.md)   | Per workspace file     | Actual clone path      | Local VS Code, best IDE integration |
| 6. Submodule   | [submodule.md](https://github.com/microsoft/hve-core/blob/main/docs/getting-started/methods/submodule.md)     | `lib/hve-core`         | `lib/hve-core`         | Team version control                |

*Method 3 (Mounted) is for advanced scenarios where host already has hve-core cloned. Most devcontainer users should use Method 2.

## Common Clone Operation

Generate a script for the user's shell (PowerShell or Bash) that:

1. Determines workspace root via `git rev-parse --show-toplevel`
2. Calculates target path based on method from table
3. Checks if target already exists
4. Clones if missing: `git clone https://github.com/microsoft/hve-core.git <target>`
5. Reports success with ✅ or skip with ⏭️

<!-- <clone-reference-powershell> -->
```powershell
$ErrorActionPreference = 'Stop'
$hveCoreDir = "<METHOD_TARGET_PATH>"  # Replace per method

if (-not (Test-Path $hveCoreDir)) {
    git clone https://github.com/microsoft/hve-core.git $hveCoreDir
    Write-Host "✅ Cloned HVE-Core to $hveCoreDir"
} else {
    Write-Host "⏭️ HVE-Core already exists at $hveCoreDir"
}
```
<!-- </clone-reference-powershell> -->

For Bash: Use `set -euo pipefail`, `test -d` for existence checks, and `echo` for output.

## Settings Configuration

After cloning, update `.vscode/settings.json` with entries for each collection subdirectory. Replace `<PREFIX>` with the settings path prefix from the method table. Do not use `**` glob patterns in paths because `chat.*Locations` settings do not support them.

Enumerate each collection subdirectory under `.github/agents/`, `.github/prompts/`, and `.github/instructions/` from the cloned HVE-Core directory. Create one entry per subdirectory. For `.github/agents/`, also check each collection folder for a `subagents/` subfolder and include it when present (e.g., `hve-core/subagents`). For `.github/skills/`, list only the collection-level folders directly under `.github/skills/` (e.g., `shared`); do not enumerate deeper subfolders (individual skill directories like `shared/pr-reference/` are not listed). Exclude the `installer` collection from `chat.agentSkillsLocations` because it is the installer skill itself and not intended for end-user settings.

Any folder named `experimental` under any artifact type (agents, prompts, instructions, or skills) must not be included without first asking the user whether they want experimental features. If the user opts in, add the `experimental` entries (and `experimental/subagents` for agents when that subfolder exists).

<!-- <settings-template> -->
```json
{
  "chat.agentFilesLocations": {
    "<PREFIX>/.github/agents/ado": true,
    "<PREFIX>/.github/agents/coding-standards": true,
    "<PREFIX>/.github/agents/data-science": true,
    "<PREFIX>/.github/agents/design-thinking": true,
    "<PREFIX>/.github/agents/github": true,
    "<PREFIX>/.github/agents/hve-core": true,
    "<PREFIX>/.github/agents/hve-core/subagents": true,
    "<PREFIX>/.github/agents/project-planning": true,
    "<PREFIX>/.github/agents/security": true
  },
  "chat.promptFilesLocations": {
    "<PREFIX>/.github/prompts/ado": true,
    "<PREFIX>/.github/prompts/coding-standards": true,
    "<PREFIX>/.github/prompts/design-thinking": true,
    "<PREFIX>/.github/prompts/github": true,
    "<PREFIX>/.github/prompts/hve-core": true,
    "<PREFIX>/.github/prompts/security": true
  },
  "chat.instructionsFilesLocations": {
    "<PREFIX>/.github/instructions/ado": true,
    "<PREFIX>/.github/instructions/coding-standards": true,
    "<PREFIX>/.github/instructions/design-thinking": true,
    "<PREFIX>/.github/instructions/github": true,
    "<PREFIX>/.github/instructions/hve-core": true,
    "<PREFIX>/.github/instructions/shared": true
  },
  "chat.agentSkillsLocations": {
    "<PREFIX>/.github/skills": true,
    "<PREFIX>/.github/skills/shared": true,
    "<PREFIX>/.github/skills/coding-standards": true
  }
}
```
<!-- </settings-template> -->

## Method-Specific Instructions

### Method 1: Peer Clone

Clone to parent directory: `Split-Path $workspaceRoot -Parent | Join-Path -ChildPath "hve-core"`

### Method 2: Git-Ignored

Additional steps before cloning:

1. Create `.hve-core/` directory
2. Add `.hve-core/` to `.gitignore` (create if missing)
3. Clone into `.hve-core/`

### Method 3: Mounted Directory

Requires host-side setup and container rebuild:

**Step 1:** Display pre-rebuild instructions:

```text
📋 Pre-Rebuild Setup Required

Clone hve-core on your HOST machine (not in container):
  cd <parent-of-your-project>
  git clone https://github.com/microsoft/hve-core.git
```

**Step 2:** Add mount to devcontainer.json:

<!-- <method-3-devcontainer-mount> -->
```jsonc
{
  "mounts": [
    "source=${localWorkspaceFolder}/../hve-core,target=/workspaces/hve-core,type=bind,readonly=true,consistency=cached"
  ]
}
```
<!-- </method-3-devcontainer-mount> -->

**Step 3:** After rebuild, validate mount exists at `/workspaces/hve-core`

### Method 4: postCreateCommand (Codespaces)

Add to devcontainer.json:

<!-- <method-4-devcontainer> -->
```jsonc
{
  "postCreateCommand": "[ -d /workspaces/hve-core ] || git clone --depth 1 https://github.com/microsoft/hve-core.git /workspaces/hve-core",
  "customizations": {
    "vscode": {
      "settings": {
        "chat.agentFilesLocations": {
          "/workspaces/hve-core/.github/agents/ado": true,
          "/workspaces/hve-core/.github/agents/coding-standards": true,
          "/workspaces/hve-core/.github/agents/data-science": true,
          "/workspaces/hve-core/.github/agents/design-thinking": true,
          "/workspaces/hve-core/.github/agents/github": true,
          "/workspaces/hve-core/.github/agents/hve-core": true,
          "/workspaces/hve-core/.github/agents/hve-core/subagents": true,
          "/workspaces/hve-core/.github/agents/project-planning": true,
          "/workspaces/hve-core/.github/agents/security": true
        },
        "chat.promptFilesLocations": {
          "/workspaces/hve-core/.github/prompts/ado": true,
          "/workspaces/hve-core/.github/prompts/coding-standards": true,
          "/workspaces/hve-core/.github/prompts/design-thinking": true,
          "/workspaces/hve-core/.github/prompts/github": true,
          "/workspaces/hve-core/.github/prompts/hve-core": true,
          "/workspaces/hve-core/.github/prompts/security": true
        },
        "chat.instructionsFilesLocations": {
          "/workspaces/hve-core/.github/instructions/ado": true,
          "/workspaces/hve-core/.github/instructions/coding-standards": true,
          "/workspaces/hve-core/.github/instructions/design-thinking": true,
          "/workspaces/hve-core/.github/instructions/github": true,
          "/workspaces/hve-core/.github/instructions/hve-core": true,
          "/workspaces/hve-core/.github/instructions/shared": true
        },
        "chat.agentSkillsLocations": {
          "/workspaces/hve-core/.github/skills": true,
          "/workspaces/hve-core/.github/skills/shared": true,
          "/workspaces/hve-core/.github/skills/coding-standards": true
        }
      }
    }
  }
}
```
<!-- </method-4-devcontainer> -->

Optional: Add `updateContentCommand` for auto-updates on rebuild.

### Method 5: Multi-Root Workspace

Create `hve-core.code-workspace` file with folders array pointing to both project and HVE-Core.

Use the actual clone path (not the folder display name) as the settings prefix.
Folder display names in `chat.*Locations` settings do not resolve reliably.

> [!IMPORTANT]
> The dev container spec has no `workspaceFile` property. Codespaces and devcontainers always open in single-folder mode. The user must manually open the `.code-workspace` file after the container starts (`File > Open Workspace from File...` or `code <path>.code-workspace`). For Codespaces, Method 4 is usually more convenient because it configures settings automatically without requiring a workspace switch.

Local VS Code: use a relative clone path from the workspace file's directory.

<!-- <method-5-workspace-local> -->
```json
{
  "folders": [
    { "name": "My Project", "path": "." },
    { "path": "../hve-core" }
  ],
  "settings": { /* Same as settings template with ../hve-core prefix */ }
}
```
<!-- </method-5-workspace-local> -->

User opens the `.code-workspace` file instead of the folder.

### Method 6: Submodule

Use git submodule commands instead of clone:

```bash
git submodule add https://github.com/microsoft/hve-core.git lib/hve-core
git submodule update --init --recursive
git add .gitmodules lib/hve-core
git commit -m "Add HVE-Core as submodule"
```

Team members run `git submodule update --init --recursive` after cloning.

Optional devcontainer.json for auto-initialization:

<!-- <method-6-devcontainer> -->
```jsonc
{
  "onCreateCommand": "git submodule update --init --recursive",
  "updateContentCommand": "git submodule update --remote lib/hve-core || true"
}
```
<!-- </method-6-devcontainer> -->

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
