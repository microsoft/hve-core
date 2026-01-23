# Pull Request

## Description
<!-- Provide a clear description of the changes in this PR -->

## Related Issue(s)
<!-- Link to the issue(s) this PR addresses using "Fixes #123" or "Closes #123" -->

## Type of Change

Select all that apply:

**Code & Documentation:**

- [ ] Bug fix (non-breaking change fixing an issue)
- [ ] New feature (non-breaking change adding functionality)
- [ ] Breaking change (fix or feature causing existing functionality to change)
- [ ] Documentation update

**Infrastructure & Configuration:**

- [ ] GitHub Actions workflow
- [ ] Linting configuration (markdown, PowerShell, etc.)
- [ ] Security configuration
- [ ] DevContainer configuration
- [ ] Dependency update

**AI Artifacts:**

- [ ] Reviewed contribution with `prompt-builder` agent and addressed all feedback
- [ ] Copilot instructions (`.github/instructions/*.instructions.md`)
- [ ] Copilot prompt (`.github/prompts/*.prompt.md`)
- [ ] Copilot agent (`.github/agents/*.agent.md`)

> **Note for AI Artifact Contributors**:
>
> - **Agents**: Research, indexing/referencing other project (using standard VS Code GitHub Copilot/MCP tools), planning, and general implementation agents likely already exist. Review `.github/agents/` before creating new ones.
> - **Model Versions**: Only contributions targeting the **latest Anthropic and OpenAI models** will be accepted. Older model versions (e.g., GPT-3.5, Claude 3) will be rejected.
> - See [Agents Not Accepted](../docs/contributing/custom-agents.md#agents-not-accepted) and [Model Version Requirements](../docs/contributing/ai-artifacts-common.md#model-version-requirements).

**Other:**

- [ ] Script/automation (`.ps1`, `.sh`, `.py`)
- [ ] Other (please describe):

## Sample Prompts (for AI Artifact Contributions)

<!-- If you checked any boxes under "AI Artifacts" above, provide a sample prompt showing how to use your contribution -->
<!-- Delete this section if not applicable -->

**User Request:**
<!-- What natural language request would trigger this agent/prompt/instruction? -->

**Execution Flow:**
<!-- Step-by-step: what happens when invoked? Include tool usage, decision points -->

**Output Artifacts:**
<!-- What files/content are created? Show first 10-20 lines as preview -->

**Success Indicators:**
<!-- How does user know it worked correctly? What validation should they perform? -->

For detailed contribution requirements, see:

- **Common Standards**: [docs/contributing/ai-artifacts-common.md](../docs/contributing/ai-artifacts-common.md) - Shared standards for XML blocks, markdown quality, RFC 2119, validation, and testing
- **Agents**: [docs/contributing/custom-agents.md](../docs/contributing/custom-agents.md) - Agent configurations with tools and behavior patterns
- **Prompts**: [docs/contributing/prompts.md](../docs/contributing/prompts.md) - Workflow-specific guidance with template variables
- **Instructions**: [docs/contributing/instructions.md](../docs/contributing/instructions.md) - Technology-specific standards with glob patterns

## Testing
<!-- Describe how you tested these changes -->

## Checklist

### Required Checks

- [ ] Documentation is updated (if applicable)
- [ ] Files follow existing naming conventions
- [ ] Changes are backwards compatible (if applicable)
- [ ] Tests added for new functionality (if applicable)

### AI Artifact Contributions
<!-- If contributing an agent, prompt, or instruction, complete these checks -->
- [ ] Used `/prompt-analyze` to review contribution
- [ ] Addressed all feedback from `prompt-builder` review
- [ ] Verified contribution follows common standards and type-specific requirements

### Required Automated Checks

The following validation commands must pass before merging:

- [ ] Markdown linting: `npm run lint:md`
- [ ] Spell checking: `npm run spell-check`
- [ ] Frontmatter validation: `npm run lint:frontmatter`
- [ ] Link validation: `npm run lint:md-links`
- [ ] PowerShell analysis: `npm run lint:ps`

## Security Considerations
<!-- ⚠️ WARNING: Do not commit sensitive information such as API keys, passwords, or personal data -->
- [ ] This PR does not contain any sensitive or NDA information
- [ ] Any new dependencies have been reviewed for security issues
- [ ] Security-related scripts follow the principle of least privilege

## Additional Notes
<!-- Any additional information that reviewers should know -->
