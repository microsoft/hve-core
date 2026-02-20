---
agent: 'agent'
description: 'Generates a commit message following the commit-message.instructions.md rules based on all changes in the branch'
---

# Generate Commit Message

Follow all instructions from #file:../instructions/commit-message.instructions.md

## Input

${input:useTerminal:true} - When `true` use the `run_in_terminal` tool with `git --no-pager diff --staged`.

## Protocol

* Use ${input:useTerminal} to either use `git` or `get_changed_files` tool to get the diff of staged changes.
* Review the complete diff and build a high quality commit message following the commit message instructions.
* Output to the user this commit message inside a markdown code block.
* Inform the user that they should copy it as-is or modify it and use it for their commit message.

---

Proceed to generate the commit message
