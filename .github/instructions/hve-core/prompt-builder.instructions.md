---
description: "Legacy Prompt Builder instruction alias that points matching AI artifacts to the canonical HVE Builder standard"
applyTo: '**/*.prompt.md, **/*.agent.md, **/*.instructions.md, **/SKILL.md'
---

# Prompt Builder Compatibility Instructions

Use `hve-builder.instructions.md` as the canonical authoring standard for every matching prompt, agent, subagent, instruction file, and skill.

## Compatibility Boundary

* This file preserves the legacy `prompt-builder` instruction identifier for existing links, eval backlinks, and installed workflows.
* It defines no independent quality rules and does not override `hve-builder.instructions.md`.
* New artifacts refer to `hve-builder.instructions.md`; compatibility consumers may continue resolving this filename.
