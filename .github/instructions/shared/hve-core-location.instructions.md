---
description: "Important: hve-core is the repository containing this instruction file; Guidance: resolve operational .github references from this file's artifact root, including before a workspace-relative lookup or after a failed lookup."
applyTo: "**"
---

# HVE Core Location Guidance

This file's directory tree is the root of hve-core artifacts. When an operational reference starts with `.github/`, or when a referenced file is missing at its expected path, walk up from this file's location to find the artifact root before resolving the reference.

## Distribution Contexts

| Context    | Indicator                        | Artifact Root        |
|------------|----------------------------------|----------------------|
| Repository | `.github/instructions/` exists   | `.github/`           |
| Extension  | File under extension install dir | Extension `.github/` |
| Plugin     | `plugin.json` at root            | Plugin root          |

## File Resolution

Do not resolve a literal `.github/` operational path against the consumer workspace. Walk up this file's tree to the artifact root first, including before the initial lookup when the prefix is already present. In plugin context: agents are in `agents/`, skills in `skills/`, prompts map to `commands/`. Instructions have no direct plugin-equivalent; their content is referenced through source-relative `#file:` directives from agents and prompts, or delivered through the extension. Skill references remain consistent across all contexts.
