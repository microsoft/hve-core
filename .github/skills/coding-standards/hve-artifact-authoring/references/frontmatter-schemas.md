---
description: 'Current frontmatter field reference for HVE Core agents, prompts, instructions, and skills'
---

# Frontmatter Schema Reference

Use the repository schemas as the validation authority. This reference summarizes the supported
field boundaries that most often affect artifact design.

## Shared Requirements

* Frontmatter is the first content in the file and uses `---` delimiters.
* `description` is required and states capability plus routing intent.
* Fields belong only to the artifact types named below.
* Omit optional fields rather than adding empty placeholders.

## Agent Frontmatter

| Field                      | Required | Purpose                                              |
|----------------------------|----------|------------------------------------------------------|
| `name`                     | Yes      | Human-readable picker and dispatch identity          |
| `description`              | Yes      | Capability and parent-routing metadata               |
| `argument-hint`            | No       | User invocation guidance                             |
| `agents`                   | No       | Fixed subagent allowlist; omit for unrestricted use  |
| `tools`                    | No       | User-managed opaque tool configuration               |
| `model`                    | No       | One scalar model selection                           |
| `handoffs`                 | No       | User-mediated transitions                            |
| `user-invocable`           | No       | Picker visibility; false for background-only workers |
| `disable-model-invocation` | No       | Prevents model-driven invocation of an orchestrator  |
| `target`                   | No       | Host execution target                                |
| `mcp-servers`              | No       | MCP server declarations                              |
| `hooks`                    | No       | Preview lifecycle hooks                              |

Use `agents: []` when nested dispatch is prohibited. Do not use an array for an agent or subagent
`model` value.

## Prompt Frontmatter

| Field           | Required | Purpose                                         |
|-----------------|----------|-------------------------------------------------|
| `description`   | Yes      | Capability and slash-command routing metadata   |
| `name`          | No       | Explicit slash-command name                     |
| `agent`         | No       | Named custom agent that receives the prompt     |
| `argument-hint` | No       | Parameter guidance                              |
| `model`         | No       | Scalar model or supported ordered fallback list |
| `tools`         | No       | Prompt-specific tool configuration              |

A prompt's tool list overrides the referenced agent's list. Add it only when that narrowing is
intentional.

## Instruction Frontmatter

| Field         | Required | Purpose                                 |
|---------------|----------|-----------------------------------------|
| `description` | Yes      | Convention and scope summary            |
| `applyTo`     | Yes      | Glob selecting files that receive rules |
| `name`        | No       | Optional display metadata               |

Keep durable project-wide facts in root instructions and path-specific conventions in scoped
instruction files.

## Skill Frontmatter

| Field            | Required | Purpose                                           |
|------------------|----------|---------------------------------------------------|
| `name`           | Yes      | Lowercase kebab-case name matching the directory  |
| `description`    | Yes      | Capability and semantic activation metadata       |
| `argument-hint`  | No       | User invocation guidance                          |
| `license`        | No       | SPDX license expression                           |
| `user-invocable` | No       | Slash-command visibility                          |
| `compatibility`  | No       | Runtime or environment requirements               |
| `metadata`       | No       | Authors, specification version, and related facts |

Skill frontmatter does not declare `tools`, `model`, `agent`, `handoffs`, or `applyTo`. Put reusable
scripts, references, templates, and assets beneath the skill root and reference them with relative
paths.

## Validation

Run the applicable current repository checks:

* `npm run lint:frontmatter`
* `npm run validate:skills` for skill changes
* `npm run plugin:sync` and `npm run plugin:validate` for distributable membership changes
* `npm run docs:generate` and `npm run docs:generate:check` for documentable artifacts
