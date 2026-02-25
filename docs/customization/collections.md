---
title: Managing Collections
description: Bundle agents, prompts, instructions, and skills into distributable collection packages with maturity filtering
author: Microsoft
ms.date: 2026-02-24
ms.topic: how-to
keywords:
  - collections
  - bundling
  - distribution
  - maturity
estimated_reading_time: 6
---

## Collection Architecture

Collections bundle related agents, prompts, instructions, and skills into distributable
packages. Each collection consists of two files in the `collections/` directory:

* A YAML manifest (`*.collection.yml`) that lists every artifact included in the collection
* A markdown description (`*.collection.md`) that provides human-readable documentation

The YAML manifest defines what the collection contains. The markdown description explains
the collection's purpose, lists key artifacts, and helps users decide whether to install it.
Together, these two files form a complete, self-contained collection package that the plugin
generation pipeline processes into distributable output under `plugins/`.

## YAML Manifest Format

Every collection manifest follows the `collection-manifest.schema.json` schema. The top-level
fields are:

| Field         | Required | Description                                                           |
|---------------|----------|-----------------------------------------------------------------------|
| `id`          | Yes      | Unique identifier (lowercase, hyphens only, e.g., `deployment-tools`) |
| `name`        | Yes      | Human-readable display name                                           |
| `description` | Yes      | Brief description of the collection's purpose                         |
| `maturity`    | No       | Collection-level maturity tier (defaults to `stable`)                 |
| `tags`        | No       | Array of discovery tags for filtering and search                      |
| `items`       | Yes      | Array of artifact entries                                             |
| `display`     | No       | Display configuration (ordering: `alpha` or `manual`)                 |

Each entry in the `items` array has these fields:

| Field      | Required | Description                                                         |
|------------|----------|---------------------------------------------------------------------|
| `path`     | Yes      | Relative path from repo root to the source file or directory        |
| `kind`     | Yes      | Artifact type: `agent`, `prompt`, `instruction`, `skill`, or `hook` |
| `maturity` | No       | Item-level maturity override (defaults to `stable`)                 |
| `usage`    | No       | Optional usage guidance for the item                                |

Here is a complete manifest example:

```yaml
id: deployment-tools
name: Deployment Tools
description: CI/CD pipeline agents and deployment automation prompts
tags:
  - deployment
  - ci-cd
  - automation
items:
  # Agents
  - path: .github/agents/deployment/pipeline-builder.agent.md
    kind: agent
  - path: .github/agents/deployment/rollback-advisor.agent.md
    kind: agent
  # Prompts
  - path: .github/prompts/deployment/deploy-staging.prompt.md
    kind: prompt
  # Instructions
  - path: .github/instructions/deployment/pipeline-standards.instructions.md
    kind: instruction
  - path: .github/instructions/shared/hve-core-location.instructions.md
    kind: instruction
  # Skills
  - path: .github/skills/deployment/canary-analysis
    kind: skill
display:
  ordering: manual
```

> [!NOTE]
> The `path` field uses repo-relative paths. Skills reference the skill directory (containing
> `SKILL.md`), not the `SKILL.md` file itself.

## Maturity Filtering

Collections support four maturity tiers that control inclusion in generated plugin output:

| Tier           | Meaning                                    | Plugin Inclusion            |
|----------------|--------------------------------------------|-----------------------------|
| `stable`       | Production-ready, fully tested             | Included in all channels    |
| `preview`      | Feature-complete but undergoing validation | Included in preview channel |
| `experimental` | Early-stage, may change significantly      | Excluded from stable builds |
| `deprecated`   | Scheduled for removal                      | Excluded from new builds    |

Maturity applies at two levels:

* **Collection-level**: Set the `maturity` field on the manifest root. A collection marked
  `experimental` excludes all its items from the stable release channel.
* **Item-level**: Set the `maturity` field on individual items within the `items` array.
  This overrides the collection-level default for specific artifacts.

When `maturity` is omitted at either level, it defaults to `stable`.

## Creating a Collection

Follow these steps to create a new collection:

1. Choose a collection ID. Use lowercase letters and hyphens (e.g., `sre-operations`).
   The ID must match the pattern `^[a-z0-9-]+$`.

2. Create the YAML manifest at `collections/{id}.collection.yml`. Define the `id`, `name`,
   `description`, `tags`, and `items` fields following the schema above.

3. Create the markdown description at `collections/{id}.collection.md`. Describe the
   collection's purpose, list the key agents and prompts, and explain when to use it.

4. Register each artifact in the `items` array with its `path` and `kind`. Verify that
   every referenced file exists at the specified path.

5. Run the plugin generation pipeline:

   ```bash
   npm run plugin:generate
   ```

6. Validate the collection metadata:

   ```bash
   npm run plugin:validate
   ```

> [!TIP]
> Start with an existing collection YAML (such as `hve-core.collection.yml`) as a template.
> Copy the structure and replace the content with your artifacts.

## Subagent Dependencies

When a parent agent declares subagents in its `agents:` frontmatter, those subagent files
must also appear in the collection YAML. The plugin generation pipeline does not
automatically resolve transitive agent dependencies.

For example, if `rpi-agent.agent.md` references `phase-implementor.agent.md` as a subagent,
both files must have entries in the collection manifest:

```yaml
items:
  - path: .github/agents/hve-core/rpi-agent.agent.md
    kind: agent
  - path: .github/agents/hve-core/subagents/phase-implementor.agent.md
    kind: agent
```

Omitting a subagent causes the parent agent to lose access to that capability when installed
from the collection.

## The hve-core-all Superset

The `hve-core-all.collection.yml` manifest serves as the canonical superset of all stable
artifacts across every collection. It aggregates items from specialized collections (such
as `hve-core`, `ado`, `github`, `project-planning`) into a single comprehensive bundle.

Update `hve-core-all.collection.yml` when you:

* Add a new artifact to any collection
* Create an entirely new collection
* Remove or deprecate an existing artifact

The superset collection ensures users who install the full bundle receive every available
artifact. Items marked with `maturity: experimental` or `maturity: deprecated` at the item
level remain in the superset for visibility but are filtered during stable channel generation.

## Role Scenarios

**Tailspin Toys' SRE/Operations lead** creates a `deployment-tools` collection to bundle
pipeline-builder agents, rollback advisors, and deployment prompts into a single
distributable package. The SRE team installs this collection across all service repositories,
giving every engineer access to standardized deployment workflows without manually copying
individual files.

**Contoso's platform architect** creates a `microservices-standards` collection containing
API design instructions, service mesh configuration skills, and architecture review agents.
New teams onboarding to the microservices platform install this single collection to receive
all governance artifacts at once.

## Further Reading

See [docs/contributing/](../contributing/) for collection validation rules and artifact
syntax reference.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
