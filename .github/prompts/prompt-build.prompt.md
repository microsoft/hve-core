---
description: "Build or improve prompt engineering artifacts following quality criteria - Brought to you by microsoft/hve-core"
agent: 'prompt-builder'
argument-hint: "file=... [requirements=...]"
---

# Prompt Build

## Inputs

* ${input:file}: (Optional) Target prompt file path. Defaults to the current open file or attached file.
* ${input:requirements}: (Optional) Additional requirements or context from the user request.

## Required Steps

### Step 1: Interpret the user request

Analyze the user request and conversation context to determine the operation.

Identify the target file:

* Use `${input:file}` when provided.
* Otherwise use the currently open editor file or attached files.
* When no target file can be determined, request clarification from the user.
* When creating a new file, use the file type conventions in the prompt-builder instructions to determine the appropriate path.

Classify the operation:

* *Create*: Target file does not exist. Gather requirements and build from scratch.
* *Modify*: Target file exists. Update content, restructure, or fix issues based on user requirements.

Gather context:

* When the target file exists and is not a prompt or instructions file, read it directly.
* When the target file is a prompt or instructions file, delegate reading to a subagent via runSubagent. If runSubagent is unavailable, pause and request confirmation to proceed or enable it before continuing.
* For subagent reads of prompt or instructions files, ask for a response that includes the file path, a concise summary of key sections, and any constraints.
* Read referenced files, excluding prompt files and instructions. Only subagents via runSubagent read prompt files or instructions.
* Note external documentation or SDKs mentioned in the user request.
* Treat ${input:requirements} as additional context when provided.

If requirements are unclear, conflicting, or incomplete, request clarification before continuing.

Summarize the interpretation before proceeding with the target file path, operation classification, and context sources.

### Step 2: Execute the build workflow

* Use the Required Steps protocol as the execution basis.
* Apply prompt-builder.instructions.md for file type structure, protocol patterns, and writing style.
* Follow markdown conventions for formatting, while using prompt frontmatter requirements for prompt files instead of generic markdown frontmatter guidance.
* Build or update the target file using the correct file type structure, including required frontmatter, Inputs section when variables exist, protocol sections, and the activation line.
* Update existing instructions to satisfy the Prompt Quality Criteria checklist across the entire file.
* Keep prompt or instructions file reads and subagent work confined to runSubagent.
* When runSubagent is unavailable, pause and request confirmation to proceed, then continue after confirmation. Use ${input:requirements} as additional context when present.

### Step 3: Summarize outcomes

Report outcomes after completing the protocol:

* Target file path and operation completed.
* Key changes applied.
* Validation results against the Prompt Quality Criteria checklist and any unresolved findings.

---

Proceed with the user's request following the Required Steps.
