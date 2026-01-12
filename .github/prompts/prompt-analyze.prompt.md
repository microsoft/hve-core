---
description: "Analyze prompt files without modification, producing quality reports, comparisons, or documentation - Brought to you by microsoft/hve-core"
agent: 'prompt-builder'
argument-hint: "[mode={validate|compare|document}] [file=<path>] [file1=<path> file2=<path>]"
---

# Prompt Analyze

## Inputs

* ${input:mode:validate}: (Optional, defaults to validate) Analysis mode - validate for quality assessment, compare for side-by-side analysis, document for generating usage documentation
* ${input:file}: (Optional) Target prompt file for validate or document modes; defaults to current open file or attached file
* ${input:file1}: (Required for compare mode unless inferred) First prompt file; can be inferred from attached files or user prompt
* ${input:file2}: (Required for compare mode unless inferred) Second prompt file; can be inferred from open editor, attachments, or user prompt
* ${input:output}: (Optional, document mode) Output path for generated documentation; defaults to `.copilot-tracking/prompt-docs/`

## Analysis Protocol

### 1. Determine Analysis Mode

Analyze the user prompt to establish the analysis mode:

When `${input:mode}` is explicitly provided, use that mode directly.

When mode is not explicit, infer from user prompt signals:

<!-- <analyze-mode-signals> -->
| Signal Words | Mode |
|--------------|------|
| validate, check, audit, review, quality, assess | validate |
| compare, diff, versus, vs, between, which is better | compare |
| document, docs, explain, describe, usage, help | document |
<!-- </analyze-mode-signals> -->

When no clear signal is present, default to **validate** mode.

### 2. Locate Target Files

Identify the files to analyze based on the selected mode:

For validate mode:

* Use `${input:file}` if provided
* Otherwise use the currently open editor file
* Otherwise check for attached files in the conversation
* Confirm the file exists and is a prompt engineering artifact (.prompt.md, .chatmode.md, .agent.md, or .instructions.md)

For compare mode:

* Resolve two files from available sources in priority order:
  1. Explicit inputs: use `${input:file1}` and `${input:file2}` if both provided
  2. Mixed sources: combine attached file(s) with currently open editor file
  3. Multiple attachments: use the first two attached prompt files in order
  4. User prompt mentions: extract file paths mentioned in the user prompt
* When only one file is identifiable, prompt the user to specify the second file
* Confirm both files exist before proceeding

For document mode:

* Follow the same resolution as validate mode for the target file
* Determine output location from `${input:output}` or use default path `.copilot-tracking/prompt-docs/<filename>-docs.md`

### 3. Execute Mode-Specific Analysis

#### Validate Mode

Assess the quality of a single prompt file through Prompt Tester evaluation:

* Read the target file in full
* Identify the file type (prompt, chatmode/agent, or instructions) from extension and content
* Construct a representative test scenario appropriate to the file's purpose
* Dispatch Prompt Tester with the constructed scenario

Compile a quality report from Prompt Tester findings:

<!-- <validate-report-structure> -->
* **File Overview**: Path, file type, description from frontmatter, and primary purpose
* **Compliance Assessment**: Adherence to prompt-builder.chatmode.md standards for the file type
* **Issues Found**: Categorized by severity (critical, major, minor) with specific line references
* **Strengths**: Aspects of the prompt that follow best practices
* **Recommendations**: Suggested improvements without applying them
<!-- </validate-report-structure> -->

#### Compare Mode

Analyze two prompt files to identify differences and recommend which approach to prefer:

* Read both files in full
* Identify file types and verify they are comparable (warn if comparing different file types)

Perform structural comparison:

* Compare frontmatter fields (description, agent, tools, applyTo)
* Compare input variables and their defaults
* Compare steps or phases (count, naming, structure)
* Compare referenced files and external dependencies
* Compare activation patterns and exit conditions

Dispatch Prompt Tester on both files using identical test scenarios:

* Use the same representative scenario for both files
* Record quality scores and issues for each

Compile a comparison report:

<!-- <compare-report-structure> -->
* **File Summaries**: Brief overview of each file's purpose and approach
* **Structural Differences**: Table of key differences in structure, inputs, and references
* **Quality Comparison**: Side-by-side Prompt Tester results (issues, severity counts)
* **Approach Analysis**: How each file handles the same use case differently
* **Recommendation**: Which file to prefer and why, or when each is more appropriate
<!-- </compare-report-structure> -->

#### Document Mode

Generate usage documentation from a prompt file for users and contributors:

* Read the target file in full
* Extract all documentable elements from the content

Generate documentation covering:

<!-- <document-output-structure> -->
* **Purpose**: What the prompt accomplishes, derived from frontmatter description and content
* **When to Use**: Scenarios where this prompt is appropriate
* **Prerequisites**: Required tools, files, or state before invocation
* **Inputs**: Table of input variables with types, defaults, and descriptions
* **Execution Flow**: Summary of steps or phases with brief descriptions
* **Outputs**: What the prompt produces (files, reports, state changes)
* **Examples**: Sample invocations with expected outcomes
* **Related Prompts**: Links to prompts that complement or extend this one
<!-- </document-output-structure> -->

Create or update documentation at the output path:

* Format as markdown suitable for docs/ inclusion
* Include cross-references to the source prompt file

### 4. Report Findings

Present analysis results based on the mode:

For validate mode:

* Display the quality report with clear section headings
* Highlight critical issues first, followed by major and minor
* Provide line-specific references for each issue
* List recommendations as actionable next steps

For compare mode:

* Display the comparison report with both files clearly identified
* Use tables for structural differences
* Present the recommendation with supporting rationale
* Note any caveats about the comparison (different file types, different purposes)

For document mode:

* Confirm the documentation file path created or updated
* Display a summary of what was documented
* Note any sections that could not be generated due to missing information

---

Proceed with prompt analysis following the Analysis Protocol.
