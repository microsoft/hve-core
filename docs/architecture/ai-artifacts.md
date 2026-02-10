---
title: AI Artifacts Architecture
description: Prompt, agent, and instruction delegation model for Copilot customizations
author: Microsoft
ms.date: 2026-01-22
ms.topic: concept
---

HVE Core provides a four-tier artifact system for customizing GitHub Copilot behavior. Each tier serves a distinct purpose in the delegation chain, enabling structured, reusable AI guidance that flows from user intent to technology-specific standards and executable utilities.

## Artifact Type Hierarchy

The artifact system organizes customizations by scope and responsibility. Prompts handle user interaction, agents orchestrate workflows, instructions encode standards, and skills provide executable utilities.

### Prompts

Prompts (`.prompt.md`) serve as workflow entry points. They capture user intent and translate requests into structured guidance for Copilot execution.

**Core characteristics:**

* Define single-session workflows with clear inputs and outputs
* Accept user inputs through `${input:varName}` template syntax
* Delegate to agents via `agent:` frontmatter references

**Frontmatter structure:**

```yaml
---
description: 'Protocol for creating ADO pull requests'
agent: 'task-planner'
---
```

Prompts answer the question "what does the user want to accomplish?" and route execution to appropriate agents.

### Agents

Agents (`.agent.md`) define task-specific behaviors with access to Copilot tools. They orchestrate multi-step workflows and make decisions based on context.

**Core characteristics:**

* Specify available tools through `tools:` frontmatter arrays
* Enable workflow handoffs via `handoffs:` references to other agents
* Maintain conversation context across multiple interactions
* Apply domain expertise through detailed behavioral instructions

**Frontmatter structure:**

```yaml
---
description: 'Orchestrates task planning with research integration'
tools: ['codebase', 'search', 'editFiles', 'changes']
handoffs: ['task-implementor', 'task-researcher']
---
```

Agents answer the question "how should this task be executed?" and coordinate the necessary tools and resources.

### Instructions

Instructions (`.instructions.md`) encode technology-specific standards and conventions. They apply automatically based on file patterns and provide consistent guidance across the codebase.

**Core characteristics:**

* Match files through `applyTo:` glob patterns for automatic application
* Define coding standards, naming conventions, and quality requirements
* Apply to specific languages, frameworks, or file types
* Stack with other instructions when multiple patterns match

**Frontmatter structure:**

```yaml
---
description: 'Python scripting standards with type hints'
applyTo: '**/*.py, **/*.ipynb'
---
```

Instructions answer the question "what standards apply to this context?" and ensure consistent code quality.

#### Repo-Specific Instructions

Instructions placed in `.github/instructions/hve-core/` are scoped to the hve-core repository itself and MUST NOT be registered as AI artifacts. These files govern internal repository concerns (CI/CD workflows, repo-specific conventions) that are not applicable outside the repository. The build system and registry validation automatically exclude this subdirectory from artifact discovery and orphan detection.

> [!IMPORTANT]
> The `.github/instructions/hve-core/` directory is reserved for repo-specific instructions. Files in this directory are never distributed through extension packages or persona collections.

### Skills

Skills (`.github/skills/<name>/SKILL.md`) provide executable utilities that agents invoke for specialized tasks. Unlike instructions (passive reference), skills contain actual scripts that perform operations.

**Core characteristics:**

* Provide self-contained utility packages with documentation and scripts
* Include parallel implementations for cross-platform support (`.sh` and `.ps1`)
* Execute actual operations rather than providing guidance
* Declare maturity level controlling extension channel inclusion

**Directory structure:**

```text
.github/skills/<skill-name>/
├── SKILL.md           # Required entry point with frontmatter
├── scripts/
│   ├── convert.sh     # Bash implementation
│   └── convert.ps1    # PowerShell implementation
└── examples/
    └── README.md      # Usage examples
```

**Frontmatter structure:**

```yaml
---
name: video-to-gif
description: 'Video-to-GIF conversion with FFmpeg optimization'
maturity: stable
---
```

**Required frontmatter fields:**

| Field         | Description                                             |
|---------------|---------------------------------------------------------|
| `name`        | Lowercase kebab-case identifier matching directory name |
| `description` | Brief capability description                            |
| `maturity`    | `stable`, `preview`, `experimental`, or `deprecated`    |

Skills answer the question "what specialized utility does this task require?" and provide executable capabilities beyond conversational guidance.

**Key distinction from instructions:**

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

**Flow mechanics:**

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

The referenced agent file (`pr-creator.agent.md`) must exist in `.github/agents/`. When a user invokes the prompt, Copilot activates the specified agent with the prompt's context.

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
.github/skills/<skill-name>/
├── SKILL.md                    # Entry point documentation
├── convert.sh                  # Bash implementation
├── convert.ps1                 # PowerShell implementation
└── examples/
    └── README.md
```

Copilot discovers skills automatically when their description matches the current task context. Skills can also be referenced explicitly by name. The skill's `SKILL.md` documents prerequisites, parameters, and usage patterns. Cross-platform scripts ensure consistent behavior across operating systems.

## Artifact Registry

The artifact registry (`.github/ai-artifacts-registry.json`) serves as the central metadata store for all AI artifacts. It enables persona-based distribution, maturity filtering, and dependency resolution without polluting individual artifact frontmatter.

### Registry Architecture

```text
┌─────────────────────────────────────────────────────────────────────┐
│                     AI Artifacts Registry                            │
│  .github/ai-artifacts-registry.json                                  │
│  ┌─────────────────┬─────────────────┬─────────────────┐            │
│  │ Agents          │ Prompts         │ Instructions    │            │
│  │ - maturity      │ - maturity      │ - maturity      │            │
│  │ - personas[]    │ - personas[]    │ - personas[]    │            │
│  │ - tags[]        │ - tags[]        │ - tags[]        │            │
│  │ - requires{}    │                 │                 │            │
│  └─────────────────┴─────────────────┴─────────────────┘            │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         Build System                                 │
│  ┌─────────────────┐    ┌─────────────────┐                         │
│  │ Collection      │    │ Prepare-        │                         │
│  │ Manifests       │───▶│ Extension.ps1   │                         │
│  │ *.collection.json    │ -Collection     │                         │
│  └─────────────────┘    └─────────────────┘                         │
└─────────────────────────────────────────────────────────────────────┘
```

### Registry Entry Structure

Each artifact entry contains metadata for filtering and dependency resolution:

```json
{
    "artifact-name": {
        "maturity": "stable",
        "personas": ["hve-core-all", "developer"],
        "tags": ["rpi", "workflow"],
        "requires": {
            "agents": ["dependency-agent"],
            "prompts": ["dependency-prompt"],
            "instructions": ["dependency-instructions"],
            "skills": []
        }
    }
}
```

| Field      | Purpose                                         |
|------------|-------------------------------------------------|
| `maturity` | Controls extension channel inclusion            |
| `personas` | Determines collection membership                |
| `tags`     | Categorization for organization and discovery   |
| `requires` | Declares dependencies for complete installation |

### Persona Model

Personas represent user roles that consume artifacts. The registry defines these personas:

| Persona       | Identifier     | Target Users        |
|---------------|----------------|---------------------|
| **All**       | `hve-core-all` | Universal inclusion |
| **Developer** | `developer`    | Software engineers  |

Artifacts assigned to `hve-core-all` appear in the full collection and may also include role-specific personas for targeted distribution.

### Collection Build System

Collections define persona-filtered artifact packages. Each collection manifest specifies which personas to include and controls release channel eligibility through a `maturity` field:

```json
{
    "id": "developer",
    "name": "hve-developer",
    "displayName": "HVE Core - Developer Edition",
    "description": "AI-powered coding agents curated for software engineers",
    "maturity": "stable",
    "personas": ["developer"]
}
```

The build system resolves collections by:

1. Reading the collection manifest to identify target personas
2. Checking collection-level maturity against the target release channel
3. Filtering registry entries by persona membership
4. Including the `hve-core-all` persona artifacts as the base
5. Adding persona-specific artifacts
6. Resolving dependencies for included artifacts

#### Collection Maturity

Collections carry their own maturity level, independent of artifact-level maturity. This controls whether the entire collection is built for a given release channel:

| Collection Maturity | PreRelease Channel | Stable Channel |
| ------------------- | ------------------ | -------------- |
| `stable`            | Included           | Included       |
| `preview`           | Included           | Included       |
| `experimental`      | Included           | Excluded       |
| `deprecated`        | Excluded           | Excluded       |

New collections should start as `experimental` until validated, then transition to `stable` by changing a single field. The `maturity` field is optional and defaults to `stable` when omitted.

### Dependency Resolution

Agents may declare dependencies on other artifacts through the `requires` field. The dependency resolver ensures complete artifact graphs are installed:

```mermaid
graph TD
    A[rpi-agent] --> B[task-researcher]
    A --> C[task-planner]
    A --> D[task-implementor]
    A --> E[task-reviewer]
    A --> F[checkpoint.prompt]
    A --> G[rpi.prompt]
```

When installing `rpi-agent`, all dependent agents and prompts are automatically included regardless of persona filter.

## Extension Integration

The VS Code extension discovers and activates AI artifacts through contribution points.

### Discovery Mechanism

The extension scans these directories at startup:

* `.github/prompts/` for workflow entry points
* `.github/agents/` for specialized behaviors
* `.github/instructions/` for technology standards (excluding `hve-core/` subdirectory)
* `.github/skills/` for utility packages

Artifact inclusion is controlled by the registry. Repo-specific instructions under `.github/instructions/hve-core/` are excluded from discovery and never packaged into extension builds.

| Maturity       | Stable Channel | Pre-release Channel |
|----------------|----------------|---------------------|
| `stable`       | Included       | Included            |
| `preview`      | Excluded       | Included            |
| `experimental` | Excluded       | Included            |
| `deprecated`   | Excluded       | Excluded            |

The maturity table above applies to individual artifacts. Collections also carry a `maturity` field that gates the entire package at the channel level (see [Collection Maturity](#collection-maturity)).

### Collection Packages

Multiple extension packages can be built from the same codebase:

| Collection | Extension ID                       | Contents                    |
|------------|------------------------------------|-----------------------------|
| Full       | `ise-hve-essentials.hve-core`      | All stable artifacts        |
| Developer  | `ise-hve-essentials.hve-developer` | Developer-focused artifacts |

Users install the collection matching their role for a curated experience.

### Activation Context

Instructions activate based on the current file's path matching `applyTo:` patterns. Prompts and agents activate through explicit user invocation. Skills activate when agents or users request their utilities.

The extension provides these contribution points:

* `/prompt <name>` invokes prompts by filename.
* Agents activate through prompt references or direct invocation.
* Matching instructions inject into Copilot context automatically.

## Related Documentation

* [AI Artifacts Common Standards](../contributing/ai-artifacts-common.md) - Quality requirements for all artifacts
* [Contributing Prompts](../contributing/prompts.md) - Prompt file specifications
* [Contributing Agents](../contributing/custom-agents.md) - Agent file specifications
* [Contributing Instructions](../contributing/instructions.md) - Instruction file specifications
* [Contributing Skills](../contributing/skills.md) - Skill package specifications

🤖 *Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
