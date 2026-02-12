---
description: "Evaluates prompt engineering artifacts against quality criteria and reports findings - Brought to you by microsoft/hve-core"
argument-hint: "file=..."
agent: 'prompt-builder'
maturity: stable
---

# Prompt Analyze

Evaluate the specified prompt engineering artifact against quality criteria without modifying it.

## Inputs

* ${input:file}: (Required) Target prompt file to analyze. Accepts `.prompt.md`, `.agent.md`, or `.instructions.md` files.

## Mode

Operate in **analyze** mode — run Phases 1 and 2 only (Understand and Test). Do not modify the target file.

Analyze mode behavior:

* Test the target file using the executor and evaluator subagents.
* Present findings as a structured analysis report.
* When no issues are found, display ✅ **Quality Assessment Passed**.
* When issues are found, group by severity and provide actionable suggestions.

---

Proceed with analysis of the target file.
