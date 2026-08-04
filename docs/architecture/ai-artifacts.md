---
title: AI Artifacts Architecture
description: Prompt, agent, and instruction delegation model for Copilot customizations
sidebar_position: 2
author: Microsoft
ms.date: 2026-08-03
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

Maturity is component metadata in `.github/plugin/marketplace.json`, not skill frontmatter. See [Marketplace Identity](#marketplace-identity).

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

## Marketplace Identity

`.github/plugin/marketplace.json` is the sole distribution authority. Every active `plugins[]` entry is an ordinary, self-contained recipe whose standard `agents`, `commands`, `rules`, `skills`, and optional `hooks` fields declare membership. The `x-hve` overlay carries display metadata, component lifecycle maturity, a documentation path, and optional profiles.

`hve-core` is the focused package for RPI workflows, HVE Builder, Git operations, and code review. `hve-core-all` is the full bundle of active content and the only package that declares the starter profile. Domain and utility packages provide narrower capability sets. The catalog remains authoritative for active package names, memberships, maturity, and documentation.

### Shared Projection

`MarketplaceHelpers.psm1` maps each recipe path to a canonical `.github` source, applies lifecycle policy, and closes transitive agent handoffs. An artifact can belong to more than one package recipe when its maturity is aligned for those memberships. Plugin generation and VSIX preparation consume the same resolved source set for each entry before destination mapping. Unresolved or ambiguous handoffs fail validation.

### Lifecycle Labels and Channels

| Lifecycle label | Stable Channel | PreRelease Channel |
|-----------------|----------------|--------------------|
| `stable`        | Included       | Included           |
| `preview`       | Included       | Included           |
| `experimental`  | Included       | Included           |
| `deprecated`    | Excluded       | Excluded           |
| `removed`       | Excluded       | Excluded           |

Component maturity defaults to `stable`. The label discloses lifecycle posture and informs governance; it does not select a release channel. Stable and PreRelease contain the same active package-name set and the same active component and maturity projection for each package. Removed component tombstones may remain in `x-hve.componentMaturity` after active membership is removed so policy checks retain the retirement record.

### Self-Contained Outputs

Every plugin and VSIX contains the complete resolved projection for its catalog entry. The architecture does not use package dependencies, aggregate metadata, `extensionPack`, or `extensionDependencies` to compose advertised content.

## Extension Integration

The VS Code extension discovers and activates AI artifacts through contribution points.

### Discovery Mechanism

The extension scans these directories at startup:

* `.github/prompts/{package-id}/` for workflow entry points
* `.github/agents/{package-id}/` for specialized behaviors
* `.github/instructions/{package-id}/` for technology standards
* `.github/skills/{package-id}/` for utility packages

These paths reflect the conventional directory structure. Artifact inclusion is controlled by standard component paths in `.github/plugin/marketplace.json`. Root-level artifacts (files directly under `.github/{type}/` with no subdirectory) are repo-specific, excluded from discovery, and never packaged into extension builds.

The lifecycle table above applies equally to extension contributions. Stable and PreRelease differ in source ownership, cadence, and version, not component membership.

### Extension Identities

Each active catalog entry projects to one Copilot plugin root and one VSIX identity. The focused `hve-core` entry retains the unsuffixed HVE Core extension identity, `ise-hve-essentials.hve-core`. Other entries use deterministic package-specific identities in the same publisher namespace, `ise-hve-essentials.hve-<package-name>`. These identities are generated from catalog package names and do not indicate that publication has occurred.

The VS Code extension is prepared with `Prepare-Extension.ps1` and packaged with `Package-Extension.ps1`. Copilot packages are generated with `npm run plugin:generate`. Generation creates ignored, materialized regular-file packages under `plugins/<package-name>/`; those local files are validation and distribution output, not reviewed source.

Choose the catalog entry that matches the required scope. Do not install `hve-core` and `hve-core-all` together because their content overlaps. Both plugin entries include the telemetry hook. VS Code has no declarative hook contribution point, so extension users configure hook locations manually.

For a repository-owned selection, the installer requires an exact `PackageName` before it resolves a profile or component. The starter profile belongs only to `hve-core-all`. It copies agents, prompts, instructions, and complete skill directories while preserving repository-relative paths; hooks are not copied.

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

To reactivate an artifact, restore its standard membership path, remove or change the tombstone, regenerate plugin and extension outputs, and run marketplace validation. The validator requires non-vacuous tombstone coverage and complete active-membership coverage for each applicable package recipe.

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
