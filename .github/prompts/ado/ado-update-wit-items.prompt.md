---
description: "Prompt to update work items based on planning files"
agent: ADO Backlog Manager
---

# Update Work Items

Follow all instructions from #file:../../instructions/ado/ado-update-wit-items.instructions.md for work item planning and planning files.

## Inputs

* ${input:handoffFile}: (Required, can be an attachment) Path to handoff markdown file, provided or inferred from attachment or prompt
* ${input:project}: (Optional) Override ADO work item project name
* ${input:areaPath}: (Optional) Override area path
* ${input:iterationPath}: (Optional) Override iteration path
* `${input:contentFormat:Markdown}`: (Optional) Content format for rich-text fields. Use `Markdown` for Azure DevOps Services (dev.azure.com) or `Html` for Azure DevOps Server (on-premises). Defaults to Markdown.
* ${input:dryRun:false}: Preview operations without making mcp ado tool calls

---

Proceed with work item execution by following all phases in order
