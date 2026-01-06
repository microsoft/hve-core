---
title: 'Contributing Chatmodes to HVE Core'
description: 'Requirements and standards for contributing GitHub Copilot chatmode files to hve-core'
author: Microsoft
ms.date: 2025-11-26
ms.topic: how-to
---

This guide defines the requirements, standards, and best practices for contributing GitHub Copilot chatmode files (`.chatmode.md`) to the hve-core library.

**⚙️ Common Standards**: See [AI Artifacts Common Standards](ai-artifacts-common.md) for shared requirements (XML blocks, markdown quality, RFC 2119, validation, testing).

## What is a Chatmode?

A **chatmode** is a specialized AI agent configuration that defines behavior, available tools, and instructions for GitHub Copilot to follow when performing specific tasks. Chatmodes enable consistent, repeatable workflows for complex development activities.

## Use Cases for Chatmodes

Create a chatmode when you need to:

* Define a specialized AI agent role (e.g., security reviewer, PR analyzer, documentation generator)
* Orchestrate multi-step workflows requiring specific tool sequences
* Maintain consistent behavior patterns across development tasks
* Provide domain-specific expertise (e.g., ADR creation, work item processing)
* Automate complex decision-making with predefined logic flows

## Chatmodes Not Accepted

The following chatmode types will likely be **rejected or closed automatically** because **equivalent chatmodes already exist in hve-core**:

### Duplicate Chatmode Categories

* **Research or Discovery Agents**: Chatmodes that search for, gather, or discover information
  * ❌ Reason: Existing chatmodes already handle research and discovery workflows
  * ✅ Alternative: Use existing research-focused chatmodes in `.github/chatmodes/`

* **Indexing or Referencing Agents**: Chatmodes that catalog, index, or create references to existing projects
  * ❌ Reason: Existing chatmodes already provide indexing and referencing capabilities
  * ❌ Tool integration: Widely supported tools built into VS Code GitHub Copilot and MCP tools with extremely wide adoption are already supported by existing hve-core chatmodes
  * ✅ Alternative: Use existing reference management chatmodes that leverage standard VS Code GitHub Copilot tools and widely-adopted MCP tools

* **Planning Agents**: Chatmodes that plan work, break down tasks, or organize backlog items
  * ❌ Reason: Existing chatmodes already handle work planning and task organization
  * ✅ Alternative: Use existing planning-focused chatmodes in `.github/chatmodes/`

* **Implementation Agents**: General-purpose coding agents that implement features
  * ❌ Reason: Existing chatmodes already provide implementation guidance
  * ✅ Alternative: Use existing implementation-focused chatmodes

### Rationale for Rejection

These chatmode types are rejected because:

1. **Existing chatmodes are hardened and heavily utilized**: The hve-core library already contains production-tested chatmodes in these categories
2. **Consistency and maintenance**: Coalescing around existing chatmodes reduces fragmentation and maintenance burden
3. **Avoid duplication**: Multiple chatmodes serving the same purpose create confusion and divergent behavior
4. **Standard tooling already integrated**: VS Code GitHub Copilot built-in tools and widely-adopted MCP tools are already leveraged by existing chatmodes

### Before Submitting

When planning to submit a chatmode that falls into these categories:

1. **Question necessity**: Does your use case truly require a new chatmode, or can existing chatmodes meet your needs?
2. **Review existing chatmodes**: Examine `.github/chatmodes/` to identify chatmodes that already serve your purpose
3. **Check tool integration**: Verify whether the VS Code GitHub Copilot tools or MCP tools you need are already used by existing chatmodes
4. **Consider enhancement over creation**: If existing chatmodes don't fully meet your requirements, evaluate whether your changes are:
   * **Generic enough** to benefit all users
   * **Valuable enough** to justify modifying the existing chatmode
5. **Propose enhancements**: Submit a PR to enhance an existing chatmode rather than creating a duplicate

### What Makes a Good New Chatmode

Focus on chatmodes that:

* **Fill gaps**: Address use cases not covered by existing chatmodes
* **Provide unique value**: Offer specialized domain expertise or workflow patterns not present in the library
* **Are non-overlapping**: Have clearly distinct purposes from existing chatmodes
* **Cannot be merged**: Represent functionality too specialized or divergent to integrate into existing chatmodes
* **Use standard tooling**: Leverage widely-supported VS Code GitHub Copilot tools and MCP tools rather than custom integrations

### Model Version Requirements

All chatmodes **MUST** target the **latest available models** from **Anthropic and OpenAI only**.

**Accepted**: Latest Claude models (e.g., Claude Sonnet 4, Claude Opus 4) and latest GPT models (e.g., GPT-5.1, o1)

**Not Accepted**: Older model versions (e.g., GPT-3.5, GPT-4.1, Claude 2), models from other providers, custom/fine-tuned models

**Rationale**: Latest models provide superior capabilities, reduce maintenance burden, and ensure future compatibility. Older model versions will be deprecated.

## File Structure Requirements

### Location

All chatmode files **MUST** be placed in:

```text
.github/chatmodes/
└── your-chatmode-name.chatmode.md
```

### Naming Convention

* Use lowercase kebab-case: `security-reviewer.chatmode.md`
* Be descriptive and action-oriented: `task-planner.chatmode.md`, `pr-review.chatmode.md`, `rpi-agent.chatmode.md`
* Avoid generic names: `helper.chatmode.md` ❌ → `ado-work-item-processor.chatmode.md` ✅

### File Format

Chatmode files **MUST**:

1. Use the `.chatmode.md` extension
2. Start with valid YAML frontmatter between `---` delimiters
3. Begin content directly after frontmatter
4. End with single newline character

## Frontmatter Requirements

### Required Fields

**`description`** (string, MANDATORY)

* **Purpose**: Concise explanation of chatmode functionality
* **Format**: Single sentence, 10-200 characters
* **Style**: Sentence case with proper punctuation
* **Example**: `'Validates contributed content for quality and compliance with hve-core standards'`

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

* **Purpose**: Tracks chatmode revisions
* **Format**: Semantic versioning (e.g., `1.0.0`)

**`author`** (string)

* **Purpose**: Attribution for chatmode creator
* **Example**: `microsoft/hve-core`, `your-team-name`

### Frontmatter Example

```yaml
---
description: 'Validates and reviews contributed chatmodes, prompts, and instructions for quality and compliance'
tools: ['codebase', 'search', 'problems', 'editFiles', 'changes', 'usages']
mode: 'agent'
version: '1.0.0'
author: 'microsoft/hve-core'
---
```

## Chatmode Content Structure Standards

### Required Sections

#### 1. Title (H1)

* Clear, action-oriented heading matching chatmode purpose
* Should align with filename and description

```markdown
# Content Validator Agent
```

#### 2. Overview/Role Definition

* Explains what the agent does and when to use it
* Defines scope and boundaries
* Sets expectations for users

```markdown
You are an expert reviewer for GitHub Copilot chatmodes, prompts, and instruction files.
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

When chatmodes use tools, they **MUST** follow these patterns:

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

Define how the chatmode communicates with users:

### Response Format

* Start all responses with: `## **[Chatmode Name]**: [Action Description]`
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

For chatmodes performing edits or validations:

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

When chatmodes integrate external knowledge, consult authoritative sources and provide minimal, annotated snippets with reference links. See [AI Artifacts Common Standards - Attribution Requirements](ai-artifacts-common.md#attribution-requirements) for guidelines.

## Validation Checklist

Before submitting your chatmode, verify:

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
* [ ] No conflicts with existing chatmodes

### Integration

* [ ] Aligns with `.github/copilot-instructions.md`
* [ ] Follows repository conventions
* [ ] Compatible with existing workflows
* [ ] Does not duplicate existing chatmode functionality

## Testing Your Chatmode

See [AI Artifacts Common Standards - Common Testing Practices](ai-artifacts-common.md#common-testing-practices) for testing guidelines. For chatmodes specifically:

1. Test with realistic scenarios matching the agent's purpose
2. Verify tool usage patterns execute correctly
3. Ensure decision points and branching logic work as intended
4. Check edge cases: missing data, invalid inputs, tool failures

## Common Issues and Fixes

### Chatmode-Specific Issues

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

See [AI Artifacts Common Standards - Getting Help](ai-artifacts-common.md#getting-help) for support resources. For chatmode-specific assistance, review existing examples in `.github/chatmodes/`.

---

Brought to you by microsoft/hve-core
