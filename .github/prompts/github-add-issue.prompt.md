---
agent: "agent"
description: "Add a GitHub issue to the backlog using discovered issue templates from .github/ISSUE_TEMPLATE/"
maturity: stable
---

# Add GitHub Issue to Backlog

This prompt is invoked by `github-issue-manager.agent.md` for issue creation workflow.
It can also be run standalone for direct issue creation tasks.

Follow all instructions from #file:../instructions/markdown.instructions.md

## Role

You WILL create GitHub issues by discovering available issue templates and collecting the necessary information. You WILL guide users through the process conversationally and ensure all required fields are collected before creation.

## General User Conversation Guidance

When a user wants to create an issue:

1. Discover available issue templates from `.github/ISSUE_TEMPLATE/`
2. Present template options if multiple exist
3. Collect required and optional field values conversationally
4. Create the issue via GitHub MCP tools
5. Log the creation to an artifact file for tracking

Be conversational and guide users step-by-step. Ask one question at a time and provide examples proactively.

## Inputs

* **${input:templateName}**: Specific template to use (optional, will discover if not provided)
* **${input:title}**: Issue title (optional, will prompt if not provided)
* **${input:body}**: Issue body content (optional, will prompt if not provided)
* **${input:labels}**: Comma-separated labels (optional)
* **${input:assignees}**: Comma-separated assignees (optional)

## Protocol

### 1. Template Discovery

You WILL discover and parse available issue templates from `.github/ISSUE_TEMPLATE/` directory.

1. Use `list_dir` to check if `.github/ISSUE_TEMPLATE/` exists
2. If directory exists:
   * Enumerate all `.yml` and `.md` files in the directory
   * For each template file, use `read_file` to load content
   * Parse YAML frontmatter to extract:
     * `name`: Template display name
     * `about`: Template description
     * `title`: Default issue title pattern
     * `labels`: Default labels array
     * `assignees`: Default assignees array
   * For `.yml` forms, parse the `body` array to extract field definitions:
     * Field `type`: input, textarea, dropdown, checkboxes, markdown
     * Field `id`: Unique identifier for the field
     * Field `attributes`: Contains label, description, placeholder, options
     * Field `validations`: Contains required flag
   * Build a template registry with all discovered templates
3. If directory does not exist or is empty:
   * Use generic fallback with basic fields: title, body, labels, assignees
   * Inform user that no custom templates were found

**YAML Form Template Structure**:

```yaml
name: Bug Report
description: File a bug report
title: "fix: "
labels: ["bug", "triage"]
assignees:
  - octocat
body:
  - type: markdown
    attributes:
      value: |
        Thanks for taking the time to fill out this bug report!
  - type: input
    id: contact
    attributes:
      label: Contact Details
      description: How can we get in touch with you if we need more info?
      placeholder: ex. email@example.com
    validations:
      required: false
  - type: textarea
    id: what-happened
    attributes:
      label: What happened?
      description: Also tell us, what did you expect to happen?
      placeholder: Tell us what you see!
    validations:
      required: true
```

**Markdown Template Structure**:

```markdown
---
name: Feature request
about: Suggest an idea for this project
title: ''
labels: enhancement
assignees: ''
---

**Is your feature request related to a problem? Please describe.**
A clear and concise description of what the problem is. Ex. I'm always frustrated when [...]

**Describe the solution you'd like**
A clear and concise description of what you want to happen.
```

### 2. Template Selection

You WILL allow user to select which template to use or specify custom fields.

1. If `${input:templateName}` is provided, locate that template in the registry
2. If not provided and multiple templates exist:
   * Present list of available templates with names and descriptions
   * Ask user to select a template by name or number
   * Wait for user response
3. If only one template exists, use it automatically
4. If no templates exist, proceed with generic field collection

### 3. Field Collection

You WILL collect all required and optional field values from the user.

1. Extract field definitions from selected template or use generic fields
2. For each required field:
   * Check if value was provided in inputs (e.g., `${input:title}`)
   * If not provided, prompt user with field label and description
   * Validate that required fields are not empty
3. For each optional field:
   * Check if value was provided in inputs
   * If not provided, ask user if they want to provide a value
   * Accept empty values for optional fields
4. Apply template defaults:
   * Use template's default title pattern if user didn't override
   * Merge template's default labels with user-provided labels:
     * Remove duplicates (case-insensitive comparison)
     * Order: template labels first, then user-provided labels
     * Normalize to lowercase for consistency
   * Merge template's default assignees with user-provided assignees:
     * Remove duplicates (case-insensitive comparison)
     * Order: template assignees first, then user-provided assignees
     * Normalize to lowercase for consistency
5. Build final issue data structure

**Conversation Flow Example**:

```text
Agent: I found 3 issue templates:
1. Bug Report - File a bug report
2. Feature Request - Suggest an idea for this project
3. Documentation - Report missing or incorrect documentation

Which template would you like to use? (1-3)

User: 1

Agent: Great! Let's create a Bug Report.

What happened? (Required)
Please describe the bug you encountered.

User: The login button doesn't work on mobile devices

Agent: Would you like to provide contact details? (Optional)
How can we get in touch if we need more info?

User: john@example.com

Agent: Creating issue...
```

### 4. Issue Creation

You WILL create the GitHub issue using MCP tools.

1. Use `mcp_github_create_issue` tool with collected data:
   * `title`: Final issue title
   * `body`: Formatted issue body with all field values using markdown structure:
     * **Field Name**: Value (for each collected field)
     * Blank line between each field for readability
     * Preserve original field formatting and line breaks
     * Example: "**Description**: User's issue description\n\n**Priority**: High"
   * `labels`: Array of label strings
   * `assignees`: Array of assignee usernames
2. Handle tool response:
   * On success: Extract issue number and URL from response
   * On failure: Report error to user and suggest retry or corrections
3. Confirm creation with user, providing issue number and URL

**MCP Tool Call Structure Example**:

```json
{
  "tool": "mcp_github_create_issue",
  "parameters": {
    "title": "fix: login button doesn't work on mobile devices",
    "body": "**What happened?**\nThe login button doesn't work on mobile devices\n\n**Contact Details**\njohn@example.com",
    "labels": ["bug", "triage"],
    "assignees": ["octocat"]
  }
}
```

**Expected Response**:

```json
{
  "number": 42,
  "html_url": "https://github.com/owner/repo/issues/42",
  "state": "open",
  "title": "fix: login button doesn't work on mobile devices"
}
```

### 5. Artifact Logging

You WILL log issue creation to artifact file for tracking and reference.

1. Create or append to artifact file in `.copilot-tracking/github-issues/`
2. Use filename pattern: `issue-{number}.md`
3. Include in artifact:
   * Issue number and URL
   * Creation timestamp
   * Template used
   * All field values provided
   * Issue state and metadata
4. Confirm artifact location to user

**Artifact File Template**:

```markdown
# GitHub Issue #42

**Created**: 2025-01-15T10:30:00Z
**URL**: https://github.com/owner/repo/issues/42
**State**: open
**Template**: Bug Report

## Metadata

* **Labels**: bug, triage
* **Assignees**: @octocat
* **Milestone**: None
* **Projects**: None

## Content

### Title

fix: login button doesn't work on mobile devices

### Body

**What happened?**
The login button doesn't work on mobile devices

**Contact Details**
john@example.com

## Timeline

* 2025-01-15T10:30:00Z - Issue created via GitHub MCP
```

## Output Requirements

After successful completion, you must provide:

1. **Issue Confirmation**:
   * Issue number and clickable URL
   * Issue title
   * Applied labels and assignees
   * Current state (always "open" for new issues)

2. **Artifact Location**:
   * Full path to created artifact file
   * Brief summary of logged information

3. **Next Steps** (optional suggestions):
   * Link to view the issue on GitHub
   * Suggest adding comments or updating the issue
   * Mention related issues or templates

## Error Handling

* **Template Directory Missing**: Use generic fallback fields, inform user
* **Template Parse Error**: Skip malformed template, continue with others
* **Required Field Missing**: Re-prompt user until value provided
* **Issue Creation Failure**: Display error message, suggest corrections
* **MCP Tool Unavailable**: Inform user to install GitHub MCP extension

## Success Criteria

* Issue successfully created on GitHub with correct metadata
* Artifact file created in `.copilot-tracking/github-issues/`
* User receives confirmation with issue number and URL
* All required fields validated before creation
* Template defaults properly applied
