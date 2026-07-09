---
title: Instructions Conformance Checks
description: Eight conformance checks the vally-tests skill emits for .instructions.md artifacts, with contract citations, stimulus shapes, and Vally grader recommendations
---
<!-- markdownlint-disable-file -->

# Instructions Conformance Checks

## Overview

This reference enumerates the eight conformance checks the `vally-tests` skill knows how to express for `.instructions.md` artifacts. Instructions files are auto-applied based on `applyTo:` glob patterns, so the contracts below focus on the metadata that governs auto-application and on the body conventions that make the guidance discoverable and consistent.

The canonical eval target for this kind is `evals/behavior-conformance/instructions.eval.yaml`. New stimulus blocks are appended to its `stimuli:` array and tagged `tags.advisory: true` per `eval-suite-routing.md`. Authors MUST run every candidate stimulus through `refusal-taxonomy.md` before emission and refuse any match.

Grader identifiers below use the Vally CLI 0.4.0 catalog (`semantic_similarity`, `contains`, `regex`, `json_schema`) per `grader-catalog.md`. Where the research phrasing recommended `output-matches`, the equivalent here is `regex`; where it recommended `llm-grader`, the equivalent is `semantic_similarity`.

## Contract Summary

| Topic                              | Section in hve-builder.instructions.md                   |
|------------------------------------|----------------------------------------------------------|
| Frontmatter and applyTo glob       | Frontmatter Requirements; File Types > Instruction Files |
| Scope and applicability statement  | File Types > Instruction Files                           |
| Core conventions as bulleted rules | Writing Style                                            |
| Code examples in fenced blocks     | Writing Style                                            |
| Patterns to avoid                  | Stale Patterns to Retire                                 |
| Validation tooling references      | File Types > Instruction Files                           |

## Conformance Checks

### Check 1: Required Frontmatter Fields

* Contract source: `hve-builder.instructions.md`, Frontmatter Requirements and File Types > Instruction Files.
* Testable behavior: instructions frontmatter MUST include a non-empty `description:` field under 120 characters AND an `applyTo:` field whose value is a glob expression.
* Suggested stimulus: ask the assistant which files a named instructions file auto-applies to and to summarize its purpose.
* Grader recommendation: `regex` with pattern `(?m)^description:\s*['"]?.{1,120}['"]?` combined with `(?m)^applyTo:\s*['"]?[^'"\n]*\*`.
* Evidence: `.github/instructions/hve-core/markdown.instructions.md` L1-L3 and `.github/instructions/hve-core/writing-style.instructions.md` L1-L3 both demonstrate the required pair.

### Check 2: ApplyTo Glob Validity

* Contract source: `hve-builder.instructions.md`, Frontmatter Requirements and File Types > Instruction Files.
* Testable behavior: the `applyTo:` value MUST be a syntactically valid glob (for example `**/*.md`, `**/*.py`, or a comma-separated list of globs) and SHOULD match at least one file in the repository.
* Suggested stimulus: ask the assistant to list a sample of files in the repository that a named instructions file would auto-apply to.
* Grader recommendation: `semantic_similarity` with rubric "Is the applyTo value a valid glob, and could it plausibly match real files in this repository?".
* Evidence: `.github/instructions/hve-core/markdown.instructions.md` L2 declares `applyTo: '**/*.md'`.

### Check 3: Scope or Applicability Statement

* Contract source: `hve-builder.instructions.md`, File Types > Instruction Files.
* Testable behavior: the body SHOULD open with an explicit scope or applicability statement (for example "Applies to all X files" or "Applies when Y condition") so readers can confirm relevance quickly. The statement SHOULD appear in the first body section.
* Suggested stimulus: ask the assistant to quote the scope statement of a named instructions file.
* Grader recommendation: `regex` with pattern `(?im)\b(scope|applicab|applies\s+to|when\s+to\s+apply)\b`.
* Evidence: `.github/instructions/hve-core/markdown.instructions.md` L8-L12 and `.github/instructions/hve-core/writing-style.instructions.md` L8 both surface scope language early in the body.

### Check 4: Core Conventions as Bulleted Rules

* Contract source: `hve-builder.instructions.md`, Writing Style.
* Testable behavior: core conventions MUST be expressed as bulleted rules (using `*` or `-`) rather than prose paragraphs so readers can scan and reference them by line.
* Suggested stimulus: ask the assistant to list the top conventions a named instructions file enforces.
* Grader recommendation: `regex` with pattern `(?m)^\s*[\*-]\s+\S.+` evaluated over the conventions section.
* Evidence: `.github/instructions/hve-core/markdown.instructions.md` L14-L16 and `.github/instructions/hve-core/writing-style.instructions.md` L24-L32 enumerate conventions as bullets.

### Check 5: Code Examples in Fenced Blocks

* Contract source: `hve-builder.instructions.md`, Writing Style.
* Testable behavior: when the instructions file presents code or markup examples, every example MUST appear in a fenced code block. A language identifier SHOULD be present whenever a recognizable language applies.
* Suggested stimulus: ask the assistant to show a correct example the instructions file recommends.
* Grader recommendation: `regex` with pattern ``(?ms)^```[a-z0-9_+-]*\n.+?\n```$``.
* Evidence: `.github/instructions/hve-core/markdown.instructions.md` L27-L30 shows a fenced example with a language identifier.

### Check 6: Patterns to Avoid Section

* Contract source: `hve-builder.instructions.md`, Stale Patterns to Retire and the "Avoid these patterns" list under Writing Style.
* Testable behavior: when conventions have meaningful counterexamples, the instructions file SHOULD include a "Patterns to Avoid" (or equivalently named) section that contrasts a correct approach with a non-conforming one.
* Suggested stimulus: ask the assistant which patterns a named instructions file warns against and what to use instead.
* Grader recommendation: `regex` with pattern `(?im)^##\s+(?:patterns?\s+to\s+avoid|anti-?patterns?|avoid)\b`.
* Evidence: `.github/instructions/hve-core/markdown.instructions.md` L31-L53 and `.github/instructions/hve-core/writing-style.instructions.md` L72-L121 carry counterexample sections.

### Check 7: Validation Tooling References

* Contract source: `hve-builder.instructions.md`, File Types > Instruction Files and Evaluation and Validation.
* Testable behavior: when a convention is mechanically checkable, the instructions file SHOULD reference the tool or command that verifies compliance (for example `npm run lint:md`, `npm run lint:frontmatter`).
* Suggested stimulus: ask the assistant which command verifies the conventions of a named instructions file.
* Grader recommendation: `regex` with pattern `(?i)(?:npm\s+run\s+\S+|pwsh\s+\S+|\blint\b|\bvalidate\b|\btest:[a-z]+\b)`.
* Evidence: `.github/instructions/hve-core/markdown.instructions.md` L12 and L39-L50 reference the relevant `npm run` commands.

### Check 8: Cross-File Consistency With Shared Standards

* Contract source: `hve-builder.instructions.md` cross-references to `markdown.instructions.md` and `writing-style.instructions.md`.
* Testable behavior: when two or more instructions files cover overlapping domains (for example markdown rules and writing-style rules both touch markdown body content), the conventions MUST NOT conflict. Conflicts MUST be either reconciled or explicitly justified.
* Suggested stimulus: ask the assistant to compare a convention from one instructions file with the related convention in another and report whether they align.
* Grader recommendation: `semantic_similarity` with rubric "Do the cited conventions from two instructions files align without contradiction, or is any divergence explicitly justified?".
* Evidence: `.github/instructions/hve-core/markdown.instructions.md` and `.github/instructions/hve-core/writing-style.instructions.md` complement each other without conflict.

## Cross-References

* Skill index: [SKILL.md](../SKILL.md).
* Grader catalog and selection rules: [grader-catalog.md](./grader-catalog.md).
* Refusal categories and regex source of truth: [refusal-taxonomy.md](./refusal-taxonomy.md).
* Eval target routing for `instructions` kind: [eval-suite-routing.md](./eval-suite-routing.md).
