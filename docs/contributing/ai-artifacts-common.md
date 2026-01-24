---
title: 'AI Artifacts Common Standards'
description: 'Common standards and quality gates for all AI artifact contributions to hve-core'
author: Microsoft
ms.date: 2025-11-26
ms.topic: reference
---

This document defines shared standards, conventions, and quality gates that apply to **all** AI artifact contributions to hve-core (agents, prompts, and instructions files).

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

## Model Version Requirements

All AI artifacts (agents, instructions, prompts) **MUST** target the **latest available models** from Anthropic and OpenAI only.

### Accepted Models

* **Anthropic**: Latest Claude models (e.g., Claude Sonnet 4, Claude Opus 4)
* **OpenAI**: Latest GPT models (e.g., GPT-5, 5.1-COdEX)

### Not Accepted

* ❌ Older model versions (e.g., GPT-4o, Claude 4)
* ❌ Models from other providers
* ❌ Custom or fine-tuned models
* ❌ Deprecated model versions

### Rationale

1. **Feature parity**: Latest models support the most advanced features and capabilities
2. **Maintenance burden**: Supporting multiple model versions creates testing and compatibility overhead
3. **Performance**: Latest models provide superior reasoning, accuracy, and efficiency
4. **Future-proofing**: Older models will be deprecated and removed from service

## Maturity Field Requirements

All AI artifacts (agents, instructions, prompts) **MUST** include a `maturity` field in frontmatter.

### Purpose

The maturity field controls which extension channel includes the artifact:

* **Stable channel**: Only artifacts with `maturity: stable`
* **Pre-release channel**: Artifacts with `stable`, `preview`, or `experimental` maturity

### Valid Values

| Value          | Description                                 | Stable Channel | Pre-release Channel |
|----------------|---------------------------------------------|----------------|---------------------|
| `stable`       | Production-ready, fully tested              | ✅ Included     | ✅ Included          |
| `preview`      | Feature-complete, may have rough edges      | ❌ Excluded     | ✅ Included          |
| `experimental` | Early development, may change significantly | ❌ Excluded     | ✅ Included          |
| `deprecated`   | Scheduled for removal                       | ❌ Excluded     | ❌ Excluded          |

### Default for New Contributions

New artifacts **SHOULD** use `maturity: stable` unless:

* The artifact is a proof-of-concept or experimental feature
* The artifact requires additional testing or feedback before wide release
* The contributor explicitly intends to target early adopters

### Example

```yaml
---
description: 'Specialized agent for security analysis'
maturity: 'stable'
tools: ['codebase', 'search']
---
```

For detailed channel and lifecycle information, see [Release Process - Extension Channels](release-process.md#extension-channels-and-maturity).

**Before submitting**: Verify your artifact targets the current latest model versions from Anthropic or OpenAI. Contributions targeting older or alternative models will be automatically rejected.

## XML-Style Block Standards

All AI artifacts use XML-style HTML comment blocks to wrap examples, schemas, templates, and critical instructions. This enables automated extraction, better navigation, and consistency.

### Requirements

* **Tag naming**: Use kebab-case (e.g., `<!-- <example-valid-frontmatter> -->`)
* **Matching pairs**: Opening and closing tags MUST match exactly
* **Unique names**: Each tag name MUST be unique within the file (no duplicates)
* **Code fence placement**: Place code fences **inside** blocks, never outside
* **Nested blocks**: Use 4-backtick outer fence when demonstrating blocks with code fences
* **Single lines**: Opening and closing tags on their own lines

### Valid XML-Style Block Structure

````markdown
<!-- <example-configuration> -->
```json
{
  "enabled": true,
  "timeout": 30
}
```
<!-- </example-configuration> -->
````

### Demonstrating Blocks with Nested Fences

When showing examples that contain XML blocks with code fences, use 4-backtick outer fence:

`````markdown
````markdown
<!-- <example-bash-script> -->
```bash
#!/bin/bash
echo "Hello World"
```
<!-- </example-bash-script> -->
````
`````

### Common Tag Patterns

* `<!-- <example-*> -->` - Code examples
* `<!-- <schema-*> -->` - Schema definitions
* `<!-- <pattern-*> -->` - Coding patterns
* `<!-- <convention-*> -->` - Convention blocks
* `<!-- <anti-pattern-*> -->` - Things to avoid
* `<!-- <reference-sources> -->` - External documentation links
* `<!-- <validation-checklist> -->` - Validation steps
* `<!-- <file-structure> -->` - File organization

### Common XML Block Issues

#### Missing Closing Tag

* **Problem**: XML-style comment blocks opened but never closed
* **Solution**: Always include matching closing tags `<!-- </block-name> -->` for all opened blocks

#### Duplicate Tag Names

* **Problem**: Using the same XML block tag name multiple times in a file
* **Solution**: Make each tag name unique (e.g., `<example-python-function>` and `<example-bash-script>` instead of multiple `<example-code>` blocks)

## Markdown Quality Standards

All AI artifacts MUST follow these markdown quality requirements:

### Heading Hierarchy

* Start with H1 title
* No skipped levels (H1 → H2 → H3, not H1 → H3)
* Use H1 for document title only
* Use H2 for major sections, H3 for subsections

### Code Blocks

* All code blocks MUST have language tags
* Use proper language identifiers: `bash`, `python`, `json`, `yaml`, `markdown`, `text`, `plaintext`
* No naked code blocks without language specification

❌ **Bad**:

````markdown
```
code without language tag
```
````

✅ **Good**:

````markdown
```python
def example(): pass
```
````

### URL Formatting

* No bare URLs in prose
* Wrap in angle brackets: `<https://example.com>`
* Use markdown links: `[text](https://example.com)`

❌ **Bad**:

```markdown
See https://example.com for details.
```

✅ **Good**:

```markdown
See <https://example.com> for details.
# OR
See [official documentation](https://example.com) for details.
```

### List Formatting

* Use consistent list markers (prefer `*` for bullets)
* Use `-` for nested lists or alternatives
* Numbered lists use `1.`, `2.`, `3.` etc.

### Line Length

* Target ~500 characters per line
* Exceptions: code blocks, tables, URLs, long technical terms
* Not a hard limit, but improves readability

### Whitespace

* No hard tabs (use spaces)
* No trailing whitespace (except 2 spaces for intentional line breaks)
* File ends with single newline character

### File Structure

* Starts with frontmatter (YAML between `---` delimiters)
* Followed by markdown content
* Ends with attribution footer
* Single newline at EOF

## RFC 2119 Directive Language

Use standardized keywords for clarity and enforceability:

### Required Behavior

* **MUST** / **WILL** / **MANDATORY** / **REQUIRED** / **CRITICAL**
* Indicates absolute requirement
* Non-compliance is a defect

**Example**:

```markdown
All functions MUST include type hints for parameters and return values.
You WILL validate frontmatter before proceeding (MANDATORY).
```

### Strong Recommendations

* **SHOULD** / **RECOMMENDED**
* Indicates best practice
* Valid reasons may exist for exceptions
* Non-compliance requires justification

**Example**:

```markdown
Examples SHOULD be wrapped in XML-style blocks for reusability.
Functions SHOULD include docstrings with parameter descriptions.
```

### Optional/Permitted

* **MAY** / **OPTIONAL** / **CAN**
* Indicates permitted but not required
* Implementer choice

**Example**:

```markdown
You MAY include version fields in frontmatter.
Contributors CAN organize examples by complexity level.
```

### Avoid Ambiguous Language

❌ **Ambiguous (Never Use)**:

```markdown
You might want to validate the input...
It could be helpful to add docstrings...
Perhaps consider wrapping examples...
Try to follow the pattern...
Maybe include tests...
```

✅ **Clear (Always Use)**:

```markdown
You MUST validate all input before processing.
Functions SHOULD include docstrings.
Examples SHOULD be wrapped in XML-style blocks.
You MAY include additional examples.
```

## Common Validation Standards

All AI artifacts are validated using these automated tools:

### Validation Commands

Run these commands before submitting:

```bash
# Validate frontmatter against schemas
npm run lint:frontmatter

# Check markdown quality
npm run lint:md

# Spell check
npm run spell-check

# Validate all links
npm run lint:md-links

# PowerShell analysis (if applicable)
npm run lint:ps
```

### Quality Gates

All submissions MUST pass:

* **Frontmatter Schema**: Valid YAML with required fields
* **Markdown Linting**: No markdown rule violations
* **Spell Check**: No spelling errors (or added to dictionary)
* **Link Validation**: All links accessible and valid
* **File Format**: Correct fences and structure

### Validation Checklist Template

Use this checklist structure in type-specific guides:

```markdown
### Validation Checklist

#### Frontmatter
- [ ] Valid YAML between `---` delimiters
- [ ] All required fields present and valid
- [ ] No trailing whitespace
- [ ] Single newline at EOF

#### Markdown Quality
- [ ] Heading hierarchy correct
- [ ] Code blocks have language tags
- [ ] No bare URLs
- [ ] Consistent list markers

#### XML-Style Blocks
- [ ] All blocks closed properly
- [ ] Unique tag names
- [ ] Code fences inside blocks

#### Technical
- [ ] File references valid
- [ ] External links accessible
- [ ] No conflicts with existing files
```

## Common Testing Practices

Before submitting any AI artifact:

### 1. Manual Testing

* Execute the artifact manually with realistic scenarios
* Verify outputs match expectations
* Check edge cases (missing data, invalid inputs, errors)

### 2. Example Verification

* All code examples are syntactically correct
* Examples run without errors
* Examples demonstrate intended patterns

### 3. Tool Validation

* Specified tools/commands exist and work
* Tool outputs match documentation
* Error messages are clear

### 4. Documentation Review

* All sections complete and coherent
* Cross-references valid
* No contradictory guidance

## Common Issues and Fixes

### Ambiguous Directives

* **Problem**: Using vague, non-committal language that doesn't clearly indicate requirements
* **Solution**: Use RFC 2119 keywords (MUST, SHOULD, MAY) to specify clear requirements

### Missing XML Block Closures

* **Problem**: XML-style comment blocks opened but never closed
* **Solution**: Always include matching closing tags for all XML-style comment blocks

### Code Blocks Without Language Tags

* **Problem**: Code blocks missing language identifiers for syntax highlighting
* **Solution**: Always specify the language for code blocks (python, bash, json, yaml, markdown, text, plaintext)

### Bare URLs

* **Problem**: URLs placed directly in text without proper markdown formatting
* **Solution**: Wrap URLs in angle brackets `<https://example.com>` or use proper markdown link syntax `[text](url)`

### Inconsistent List Markers

* **Problem**: Mixing different bullet point markers (* and -) in the same list
* **Solution**: Use consistent markers throughout (prefer * for bullets, - for nested or alternatives)

### Trailing Whitespace

* **Problem**: Extra spaces at the end of lines (except intentional 2-space line breaks)
* **Solution**: Remove all trailing whitespace from lines

### Skipped Heading Levels

* **Problem**: Jumping from H1 to H3 without an H2, breaking document hierarchy
* **Solution**: Follow proper heading sequence (H1 → H2 → H3) without skipping levels

## Attribution Requirements

All AI artifacts MUST include attribution footer at the end:

```markdown
---

Brought to you by microsoft/hve-core
```

**Placement**: After all content, before final closing fence.

**Format**:

* Horizontal rule (`---`)
* Blank line
* Exact text: "Brought to you by microsoft/hve-core"
* Or team-specific: "Brought to you by microsoft/edge-ai"

## Getting Help

When contributing AI artifacts:

### Review Examples

* **Agents**: Examine files in `.github/agents/`
* **Prompts**: Examine files in `.github/prompts/`
* **Instructions**: Examine files in `.github/instructions/`

### Check Repository Standards

* Read `.github/copilot-instructions.md` for repository-wide conventions
* Review existing files in same category for patterns
* Use `prompt-builder.agent.md` agent for guided assistance

### Ask Questions

* Open draft PR and ask in comments
* Reference specific validation errors
* Provide context about your use case

### Common Resources

* [Contributing Custom Agents](custom-agents.md) - Agent configurations
* [Contributing Prompts](prompts.md) - Workflow guidance
* [Contributing Instructions](instructions.md) - Technology standards
* [Pull Request Template](../../.github/PULL_REQUEST_TEMPLATE.md) - Submission checklist

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
