---
description: "Path resolution rules for hve-core artifacts and workspace tracking files"
applyTo: "**"
---

# HVE Core Path Resolution

## HVE Core Root

The hve-core root is the ancestor directory that contains the artifact tree
(agents, instructions, skills, prompts). Locate it by walking up from this
instruction file's disk path until reaching a directory whose children include
an `instructions/` folder.

The hve-core root varies by installation context, and the artifact subtree
may or may not sit inside a `.github/` directory:

| Context              | HVE core root                                          | Artifact prefix |
|----------------------|--------------------------------------------------------|-----------------|
| In-repo              | Workspace root (e.g., `/workspaces/hve-core/`)        | `.github/`      |
| VS Code extension    | Extension install (e.g., `~/.vscode-server-insiders/extensions/ise-hve-essentials.hve-**-<version>/`) | `.github/` |
| Copilot CLI plugin   | Plugin directory (e.g., `~/.copilot/installed-plugins/_direct/hve-**/`) | *(none)* |
| Peer clone           | Sibling directory (e.g., `../hve-core/`)               | `.github/`      |

In the CLI plugin context, artifacts like skills and agents live directly
under the plugin root (`skills/`, `agents/`) without a `.github/` parent.

## Path Resolution Rules

### Artifact paths (`.github/` prefixed)

When prose text references a path starting with `.github/` (e.g.,
`.github/agents/**/researcher-subagent.agent.md`):

1. Compute the hve-core root from this instruction file's disk location.
2. Join the hve-core root with the referenced path.
3. If the file is not found, retry after stripping the `.github/` prefix
   (covers the Copilot CLI plugin layout).
4. If still not found, fall back to a workspace-root search.

### Workspace paths (`.copilot-tracking/`)

Paths starting with `.copilot-tracking/` reference session artifacts in the
user's workspace. Always resolve these relative to the workspace root (the
folder open in VS Code or the working directory in CLI), never relative to
the hve-core root.

### `#file:` directives

`#file:` references resolve relative to the containing file's disk location
automatically. Prefer `#file:` in agent and instruction files when the
artifact must pull in the full contents of another hve-core file, since this
works correctly regardless of installation method.