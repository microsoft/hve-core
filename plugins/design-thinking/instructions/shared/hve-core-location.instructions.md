---
description: "Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree."
applyTo: "**"
---

# HVE Core Location Guidance

This file's directory tree is the root of hve-core artifacts. When a referenced file is missing at its expected path, walk up from this file's location to find the artifact root.

## Distribution Contexts

| Context    | Indicator                        | Artifact Root        |
|------------|----------------------------------|----------------------|
| Repository | `.github/instructions/` exists   | `.github/`           |
| Extension  | File under extension install dir | Extension `.github/` |
| Plugin     | `plugin.json` at root            | Plugin root          |

## File Resolution

When a reference fails, walk up this file's tree to the artifact root. In plugin context: agents are in `agents/`, skills in `skills/`, prompts map to `commands/`. Instructions have no direct plugin-equivalent; their content is referenced via `#file:` from agents and prompts, or delivered via the extension. Skill references remain consistent across all contexts.
