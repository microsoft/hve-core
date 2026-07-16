---
title: Prompts Conformance Checks
description: Twelve conformance checks the vally-tests skill emits for .prompt.md artifacts, with contract citations, stimulus shapes, and Vally grader recommendations
---
<!-- markdownlint-disable-file -->

# Prompts Conformance Checks

## Overview

This reference enumerates the twelve conformance checks the `vally-tests` skill knows how to express for `.prompt.md` artifacts. Each check exercises a behavior the prompt's authoring contract already claims, then routes the resulting stimulus block to the canonical Vally eval file declared in `eval-suite-routing.md`.

The canonical eval target for this kind is `evals/behavior-conformance/prompts.eval.yaml`. New stimulus blocks are appended to its `stimuli:` array and tagged `tags.advisory: true` per `eval-suite-routing.md`. Authors MUST run every candidate stimulus through `refusal-taxonomy.md` before emission and refuse any match.

Grader identifiers below use the Vally CLI 0.4.0 catalog (`semantic_similarity`, `contains`, `regex`, `json_schema`) per `grader-catalog.md`. Where the research phrasing recommended `output-matches`, the equivalent here is `regex`; where it recommended `output-contains`, the equivalent is `contains`; where it recommended `llm-grader`, the equivalent is `semantic_similarity`.

## Contract Summary

| Topic                              | Section in hve-builder.instructions.md              |
|------------------------------------|-----------------------------------------------------|
| Frontmatter and metadata           | Frontmatter Requirements; File Types > Prompt Files |
| Agent delegation                   | File Types > Prompt Files                           |
| Input variables and argument hints | File Types > Prompt Files; Frontmatter Requirements |
| Protocol structure                 | File Types > Agent Files                            |
| Step and phase headings            | File Types > Agent Files                            |
| Writing style and link format      | Writing Style                                       |
| Subagent invocation                | Referencing Other Artifacts                         |
| Quality criteria checklist         | Quality Criteria                                    |

## Conformance Checks

### Check 1: Required Frontmatter Fields

* Contract source: `hve-builder.instructions.md`, Frontmatter Requirements and File Types > Prompt Files.
* Testable behavior: prompt frontmatter MUST include a non-empty `description:` field under 120 characters; OPTIONAL fields `agent:`, `argument-hint:`, and a `---` activation line MAY be present when the prompt delegates or accepts arguments.
* Suggested stimulus: ask the assistant to summarize the frontmatter of a named prompt under `.github/prompts/hve-core/`, then assert that the description value is surfaced in the response.
* Grader recommendation: `regex` with pattern `(?m)^description:\s*['"]?.{1,120}['"]?`.
* Evidence: `.github/prompts/hve-core/task-research.prompt.md` L2-L4 shows `description:`, `agent:`, and `argument-hint:` together.

### Check 2: Agent Delegation Without Duplication

* Contract source: `hve-builder.instructions.md`, File Types > Prompt Files.
* Testable behavior: when the prompt sets `agent:`, it MUST NOT duplicate the delegated agent's Required Phases or Required Steps; instead the prompt references the specific phases or sections that differ and extends rather than substitutes the agent's requirements section.
* Suggested stimulus: ask the assistant to describe what a delegating prompt adds on top of its agent, naming the delegated agent and any sections that differ.
* Grader recommendation: `semantic_similarity` with rubric "Does the response identify the delegated agent and confirm that the prompt extends rather than duplicates the agent's protocol?".
* Evidence: `.github/prompts/hve-core/prompt-build.prompt.md` L6-L8 delegates to the `Prompt Builder` agent and contributes a Requirements section without re-stating the agent's phases.

### Check 3: Inputs Documentation Format

* Contract source: `hve-builder.instructions.md`, File Types > Prompt Files and Frontmatter Requirements.
* Testable behavior: when the prompt defines inputs, the Inputs section MUST document every input variable using `${input:varName}` for required inputs or `${input:varName:defaultValue}` for optional inputs.
* Suggested stimulus: ask the assistant to list the inputs a named prompt accepts and the default value (if any) for each.
* Grader recommendation: `regex` with pattern `\$\{input:[a-zA-Z_][a-zA-Z0-9_]*(?::[^}]*)?\}`.
* Evidence: `.github/prompts/hve-core/task-research.prompt.md` L9-L11 documents `${input:chat:true}` and `${input:topic}` with descriptions.

### Check 4: Argument Hint Format

* Contract source: `hve-builder.instructions.md`, File Types > Prompt Files and Frontmatter Requirements.
* Testable behavior: when the prompt declares `argument-hint:`, the value MUST use `[]` for positional arguments, `key=value` for named arguments, `{option1|option2}` for enumerated choices, and `...` for free-form remainders.
* Suggested stimulus: ask the assistant to show the argument hint a named prompt advertises in the VS Code picker.
* Grader recommendation: `regex` with pattern `argument-hint:\s*["'][^"']*(?:\[.*\]|\{.*\|.*\}|=|\.\.\.)`.
* Evidence: `.github/prompts/hve-core/task-research.prompt.md` L4 shows `argument-hint: "topic=... [chat={true|false}]"`.

### Check 5: Protocol Structure Presence

* Contract source: `hve-builder.instructions.md`, File Types > Agent Files.
* Testable behavior: a prompt with multiple ordered stages or a complex workflow MUST include either `## Required Steps` (autonomous, step-based) or `## Required Phases` (conversational, phase-based). Single-task prompts MAY omit a protocol section.
* Suggested stimulus: ask the assistant whether a named prompt uses a step-based or phase-based protocol and to name the section heading.
* Grader recommendation: `regex` with pattern `(?m)^##\s+Required\s+(Steps|Phases|Protocol)\b`.
* Evidence: `.github/prompts/hve-core/prompt-build.prompt.md` declares a `## Required Protocol` section that scopes its gate behavior.

### Check 6: Step and Phase Heading Consistency

* Contract source: `hve-builder.instructions.md`, File Types > Agent Files.
* Testable behavior: when a protocol section is present, each step heading MUST take the form `### Step N: Short Summary` and each phase heading MUST take the form `### Phase N: Short Summary` with a descriptive summary after the colon.
* Suggested stimulus: ask the assistant to list the step or phase headings of a named prompt in order.
* Grader recommendation: `regex` with pattern `(?m)^###\s+(?:Step|Phase)\s+\d+:\s+\S.+`.
* Evidence: `.github/agents/hve-core/task-researcher.agent.md` L74-L120 demonstrates the heading shape for a phase-based protocol.

### Check 7: File References as Markdown Links

* Contract source: `hve-builder.instructions.md`, Writing Style.
* Testable behavior: file path references that appear in user-facing response sections MUST be formatted as markdown links `[filename](path/to/file)`. Such references MUST NOT be wrapped in backticks, because backticks suppress link rendering.
* Suggested stimulus: ask the assistant to point to a specific file the prompt references and confirm the response surfaces a clickable markdown link.
* Grader recommendation: `regex` with positive pattern `\[[^\]]+\]\([^)]+\.(?:md|py|ts|js|sh|ps1|yml|yaml)\)` and negate pattern ``(?<!\\)`[a-zA-Z0-9_./-]+\.(?:md|py|ts|js|sh|ps1|yml|yaml)` ``.
* Evidence: the Writing Style section in `hve-builder.instructions.md` states the markdown-link surface rule for user-facing file references.

### Check 8: URL References as Markdown Links

* Contract source: `hve-builder.instructions.md`, Writing Style.
* Testable behavior: external URL references MUST be formatted as markdown links `[display text](https://example.com)`. Raw URLs and backtick-wrapped URLs are non-conforming.
* Suggested stimulus: ask the assistant to cite an external resource the prompt or its delegated agent points to.
* Grader recommendation: `regex` with pattern `\[[^\]]+\]\(https?://[^\s)]+\)`.
* Evidence: the Writing Style section in `hve-builder.instructions.md` and `writing-style.instructions.md` reinforce the markdown link requirement for URLs.

### Check 9: List Type Matches Purpose

* Contract source: `hve-builder.instructions.md`, Writing Style.
* Testable behavior: bulleted lists (`*` or `-`) MUST be used for groupings and option lists; numbered lists (`1.`, `2.`, ...) MUST be used for sequential action steps. Sequence vs grouping intent MUST match the list type.
* Suggested stimulus: ask the assistant to walk through the ordered steps of a named prompt's protocol and separately to enumerate the groupings of optional inputs.
* Grader recommendation: `semantic_similarity` with rubric "Does the response use ordered lists for sequential steps and bulleted lists for groupings consistent with the prompt's structure?".
* Evidence: every sampled prompt under `.github/prompts/hve-core/` follows this convention.

### Check 10: Prompt Design Principles

* Contract source: `hve-builder.instructions.md`, Outcome-First Authoring Core and Quality Criteria.
* Testable behavior: prompt outputs MUST exhibit clarity (followable without guessing), consistency (similar inputs yield similar shapes), alignment (matches repo conventions), coherence (no internal conflicts), calibration (just enough instruction), and correctness (asks rather than guesses when inputs are ambiguous).
* Suggested stimulus: invoke the prompt with a deliberately ambiguous or incomplete input and observe whether the assistant asks for clarification rather than fabricating values.
* Grader recommendation: `semantic_similarity` with rubric "Does the response demonstrate the six prompt-design principles, in particular asking for clarification on ambiguous inputs instead of guessing?".
* Evidence: all sampled prompts under `.github/prompts/hve-core/`.

### Check 11: Few-Shot Examples in Fenced Code Blocks

* Contract source: `hve-builder.instructions.md`, Writing Style.
* Testable behavior: when the prompt presents code examples or few-shot demonstrations, those examples MUST appear inside correctly fenced code blocks with a language identifier where one applies.
* Suggested stimulus: ask the assistant to reproduce a short example the prompt references.
* Grader recommendation: `regex` with pattern ``(?ms)^```[a-z0-9_+-]*\n.+?\n```$``.
* Evidence: the Writing Style guidance in `hve-builder.instructions.md` and skill reference files such as `.github/skills/hve-core/vally-tests/references/refusal-taxonomy.md` apply fenced code blocks consistently.

### Check 12: Subagent Invocation Uses Human-Readable Names

* Contract source: `hve-builder.instructions.md`, Referencing Other Artifacts.
* Testable behavior: when the prompt or its delegated agent invokes a subagent, invocation text MUST reference the subagent by the human-readable `name:` from the subagent's frontmatter (for example, "Run Researcher Subagent"). Invocation by filename or by file path is non-conforming.
* Suggested stimulus: ask the assistant which subagent a named prompt invokes and how the invocation reads.
* Grader recommendation: `regex` with positive pattern `(?i)\brun\s+[A-Z][A-Za-z0-9 ]+\s+Subagent\b` and negate pattern `(?i)[A-Za-z0-9_-]+\.agent\.md`.
* Evidence: `.github/agents/hve-core/task-researcher.agent.md` L31-L35 shows the invocation phrased as "Run `Researcher Subagent`".

## Cross-References

* Skill index: [SKILL.md](../SKILL.md).
* Grader catalog and selection rules: [grader-catalog.md](./grader-catalog.md).
* Refusal categories and regex source of truth: [refusal-taxonomy.md](./refusal-taxonomy.md).
* Eval target routing for `prompt` kind: [eval-suite-routing.md](./eval-suite-routing.md).
