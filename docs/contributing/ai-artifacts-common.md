---
title: 'AI Artifacts Common Standards'
description: 'Common standards and quality gates for all AI artifact contributions to hve-core'
sidebar_position: 2
author: Microsoft
ms.date: 2026-08-19
ms.topic: reference
keywords:
  - contributing
  - ai artifacts
  - standards
---

This document defines shared standards, conventions, and quality gates that apply to **all** AI artifact contributions to hve-core (agents, prompts, instructions, and skills).

## Asset Reference Documentation

Every documentable agent, prompt, instruction, and skill MUST include its paired
page under `docs/reference/**`. Follow the
[asset reference documentation guide](asset-docs.md) to generate the page, preserve
the generator-owned regions, author the usage sections, and satisfy the local and
pull request validation gates.

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

## Model Version Requirements

All AI artifacts (agents, instructions, prompts) **MUST** target models listed in the model catalog (`scripts/linting/model-catalog.json`). The catalog defines which models are available in GitHub Copilot and which providers are accepted via the `providerAllowlist` field.

### Accepted Models

Any model in the catalog whose provider appears in `providerAllowlist` and whose status is `ga` or `preview`. Run `npm run lint:models` to validate references against the catalog.

### Not Accepted

* ❌ Models not present in the catalog
* ❌ Models from providers outside the catalog's `providerAllowlist`
* ❌ Custom or fine-tuned models
* ❌ Models with `retiring` or `retired` status

### Model Name Format

Model references in frontmatter use the VS Code display name with vendor suffix:

```yaml
# Single model
model: Claude Haiku 4.5 (copilot)

# Prioritized fallback array (system tries each in order)
model:
  - Claude Haiku 4.5 (copilot)
  - GPT-5.4 mini (copilot)
```

The `(copilot)` suffix is required. Run `npm run lint:models` to validate all model references against the catalog.

### Model Selection (Optional)

The `model` frontmatter property is **optional**. When omitted, the agent or prompt inherits the user's session model (whatever is selected in the VS Code model picker).

Use explicit model selection for cost optimization:

| Tier     | Multiplier  | Use When                                                | Example Models                 |
|----------|-------------|---------------------------------------------------------|--------------------------------|
| Fast     | 0.25x–0.33x | Read-only research, mechanical file ops, classification | Claude Haiku 4.5, GPT-5.4 mini |
| Standard | 1x          | Code generation, architecture, complex synthesis        | Claude Sonnet 4.6, GPT-5.4     |
| Premium  | 3x–15x      | Vision-capable tasks, complex architectural decisions   | Claude Opus 4.6, GPT-5.5       |

### Cost Tier Constraint

The `model` property is a **preference hint**, not a hard constraint. VS Code never fails a prompt or agent invocation due to model unavailability. When a specified model is unavailable or exceeds the cost tier of the parent model, VS Code falls back through the array entries in order, then to the session model (model picker selection).

VS Code enforces that subagent models cannot exceed the cost tier of the parent model. If the user selects Sonnet (standard) in the model picker, subagents can use Haiku (fast) but not Opus (premium). Fallback arrays provide resilience when the preferred model is unavailable or exceeds the cost tier. A single-model string is equally safe: it falls back to the session model when the specified model cannot be used.

### Model Catalog Validation

Model references are validated against `scripts/linting/model-catalog.json` by the `lint:models` script. A scheduled GitHub Actions workflow (`model-validation.yml`) runs weekly to detect catalog drift and retiring models.

To refresh the catalog from upstream documentation:

```bash
npm run lint:models:refresh
```

### Rationale

1. Feature parity: latest models support the most advanced features and capabilities
2. Maintenance burden: supporting multiple model versions creates testing and compatibility overhead
3. Performance: latest models provide superior reasoning, accuracy, and efficiency
4. Future-proofing: older models will be deprecated and removed from service
5. Cost optimization: fast-tier models reduce consumption for tasks that do not require premium reasoning

## Plugin Membership

Root `plugin.json` is the distribution authority for the single `hve-core` plugin and VSIX. `npm run plugin:sync` derives repository-relative membership from tracked package-scoped artifacts under `.github`:

* Agents under `.github/agents/<package>/**/*.agent.md`
* Prompts under `.github/prompts/<package>/**/*.prompt.md`
* Instructions under `.github/instructions/<package>/**/*.instructions.md`
* Skills with `.github/skills/<package>/<skill>/SKILL.md` unless the skill's top-level license has a noncommercial qualifier

Root-level repository-only artifacts are excluded. The manifest retains the fixed telemetry hook. `.github/plugin/marketplace.json` contains one `hve-core` entry with the relative source `.` and no component recipe.

## Extension Packaging

`Prepare-Extension.ps1` maps the complete plugin manifest to the single `ise-hve-essentials.hve-core` extension. `Package-Extension.ps1` stages only git-tracked files from those contribution roots plus explicit shared resources. Hooks remain plugin-only because VS Code has no declarative hook contribution point.

Stable and PreRelease contain the same manifest membership. Their differences are version, cadence, source branch, release assurance, and the VS Code Marketplace pre-release flag.

## Manifest Workflow

When you add or change an artifact:

1. Author the artifact under a package subdirectory of `.github/`.
2. Run `npm run plugin:sync` to update root `plugin.json`.
3. Update `docs/plugins/hve-core.md` when user-visible capabilities or identity guidance changed.
4. Run `npm run plugin:validate`.
5. Run `npm run docs:generate:check` and the focused tests for the changed artifact kind.
6. Run the applicable extension preparation command when extension output is in scope.

Commit canonical sources, the synchronized plugin manifest, the sole plugin documentation page, and the single extension manifest and README when they change. Do not create a copied plugin tree or plugin ZIP.

### Validation Contract

`npm run plugin:validate` runs manifest check mode and hook validation. It rejects membership drift, invalid one-entry locator metadata, name or version mismatch, source escape, missing declared components, recipe fields on the locator, and invalid hooks.

See the [Plugin Scripts README](https://github.com/microsoft/hve-core/blob/main/scripts/plugins/README.md) for synchronization and validation details.

## XML-Style Block Standards

All AI artifacts use XML-style HTML comment blocks to wrap examples, schemas, templates, and critical instructions. This enables automated extraction, better navigation, and consistency.

### Requirements

| Rule                 | Description                                                           |
|----------------------|-----------------------------------------------------------------------|
| Tag naming           | Use kebab-case (e.g., `<!-- <example-valid-frontmatter> -->`)         |
| Matching pairs       | Opening and closing tags MUST match exactly                           |
| Unique names         | Each tag name MUST be unique within the file (no duplicates)          |
| Code fence placement | Place code fences inside blocks, never outside                        |
| Nested blocks        | Use 4-backtick outer fence when demonstrating blocks with code fences |
| Single lines         | Opening and closing tags on their own lines                           |

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

XML-style comment blocks opened but never closed. Always include matching closing tags `<!-- </block-name> -->` for all opened blocks.

#### Duplicate Tag Names

Using the same XML block tag name multiple times in a file. Make each tag name unique (e.g., `<example-python-function>` and `<example-bash-script>` instead of multiple `<example-code>` blocks).

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

❌ Bad:

````markdown
```
code without language tag
```
````

✅ Good:

````markdown
```python
def example(): pass
```
````

### URL Formatting

* No bare URLs in prose
* Wrap in angle brackets: `<https://example.com>`
* Use markdown links: `[text](https://example.com)`

❌ Bad:

```markdown
See https://example.com for details.
```

✅ Good:

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
* Omits any attribution suffix from the `description` field
* Single newline at EOF

## RFC 2119 Directive Language

Use standardized keywords for clarity and enforceability:

### Required Behavior

MUST, WILL, MANDATORY, REQUIRED, and CRITICAL indicate absolute requirements. Non-compliance is a defect.

#### Example: Required Behavior

```markdown
All functions MUST include type hints for parameters and return values.
You WILL validate frontmatter before proceeding (MANDATORY).
```

### Strong Recommendations

SHOULD and RECOMMENDED indicate best practices. Valid reasons may exist for exceptions, but non-compliance requires justification.

#### Example: Strong Recommendations

```markdown
Examples SHOULD be wrapped in XML-style blocks for reusability.
Functions SHOULD include docstrings with parameter descriptions.
```

### Optional/Permitted

MAY, OPTIONAL, and CAN indicate permitted but not required behavior. The choice is left to the implementer.

#### Example: Optional Behavior

```markdown
You MAY include version fields in frontmatter.
Contributors CAN organize examples by complexity level.
```

### Avoid Ambiguous Language

❌ Ambiguous (Never Use):

```markdown
You might want to validate the input...
It could be helpful to add docstrings...
Perhaps consider wrapping examples...
Try to follow the pattern...
Maybe include tests...
```

✅ Clear (Always Use):

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

# Validate model references in agent/prompt frontmatter
npm run lint:models

# PowerShell analysis (if applicable)
npm run lint:ps

# Validate skill structure (if applicable)
npm run validate:skills

# Scaffold reference pages for new documentable assets
npm run docs:generate

# Validate asset reference pages and AUTO-GENERATED regions
npm run lint:asset-docs
```

### Quality Gates

All submissions MUST pass:

| Gate               | Description                                 |
|--------------------|---------------------------------------------|
| Frontmatter Schema | Valid YAML with required fields             |
| Markdown Linting   | No markdown rule violations                 |
| Spell Check        | No spelling errors (or added to dictionary) |
| Link Validation    | All links accessible and valid              |
| File Format        | Correct fences and structure                |

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

Using vague, non-committal language that doesn't clearly indicate requirements. Use RFC 2119 keywords (MUST, SHOULD, MAY) to specify clear requirements.

### Missing XML Block Closures

XML-style comment blocks opened but never closed. Always include matching closing tags for all XML-style comment blocks.

### Code Blocks Without Language Tags

Code blocks missing language identifiers for syntax highlighting. Always specify the language for code blocks (python, bash, json, yaml, markdown, text, plaintext).

### Bare URLs

URLs placed directly in text without proper markdown formatting. Wrap URLs in angle brackets `<https://example.com>` or use proper markdown link syntax `[text](url.md)`.

### Inconsistent List Markers

Mixing different bullet point markers (\* and -) in the same list. Use consistent markers throughout (prefer \* for bullets, - for nested or alternatives).

### Trailing Whitespace

Extra spaces at the end of lines (except intentional 2-space line breaks). Remove all trailing whitespace from lines.

### Skipped Heading Levels

Jumping from H1 to H3 without an H2, breaking document hierarchy. Follow proper heading sequence (H1 → H2 → H3) without skipping levels.

## Attribution Requirements

Source artifacts carry no attribution suffix or footer. Author `description:` fields without a trailing attribution string, and do not add a blockquote attribution footer to `SKILL.md` bodies.

## GitHub Issue Title Conventions

When filing issues against hve-core, use Conventional Commit-style title prefixes that match the repository's commit message format.

### Issue Title Format

| Issue Type           | Title Prefix          | Example                                         |
|----------------------|-----------------------|-------------------------------------------------|
| Bug reports          | `fix:`                | `fix: validation script fails on Windows paths` |
| Agent requests       | `feat(agents):`       | `feat(agents): add Azure cost analysis agent`   |
| Prompt requests      | `feat(prompts):`      | `feat(prompts): add PR description generator`   |
| Instruction requests | `feat(instructions):` | `feat(instructions): add Go language standards` |
| Skill requests       | `feat(skills):`       | `feat(skills): add diagram generation skill`    |
| General features     | `feat:`               | `feat: support multi-root workspaces`           |
| Documentation        | `docs:`               | `docs: clarify installation steps`              |

### Benefits

* Issue titles align with commit and PR title conventions
* Automated changelog generation works correctly
* Scopes clearly identify affected artifact categories
* Consistent formatting across all project tracking

### Reference

See [commit-message.instructions.md](https://github.com/microsoft/hve-core/blob/main/.github/instructions/hve-core/commit-message.instructions.md) for the complete list of types and scopes.

## Getting Help

When contributing AI artifacts:

### Review Examples

| Artifact Type | Location                                                                  |
|---------------|---------------------------------------------------------------------------|
| Agents        | Files in `.github/agents/{package-id}/` (the conventional location)       |
| Prompts       | Files in `.github/prompts/{package-id}/` (the conventional location)      |
| Instructions  | Files in `.github/instructions/{package-id}/` (the conventional location) |

### Check Repository Standards

* Read `.github/copilot-instructions.md` for repository-wide conventions
* Review existing files in same category for patterns
* Use the `hve-builder` skill for guided artifact authoring, review, and validation

### Ask Questions

* Open draft PR and ask in comments
* Reference specific validation errors
* Provide context about your use case

### Common Resources

* [Contributing Custom Agents](custom-agents.md) - Agent configurations
* [Contributing Prompts](prompts.md) - Workflow guidance
* [Contributing Instructions](instructions.md) - Technology standards
* [Pull Request Template](https://github.com/microsoft/hve-core/blob/main/.github/PULL_REQUEST_TEMPLATE.md) - Submission checklist

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
