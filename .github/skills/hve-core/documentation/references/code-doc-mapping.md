---
title: Code-to-documentation mapping
description: Mapping of implementation surfaces to the documentation artifacts that should be reviewed for drift.
---

# Code-to-documentation mapping

This reference preserves the mapping used by the former drift checker and makes it
available to the new drift mode.

| Changed path pattern      | Documentation reference                                                                     |
|---------------------------|---------------------------------------------------------------------------------------------|
| `scripts/**`              | `scripts/README.md`, `docs/architecture/workflows.md`                                       |
| `.github/agents/**`       | `docs/agents/`, `docs/contributing/custom-agents.md`, `docs/customization/custom-agents.md` |
| `.github/instructions/**` | `docs/contributing/instructions.md`, `docs/customization/instructions.md`                   |
| `.github/skills/**`       | `docs/contributing/skills.md`, `docs/customization/skills.md`                               |
| `.github/prompts/**`      | `docs/contributing/prompts.md`, `docs/customization/prompts.md`                             |
| `extension/**`            | `extension/PACKAGING.md`                                                                    |
| `collections/**`          | `docs/customization/collections.md`                                                         |
| `.devcontainer/**`        | `docs/getting-started/`, `docs/customization/environment.md`                                |
| `.github/workflows/**`    | `docs/architecture/workflows.md`                                                            |

## Drift assessment heuristics

- Read the relevant documentation before judging accuracy.
- Compare implementation details to documented file paths, commands, behavior, and options.
- Prioritize factual discrepancies over style concerns.
- If the change is purely cosmetic, skip it.
- If no documentation target exists for the changed surface, note that no drift check is
  required.
