---
description: "Save or restore conversation context using memory files - Brought to you by microsoft/hve-core"
agent: 'memory'
maturity: experimental
argument-hint: "[mode={save|continue}] [description=...]"
---

# Checkpoint

## Inputs

* ${input:mode:save}: (Optional, defaults to save) Operation mode: save or continue
* ${input:description}: (Optional) Memory file description for save, or search term for continue
* ${input:chat:true}: (Optional, defaults to true) Include conversation context

## Required Steps

### Step 1: Determine Mode

Identify the operation mode from input:

* Default to save when mode is not specified
* Interpret "continue" in the user prompt as continue mode
* Prompt for a search term when continuing without a description or open memory file

### Step 2: Execute Operation

Invoke the memory agent with determined mode:

* For save mode: Proceed to save mode phase of memory agent
  * Use the description input as the memory file name, or generate from conversation context
  * Analyze conversation for relevant context to preserve

* For continue mode:
  * Use the description input as search term, or check for open memory files
  * Search memory directory when no active memory is found
  * Present matches for selection when multiple files match

---

Proceed with the determined mode using the memory agent.
