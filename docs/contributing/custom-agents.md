---
title: 'Contributing Agents to HVE Core'
description: 'Requirements and standards for contributing GitHub Copilot agent files to hve-core'
sidebar_position: 5
author: Microsoft
ms.date: 2026-11-06
ms.topic: how-to
keywords:
  - contributing
  - custom agents
  - standards
---

This guide defines the requirements, standards, and best practices for contributing GitHub Copilot agent files (`.agent.md`) to the hve-core library. HVE Core agents target the Copilot agent harness, the Copilot SDK runtime that VS Code uses by default and that also runs Copilot CLI.

⚙️ Common Standards: See [AI Artifacts Common Standards](ai-artifacts-common) for shared requirements (XML blocks, markdown quality, RFC 2119, validation, testing).

## What is an Agent?

An **agent** is a specialized AI configuration that defines behavior, available tools, and instructions for GitHub Copilot to follow when performing specific tasks. Agents enable consistent, repeatable workflows for complex development activities.

## Use Cases for Agents

Create an agent when you need to:

* Define a specialized AI agent role (e.g., security reviewer, PR analyzer, documentation generator)
* Orchestrate multi-step workflows requiring specific tool sequences
* Maintain consistent behavior patterns across development tasks
* Provide domain-specific expertise (e.g., ADR creation, work item processing)
* Automate complex decision-making with predefined logic flows

## Agents Not Accepted

The following agent types will likely be **rejected or closed automatically** because equivalent agents already exist in hve-core:

### Duplicate Agent Categories

#### Research or Discovery Agents

Agents that search for, gather, or discover information.

* ❌ Reason: Existing agents already handle research and discovery workflows
* ✅ Alternative: Use existing research-focused agents in `.github/agents/`

#### Indexing or Referencing Agents

Agents that catalog, index, or create references to existing projects.

* ❌ Reason: Existing agents already provide indexing and referencing capabilities
* ❌ Tool integration: Widely supported tools built into VS Code GitHub Copilot and MCP tools with extremely wide adoption are already supported by existing hve-core agents
* ✅ Alternative: Use existing reference management agents that use standard VS Code GitHub Copilot tools and widely-adopted MCP tools

#### Planning Agents

Agents that plan work, break down tasks, or organize backlog items.

* ❌ Reason: Existing agents already handle work planning and task organization
* ✅ Alternative: Use existing planning-focused agents in `.github/agents/`

#### Implementation Agents

General-purpose coding agents that implement features.

* ❌ Reason: Existing agents already provide implementation guidance
* ✅ Alternative: Use existing implementation-focused agents

### Rationale for Rejection

These agent types are rejected because:

1. Existing agents are hardened and heavily used: the hve-core library already contains production-tested agents in these categories
2. Consistency and maintenance: coalescing around existing agents reduces fragmentation and maintenance burden
3. Avoid duplication: multiple agents serving the same purpose create confusion and divergent behavior
4. Standard tooling already integrated: VS Code GitHub Copilot built-in tools and widely-adopted MCP tools are already used by existing agents

### Before Submitting

When planning to submit an agent that falls into these categories:

1. Question necessity: does your use case truly require a new agent, or can existing agents meet your needs?
2. Review existing agents: examine `.github/agents/` to identify agents that already serve your purpose
3. Check tool integration: verify whether the VS Code GitHub Copilot tools or MCP tools you need are already used by existing agents
4. Consider enhancement over creation: if existing agents don't fully meet your requirements, evaluate whether your changes are generic enough to benefit all users and valuable enough to justify modifying the existing agent
5. Propose enhancements: submit a PR to enhance an existing agent rather than creating a duplicate

### What Makes a Good New Agent

Focus on agents that:

| Criterion            | Description                                                                                     |
|----------------------|-------------------------------------------------------------------------------------------------|
| Fill gaps            | Address use cases not covered by existing agents                                                |
| Provide unique value | Offer specialized domain expertise or workflow patterns not present in the library              |
| Are non-overlapping  | Have clearly distinct purposes from existing agents                                             |
| Cannot be merged     | Represent functionality too specialized or divergent to integrate into existing agents          |
| Use standard tooling | Use widely-supported VS Code GitHub Copilot tools and MCP tools rather than custom integrations |

### Model Version Requirements

All agents **MUST** target models listed in the model catalog (`scripts/linting/model-catalog.json`). The catalog defines which models are available in GitHub Copilot and which providers are accepted via the `providerAllowlist` field. Catalog membership is a validity check; use it alongside the responsibility-based profile selection in [Model Selection for Subagents](#model-selection-for-subagents) rather than as a free choice among catalog entries.

Accepted: A canonical profile scalar (see below) or any other model in the catalog whose provider appears in `providerAllowlist` and whose status is `ga` or `preview`, when a narrow, disclosed override justifies deviating from the canonical scalar

Not Accepted: Models not present in the catalog, models from providers outside the `providerAllowlist`, custom/fine-tuned models, models with `retiring` or `retired` status

### Model Selection for Subagents

The `model` frontmatter property is **optional** and, per the [official custom agents configuration reference](https://docs.github.com/en/copilot/reference/custom-agents-configuration), must be a single **string** for GitHub.com, the Copilot CLI, and supported IDEs. When omitted, a subagent inherits the invoking parent's model, and a directly invoked agent uses the current session or model-picker selection.

When a stable model is needed, select a responsibility profile first (High, Medium, or Low; see the "Choose the model profile" section of the `hve-builder` skill's `artifact-types.md` reference), then declare that profile's canonical scalar:

```yaml
# Low profile: bounded, literal, mechanical execution
model: GPT-6 Luna (copilot)
```

```yaml
# Medium profile: semantic discovery, authoring, or calibrated review
model: GPT-6 Sol (copilot)
```

```yaml
# Subagent that writes code — omit model to inherit session model
# (no model property)
```

Do not use a YAML array for `model` (for example, a list of fallback models). Copilot CLI versions before the fix for [github/copilot-cli#2133](https://github.com/github/copilot-cli/issues/2133) rejected an array with `model: Expected string, received array` and dropped the agent, and the HVE Core model linter still reports an array as an error.

Run `npm run lint:models` to validate model references against the catalog. It also reports an array-form `model` on an agent as an error.

## File Structure Requirements

### Location

Agent files are typically organized in a package subdirectory by convention:

```text
.github/agents/{package-id}/
├── your-agent-name.agent.md
└── subagents/
    └── your-subagent-name.agent.md
```

> [!NOTE]
> Tracked agents beneath a `.github/agents/<package>/` subdirectory are included automatically when `npm run plugin:sync` derives root `plugin.json`.

### Naming Convention

* Use lowercase kebab-case: `security-reviewer.agent.md`
* Be descriptive and action-oriented: `security-reviewer.agent.md`, `code-review.agent.md`, `rpi-agent.agent.md`
* Avoid generic names: `helper.agent.md` ❌ → `ado-work-item-processor.agent.md` ✅

### File Format

Agent files MUST:

1. Use the `.agent.md` extension
2. Start with valid YAML frontmatter between `---` delimiters
3. Begin content directly after frontmatter
4. End with single newline character

## Frontmatter Requirements

### Required Fields

**`description`** (string, MANDATORY)

| Attribute | Details                                                                              |
|-----------|--------------------------------------------------------------------------------------|
| Purpose   | Concise explanation of agent functionality                                           |
| Format    | Single sentence, 10-200 characters                                                   |
| Style     | Sentence case with proper punctuation                                                |
| Example   | `'Validates contributed content for quality and compliance with hve-core standards'` |

### Optional Fields

**`name`** (string)

| Attribute | Details                                                                                          |
|-----------|--------------------------------------------------------------------------------------------------|
| Purpose   | Display name in the agent picker and the identity parent agents use to dispatch it as a subagent |
| Format    | Human-readable name (for example, `Report Generator`), not required to match the filename        |
| Default   | File name used if not specified                                                                  |

**`tools`** (array of strings)

| Attribute | Details                                          |
|-----------|--------------------------------------------------|
| Purpose   | Grants the tools this agent can use              |
| Format    | Array of Copilot tool aliases and MCP tool names |

Copilot recognizes these aliases:

| Alias      | Grants                                                       |
|------------|--------------------------------------------------------------|
| `read`     | Reading files                                                |
| `edit`     | Creating and changing files                                  |
| `search`   | Searching file names and file contents                       |
| `execute`  | Running shell commands                                       |
| `web`      | Web access                                                   |
| `agent`    | Starting subagents with the `task` tool                      |
| `skill`    | Activating skills by name                                    |
| `ask_user` | Asking the user questions; subagents never receive this tool |
| `todo`     | Tracking a task list                                         |

Name MCP tools in `server/tool` or `server/*` form, such as `microsoft-docs/*`. Copilot ignores names it does not recognize, so use these aliases in place of VS Code tool names. An empty list grants every tool.

> [!NOTE]
> GitHub's [custom agents configuration reference](https://docs.github.com/en/copilot/reference/custom-agents-configuration) is the authoritative source for tool aliases.

#### Referencing tools in agent bodies

The `tools:` field grants access, and the agent body decides when to use each tool. The Copilot harness does not resolve `#tool:` references in an agent body, so name the tool in plain text where a step depends on it:

```markdown
Search the repository for existing validators, then confirm the target files with the user through `ask_user` before editing.
```

Keep every tool the body relies on in the `tools:` list. A body that tells the agent to activate a skill also needs `skill` in that list.

**`skills`** (array of strings)

| Attribute | Details                                                                                        |
|-----------|------------------------------------------------------------------------------------------------|
| Purpose   | Skills to preload into the agent's context when it starts                                      |
| Format    | Array of skill names, each matching a skill folder name in lowercase kebab-case                |
| Behavior  | Copilot injects each `SKILL.md` body at session start; files the skill links to are not loaded |

**`model`** (string)

| Attribute | Details                                                                                               |
|-----------|-------------------------------------------------------------------------------------------------------|
| Purpose   | Specifies the AI model for this agent                                                                 |
| Format    | Single scalar model name; an array breaks the Copilot CLI, and `npm run lint:models` rejects it       |
| Default   | Currently selected model in model picker when omitted (or the invoking parent's model for a subagent) |

**`reasoning-effort`** (string enum)

| Attribute    | Details                                                                                       |
|--------------|-----------------------------------------------------------------------------------------------|
| Purpose      | Reasoning effort for the agent's model                                                        |
| Valid values | `low`, `medium`, `high`, `xhigh`, `max`                                                       |
| Default      | When omitted, a per-call value from the dispatcher, the session, or the model default applies |

**`user-invocable`** (boolean)

| Attribute | Details                                                         |
|-----------|-----------------------------------------------------------------|
| Purpose   | Controls whether the agent appears in the agents dropdown       |
| Default   | `true`                                                          |
| Usage     | Set to `false` for agents that are only accessible as subagents |

**`disable-model-invocation`** (boolean)

| Attribute | Details                                                                                                       |
|-----------|---------------------------------------------------------------------------------------------------------------|
| Purpose   | Prevents the agent from being invoked as a subagent by other agents                                           |
| Default   | `false`                                                                                                       |
| Usage     | Set to `true` for agents that run subagents, cause side effects, or should only run when explicitly requested |

**`target`** (string enum)

| Attribute    | Details                                 |
|--------------|-----------------------------------------|
| Purpose      | Target environment for the custom agent |
| Valid values | `vscode`, `github-copilot`              |

**`mcp-servers`** (array of objects)

| Attribute | Details                                                                                                        |
|-----------|----------------------------------------------------------------------------------------------------------------|
| Purpose   | MCP server configuration for GitHub Copilot agents                                                             |
| Usage     | Only applicable when `target: github-copilot`; VS Code does not forward these declarations to Copilot sessions |

**`hooks`**

| Attribute | Details                       |
|-----------|-------------------------------|
| Purpose   | Lifecycle hooks for the agent |
| Status    | Preview                       |

### Unsupported Fields

The Copilot harness does not support `handoffs`, `agents`, or `argument-hint` on agents, and `npm run lint:frontmatter` rejects them. Agents written for VS Code's earlier Local harness used them for handoff buttons, subagent allowlists, and chat input hints. Describe the next agent to switch to, or the subagents to delegate to, in the agent body instead. Skills still support `argument-hint`; see [Contributing Skills](skills).

### Deprecated Fields

**`infer`** (boolean)

| Attribute         | Details                                                                                                                         |
|-------------------|---------------------------------------------------------------------------------------------------------------------------------|
| Status            | Deprecated. Use `user-invocable` and `disable-model-invocation` instead.                                                        |
| Previous behavior | `infer: true` (default) made the agent both visible in the picker and available as a subagent. `infer: false` hid it from both. |

### Frontmatter Example

```yaml
---
name: Content Validator
description: 'Validates contributed agents, instructions, and skills for quality and compliance'
tools: [read, search, agent, skill, ask_user]
skills:
  - untrusted-content-boundary
disable-model-invocation: true
---
```

This agent preloads `untrusted-content-boundary` because it reads contributed content. It lists `skill` so it can activate other skills by name and `agent` so it can dispatch subagents, and `disable-model-invocation: true` keeps other agents from starting it as a subagent.

Name the subagents an agent dispatches in its body, as [Subagents](#subagents) describes. Use a generic dispatch prompt when a lifecycle stage needs isolated work and no stable specialized worker is required.

## Plugin Manifest Registration

Distributable agents must use the canonical path `.github/agents/<package>/<subpath>/<name>.agent.md`. `npm run plugin:sync` adds that repository-relative path to the `agents` array in root `plugin.json`.

Ensure every subagent the agent dispatches is also eligible for manifest inclusion. Update `docs/plugins/hve-core.md` when the user-visible agent surface changes, then run `npm run plugin:sync`, `npm run plugin:validate`, and `npm run docs:generate:check`.

## Path Portability

Agents are packaged and relocatable. The root directory varies by distribution context (in-repo, Copilot CLI plugin, VS Code extension). To ensure references to other artifacts remain portable and do not break across environments, follow these cross-artifact reference rules:

* Refer to a skill, agent, or subagent by the `name:` value from its frontmatter, not by a hard-coded path.
* Refer to an instruction file by its full `<name>.instructions.md` filename.
* Reserve file paths for an agent's own bundled resources, relative to the agent root.
* Never hard-code a skill's `SKILL.md` path, another agent's file path, or a cross-artifact directory path.
* Do not use `#file:` directives. The Copilot harness does not load them, and `npm run lint:artifact-portability` flags any `#file:` directive outside inline code.

Repo-root-relative paths (such as `.github/agents/...` or `.github/skills/...`) break portability and should not be used for cross-artifact references.

## Loading Skills and Instructions

Agents reach skills and instructions by name. Choose the mechanism by when the agent needs the content:

| Need                                | How the agent gets it                                                                                                                                                                   |
|-------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| A skill's rules from the first turn | List the skill under `skills:`. Copilot injects the `SKILL.md` body at session start, without the files it links to.                                                                    |
| A skill later in the workflow       | List `skill` in `tools` and name the skill in the body, so the agent activates it by name.                                                                                              |
| A path-specific instruction file    | Name the file in the body and have the agent read it with its read tool. Copilot applies an instruction that has `applyTo` only after a matching file is read or edited in the session. |

Instructions without `applyTo` are inlined in every session, so keep them rare. Preloaded skills also count toward an agent's cold-start budget when `scripts/linting/agent-cold-start-budgets.json` lists the agent, and `npm run lint:cold-start` enforces that budget.

The Security Planner loads its identity rules this way:

```markdown
At session start, before phase work, activate the `planner-identity` skill and read
`identity.instructions.md`, this planner's identity instructions, by name.
```

## Subagents

Subagents take isolated work from a parent agent. Place them under `.github/agents/{package-id}/subagents/` and set `user-invocable: false` so they stay out of the agent picker.

* A parent starts a subagent with the `task` tool, which the `agent` alias grants. VS Code's Local harness called this tool `runSubagent`.
* The parent names each subagent in its body by the subagent's `name` value. The tool dispatches by name, so nesting depth does not matter.
* Subagents do not receive repository instructions. A subagent gets its rules from its own body, a preloaded skill, or the parent's dispatch prompt.
* Subagents never receive `ask_user`, so the parent handles any questions for the user.
* Leave `agent` out of a subagent's `tools` when it must not dispatch further.

A dispatch prompt defines the exact inputs and read boundary, the owned write or evidence boundary, the expected return shape, the stage gate, and the step that consumes the result. The `code-review` skill dispatches a perspective worker this way:

```markdown
Dispatch `Code Review Functional` with the review root, snapshot ID, work item ID,
assigned files and hunks, and the result path that `schedule` recorded.
```

Its perspective subagents can activate skills but cannot dispatch further:

```yaml
---
name: Code Review Functional
description: "Review assigned snapshot evidence for behavioral defects and return the shared worker result."
tools:
  - search
  - read
  - edit
  - skill
user-invocable: false
skills:
  - code-review-core
  - code-review-functional
---
```

## Moving Between Agents and Phases

The Copilot harness has no handoff buttons. When work continues in another agent, say so in the body and name the agent to switch to. The DT Learning Tutor, for example, tells a learner who is ready for a real project to switch to the DT Coach agent. For RPI work, users move between phases by invoking the next skill, such as `/rpi-plan`, or by working with the RPI Agent.

## Agent Content Structure Standards

### Required Sections

#### 1. Title (H1)

* Clear, action-oriented heading matching agent purpose
* Should align with filename and description

```markdown
# Content Validator Agent
```

#### 2. Overview/Role Definition

* Explains what the agent does and when to use it
* Defines scope and boundaries
* Sets expectations for users

```markdown
You are an expert reviewer for GitHub Copilot agents, instructions, and skills.
Your mission is to ensure all contributed guidance files meet hve-core quality standards
before they're merged into the library.
```

#### 3. Core Directives/Instructions

* Uses clear, imperative language
* Employs RFC 2119 keywords consistently:
  * MUST, WILL, MANDATORY, and CRITICAL indicate required behavior
  * SHOULD and RECOMMENDED indicate strong guidance
  * MAY and OPTIONAL indicate permitted but not required behavior
* Provides step-by-step workflows
* Includes decision points and branching logic

#### 4. Examples and Templates

* Demonstrates correct usage patterns
* Shows both positive (✅) and negative (❌) examples
* Wraps in XML-style blocks for reusability

#### 5. Success Criteria

* Defines completion conditions
* Specifies validation checkpoints
* Lists quality gates

#### 6. Attribution Footer

Source artifacts carry no attribution footer.

### XML-Style Block Requirements

See [AI Artifacts Common Standards - XML-Style Block Standards](ai-artifacts-common#xml-style-block-standards) for complete rules and examples.

### Directive Language Standards

Use RFC 2119 compliant keywords (MUST/SHOULD/MAY). See [AI Artifacts Common Standards - RFC 2119 Directive Language](ai-artifacts-common#rfc-2119-directive-language) for complete guidance.

## Tool Usage Discipline

When agents use tools, they **MUST** follow these patterns:

### Tool Usage Preambles

Before any batch of tool calls, include a one-sentence explanation:

```markdown
Tool Usage Preamble: "Analyzing file structure, reading schemas, and checking
repository conventions to establish validation baseline."
```

### Checkpoints

After 3-5 tool calls or more than 3 file edits, provide a compact checkpoint:

```markdown
Checkpoint After Discovery: "Identified [file type], loaded [schema name],
found [N] related files for comparison."
```

### Tool Result Integration

* Document how tool results inform next steps
* Specify error handling for tool failures
* Justify tool selection (why this tool for this task)

## Output Formatting Requirements

Define how the agent communicates with users:

### Response Format

* Start all responses with: `## [Agent Name]: [Action Description]`
* Use short, action-oriented section headers
* Employ proper markdown formatting
* Include emojis for visual clarity (when appropriate)

### Status Reporting

Specify formats for:

* Progress updates
* Error messages
* Completion confirmations
* Validation results

### Requirements Checklist

For agents performing edits or validations:

```markdown
### Requirements Checklist

- [x] Pre-validation analysis complete - Loaded schema, checked conventions
- [x] Frontmatter validation - All required fields present
- [ ] Technical validation - 2 broken file references found
```

### Quality Gates

Report validation status:

```markdown
### Quality Gates

- Build: PASS
- Lint: FAIL - Markdownlint flagged: bare URLs (lines 45, 67)
- Schema: PASS - Frontmatter validates
```

## Research and External Sources

When agents integrate external knowledge, consult authoritative sources and provide minimal, annotated snippets with reference links. See [AI Artifacts Common Standards - Attribution Requirements](ai-artifacts-common#attribution-requirements) for guidelines.

## Validation Checklist

Before submitting your agent, verify:

### Frontmatter

* [ ] Valid YAML between `---` delimiters
* [ ] `description` field present and descriptive (10-200 chars)
* [ ] `tools` array uses Copilot aliases or MCP tool names (if present)
* [ ] `skills` entries match existing skill folder names (if present)
* [ ] `model` is a single scalar value (if present)
* [ ] No fields the Copilot harness does not support (see [Unsupported Fields](#unsupported-fields))
* [ ] `user-invocable` and `disable-model-invocation` used correctly (if present)
* [ ] No trailing whitespace in values
* [ ] Single newline at EOF

### Content Structure

* [ ] Clear H1 title matching purpose
* [ ] Overview/role definition section
* [ ] Core directives with RFC 2119 keywords
* [ ] Examples wrapped in XML-style blocks
* [ ] Success criteria defined
* [ ] Attribution footer absent

### Common Standards

* [ ] Markdown quality (see [Common Standards - Markdown Quality](ai-artifacts-common#markdown-quality-standards))
* [ ] XML-style blocks properly formatted (see [Common Standards - XML-Style Blocks](ai-artifacts-common#xml-style-block-standards))
* [ ] RFC 2119 keywords used consistently (see [Common Standards - RFC 2119](ai-artifacts-common#rfc-2119-directive-language))

### Technical Validation

* [ ] All file references point to existing files
* [ ] External links are valid and accessible
* [ ] Tool names in frontmatter are correct
* [ ] `npm run lint:artifact-portability` reports no `#file:` directives; skills load through `skills:` or activation by name
* [ ] No conflicts with existing agents

### Integration

* [ ] Aligns with `.github/copilot-instructions.md`
* [ ] Follows repository conventions
* [ ] Compatible with existing workflows
* [ ] Does not duplicate existing agent functionality

## Testing Your Agent

See [AI Artifacts Common Standards - Common Testing Practices](ai-artifacts-common#common-testing-practices) for testing guidelines. For agents specifically:

1. Test with realistic scenarios matching the agent's purpose
2. Verify tool usage patterns execute correctly
3. Ensure decision points and branching logic work as intended
4. Check edge cases: missing data, invalid inputs, tool failures

## Common Issues and Fixes

### Agent-Specific Issues

### Invalid Tool Names

Using misspelled aliases or tool names that Copilot does not recognize. Copilot ignores unrecognized names, so the agent silently loses that tool. Use the aliases listed under `tools` in place of VS Code tool names, and name MCP tools in `server/tool` or `server/*` form.

### Skill Never Loads

An agent cannot activate a skill by name unless its `tools` list includes `skill`, so a body step that activates a skill fails without it. Add `skill` to the list, or preload the skill with `skills:` when the agent needs it from the first turn.

For additional common issues (XML blocks, markdown, directives), see [AI Artifacts Common Standards - Common Issues and Fixes](ai-artifacts-common#common-issues-and-fixes).

## Automated Validation

Run these commands before submission (see [Common Standards - Common Validation](ai-artifacts-common#common-validation-standards)):

* `npm run lint:frontmatter`
* `npm run lint:md`
* `npm run spell-check`
* `npm run lint:md-links`
* `npm run lint:models` (when the agent sets `model`)
* `npm run lint:artifact-portability` (flags workspace-root `.github` paths and `#file:` directives)
* `npm run docs:generate` (required when adding a new agent; scaffolds the reference page under `docs/reference/agents/`)
* `npm run lint:asset-docs`

All checks **MUST** pass before merge.

## Related Documentation

* [AI Artifacts Common Standards](ai-artifacts-common) - Shared standards for all contributions
* [Contributing Skills](skills) - Skill packages that agents preload or activate
* [Contributing Slash Commands](prompts) - Reusable slash commands, contributed as skills
* [Contributing Instructions](instructions) - Technology-specific standards
* [Pull Request Template](https://github.com/microsoft/hve-core/blob/main/.github/PULL_REQUEST_TEMPLATE.md) - Submission requirements

## Getting Help

See [AI Artifacts Common Standards - Getting Help](ai-artifacts-common#getting-help) for support resources. For agent-specific assistance, review existing examples in `.github/agents/{package-id}/` (the conventional location for agent files).

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
