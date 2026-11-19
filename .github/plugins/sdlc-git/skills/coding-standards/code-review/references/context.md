---
description: 'Context phase reference for Code Review covering area grouping, change reasons, change maps, and factual symbol or flow explanations.'
---

# Review context

## Goal

Explain captured changes, affected areas, or a specific symbol using evidence-backed observations without grading findings. Follow [review-contract.md](review-contract.md).

## Flow

1. Read the assignment and captured snapshot evidence. For an area overview, group the assigned surface by responsibility and summarize intent, before/after behavior, entry points, control and data flow, and affected consumers. Propose `reasons` (`R1` to `R9`) with the files or hunks each explains, plus `changeMap` boxes, parts, and links when the change connects multiple parts; the orchestrating agent decides what to persist. For a symbol or flow question, answer that question directly and trace its immediate callers and callees.
2. Anchor relationships to captured hunks when available or record an explicit `uncertainty`; never fabricate a whole-codebase graph. Use code-intelligence or symbol tools first and bounded file reads otherwise.
3. Return factual `observations` with openable evidence references and follow-on symbols, naming any missing evidence that blocks a complete explanation.

## Completion

Return `findings: []`. The orchestrating agent consumes `observations` to update area descriptions, impact edges, `reasons`, and `changeMap`. Context tasks do not count as review coverage or assign severities, dispositions, or outcomes.
