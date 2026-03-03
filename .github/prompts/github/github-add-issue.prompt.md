---
description: 'Create a GitHub issue using discovered repository templates and conversational field collection'
agent: GitHub Backlog Manager
argument-hint: "[templateName=...] [title=...] [labels=...]"
---

# Add GitHub Issue

Discover available issue templates from the repository, collect required and optional fields through conversation, create the issue via GitHub MCP tools, and log the result for tracking.

Follow all instructions from #file:../../instructions/github/github-backlog-planning.instructions.md for shared conventions and the GitHub MCP Tool Catalog.

## Inputs

* `${input:templateName}`: (Optional) Specific template name to use. When not provided, discover available templates and present options.
* `${input:title}`: (Optional) Issue title. When not provided, prompt during field collection.
* `${input:body}`: (Optional) Issue body content. When not provided, prompt during field collection.
* `${input:labels}`: (Optional) Comma-separated labels to apply.
* `${input:assignees}`: (Optional) Comma-separated assignees.

## Required Steps

The workflow proceeds through five steps: resolve repository context, discover available templates, collect issue details from the user, create the issue, and log the result as a tracking artifact.

### Step 1: Resolve Repository Context

Establish the target repository and verify access before proceeding.

1. Call `mcp_github_get_me` to verify repository access and determine the authenticated user.
2. Derive the repository owner and name from the active workspace git remote or user input.
3. Call `mcp_github_list_issue_types` with the owner parameter to determine whether the organization supports issue types. Record valid type values for use during issue creation.

### Step 2: Discover Templates

Locate and parse issue templates from the repository.

1. Use `list_dir` to check whether `.github/ISSUE_TEMPLATE/` exists in the repository.
2. When the directory exists, enumerate `.yml` and `.md` template files and read each with `read_file`. Extract the template name, description, default title pattern, default labels, default assignees, and field definitions from YAML frontmatter and body content.
3. When the directory does not exist or is empty, proceed with generic fields (title, body, labels, assignees) and inform the user that no custom templates were found.

### Step 3: Collect Issue Details

Select a template and gather field values through conversation.

1. When `${input:templateName}` matches a discovered template, use it. When multiple templates exist and no input was provided, present the available options and ask the user to select one. When only one template exists, use it automatically.
2. For each required field not already provided through inputs, prompt the user with the field label and description. Validate that required fields are not empty before continuing.
3. For optional fields not provided through inputs, ask the user whether they want to supply a value.
4. Merge template defaults with user-provided values for labels and assignees, removing duplicates.
5. When the organization supports issue types (from Step 1), include the type field in collection if the template or user specifies one.

### Step 4: Create Issue

Submit the issue to GitHub and confirm the result.

1. Call `mcp_github_issue_write` with `method: 'create'`, supplying the owner, repo, title, formatted body, labels, and assignees collected in previous steps. Include the `type` parameter only when the organization supports issue types and a type was selected.
2. On success, extract the issue number and URL from the response and confirm creation with the user.
3. On failure, report the error and suggest corrections or a retry.

### Step 5: Log Artifact

Record the created issue for tracking purposes.

1. Create or append to an artifact file in `.copilot-tracking/github-issues/` using the filename pattern `issue-{number}.md`.
2. Include the issue number, URL, creation timestamp, template used, applied labels, assignees, and field values.
3. Confirm the artifact location to the user.

## Success Criteria

* Repository context is resolved and access is verified before template discovery.
* All available templates are discovered and presented when multiple exist.
* Required fields are validated before issue creation.
* The issue is created with correct metadata including labels, assignees, and type when supported.
* An artifact file is created in `.copilot-tracking/github-issues/` with issue details.

## Error Handling

* Template directory missing: proceed with generic fields and inform the user.
* Template parse error: skip the malformed template, continue with remaining templates, and warn the user.
* Required field missing after prompting: re-prompt until a value is provided.
* Issue creation failure: display the error message and suggest corrections.
* Organization does not support issue types: omit the type parameter silently.

---

Proceed with creating the GitHub issue following the Required Steps.
