---
title: Code-to-documentation mapping
description: Mapping of implementation surfaces to the documentation artifacts that should be reviewed for drift.
---

# Code-to-documentation mapping

This reference preserves the mapping used by the former drift checker and makes it
available to the new drift mode. For a documentable AI artifact, inspect its paired
asset reference page before the broader conceptual and contributor documentation.

| Changed path pattern                                 | Paired asset reference                         | Additional documentation to review                                                          |
|------------------------------------------------------|------------------------------------------------|---------------------------------------------------------------------------------------------|
| `.github/agents/<path>/<name>.agent.md`              | `docs/reference/agents/<path>/<name>.md`       | `docs/agents/`, `docs/contributing/custom-agents.md`, `docs/customization/custom-agents.md` |
| `.github/prompts/<path>/<name>.prompt.md`            | `docs/reference/prompts/<path>/<name>.md`      | `docs/contributing/prompts.md`, `docs/customization/prompts.md`                             |
| `.github/instructions/<path>/<name>.instructions.md` | `docs/reference/instructions/<path>/<name>.md` | `docs/contributing/instructions.md`, `docs/customization/instructions.md`                   |
| `.github/skills/<path>/<skill>/**`                   | `docs/reference/skills/<path>/<skill>.md`      | `docs/contributing/skills.md`, `docs/customization/skills.md`                               |
| `scripts/**`                                         | Not applicable                                 | `scripts/README.md`, `docs/architecture/workflows.md`                                       |
| `extension/**`                                       | Not applicable                                 | `extension/PACKAGING.md`                                                                    |
| `collections/**`                                     | Not applicable                                 | `docs/customization/collections.md`                                                         |
| `.devcontainer/**`                                   | Not applicable                                 | `docs/getting-started/`, `docs/customization/environment.md`                                |
| `.github/workflows/**`                               | Not applicable                                 | `docs/architecture/workflows.md`                                                            |

The placeholder `<path>` preserves every directory between the artifact kind and
the asset name, including nested `subagents/` directories. A skill has one paired
page for its whole directory; changes to `SKILL.md`, `references/`, `scripts/`, or
other files in that directory all map to the same page. Root-level repo-specific
artifacts and deprecated artifacts are not documentable and have no paired page.

## Drift assessment heuristics

- Read the paired asset reference page first when the changed path matches an AI
  artifact mapping.
- Confirm the paired page exists, its generated regions describe the current source,
  and its authored usage sections remain accurate after the change.
- Review the additional conceptual and contributor documentation when behavior,
  invocation, file paths, commands, or options changed.
- Prioritize factual discrepancies over style concerns.
- If the change is purely cosmetic, skip it.
- If no documentation target exists for the changed surface, note that no drift check is
  required.
