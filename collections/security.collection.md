Security review, planning, incident response, risk assessment, vulnerability analysis, supply chain security, and responsible AI assessment for cloud and hybrid environments.

> [!CAUTION]
> The security agents and prompts in this collection are **assistive tools only**. They do not replace professional security tooling (SAST, DAST, SCA, penetration testing, compliance scanners) or qualified human review. All AI-generated security artifacts **must** be reviewed and validated by qualified security professionals before use. AI outputs may contain inaccuracies, miss critical threats, or produce recommendations that are incomplete or inappropriate for your environment.

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

### Chat Agents

| Name                    | Description                                                                                  |
|-------------------------|----------------------------------------------------------------------------------------------|
| **researcher-subagent** | Research subagent using search tools, read tools, fetch web page, github repo, and mcp tools |

### Instructions

| Name                           | Description                                                                                                                                                                                                                                                 |
|--------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **shared/disclaimer-language** | Centralized disclaimer language for AI-assisted planning agents requiring professional review acknowledgment                                                                                                                                                |
| **shared/hve-core-location**   | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

### Skills

| Name             | Description                                                                                                                                                                                                                                                                                                                                                                  |
|------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **pr-reference** | Generates PR reference XML containing commit history and unified diffs between branches with extension and path filtering. Includes utilities to list changed files by type and read diff chunks. Use when creating pull request descriptions, preparing code reviews, analyzing branch changes, discovering work items from diffs, or generating structured diff summaries. |

<!-- END AUTO-GENERATED ARTIFACTS -->
