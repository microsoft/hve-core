---
title: 'Contributing Prompts to HVE Core'
description: 'Requirements and standards for contributing GitHub Copilot prompt files to hve-core'
author: Microsoft
ms.date: 2025-11-26
ms.topic: how-to
---

This guide defines the requirements, standards, and best practices for contributing GitHub Copilot prompt files (`.prompt.md`) to the hve-core library.

**⚙️ Common Standards**: See [AI Artifacts Common Standards](ai-artifacts-common.md) for shared requirements (XML blocks, markdown quality, RFC 2119, validation, testing).

## What is a Prompt?

A **prompt** is a workflow-specific guidance document that provides context, requirements, and step-by-step instructions for GitHub Copilot to complete a particular task or process. Prompts are typically invoked in specific contexts or workflows.

## Use Cases for Prompts

Create a prompt when you need to:

* Guide a specific workflow or process (e.g., creating pull requests, processing work items)
* Provide context-sensitive instructions triggered by user actions
* Define a repeatable task with clear inputs and outputs
* Document a multi-step procedure for AI execution
* Establish standards for a particular type of deliverable

## File Structure Requirements

### Location

All prompt files **MUST** be placed in:

```text
.github/prompts/
└── your-prompt-name.prompt.md
```

### Naming Convention

* Use lowercase kebab-case: `pull-request.prompt.md`
* Be specific about workflow/task: `ado-create-pull-request.prompt.md`
* Include domain prefix when relevant: `ado-`, `git-`, `github-`
* Avoid generic names: `workflow.prompt.md` ❌ → `ado-process-my-work-items-for-task-planning.prompt.md` ✅

### File Format

Prompt files **MUST**:

1. Use the `.prompt.md` extension
2. Start with valid YAML frontmatter between `---` delimiters
3. Begin content directly after frontmatter
4. End with single newline character

## Frontmatter Requirements

### Required Fields

**`description`** (string, MANDATORY)

* **Purpose**: Concise explanation of prompt purpose and use case
* **Format**: Single sentence, 10-200 characters
* **Style**: Sentence case with proper punctuation
* **Example**: `'Required protocol for creating Azure DevOps pull requests with work item discovery and reviewer identification'`

**`mode`** (string enum, MANDATORY for prompts)

* **Purpose**: Defines when/how the prompt is invoked
* **Valid values**:
  * `agent` - Used by specialized AI agents
  * `assistant` - General-purpose assistance context
  * `copilot` - GitHub Copilot-specific workflows
  * `workflow` - Automated workflow/pipeline context
* **Example**: `workflow`

**`maturity`** (string enum, MANDATORY)

* **Purpose**: Controls which extension channel includes this prompt
* **Valid values**:
  * `stable` - Production-ready, included in Stable and Pre-release channels
  * `preview` - Feature-complete, included in Pre-release channel only
  * `experimental` - Early development, included in Pre-release channel only
  * `deprecated` - Scheduled for removal, excluded from all channels
* **Default**: New prompts should use `stable` unless targeting early adopters
* **Example**: `stable`

### Optional Fields

**`category`** (string enum)

* **Purpose**: Organizes prompts by domain
* **Valid values**:
  * `ado` - Azure DevOps workflows
  * `git` - Git operations
  * `documentation` - Documentation generation/maintenance
  * `workflow` - General workflow automation
  * `development` - Development tasks

**`version`** (string)

* **Purpose**: Tracks prompt revisions
* **Format**: Semantic versioning (e.g., `1.0.0`)

**`author`** (string)

* **Purpose**: Attribution for prompt creator
* **Example**: `microsoft/hve-core`, `your-team-name`

**`lastUpdated`** (string)

* **Purpose**: Timestamp of last modification
* **Format**: ISO 8601 date (YYYY-MM-DD)

### Frontmatter Example

```yaml
---
description: 'Required protocol for creating Azure DevOps pull requests with work item discovery, reviewer identification, and automated linking'
mode: 'workflow'
maturity: 'stable'
category: 'ado'
version: '1.0.0'
author: 'microsoft/hve-core'
lastUpdated: '2025-11-19'
---
```

## Prompt Content Structure Standards

### Required Sections

#### 1. Title (H1)

* Clear, action-oriented heading describing the workflow
* Should align with filename and description

```markdown
# Azure DevOps Pull Request Creation Protocol
```

#### 2. Overview/Purpose

* Explains what the prompt does and when to use it
* Defines scope and prerequisites
* Lists expected outcomes

```markdown
## Overview

This prompt guides the creation of Azure DevOps pull requests with automated
work item discovery, reviewer identification, and compliance validation.
```

#### 3. Prerequisites/Context

* Lists required information, tools, or setup
* Specifies environment assumptions
* Defines input requirements

```markdown
## Prerequisites

* Active Azure DevOps connection
* Current branch with committed changes
* Work item IDs or branch naming following conventions
```

#### 4. Workflow Steps

* Provides clear, numbered steps for execution
* Uses imperative, unambiguous language
* Includes decision points and branching logic
* Specifies tool usage at each step

```markdown
## Workflow Steps

1. **Discovery Phase**: Identify related work items from branch name or commit messages
2. **Reviewer Selection**: Query ADO for default reviewers based on repository policies
3. **PR Creation**: Generate PR with title, description, and work item links
4. **Validation**: Verify PR was created successfully with correct metadata
```

#### 5. Success Criteria

* Defines completion conditions
* Specifies validation checkpoints
* Lists expected artifacts

```markdown
## Success Criteria

* [ ] PR created in target repository
* [ ] Work items linked to PR
* [ ] Required reviewers added
* [ ] PR description follows template
```

#### 6. Examples

* Demonstrates correct usage with realistic scenarios
* Shows input/output patterns
* Wraps in XML-style blocks for reusability

#### 7. Error Handling

* Documents common failure modes
* Provides recovery procedures
* Specifies fallback behaviors

#### 8. Attribution Footer

* **MANDATORY**: Include at end of file

```markdown
---

Brought to you by microsoft/hve-core
```

### XML-Style Block Requirements

See [AI Artifacts Common Standards - XML-Style Block Standards](ai-artifacts-common.md#xml-style-block-standards) for complete rules and examples.

### Template Variable Standards

Use `{{double_curly_braces}}` for placeholders:

<!-- <example-template-variables> -->
```yaml
# ✅ CORRECT: Template variables in YAML frontmatter
---
title: "{{feature_name}} - {{brief_description}}"
branch: "feature/{{work_item_id}}-{{task_name}}"
assignee: "{{user_email}}"
---

# ❌ INCORRECT: Non-standard variable syntax in YAML frontmatter
---
title: "<feature-name> - <brief-description>"
branch: "feature/<work-item-id>-<task-name>"
assignee: "<user.email>"
---
```
<!-- </example-template-variables> -->

**Variable Naming**:

* Use snake_case: `{{work_item_id}}`, `{{user_name}}`
* Be descriptive: `{{target_branch}}` not `{{tb}}`
* Group related variables: `{{pr_title}}`, `{{pr_description}}`, `{{pr_labels}}`

### Directive Language Standards

Use RFC 2119 compliant keywords (MUST/SHOULD/MAY). See [AI Artifacts Common Standards - RFC 2119 Directive Language](ai-artifacts-common.md#rfc-2119-directive-language) for complete guidance.

## Workflow Definition Standards

Prompts should clearly define:

### Entry Points

What triggers this prompt:

```markdown
## Invocation

This prompt is invoked when:

* User requests "create ADO pull request"
* User runs command: `/prompt ado-create-pull-request`
* Workflow automation reaches PR creation step
```

### Decision Points

Where choices affect flow:

```markdown
## Decision Logic

**If** work items found in branch name:
  → Use those work items for linking

**Else if** work items in commit messages:
  → Extract and use those work items

**Else**:
  → Prompt user for work item IDs
```

### Tool Usage

Which tools are used and when:

```markdown
## Required Tools

1. `mcp_azure_devops` - Work item queries and PR creation
2. `git/*` - Branch and commit information
3. `search` - Repository policy lookups
```

### Output Specifications

What artifacts are produced:

```markdown
## Output Artifacts

1. **Pull Request**: Created in ADO with metadata
2. **Handoff Document**: `.copilot-tracking/pr/{{YYYY-MM-DD}}-pr-{{id}}-handoff.md`
3. **Validation Report**: Summary of PR creation status
```

## Context Requirements

Prompts **SHOULD** specify:

### File/Path Contexts

When specific files/paths trigger behavior:

```yaml
---
description: 'Required protocol for creating Azure DevOps pull requests'
mode: 'workflow'
applyTo: '**/.copilot-tracking/pr/new/**'  # Workflow-specific context
---
```

### Data Requirements

What information must be available:

```markdown
## Required Context

* `{{current_branch}}` - Active git branch name
* `{{target_branch}}` - Destination branch (default: main/master)
* `{{repository_url}}` - ADO repository URL
* `{{user_email}}` - Current user's email for reviewer queries
```

### State Assumptions

What must be true before execution:

```markdown
## Preconditions

* Working directory is a git repository
* Changes are committed to current branch
* User has ADO credentials configured
* Target branch exists in remote repository
```

## Output Formatting Requirements

Define how the prompt produces results:

### Response Format

Structure for user-facing output:

```markdown
## Output Format

### PR Creation Summary

**Status**: [Success|Failed]
**PR ID**: [ID]
**PR URL**: [URL]
**Work Items Linked**: [IDs]
**Reviewers Added**: [Names]

### Validation Results

* [x] PR created successfully
* [x] Work items linked
* [ ] CI pipeline triggered
```

### File Outputs

Specifications for generated files:

```markdown
## Handoff Document Format

File: `.copilot-tracking/pr/{{YYYY-MM-DD}}-pr-{{id}}-handoff.md`

Content:

* PR metadata (ID, URL, title)
* Work item links with status
* Reviewer assignments
* Validation checklist
```

### Error Reporting

Format for failure scenarios:

```markdown
## Error Format

**Error Type**: [Authentication|Validation|Network]
**Message**: [Detailed error description]
**Recovery Steps**:

1. [Step to resolve]
2. [Alternative approach]
```

## Validation Checklist

Before submitting your prompt, verify:

### Frontmatter

* [ ] Valid YAML between `---` delimiters
* [ ] `description` field present and descriptive (10-200 chars)
* [ ] `mode` field present with valid value
* [ ] `category` field appropriate for domain (if present)
* [ ] No trailing whitespace in values
* [ ] Single newline at EOF

### Content Structure

* [ ] Clear H1 title describing workflow
* [ ] Overview/purpose section
* [ ] Maturity field set appropriately (see [Common Standards - Maturity](ai-artifacts-common.md#maturity-field-requirements))
* [ ] Prerequisites or context section
* [ ] Workflow steps with clear sequence
* [ ] Success criteria defined
* [ ] Error handling documented
* [ ] Attribution footer present

### Workflow Definition

* [ ] Entry points/triggers specified
* [ ] Decision logic clearly documented
* [ ] Tool usage requirements listed
* [ ] Output artifacts defined
* [ ] State assumptions documented

### Common Standards

* [ ] Markdown quality (see [Common Standards - Markdown Quality](ai-artifacts-common.md#markdown-quality-standards))
* [ ] XML-style blocks properly formatted (see [Common Standards - XML-Style Blocks](ai-artifacts-common.md#xml-style-block-standards))
* [ ] RFC 2119 keywords used consistently (see [Common Standards - RFC 2119](ai-artifacts-common.md#rfc-2119-directive-language))
* [ ] Template variables use `{{snake_case}}`

### Technical Validation

* [ ] All file references point to existing files
* [ ] External links are valid and accessible
* [ ] Tool references use correct names
* [ ] Template variables are clearly defined

### Integration

* [ ] Aligns with `.github/copilot-instructions.md`
* [ ] Follows repository conventions
* [ ] Compatible with existing prompts/workflows
* [ ] Does not duplicate existing prompt functionality

## Testing Your Prompt

See [AI Artifacts Common Standards - Common Testing Practices](ai-artifacts-common.md#common-testing-practices) for testing guidelines. For prompts specifically:

1. Follow prompt steps manually to verify workflow logic
2. Test with AI execution using realistic scenarios
3. Verify all output artifacts match specifications
4. Test decision points with different data conditions

## Common Issues and Fixes

### Prompt-Specific Issues

### Template Variables with Wrong Format

* **Problem**: Using incorrect syntax for template variables (angle brackets or shell-style)
* **Solution**: Always use `{{variable_name}}` handlebars format for template variables

### Ambiguous Workflow Steps

* **Problem**: Vague workflow steps without specific tools, conditions, or decision logic
* **Solution**: Provide explicit tool usage, decision trees, and fallback strategies with clear conditional logic

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
* [Contributing Custom Agents](custom-agents.md) - AI agent configuration files
* [Contributing Instructions](instructions.md) - Technology-specific standards
* [Pull Request Template](../../.github/PULL_REQUEST_TEMPLATE.md) - Submission requirements

## Getting Help

See [AI Artifacts Common Standards - Getting Help](ai-artifacts-common.md#getting-help) for support resources. For prompt-specific assistance, review existing examples in `.github/prompts/`.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
