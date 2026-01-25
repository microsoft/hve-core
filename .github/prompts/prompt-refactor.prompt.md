---
description: "Refactors and cleans up prompt engineering artifacts through iterative improvement - Brought to you by microsoft/hve-core"
argument-hint: "file=..."
agent: 'prompt-builder'
maturity: stable
---

# Prompt Refactor

This prompt extends the prompt-build workflow with a focus on refactoring and cleanup operations. The protocol iterates through research, authoring, and validation phases until the target file passes all Prompt Quality Criteria.

## Inputs

* ${input:file}: (Required) Target prompt file to refactor. Accepts `.prompt.md`, `.agent.md`, or `.instructions.md` files.
* ${input:requirements}: (Optional) Additional refactoring requirements or focus areas.

## Required Steps

**Important requirements**:

* **Important**, always be thorough and accurate.
* Follow the prompt-build protocol phases while applying these refactoring-specific requirements.
* Avoid overly verbose instructions and examples.
* Refactor instructions and examples continually.
* Repeat steps and phases as needed to be thorough and accurate.

### Step 1: Baseline Assessment

Dispatch a subagent using `runSubagent` to evaluate the current state of the target file:

* Read the target file at `${input:file}` and the prompt-builder instructions.
* Identify quality issues, outdated patterns, and areas for compression.
* Catalog any schema, API, SDK, or tool call references that require verification.
* Return findings with severity and category for each issue.

### Step 2: Research and Verification

Dispatch a research subagent using `runSubagent` to verify external references:

* Identify all schema, API, SDK, or tool call instructions in the target file.
* Use official documentation tools to verify accuracy and currency.
* Search official repositories for current patterns and conventions.
* Return a verification report with corrections needed.

### Step 3: Refactor and Compress

Apply the prompt-build protocol's Phase 3 (Build) with these refactoring requirements:

* Remove or condense redundant instructions while preserving intent.
* Replace verbose examples with concise instruction lines where examples are not essential.
* Update outdated prompting patterns to follow current Prompt Writing Style.
* Correct any schema, API, SDK, or tool call instructions based on research findings.
* Fix and improve templates to match current file type guidelines.

### Step 4: Validate and Iterate

Apply the prompt-build protocol's Phase 4 (Validate) requirements:

* Dispatch validation subagents to test the refactored file.
* Evaluate against all Prompt Quality Criteria.
* Return to Step 3 when issues are found.
* Continue iteration until all criteria pass.

### Step 5: Report Outcomes

After validation passes, summarize the refactoring session:

* List changes made with file paths.
* Summarize instructions removed, compressed, or updated.
* Report schema, API, or tool call corrections applied.
* Confirm Prompt Quality Criteria validation results.

---

Proceed with refactoring the target file following the Required Steps.
