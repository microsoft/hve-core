---
description: "Cleanup heuristics and quality criteria for the prompt-refactor skill"
---

# Refactor Checklist

Use this checklist when refining existing prompt artifacts.

* Remove confusion and ambiguity by tightening wording, reducing hidden assumptions, and making the primary objective explicit.
* Consolidate duplicated guidance so repeated instructions appear once and are referenced clearly.
* Remove redundant or unnecessary examples, especially when they duplicate the core instruction or add noise.
* Tighten structure by making sections, protocol steps, and handoffs easier to follow.
* Preserve functional intent unless a requirement explicitly changes it.
* Preserve appropriate phase, step, or playbook shape for the artifact type; simplify protocol structure only when the workflow remains clear and complete.
* Confirm frontmatter and schema metadata match the artifact type, including required fields and any type-specific fields such as `applyTo`, `agent`, `agents`, `tools`, `name`, `argument-hint`, or `license`.
* Keep references to skills, prompts, agents, instructions, and bundled skill resources semantic and portable; avoid hard-coded repository-root paths when a name, slash command, relative bundled-resource link, or artifact-specific reference is expected.
* Preserve or update any final response contract so callers receive changed files, rationale, evaluation or validation status, skipped validations with reasons, and remaining issues when those fields are relevant.
* Align edits to the Prompt Design Principles and validate against the Prompt Quality Criteria in `prompt-builder.instructions.md` rather than a separate category set: tighten for Clarity, Consistency, Alignment, Coherence, Calibration, and Correctness, and confirm the refactored artifact still satisfies every applicable Prompt Quality Criteria item.
