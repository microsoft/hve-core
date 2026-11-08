---
title: Installation Methods
description: Phase 4 installation methods for the hve-core installer, covering where to keep an HVE-Core clone and how Copilot uses it.
---
<!-- markdownlint-disable-file -->

## Phase 4: Installation Methods

A clone is a way to store and pin a copy of HVE-Core. Clone HVE-Core with the method selected through the decision matrix, then continue by route:

* Clone route: connect the clone to Copilot as described in [Connect the Clone to Copilot](#connect-the-clone-to-copilot).
* Native adoption: stop after cloning. The clone is only the source that Phase 7 copies from. Leave it unconnected, because connecting it as well would deliver the same content through two routes.

For detailed documentation, see the [installation methods documentation](https://github.com/microsoft/hve-core/blob/main/docs/getting-started/methods/).

### Method Configuration

| Method         | Documentation                                                                                                 | Target Location                   | Inside the Checkout | Copilot Uses It Through                                        | Best For                                        |
|----------------|---------------------------------------------------------------------------------------------------------------|-----------------------------------|---------------------|----------------------------------------------------------------|-------------------------------------------------|
| 1. Peer Clone  | [peer-clone.md](https://github.com/microsoft/hve-core/blob/main/docs/getting-started/methods/peer-clone.md)   | `../hve-core`                     | No                  | Plugin from source                                             | Local VS Code, solo developers                  |
| 2. Git-Ignored | [git-ignored.md](https://github.com/microsoft/hve-core/blob/main/docs/getting-started/methods/git-ignored.md) | `.hve-core/`                      | Yes                 | Plugin from source or settings file                            | Devcontainer, isolation                         |
| 3. Mounted*    | [mounted.md](https://github.com/microsoft/hve-core/blob/main/docs/getting-started/methods/mounted.md)         | `.hve-core/` (host clone mounted) | Yes                 | Settings file, or plugin from source with a Plugins page check | Devcontainers sharing one host clone            |
| 4. Codespaces  | [codespaces.md](https://github.com/microsoft/hve-core/blob/main/docs/getting-started/methods/codespaces.md)   | `.hve-core/`                      | Yes                 | Settings file                                                  | Codespaces with a pinned or customized copy     |
| 5. Multi-Root  | [multi-root.md](https://github.com/microsoft/hve-core/blob/main/docs/getting-started/methods/multi-root.md)   | Per workspace file                | No                  | Plugin from source                                             | Local VS Code, HVE-Core open beside the project |
| 6. Submodule   | [submodule.md](https://github.com/microsoft/hve-core/blob/main/docs/getting-started/methods/submodule.md)     | `lib/hve-core`                    | Yes                 | Settings file or plugin from source                            | Team version control                            |

*Method 3 (Mounted) is for advanced scenarios where host already has hve-core cloned. Most devcontainer users should use Method 2.

### Common Clone Operation

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

### Connect the Clone to Copilot

Use one connection per clone. Any clone that the VS Code host can read can be installed as a plugin from source. A clone inside the project's checkout (Methods 2, 3, 4, and 6) can instead have its folders declared in `.github/copilot/settings.json`. Never use both for the same clone, and do not combine either one with the HVE-Core plugin or the extension.

#### Install the Clone as a Plugin from Source

Installing from source works wherever the VS Code host can read the folder and gives the full set: agents, skills, and path-specific instructions. HVE-Core keeps `plugin.json` at its repository root, so the root folder of the clone is the plugin folder. How this route behaves inside a dev container or codespace is not confirmed, so there the user must check that `hve-core` appears on the **Plugins** page before relying on it.

Editor controls and Command Palette commands need the user, so present these steps with the resolved clone path and wait for confirmation:

<!-- <plugin-from-source-steps> -->
```text
🔌 Install Your HVE-Core Clone as a Plugin

1. Open the Agent Customizations editor and select Plugins.
2. Select the add (+) button next to User or Workspace.
3. Enter the clone's root folder: [clone path]

Or run "Chat: Install Plugin from Source" from the Command Palette
and enter the same folder.

In a dev container or codespace, check that hve-core appears on the
Plugins page before you rely on it.

Reply "done" when the plugin is installed.
```
<!-- </plugin-from-source-steps> -->

#### Declare the Clone in `.github/copilot/settings.json`

Use this only for a clone inside the project's checkout: Methods 2, 3, and 4 (`.hve-core`) or Method 6 (`lib/hve-core`). Get approval under Checkpoint 3, then create `.github/copilot/settings.json` with the content below, or merge the three keys into the existing file. Replace `<PREFIX>` with the clone's path relative to the checkout root.

<!-- <settings-directories> -->
```json
{
  "agentDirectories": ["<PREFIX>/.github/agents"],
  "skillDirectories": ["<PREFIX>/.github/skills"],
  "instructionDirectories": ["<PREFIX>/.github/instructions"]
}
```
<!-- </settings-directories> -->

Before writing, tell the user what this declaration does and does not cover:

* Paths must be literal folders inside the checkout. Absolute paths, `~`, environment variables, globs, and paths that leave the checkout are rejected.
* The folders load only when the workspace folder is trusted.
* Copilot finds agents and skills nested by package under each folder, so the declaration includes every package, `experimental` among them. Copilot also inlines instructions that have no `applyTo`.
* Whether path-specific instructions (those with `applyTo`) load from these folders is not confirmed yet. Every HVE-Core instruction declares `applyTo`, so when the user needs the instructions, recommend a plugin route instead: the clone installed as a plugin from source on a local machine, or the HVE-Core plugin or team default in a dev container or codespace, where installing from source is not confirmed.
* A sibling folder such as `../hve-core` or a folder in the home directory is outside the checkout and cannot be declared. Install it as a plugin from source instead.
* The same file can also hold the plugin keys from the team default route. Do not enable the HVE-Core plugin there while the clone's folders are declared, because the agents would then arrive through two routes.
* Commit the file only when everyone who opens the repository gets the same folder. A submodule qualifies, and so does a `.hve-core` folder that committed devcontainer configuration mounts or clones (Methods 3 and 4). A git-ignored clone made by hand (Method 2) does not.

### Method-Specific Instructions

#### Method 1: Peer Clone

Clone to parent directory: `Split-Path $workspaceRoot -Parent | Join-Path -ChildPath "hve-core"`

The peer clone is outside the project's checkout. For the clone route, install it as a plugin from source.

#### Method 2: Git-Ignored

Additional steps before cloning:

1. Create `.hve-core/` directory
2. Add `.hve-core/` to `.gitignore` (create if missing)
3. Clone into `.hve-core/`

For the clone route, install the `.hve-core` folder as a plugin from source. When the user prefers the settings file, declare its folders with the prefix `.hve-core` and keep that declaration out of commits, because other checkouts do not have the git-ignored folder.

#### Method 3: Mounted Directory

Method 3 shares one HVE-Core clone on the host across several devcontainer projects. Each project mounts the clone into a git-ignored `.hve-core/` folder inside its workspace folder. It needs host-side setup and a container rebuild, and it does not work in Codespaces, which has no access to the host file system.

**Step 1:** Display pre-rebuild instructions:

```text
📋 Pre-Rebuild Setup Required

Clone hve-core on your HOST machine (not in container):
  cd <parent-of-your-project>
  git clone https://github.com/microsoft/hve-core.git
```

**Step 2:** After approval under Checkpoint 3, add the mount to devcontainer.json. It mounts the host clone at `.hve-core` inside the container's workspace folder:

<!-- <method-3-devcontainer-mount> -->
```jsonc
{
  "mounts": [
    "source=${localWorkspaceFolder}/../hve-core,target=${containerWorkspaceFolder}/.hve-core,type=bind,readonly=true,consistency=cached"
  ]
}
```
<!-- </method-3-devcontainer-mount> -->

The object form is an alternative:

<!-- <method-3-devcontainer-mount-object> -->
```jsonc
{
  "mounts": [
    {
      "type": "bind",
      "source": "${localWorkspaceFolder}/../hve-core",
      "target": "${containerWorkspaceFolder}/.hve-core"
    }
  ]
}
```
<!-- </method-3-devcontainer-mount-object> -->

**Step 3:** Add `.hve-core/` to `.gitignore` (create if missing) so Git does not pick up the mounted copy:

```text
# Shared HVE Core mount (local only)
.hve-core/
```

**Step 4:** Have the user run **Dev Containers: Rebuild Container**, then validate that the mount exists at `.hve-core` in the project folder.

**Step 5:** Treat `.hve-core` as a pre-existing source. Before Phase 7 collision detection or component copy, apply the upstream-source verification in [component-installation.md](component-installation.md) to `.hve-core`. A missing or unexpected `origin` warns and requires confirmation; it does not automatically reject an intentional fork or local clone.

**Step 6:** For the clone route, declare `.hve-core/.github/agents`, `.hve-core/.github/skills`, and `.hve-core/.github/instructions` in `.github/copilot/settings.json`, following Declare the Clone in `.github/copilot/settings.json` above with `<PREFIX>` set to `.hve-core`, and tell the user its limits.

Installing the mount as a plugin from source, with a path such as `/workspaces/my-project/.hve-core`, is an alternative only when the user confirms that `hve-core` appears on the **Plugins** page, because that route is not confirmed inside a container. When the user takes that alternative, skip the settings file.

#### Method 4: postCreateCommand (Codespaces)

When the user needs no pinned or customized copy, recommend the Team Default Route from Phase 2 instead. That route puts the plugin keys in `.github/copilot/settings.json` and needs no clone. Copilot then offers HVE-Core to everyone who opens the repository in a codespace.

For a pinned or customized copy, clone HVE-Core into `.hve-core/` inside the repository folder. There the copy persists under `/workspaces` and sits inside the checkout, where the settings file can declare it.

**Step 1:** Add `.hve-core/` to `.gitignore` (create if missing):

```text
# HVE Core clone (created by postCreateCommand)
.hve-core/
```

**Step 2:** After approval under Checkpoint 3, add the clone command to devcontainer.json:

<!-- <method-4-devcontainer> -->
```jsonc
{
  "postCreateCommand": "[ -d .hve-core ] || git clone --depth 1 https://github.com/microsoft/hve-core.git .hve-core"
}
```
<!-- </method-4-devcontainer> -->

To pin a version, add `--branch <release-tag>` to the clone command. To refresh the clone each time the codespace starts, also add a `postStartCommand` of `cd .hve-core && git pull --ff-only 2>/dev/null || true`.

**Step 3:** For the clone route, declare `.hve-core/.github/agents`, `.hve-core/.github/skills`, and `.hve-core/.github/instructions` in `.github/copilot/settings.json`, following Declare the Clone in `.github/copilot/settings.json` above with `<PREFIX>` set to `.hve-core`, and tell the user its limits. When the file holds the HVE-Core plugin keys from the team default, remove them so HVE-Core arrives through one route.

**Step 4:** Remind the user to commit `.gitignore`, `devcontainer.json`, and the settings file, then create a new codespace or run **Codespaces: Rebuild Container** in an existing one.

#### Method 5: Multi-Root Workspace

After approval under Checkpoint 3, create `hve-core.code-workspace` file with folders array pointing to both project and HVE-Core.

> [!IMPORTANT]
> The dev container spec has no `workspaceFile` property. Codespaces and devcontainers always open in single-folder mode. The user must manually open the `.code-workspace` file after the container starts (`File > Open Workspace from File...` or `code <path>.code-workspace`). For Codespaces, Method 4 is usually more convenient because it does not require a workspace switch.

Local VS Code: use a relative clone path from the workspace file's directory.

<!-- <method-5-workspace-local> -->
```json
{
  "folders": [
    { "name": "My Project", "path": "." },
    { "path": "../hve-core" }
  ]
}
```
<!-- </method-5-workspace-local> -->

User opens the `.code-workspace` file instead of the folder. The HVE-Core folder is outside the project's checkout, so for the clone route, install it as a plugin from source.

Resolve the HVE-Core folder's actual clone path from the workspace file and treat it as a pre-existing source. Before Phase 7 collision detection or component copy, apply the upstream-source verification in [component-installation.md](component-installation.md). A missing or unexpected `origin` warns and requires confirmation; it does not automatically reject an intentional fork or local clone.

#### Method 6: Submodule

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

For the clone route, pick one connection for the whole team:

* Declare the submodule's folders in `.github/copilot/settings.json` with the prefix `lib/hve-core` and commit the file. Everyone who initializes the submodule and opens the repository in a trusted folder then gets the agents and skills; path-specific instructions from declared folders are not confirmed.
* Or leave the settings file out and have each person install `lib/hve-core` as a plugin from source for the full set.
