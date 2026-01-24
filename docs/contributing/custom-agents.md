---
title: 'Contributing Agents to HVE Core'
description: 'Requirements and standards for contributing GitHub Copilot agent files to hve-core'
author: Microsoft
ms.date: 2025-11-26
ms.topic: how-to
---

This guide defines the requirements, standards, and best practices for contributing GitHub Copilot agent files (`.agent.md`) to the hve-core library.

**⚙️ Common Standards**: See [AI Artifacts Common Standards](ai-artifacts-common.md) for shared requirements (XML blocks, markdown quality, RFC 2119, validation, testing).

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

The following agent types will likely be **rejected or closed automatically** because **equivalent agents already exist in hve-core**:

### Duplicate Agent Categories

* **Research or Discovery Agents**: Agents that search for, gather, or discover information
  * ❌ Reason: Existing agents already handle research and discovery workflows
  * ✅ Alternative: Use existing research-focused agents in `.github/agents/`

* **Indexing or Referencing Agents**: Agents that catalog, index, or create references to existing projects
  * ❌ Reason: Existing agents already provide indexing and referencing capabilities
  * ❌ Tool integration: Widely supported tools built into VS Code GitHub Copilot and MCP tools with extremely wide adoption are already supported by existing hve-core agents
  * ✅ Alternative: Use existing reference management agents that leverage standard VS Code GitHub Copilot tools and widely-adopted MCP tools

* **Planning Agents**: Agents that plan work, break down tasks, or organize backlog items
  * ❌ Reason: Existing agents already handle work planning and task organization
  * ✅ Alternative: Use existing planning-focused agents in `.github/agents/`

* **Implementation Agents**: General-purpose coding agents that implement features
  * ❌ Reason: Existing agents already provide implementation guidance
  * ✅ Alternative: Use existing implementation-focused agents

### Rationale for Rejection

These agent types are rejected because:

1. **Existing agents are hardened and heavily utilized**: The hve-core library already contains production-tested agents in these categories
2. **Consistency and maintenance**: Coalescing around existing agents reduces fragmentation and maintenance burden
3. **Avoid duplication**: Multiple agents serving the same purpose create confusion and divergent behavior
4. **Standard tooling already integrated**: VS Code GitHub Copilot built-in tools and widely-adopted MCP tools are already leveraged by existing agents

### Before Submitting

When planning to submit an agent that falls into these categories:

1. **Question necessity**: Does your use case truly require a new agent, or can existing agents meet your needs?
2. **Review existing agents**: Examine `.github/agents/` to identify agents that already serve your purpose
3. **Check tool integration**: Verify whether the VS Code GitHub Copilot tools or MCP tools you need are already used by existing agents
4. **Consider enhancement over creation**: If existing agents don't fully meet your requirements, evaluate whether your changes are:
   * **Generic enough** to benefit all users
   * **Valuable enough** to justify modifying the existing agent
5. **Propose enhancements**: Submit a PR to enhance an existing agent rather than creating a duplicate

### What Makes a Good New Agent

Focus on agents that:

* **Fill gaps**: Address use cases not covered by existing agents
* **Provide unique value**: Offer specialized domain expertise or workflow patterns not present in the library
* **Are non-overlapping**: Have clearly distinct purposes from existing agents
* **Cannot be merged**: Represent functionality too specialized or divergent to integrate into existing agents
* **Use standard tooling**: Leverage widely-supported VS Code GitHub Copilot tools and MCP tools rather than custom integrations

### Model Version Requirements

All agents **MUST** target the **latest available models** from **Anthropic and OpenAI only**.

**Accepted**: Latest Claude models (e.g., Claude Sonnet 4, Claude Opus 4) and latest GPT models (e.g., GPT-5.1, o1)

**Not Accepted**: Older model versions (e.g., GPT-3.5, GPT-4.1, Claude 2), models from other providers, custom/fine-tuned models

**Rationale**: Latest models provide superior capabilities, reduce maintenance burden, and ensure future compatibility. Older model versions will be deprecated.

## File Structure Requirements

### Location

All agent files **MUST** be placed in:

```text
.github/agents/
└── your-agent-name.agent.md
```

### Naming Convention

* Use lowercase kebab-case: `security-reviewer.agent.md`
* Be descriptive and action-oriented: `task-planner.agent.md`, `pr-review.agent.md`, `rpi-agent.agent.md`
* Avoid generic names: `helper.agent.md` ❌ → `ado-work-item-processor.agent.md` ✅

### File Format

Agent files **MUST**:

1. Use the `.agent.md` extension
2. Start with valid YAML frontmatter between `---` delimiters
3. Begin content directly after frontmatter
4. End with single newline character

## Frontmatter Requirements

### Required Fields

**`description`** (string, MANDATORY)

* **Purpose**: Concise explanation of agent functionality
* **Format**: Single sentence, 10-200 characters
* **Style**: Sentence case with proper punctuation
* **Example**: `'Validates contributed content for quality and compliance with hve-core standards'`

**`maturity`** (string enum, MANDATORY)

* **Purpose**: Controls which extension channel includes this agent
* **Valid values**:
  * `stable` - Production-ready, included in Stable and Pre-release channels
  * `preview` - Feature-complete, included in Pre-release channel only
  * `experimental` - Early development, included in Pre-release channel only
  * `deprecated` - Scheduled for removal, excluded from all channels
* **Default**: New agents should use `stable` unless targeting early adopters
* **Example**: `stable`

### Optional Fields

**`tools`** (array of strings)

* **Purpose**: Lists GitHub Copilot tools available to this agent
* **Format**: Array of valid tool names in logical order (read before write)
* **Valid tools**:
  * `codebase` - Semantic code search
  * `search` - Grep/regex search
  * `problems` - Error/warning diagnostics
  * `editFiles` - File modification
  * `changes` - Git change tracking
  * `usages` - Symbol reference search
  * `githubRepo` - External GitHub repository search
  * `fetch` - Web page content retrieval
  * `runCommands` - Terminal command execution
  * `think` - Extended reasoning
  * `findTestFiles` - Test file discovery
  * `terminalLastCommand` - Terminal history
  * `searchResults` - Search view results
  * `edit/createFile` - File creation
  * `edit/createDirectory` - Directory creation
  * `Bicep (EXPERIMENTAL)/*` - Bicep tooling
  * `terraform/*` - Terraform tooling
  * `context7/*` - Library documentation
  * `microsoft-docs/*` - Microsoft documentation

**`mode`** (string enum)

* **Purpose**: Defines agent interaction pattern
* **Valid values**: `agent`, `assistant`, `copilot`
* **Default**: Auto-detected from usage pattern

**`version`** (string)

* **Purpose**: Tracks agent revisions
* **Format**: Semantic versioning (e.g., `1.0.0`)

**`author`** (string)

* **Purpose**: Attribution for agent creator
* **Example**: `microsoft/hve-core`, `your-team-name`

**`handoffs`** (array of objects)

* **Purpose**: Declares agent-to-agent handoff buttons that appear in the chat UI
* **Format**: Array of handoff declarations
* **Fields per handoff**:
  * `label` (string, required): Button text displayed in UI, supports emoji
  * `agent` (string, required): Target agent filename without `.agent.md` extension
  * `prompt` (string, optional): Pre-filled prompt text, can include slash commands
  * `send` (boolean, optional): When true, auto-submits prompt; when false (default), user can edit
* **Requirements**: VS Code 1.106+ required for handoff support
* **Example**:

  ```yaml
  handoffs:
    - label: "📋 Create Plan"
      agent: task-planner
      prompt: /task-plan
      send: true
  ```

### Frontmatter Example

```yaml
---
description: 'Validates and reviews contributed agents, prompts, and instructions for quality and compliance'
tools: ['codebase', 'search', 'problems', 'editFiles', 'changes', 'usages']
mode: 'agent'
version: '1.0.0'
author: 'microsoft/hve-core'
---
```

### MCP Tool Dependencies

When agents reference MCP tools in their `tools:` frontmatter or body content, document the dependencies clearly.

**Frontmatter declaration:**

```yaml
tools: ['github/*', 'ado/*', 'context7/*', 'microsoft-docs/*']
```

**Curated MCP servers referenced by HVE-Core agents:**

| Server         | Tool Pattern       | Purpose                                   |
|----------------|--------------------|-------------------------------------------|
| github         | `github/*`         | GitHub repository and issue management    |
| ado            | `ado/*`            | Azure DevOps work items, pipelines, repos |
| context7       | `context7/*`       | Library and SDK documentation lookup      |
| microsoft-docs | `microsoft-docs/*` | Microsoft Learn documentation             |

**Guidelines for MCP tool references:**

* Document MCP dependencies in agent body text when using `mcp_*` tool patterns
* Agents should gracefully handle missing MCP servers (tools unavailable)
* Reference the [MCP Server Configuration](../getting-started/mcp-configuration.md) guide when agents require MCP tools
* Prefer built-in VS Code Copilot tools when equivalent functionality exists

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
You are an expert reviewer for GitHub Copilot agents, prompts, and instruction files.
Your mission is to ensure all contributed guidance files meet hve-core quality standards
before they're merged into the library.
```

#### 3. Core Directives/Instructions

* Uses clear, imperative language
* Employs RFC 2119 keywords consistently:
  * **MUST/WILL/MANDATORY/CRITICAL** - Required behavior
  * **SHOULD/RECOMMENDED** - Strong guidance
  * **MAY/OPTIONAL** - Permitted but not required
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

* **MANDATORY**: Include at end of file

```markdown
---

Brought to you by microsoft/hve-core
```

### XML-Style Block Requirements

See [AI Artifacts Common Standards - XML-Style Block Standards](ai-artifacts-common.md#xml-style-block-standards) for complete rules and examples.

### Directive Language Standards

Use RFC 2119 compliant keywords (MUST/SHOULD/MAY). See [AI Artifacts Common Standards - RFC 2119 Directive Language](ai-artifacts-common.md#rfc-2119-directive-language) for complete guidance.

## Tool Usage Discipline

When agents use tools, they **MUST** follow these patterns:

### Tool Usage Preambles

Before any batch of tool calls, include a one-sentence explanation:

```markdown
**Tool Usage Preamble**: "Analyzing file structure, reading schemas, and checking
repository conventions to establish validation baseline."
```

### Checkpoints

After 3-5 tool calls or more than 3 file edits, provide a compact checkpoint:

```markdown
**Checkpoint After Discovery**: "Identified [file type], loaded [schema name],
found [N] related files for comparison."
```

### Tool Result Integration

* Document how tool results inform next steps
* Specify error handling for tool failures
* Justify tool selection (why this tool for this task)

## Output Formatting Requirements

Define how the agent communicates with users:

### Response Format

* Start all responses with: `## **[Agent Name]**: [Action Description]`
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

- **Build**: PASS
- **Lint**: FAIL - Markdownlint flagged: bare URLs (lines 45, 67)
- **Schema**: PASS - Frontmatter validates
```

## Research and External Sources

When agents integrate external knowledge, consult authoritative sources and provide minimal, annotated snippets with reference links. See [AI Artifacts Common Standards - Attribution Requirements](ai-artifacts-common.md#attribution-requirements) for guidelines.

## Validation Checklist

Before submitting your agent, verify:

### Frontmatter

* [ ] Valid YAML between `---` delimiters
* [ ] `description` field present and descriptive (10-200 chars)
* [ ] `tools` array contains only valid tool names (if present)
* [ ] `mode` is one of: `agent`, `assistant`, `copilot` (if present)
* [ ] No trailing whitespace in values
* [ ] Single newline at EOF

### Content Structure

* [ ] Clear H1 title matching purpose
* [ ] Overview/role definition section
* [ ] Core directives with RFC 2119 keywords
* [ ] Examples wrapped in XML-style blocks
* [ ] Success criteria defined
* [ ] Attribution footer present

### Common Standards

* [ ] Markdown quality (see [Common Standards - Markdown Quality](ai-artifacts-common.md#markdown-quality-standards))
* [ ] XML-style blocks properly formatted (see [Common Standards - XML-Style Blocks](ai-artifacts-common.md#xml-style-block-standards))
* [ ] RFC 2119 keywords used consistently (see [Common Standards - RFC 2119](ai-artifacts-common.md#rfc-2119-directive-language))

### Technical Validation

* [ ] All file references point to existing files
* [ ] External links are valid and accessible
* [ ] Tool names in frontmatter are correct
* [ ] No conflicts with existing agents

### Integration

* [ ] Aligns with `.github/copilot-instructions.md`
* [ ] Follows repository conventions
* [ ] Compatible with existing workflows
* [ ] Does not duplicate existing agent functionality

## Testing Your Agent

See [AI Artifacts Common Standards - Common Testing Practices](ai-artifacts-common.md#common-testing-practices) for testing guidelines. For agents specifically:

1. Test with realistic scenarios matching the agent's purpose
2. Verify tool usage patterns execute correctly
3. Ensure decision points and branching logic work as intended
4. Check edge cases: missing data, invalid inputs, tool failures

## Common Issues and Fixes

### Agent-Specific Issues

### Invalid Tool Names

* **Problem**: Referencing tools that don't exist or using incorrect camelCase variants
* **Solution**: Use exact tool names from VS Code Copilot's available tools list

For additional common issues (XML blocks, markdown, directives), see [AI Artifacts Common Standards - Common Issues and Fixes](ai-artifacts-common.md#common-issues-and-fixes).

## Automated Validation

Run these commands before submission (see [Common Standards - Common Validation](ai-artifacts-common.md#common-validation-standards)):

* `npm run lint:frontmatter`
* `npm run lint:md`
* `npm run spell-check`
* `npm run lint:md-links`

All checks **MUST** pass before merge.

## Related Documentation

* [AI Artifacts Common Standards](ai-artifacts-common.md) - Shared standards for all contributions
* [Contributing Prompts](prompts.md) - Workflow-specific guidance files
* [Contributing Instructions](instructions.md) - Technology-specific standards
* [Pull Request Template](../../.github/PULL_REQUEST_TEMPLATE.md) - Submission requirements

## Getting Help

See [AI Artifacts Common Standards - Getting Help](ai-artifacts-common.md#getting-help) for support resources. For agent-specific assistance, review existing examples in `.github/agents/`.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
