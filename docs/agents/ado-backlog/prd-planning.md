---
title: PRD Planning Workflow
description: Convert product requirements documents into Azure DevOps work item hierarchies with structured decomposition
author: Microsoft
ms.date: 2026-02-26
ms.topic: tutorial
keywords:
  - azure devops backlog manager
  - prd planning
  - work item hierarchy
  - github copilot
estimated_reading_time: 4
---

The PRD Planning workflow converts product requirements documents into Azure DevOps work item hierarchies, decomposing requirements into the four-level structure (Epic > Feature > Story > Task) that Azure DevOps supports natively.

## When to Use

* 📄 A product requirements document needs conversion to work items
* 🏗️ Building an initial backlog from a specification or design document
* 🔗 Requirements need traceability from document to backlog items
* 📊 Converting a large requirements set into a structured work item hierarchy

## What It Does

1. Accepts a PRD, specification, or requirements document as input
2. Delegates to the `@AzDO PRD to WIT` agent for parsing and decomposition
3. Maps requirements to Azure DevOps work item types (Epic, Feature, User Story, Task)
4. Builds parent-child relationships following the four-level hierarchy
5. Produces a handoff file with the complete work item hierarchy ready for execution

> [!NOTE]
> PRD Planning delegates to a specialized agent (`@AzDO PRD to WIT`) that handles the document parsing and hierarchy construction. The ADO Backlog Manager orchestrates the handoff and provides the execution path.

## Hierarchy Model

Azure DevOps supports a four-level work item hierarchy. PRD Planning maps requirements to the appropriate level based on scope and granularity:

| Level   | Work Item Type | Typical Scope                          |
|---------|----------------|----------------------------------------|
| Level 1 | Epic           | Business initiative or major objective |
| Level 2 | Feature        | Functional capability or component     |
| Level 3 | User Story     | User-facing requirement or scenario    |
| Level 4 | Task           | Implementation step or technical work  |

Requirements that span multiple features become Epics. Requirements with clear user value become User Stories. Implementation details become Tasks under their parent Stories.

## Output Artifacts

```text
.copilot-tracking/workitems/prds/<prd-name>/
├── artifact-analysis.md  # Extracted requirements and field mappings
├── work-items.md         # Proposed work item hierarchy
├── planning-log.md       # Decomposition decisions and progress
└── handoff.md            # Execution-ready operations
```

## How to Use

### Option 1: Handoff Button

Click the "PRD" handoff button in the ADO Backlog Manager agent. This delegates to the `@AzDO PRD to WIT` agent with your document context.

### Option 2: Direct Reference

Reference your requirements document in a conversation with the ADO Backlog Manager:

```text
Convert this PRD to Azure DevOps work items: [path/to/requirements.md]
```

### Option 3: Inline Content

Paste requirements directly into the chat:

```text
Create a work item hierarchy from these requirements:
1. Users can search by keyword
2. Search results display in a paginated list
3. Results can be filtered by date range
```

## Example Prompt

```text
Parse the product requirements document at docs/prd-v2.md and create
an Azure DevOps work item hierarchy. Use Epics for major features and
decompose each into Stories with Tasks for implementation steps.
```

## Tips

* ✅ Provide a structured document with clear requirement boundaries for best results
* ✅ Review the proposed hierarchy before executing to verify parent-child relationships
* ✅ Use the execution workflow to apply the hierarchy after review
* ✅ Combine with sprint planning to assign the created hierarchy to iterations
* ❌ Do not mix PRD planning with manual work item creation in the same session
* ❌ Do not skip hierarchy review before execution (parent-child errors are harder to fix)
* ❌ Do not expect PRD planning to handle ongoing triage (use the triage workflow instead)

## Common Pitfalls

| Pitfall                                  | Solution                                                      |
|------------------------------------------|---------------------------------------------------------------|
| Requirements too vague for decomposition | Add specificity to the source document before conversion      |
| Hierarchy too deep or too shallow        | Adjust the decomposition level in your prompt                 |
| Duplicate work items from repeated runs  | Check existing backlog items before re-running PRD conversion |
| Missing parent-child links               | Verify the handoff file before execution                      |

## Next Steps

1. Review the proposed hierarchy in the handoff file
2. Use the "Execute" handoff to apply the work item hierarchy to Azure DevOps
3. Continue with [Sprint Planning](sprint-planning.md) to assign iterations to the new items

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
