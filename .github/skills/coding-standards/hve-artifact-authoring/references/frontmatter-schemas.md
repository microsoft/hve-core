---
description: 'Current frontmatter field reference for HVE Core agents, instructions, and skills'
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

| Field                      | Required | Purpose                                                                    |
|----------------------------|----------|----------------------------------------------------------------------------|
| `name`                     | Yes      | Human-readable picker and dispatch identity                                |
| `description`              | Yes      | Capability and parent-routing metadata                                     |
| `tools`                    | No       | User-managed opaque tool configuration                                     |
| `skills`                   | No       | Skills preloaded into the agent's context at start                         |
| `model`                    | No       | One scalar model selection                                                 |
| `reasoning-effort`         | No       | Reasoning effort for the selected model                                    |
| `user-invocable`           | No       | Picker visibility; false for background-only workers                       |
| `disable-model-invocation` | No       | Prevents model-driven invocation of an orchestrator                        |
| `target`                   | No       | Host execution target                                                      |
| `mcp-servers`              | No       | MCP server declarations; VS Code does not forward them to Copilot sessions |
| `hooks`                    | No       | Preview lifecycle hooks                                                    |

The Copilot harness does not support `handoffs`, `agents`, or `argument-hint` on agents, and
`npm run lint:frontmatter` rejects them. Describe the next agent to switch to, or the subagents to
delegate to, in the body. Do not use an array for an agent or subagent `model` value.

For `tools`, Copilot recognizes the aliases `read`, `edit`, `search`, `execute`, `web`, `agent`, and `todo`,
MCP names in `server/tool` or `server/*` form, `skill`, and `ask_user`, and it ignores names it does
not recognize. An agent cannot activate a skill by name without `skill` in its list, subagents never
receive `ask_user`, and an empty list grants every tool.

## Prompt Files

The Copilot harness does not load prompt files (`.prompt.md`). Write a user-invocable skill instead:
set `user-invocable: true`, put the expected arguments in `argument-hint`, and describe each input
in the body.

## Instruction Frontmatter

| Field         | Required | Purpose                                 |
|---------------|----------|-----------------------------------------|
| `description` | Yes      | Convention and scope summary            |
| `applyTo`     | Yes      | Glob selecting files that receive rules |
| `name`        | No       | Optional display metadata               |

Keep durable project-wide facts in root instructions and path-specific conventions in scoped
instruction files.

## Skill Frontmatter

| Field                      | Required | Purpose                                                            |
|----------------------------|----------|--------------------------------------------------------------------|
| `name`                     | Yes      | Lowercase kebab-case name matching the directory                   |
| `description`              | Yes      | Capability and semantic activation metadata                        |
| `argument-hint`            | No       | User invocation guidance                                           |
| `license`                  | No       | SPDX license expression                                            |
| `user-invocable`           | No       | Slash-command visibility                                           |
| `disable-model-invocation` | No       | Hides the skill from the model, so only its slash command loads it |
| `compatibility`            | No       | Runtime or environment requirements                                |
| `metadata`                 | No       | Authors, specification version, and related facts                  |

Skill frontmatter does not declare `tools`, `model`, `skills`, or `applyTo`. Put reusable
scripts, references, templates, and assets beneath the skill root and reference them with relative
paths.

## Validation

Run the applicable current repository checks:

* `npm run lint:frontmatter`
* `npm run validate:skills` for skill changes
* `npm run plugin:sync` and `npm run plugin:validate` for distributable membership changes
* `npm run docs:generate` and `npm run docs:generate:check` for documentable artifacts
