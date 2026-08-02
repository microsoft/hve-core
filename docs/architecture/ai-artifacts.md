---
title: AI Artifacts Architecture
description: Prompt, agent, and instruction delegation model for Copilot customizations
sidebar_position: 2
author: Microsoft
ms.date: 2026-08-02
ms.topic: concept
---

HVE Core provides a four-tier artifact system for customizing GitHub Copilot behavior. Each tier serves a distinct purpose in the delegation chain, enabling structured, reusable AI guidance that flows from user intent to technology-specific standards and executable utilities.

## Artifact Type Hierarchy

The artifact system organizes customizations by scope and responsibility. Prompts handle user interaction, agents orchestrate workflows, instructions encode standards, and skills provide executable utilities.

### Prompts

Prompts (`.prompt.md`) serve as workflow entry points. They capture user intent and translate requests into structured guidance for Copilot execution.

#### Core Characteristics

* Define single-session workflows with clear inputs and outputs
* Accept user inputs through `${input:varName}` template syntax
* Delegate to agents via `agent:` frontmatter references

#### Frontmatter Structure

```yaml
---
description: 'Protocol for creating ADO pull requests'
agent: RPI Agent
---
```

Prompts answer the question "what does the user want to accomplish?" and route execution to appropriate agents.

### Agents

Agents (`.agent.md`) define task-specific behaviors with access to Copilot tools. They orchestrate multi-step workflows and make decisions based on context.

#### Core Characteristics

* Specify available tools through `tools:` frontmatter arrays
* Enable workflow handoffs via `handoffs:` references to other agents
* Maintain conversation context across multiple interactions
* Apply domain expertise through detailed behavioral instructions

#### Frontmatter Structure

```yaml
---
description: 'Orchestrates task planning with research integration'
tools: ['codebase', 'search', 'editFiles', 'changes']
handoffs:
  - label: "Coordinate RPI Work"
    agent: RPI Agent
    prompt: "Coordinate this task through the applicable RPI phases"
    send: true
---
```

Agents answer the question "how should this task be executed?" and coordinate the necessary tools and resources.

### Instructions

Instructions (`.instructions.md`) encode technology-specific standards and conventions. They apply automatically based on file patterns and provide consistent guidance across the codebase.

#### Core Characteristics

* Match files through `applyTo:` glob patterns for automatic application
* Define coding standards, naming conventions, and quality requirements
* Apply to specific languages, frameworks, or file types
* Stack with other instructions when multiple patterns match

#### Frontmatter Structure

```yaml
---
description: 'Python scripting standards with type hints'
applyTo: '**/*.py, **/*.ipynb'
---
```

Instructions answer the question "what standards apply to this context?" and ensure consistent code quality.

#### Repo-Specific Instructions

Instructions placed at the root of `.github/instructions/` (without a subdirectory) are scoped to the hve-core repository itself and MUST NOT be included in marketplace package membership. These files govern internal repository concerns (CI/CD workflows, repo-specific conventions) that are not applicable outside the repository. Root-level artifacts are intentionally excluded from artifact selection and package composition.

> [!IMPORTANT]
> Root-level files under `.github/instructions/` (no subdirectory) are repo-specific and never distributed. Files in subdirectories like `hve-core/`, `ado/`, and `shared/` are package-scoped and distributable.

### Skills

Skills (`.github/skills/<name>/SKILL.md`) provide executable utilities that agents invoke for specialized tasks. Unlike instructions (passive reference), skills contain actual scripts that perform operations.

#### Core Characteristics

* Provide self-contained utility packages with documentation and scripts
* Include parallel implementations for cross-platform support (`.sh` and `.ps1`)
* Execute actual operations rather than providing guidance

#### Directory Structure (by Convention)

```text
.github/skills/{package-id}/<skill-name>/
├── SKILL.md           # Required entry point with frontmatter
├── scripts/
│   ├── convert.sh     # Bash implementation
│   └── convert.ps1    # PowerShell implementation
└── examples/
    └── README.md      # Usage examples
```

#### Frontmatter Structure

```yaml
---
name: video-to-gif
description: 'Video-to-GIF conversion with FFmpeg optimization'
---
```

#### Required Frontmatter Fields

| Field         | Description                                             |
|---------------|---------------------------------------------------------|
| `name`        | Lowercase kebab-case identifier matching directory name |
| `description` | Brief capability description                            |

Maturity is package metadata in `.github/plugin/marketplace.json`, not skill frontmatter. See [Marketplace Packages](#marketplace-packages).

Skills answer the question "what specialized utility does this task require?" and provide executable capabilities beyond conversational guidance.

#### Key Distinction from Instructions

| Aspect     | Instructions                | Skills                |
|------------|-----------------------------|-----------------------|
| Nature     | Passive reference           | Active execution      |
| Content    | Standards and conventions   | Scripts and utilities |
| Activation | Automatic via glob patterns | Explicit invocation   |
| Output     | Guidance for Copilot        | Executed operations   |

## Delegation Flow

The artifact system follows a hierarchical delegation model. User requests flow through prompts to agents, which apply relevant instructions during execution.

```mermaid
graph LR
    USER[User Request] --> PROMPT[Prompt]
    PROMPT --> AGENT[Agent]
    AGENT --> INSTR[Instructions]
    AGENT --> SKILLS[Skills]
```

### Flow Mechanics

1. User invokes a prompt through `/prompt` commands or workflow triggers.
2. Prompt references an agent via `agent:` frontmatter, delegating execution.
3. Agent executes with instructions auto-applied based on file context.
4. Agent invokes skills for specialized utilities with executable scripts.

This delegation model separates concerns. Prompts handle user interaction, agents manage orchestration, and instructions provide standards.

## Interface Contracts

Each artifact type defines clear interfaces for interoperability.

### Prompt-to-Agent References

Prompts reference agents through the `agent:` frontmatter field:

```yaml
---
description: 'Create a pull request with work item linking'
agent: 'pr-creator'
---
```

The referenced agent file (`pr-creator.agent.md`) is typically organized under `.github/agents/{package-id}/` by convention. When a user invokes the prompt, Copilot activates the specified agent with the prompt's context.

### Instruction Glob Patterns

Instructions use `applyTo:` patterns for automatic activation:

| Pattern                      | Matches                              |
|------------------------------|--------------------------------------|
| `**/*.py`                    | All Python files recursively         |
| `**/tests/**/*.ts`           | TypeScript files in test directories |
| `**/.copilot-tracking/pr/**` | PR tracking files                    |

Multiple instructions can apply to the same file. When patterns overlap, all matching instructions contribute guidance. Pattern specificity determines precedence for conflicting directives.

### Skill Entry Points

Skills provide self-contained utilities through the `SKILL.md` file:

```text
.github/skills/{package-id}/<skill-name>/
├── SKILL.md                    # Entry point documentation
├── convert.sh                  # Bash implementation
├── convert.ps1                 # PowerShell implementation
└── examples/
    └── README.md
```

The `{package-id}` path segment reflects the conventional organization; artifacts can reside in any subfolder.

Copilot discovers skills automatically when their description matches the current task context. Skills can also be referenced explicitly by name. The skill's `SKILL.md` documents prerequisites, parameters, and usage patterns. Cross-platform scripts ensure consistent behavior across operating systems.

## Marketplace Packages

`.github/plugin/marketplace.json` is the sole package-definition authority. Standard `agents`, `commands`, `rules`, `skills`, and `hooks` fields declare membership. The `x-hve` overlay contains only display name, package and component maturity, documentation, and aggregate status.

### Shared Projection

`MarketplaceHelpers.psm1` maps package paths to canonical `.github` sources, applies channel maturity, and closes transitive agent handoffs. Plugin generation and VSIX preparation consume the same resolved source sets before destination mapping. Unresolved or ambiguous handoffs fail validation.

### Package Channels

| Maturity       | Stable Channel | Pre-release Channel |
|----------------|----------------|---------------------|
| `stable`       | Included       | Included            |
| `preview`      | Excluded       | Included            |
| `experimental` | Excluded       | Included            |
| `deprecated`   | Excluded       | Excluded            |
| `removed`      | Excluded       | Excluded            |

Component maturity defaults to `stable`. Removed component tombstones may remain in `x-hve.componentMaturity` after active membership is removed so policy checks retain the retirement record.

### Self-Contained Outputs

Every plugin and VSIX package contains its complete resolved projection. The architecture does not use plugin dependencies, `extensionPack`, or `extensionDependencies` to compose advertised content. `hve-core-all` is the validated aggregate and must cover every eligible PreRelease component.

## Extension Integration

The VS Code extension discovers and activates AI artifacts through contribution points.

### Discovery Mechanism

The extension scans these directories at startup:

* `.github/prompts/{package-id}/` for workflow entry points
* `.github/agents/{package-id}/` for specialized behaviors
* `.github/instructions/{package-id}/` for technology standards
* `.github/skills/{package-id}/` for utility packages

These paths reflect the conventional directory structure. Artifact inclusion is controlled by standard component paths in `.github/plugin/marketplace.json`. Root-level artifacts (files directly under `.github/{type}/` with no subdirectory) are repo-specific, excluded from discovery, and never packaged into extension builds.

| Maturity       | Stable Channel | Pre-release Channel |
|----------------|----------------|---------------------|
| `stable`       | Included       | Included            |
| `preview`      | Excluded       | Included            |
| `experimental` | Excluded       | Included            |
| `deprecated`   | Excluded       | Excluded            |
| `removed`      | Excluded       | Excluded            |

The maturity table above applies to component metadata; package-level maturity is also read from the marketplace overlay.

### Extension Package Identities

Each package produces two distributable outputs from the same codebase: a VS Code extension (`.vsix`) and a Copilot plugin published through the repository marketplace.

| Package          | Extension ID                              | Contents                                        |
|------------------|-------------------------------------------|-------------------------------------------------|
| Core (flagship)  | `ise-hve-essentials.hve-core`             | RPI workflow and core artifacts                 |
| Full             | `ise-hve-essentials.hve-core-all`         | All artifacts eligible for the selected channel |
| ADO              | `ise-hve-essentials.hve-ado`              | Azure DevOps integration                        |
| GitHub           | `ise-hve-essentials.hve-github`           | GitHub backlog and issue management             |
| GitLab           | `ise-hve-essentials.hve-gitlab`           | GitLab merge request and pipeline management    |
| Jira             | `ise-hve-essentials.hve-jira`             | Jira backlog and requirements management        |
| Project Planning | `ise-hve-essentials.hve-project-planning` | Architecture, requirements, agile coaching      |
| RPI              | `ise-hve-essentials.hve-rpi`              | Research, Plan, Implement, and Review workflow  |
| Coding Standards | `ise-hve-essentials.hve-coding-standards` | Language-specific coding conventions            |
| Data Science     | `ise-hve-essentials.hve-data-science`     | Notebooks, dashboards, data analysis            |
| Security         | `ise-hve-essentials.hve-security`         | Security review, planning, and threat modeling  |
| Design Thinking  | `ise-hve-essentials.hve-design-thinking`  | 9-method DT coaching and learning               |
| Installer        | `ise-hve-essentials.hve-installer`        | HVE Core installation and setup                 |
| Experimental     | `ise-hve-essentials.hve-experimental`     | Early-stage artifacts under active iteration    |

The VS Code extension is built with `Prepare-Extension.ps1` and `Package-Extension.ps1`. Copilot packages are generated with `npm run plugin:generate` from the standard component fields in `.github/plugin/marketplace.json`.

Generation creates ignored, materialized regular-file packages under `plugins/<package-name>/`; those local files are validation and distribution output, not reviewed source. VSIX preparation consumes the same marketplace projection as plugin generation.

Users install the package matching their role for a curated experience. The **Core** extension provides the RPI workflow essentials, while the **Full** extension aggregates artifacts from all eligible marketplace packages.

### Activation Context

Instructions activate based on the current file's path matching `applyTo:` patterns. Prompts and agents activate through explicit user invocation. Skills activate when agents or users request their utilities.

The extension provides these contribution points:

* `/prompt <name>` invokes prompts by filename.
* Agents activate through prompt references or direct invocation.
* Matching instructions inject into Copilot context automatically.

## Deprecated Artifacts

Artifacts that have been superseded or are scheduled for removal live under `.github/deprecated/{type}/`, preserving the same type subdirectories used by active artifacts.

### Location

```text
.github/deprecated/
├── agents/         # Superseded agent files
├── instructions/   # Retired instruction files
├── prompts/        # Retired prompt files
└── skills/         # Retired skill packages
```

### Automatic Exclusion

The build system excludes `.github/deprecated/` contents from all downstream surfaces:

| Surface              | Exclusion Mechanism                         |
|----------------------|---------------------------------------------|
| Marketplace packages | Catalog membership and source containment   |
| Plugin generation    | `Get-ArtifactFiles` path filter             |
| Extension packaging  | Discovery function `deprecated` path filter |
| VS Code activation   | Not discovered at runtime                   |

Remove deprecated paths from marketplace membership when an artifact moves to `.github/deprecated/`. The path-based exclusion operates independently of `maturity` metadata, providing a reliable safety net against silent reintroduction.

### Retention and Removal

Deprecated artifacts remain in the repository for traceability and migration guidance. Each deprecated file SHOULD contain a frontmatter note or heading that identifies its replacement. Permanent removal occurs at a planned retirement window with a corresponding changelog entry.

### When to Deprecate

Move an artifact to `.github/deprecated/{type}/` when:

* A newer artifact fully replaces its functionality
* The artifact is no longer maintained or tested
* The artifact targets a retired platform or workflow

## Removed Artifacts

The `removed` maturity is an `x-hve.componentMaturity` tombstone keyed by package-relative component path. It removes an artifact from every generated distribution while retaining policy history without adding maturity to artifact frontmatter.

To reactivate an artifact, restore its standard membership path, remove or change the tombstone, regenerate plugin and extension outputs, and run marketplace validation. The validator requires non-vacuous tombstone coverage and the aggregate package must continue to cover every active eligible component.

| Mechanism                  | Signal                      | Distribution behavior                 |
|----------------------------|-----------------------------|---------------------------------------|
| `deprecated` maturity      | Sunset in progress          | Excluded from both channels           |
| `removed` tombstone        | Withdrawn from distribution | Excluded while policy history remains |
| `.github/deprecated/` path | Archived source             | Excluded by source containment rules  |

## Related Documentation

* [Agent Systems Catalog](../agents/) - Overview of all agent systems with workflow documentation
* [AI Artifacts Common Standards](../contributing/ai-artifacts-common.md) - Quality requirements for all artifacts
* [Contributing Prompts](../contributing/prompts.md) - Prompt file specifications
* [Contributing Agents](../contributing/custom-agents.md) - Agent file specifications
* [Contributing Instructions](../contributing/instructions.md) - Instruction file specifications
* [Contributing Skills](../contributing/skills.md) - Skill package specifications

🤖 *Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
