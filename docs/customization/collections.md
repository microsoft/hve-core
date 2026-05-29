---
title: Managing Collections
description: Bundle agents, prompts, instructions, and skills into distributable collection packages with maturity filtering
author: Microsoft
ms.date: 2026-03-10
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
packages. Collection membership and metadata start in `collections/core-manifest.yml`,
which is the manual source for collection definitions, artifact assignments, and maturity
values.

The collection pipeline derives package manifests and distributable output from that source:

* `collections/core-manifest.yml` defines collection metadata, artifact membership, and maturity.
* `collections/*.collection.yml` files are generated package manifests consumed by validation,
  extension packaging, and plugin generation.
* `collections/*.collection.md` files provide human-readable collection descriptions.
* `plugins/` contains generated plugin bundles and should not be edited directly.

Generated collection manifests define what each package contains. Markdown descriptions explain
the collection's purpose, list key artifacts, and help users decide whether to install it.
Together, the generated manifest and markdown description form a complete collection package.

> [!IMPORTANT]
> The HVE Core installer skill supports agent bundle selection by collection during clone-based setup. This copies agents only. Prompts, instructions, and skills are not filtered by collection. See the [installation guide](../getting-started/install.md) for setup options.

## Core Manifest Format

Edit `collections/core-manifest.yml` when you add a collection, assign artifacts to a
collection, or change maturity. The core manifest uses a top-level `collections` map keyed by
collection ID. Each collection entry defines the generated manifest path, display metadata,
tags, and item counts used by the collection tooling.

Generated `collections/*.collection.yml` files follow the `collection-manifest.schema.json`
schema. Tooling derives these files from the core manifest workflow. The generated top-level
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

Here is an example generated manifest:

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
| `preview`      | Feature-complete but undergoing validation | Included in all channels    |
| `experimental` | Early-stage, may change significantly      | Excluded from stable builds |
| `deprecated`   | Scheduled for removal                      | Excluded from new builds    |

Maturity applies at two levels in the canonical manifest workflow:

* Collection-level maturity excludes an entire collection from release channels when needed.
* Item-level maturity overrides the collection default for specific artifacts.

When `maturity` is omitted at either level, it defaults to `stable`.

## Creating a Collection

Follow these steps to create a new collection:

1. Choose a collection ID. Use lowercase letters and hyphens (e.g., `sre-operations`).
   The ID must match the pattern `^[a-z0-9-]+$`.

2. Add the collection to `collections/core-manifest.yml`. Define the generated manifest path,
   display name, description, tags, and maturity metadata used by the collection tooling.

3. Create the markdown description at `collections/{id}.collection.md`. Describe the
   collection's purpose, list the key agents and prompts, and explain when to use it.

4. Register each artifact assignment and maturity value through the canonical manifest
  workflow. Verify that every referenced file exists at the specified path.

5. Run the plugin generation pipeline:

   ```bash
   npm run plugin:generate
   ```

6. Validate the collection metadata:

   ```bash
   npm run plugin:validate
   ```

> [!TIP]
> Compare nearby entries in `collections/core-manifest.yml` when adding metadata for a new
> collection. Do not copy and edit generated `*.collection.yml` files as source material.

## Subagent Dependencies

When a parent agent declares subagents in its `agents:` frontmatter, those subagent files
must be included through the canonical manifest workflow. The generated package manifest must
contain both the parent and its required subagents so installed collections have the full
agent capability.

For example, if `rpi-agent.agent.md` references `phase-implementor.agent.md` as a subagent,
both files must appear in the generated collection manifest:

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

The `hve-core-all.collection.yml` manifest is the generated superset of stable artifacts
across every collection. It aggregates items from specialized collections such as `hve-core`,
`ado`, `github`, and `project-planning` into a single comprehensive bundle.

Update `collections/core-manifest.yml` and regenerate outputs when you:

* Add a new artifact to any collection.
* Create a collection.
* Remove or deprecate an existing artifact.

The superset collection ensures users who install the full bundle receive every available
artifact. Items marked with `maturity: experimental` or `maturity: deprecated` remain visible
to tooling but are filtered during stable channel generation.

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
