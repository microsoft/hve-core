---
name: code-review-context
description: 'Explain captured changes, affected areas, or a specific symbol without grading findings. Shared by Code Review Orientation and Explainer.'
license: CC-BY-4.0
user-invocable: false
---

# Review context

## Goal

Help the reviewer understand the change and its affected consumers using
evidence-backed explanations. Use `code-review-core` when not preloaded.

## Flow

1. Read the parent's assignment and the relevant captured evidence. For an
   overview, group the assigned surface by responsibility and explain intent,
   before/after behavior, entry points, control/data flow, and affected consumers.
   An overview may also propose reasons for the change, with the files or hunks
   each explains, and change-map parts and links; the parent decides what to
   record. For a symbol question, answer that question and trace its immediate
   context.
2. Link relationships to source evidence. Keep unverified relationships as
   explicit questions or uncertainties; do not fabricate a whole-codebase graph.
   Use semantic/symbol tools when available and bounded file reads otherwise.
3. Return factual observations with openable evidence references and useful
   follow-on symbols. Name any missing evidence that prevents an answer.

## Completion

Return `findings: []`. The parent uses the observations to update area
descriptions, impact relationships, reasons, and the change map; note unresolved
questions there too.

Success means the requested explanation is supported and understandable.
Explanation does not complete review coverage or assign severity, verdicts,
recommendations, or human approval.
