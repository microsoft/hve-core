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

## Collection Manifests

Collection manifests in `collections/*.collection.yml` are the source of truth for artifact selection and maturity.

### Collection Purpose

Collection manifests serve three primary functions:

1. **Selection**: Determine which artifacts are included in each collection via `items[]`
2. **Maturity filtering**: Control channel inclusion with `items[].maturity` (defaults to `stable`)
3. **Packaging inputs**: Provide canonical manifest data used by build and distribution flows

### Collection Structure

Each manifest contains top-level collection metadata and an `items` array:

```yaml
id: coding-standards
name: Coding Standards
description: Language-specific coding instructions
tags:
  - coding-standards
  - bash
  - python
items:
  - path: .github/instructions/python-script.instructions.md
    kind: instruction
    maturity: stable
  - path: .github/prompts/task-plan.prompt.md
    kind: prompt
    maturity: preview
```

### Collection Tags

Each collection manifest declares a top-level `tags` array for categorization and discoverability. Tags exist **only at the collection level**, not on individual items.

| Collection           | Tags                                                                          |
|----------------------|-------------------------------------------------------------------------------|
| `hve-core-all`       | `hve`, `complete`, `bundle`                                                   |
| `ado`                | `azure-devops`, `ado`, `work-items`, `builds`, `pull-requests`                |
| `coding-standards`   | `coding-standards`, `bash`, `bicep`, `csharp`, `python`, `terraform`, `uv`    |
| `data-science`       | `data`, `jupyter`, `streamlit`, `dashboards`, `visualization`, `data-science` |
| `git`                | `git`, `commits`, `merge`, `pull-request`                                     |
| `github`             | `github`, `issues`, `backlog`, `triage`, `sprint`                             |
| `project-planning`   | `documentation`, `architecture`, `adr`, `brd`, `prd`, `diagrams`, `planning`  |
| `prompt-engineering` | `prompts`, `agents`, `authoring`, `refactoring`                               |
| `rpi`                | `workflow`, `rpi`, `planning`, `research`, `implementation`, `review`         |
| `security-planning`  | `security`, `incident-response`, `risk`, `planning`                           |

When creating a new collection, choose tags that describe the domain, technologies, and workflows covered. Use lowercase kebab-case and prefer existing tags before introducing new ones.

### Collection Item Format

Each `items[]` entry follows this structure:

```yaml
- path: .github/agents/rpi-agent.agent.md
  kind: agent
  maturity: stable
```

| Field      | Required | Description                                                                    |
|------------|----------|--------------------------------------------------------------------------------|
| `path`     | Yes      | Repository-relative path to the artifact source                                |
| `kind`     | Yes      | Artifact type (`agent`, `prompt`, `instruction`, `skill`, or `hook`)           |
| `maturity` | No       | Release readiness level; when omitted, effective maturity defaults to `stable` |

### Adding Artifacts to a Collection

When contributing a new artifact:

1. Create the artifact file in the appropriate directory
2. Add a matching `items[]` entry in one or more `collections/*.collection.yml` files
3. Set `maturity` when the artifact should be `preview`, `experimental`, or `deprecated`
4. Update the collection's `tags` array if your artifact introduces a new technology or domain not yet represented
5. Run `npm run lint:yaml` to validate manifest syntax and schema compliance

### Repo-Specific Instructions Exclusion

Instructions placed in `.github/instructions/hve-core/` are repo-specific and MUST NOT be added to collection manifests. These files govern internal hve-core repository concerns (CI/CD workflows, repo-specific conventions) that do not apply outside this repository. They are excluded from:

* Collection manifests
* Extension packaging and distribution
* Collection builds
* Artifact selection for published bundles

If your instructions apply only to the hve-core repository and are not intended for distribution to consumers, place them in `.github/instructions/hve-core/`. Otherwise, place them in `.github/instructions/` or a technology-specific subdirectory (e.g., `csharp/`, `bash/`).

## Collection Taxonomy

Collections represent role-targeted artifact packages for HVE-Core artifacts. The collection system enables role-specific artifact distribution without fragmenting the codebase.

### Defined Collections

| Collection             | Identifier           | Description                                                                      |
|------------------------|----------------------|----------------------------------------------------------------------------------|
| **All**                | `hve-core-all`       | Full bundle of all stable HVE Core agents, prompts, instructions, and skills     |
| **Azure DevOps**       | `ado`                | Azure DevOps work item management, build monitoring, and pull request creation   |
| **Coding Standards**   | `coding-standards`   | Language-specific coding instructions for bash, Bicep, C#, Python, and Terraform |
| **Data Science**       | `data-science`       | Data specification generation, Jupyter notebooks, and Streamlit dashboards       |
| **Git Workflow**       | `git`                | Git commit messages, merges, setup, and pull request prompts                     |
| **GitHub Backlog**     | `github`             | GitHub issue discovery, triage, sprint planning, and backlog execution           |
| **Project Planning**   | `project-planning`   | PRDs, BRDs, ADRs, architecture diagrams, and documentation operations            |
| **Prompt Engineering** | `prompt-engineering` | Tools for analyzing, building, and refactoring prompts, agents, and instructions |
| **RPI Workflow**       | `rpi`                | Research, Plan, Implement, Review workflow agents and prompts                    |
| **Security Planning**  | `security-planning`  | Security plan creation, incident response, and risk assessment                   |

### Collection Assignment Guidelines

When assigning collections to artifacts:

* **Universal artifacts** should include `hve-core-all` plus any role-specific collections that particularly benefit
* **Role-specific artifacts** should include only the relevant collections (omit `hve-core-all` for highly specialized artifacts)
* **Cross-cutting tools** like RPI workflow artifacts (`task-researcher`, `task-planner`) should include multiple relevant collections

**Example collection assignments:**

Adding an artifact to multiple collections means adding its `items[]` entry in each relevant `collections/*.collection.yml`:

```yaml
# In collections/hve-core-all.collection.yml - Universal
- path: .github/instructions/markdown.instructions.md
  kind: instruction

# In collections/coding-standards.collection.yml - Coding standards
- path: .github/instructions/markdown.instructions.md
  kind: instruction

# In collections/rpi.collection.yml - Core workflow
- path: .github/agents/rpi-agent.agent.md
  kind: agent
```

### Selecting Collections for New Artifacts

Answer these questions when determining collection assignments:

1. **Who is the primary user?** Identify the main role that benefits from this artifact
2. **Who else benefits?** Consider secondary roles that may find value
3. **Is it foundational?** Core workflow artifacts should include multiple collections
4. **Is it specialized?** Domain-specific artifacts may target fewer collections

When in doubt, include `hve-core-all` to ensure the artifact appears in the full collection while still enabling targeted distribution.

## Dependency Declarations

Some artifacts require other artifacts to function correctly. Dependency behavior is resolved during packaging.

### Dependency Types

| Type           | Purpose                                                                          |
|----------------|----------------------------------------------------------------------------------|
| `agents`       | Agents this artifact dispatches at runtime via `runSubagent` (excludes handoffs) |
| `prompts`      | Prompts this artifact invokes or references                                      |
| `instructions` | Instructions this artifact relies on for code generation                         |
| `skills`       | Skills this artifact executes for specialized tasks                              |

> **Note**: Frontmatter `handoffs` (UI buttons that suggest next agents) are resolved dynamically during packaging and MUST NOT be listed in `requires.agents`. Only agents invoked programmatically through `runSubagent` belong here.

### Handoff vs Requires Maturity Filtering

Handoff targets and `requires` dependencies follow different maturity rules during extension packaging:

| Mechanism  | Maturity Filtered | Reason                                                                    |
|------------|-------------------|---------------------------------------------------------------------------|
| `requires` | Yes               | Runtime dependencies are excluded when their maturity exceeds the channel |
| `handoffs` | No                | UI buttons must resolve to a valid agent or the button is broken          |

During extension packaging (`scripts/extension/Prepare-Extension.ps1`), the `Resolve-HandoffDependencies` function encounters a handoff target whose maturity falls outside the allowed set and still includes that agent in the package. The maturity check only gates whether the target's own handoffs are traversed further. This ensures that a stable agent handing off to a preview agent produces a functional UI button in both stable and pre-release channels.

The companion function `Resolve-RequiresDependencies` in the same script applies strict maturity filtering: dependencies whose maturity level is outside the allowed set are excluded entirely.

### Declaring Dependencies

Add the `requires` field to collection items in `collections/*.collection.yml`:

```yaml
- path: .github/agents/rpi-agent.agent.md
  kind: agent
  maturity: stable
  requires:
    agents:
      - task-researcher
      - task-planner
      - task-implementor
      - task-reviewer
    prompts:
      - task-research
      - task-plan
      - task-implement
      - task-review
```

### Dependency Resolution

Dependency resolution currently operates at **build time** during extension packaging. The `Resolve-RequiresDependencies` function in `Prepare-Extension.ps1` walks `requires` blocks to compute the transitive closure of all dependent artifacts across types (agents, prompts, instructions, skills). Similarly, `Resolve-HandoffDependencies` performs BFS traversal of agent handoff declarations to ensure all reachable agents are included in the package.

For clone-based installations, the installer agent supports **agent-only collection filtering** in Phase 7. Full installer-side dependency resolution (automatically including required prompts, instructions, and skills based on the dependency graph) is planned for a future release.

### Dependency Best Practices

* **Declare all runtime dependencies**: List every artifact your artifact references
* **Prefer explicit over implicit**: Document dependencies even if currently co-located
* **Keep dependencies minimal**: Avoid unnecessary coupling between artifacts
* **Test with minimal installs**: Verify your artifact works with only declared dependencies

## Maturity Field Requirements

Maturity is defined in `collections/*.collection.yml` under `items[].maturity` and MUST NOT appear in artifact frontmatter.

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

When `items[].maturity` is omitted, the effective maturity defaults to `stable`.

### Default for New Contributions

New collection items **SHOULD** use `maturity: stable` unless:

* The artifact is a proof-of-concept or experimental feature
* The artifact requires additional testing or feedback before wide release
* The contributor explicitly intends to target early adopters

### Setting Maturity

Add or update the maturity value on each collection item in `collections/*.collection.yml`:

```yaml
items:
  - path: .github/agents/example.agent.md
    kind: agent
    maturity: stable
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

See [commit-message.instructions.md](../../.github/instructions/commit-message.instructions.md) for the complete list of types and scopes.

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
