---
description: "Shared guidance for RPI skill-forward artifacts, subagent dispatch, and tracking-file conventions"
applyTo: '.github/skills/rpi/**, .copilot-tracking/research/**, .copilot-tracking/plans/**, .copilot-tracking/details/**, .copilot-tracking/changes/**'
---

# RPI Skill-Forward Guidance

Use this guidance for the new RPI skill packages and their tracking outputs.

## Core Rules

* Treat each RPI skill as an entry-point playbook, not as a full orchestration engine. Use existing subagents for tool access, model selection, and context isolation.
* Keep skill frontmatter limited to the schema-supported fields: `name`, `description`, `user-invocable`, `argument-hint`, `license`, and `metadata` when needed. Do not add `tools`, `model`, `agent`, `handoffs`, or `applyTo` to `SKILL.md`.
* Use `user-invocable:` consistently for agents, subagents, and skills; do not copy legacy `user-invokable:` guidance into new or corrected artifacts.
* When the workflow needs explicit stage sequencing, state the next handoff in the skill body or shared instructions rather than inventing thin prompt wrappers.
* Persist research, plan, details, and changes outputs under `.copilot-tracking/` using the existing file conventions for the current phase.

## Dispatch and Handoff Expectations

* Prefer explicit `runSubagent` or `task` dispatch to existing RPI subagents for phase-specific work.
* Keep the parent skill response compact and evidence-first; write full detail to the tracking file the phase owns.
* If a handoff is required across research, planning, implementation, and review, name the next phase and the expected artifact path instead of embedding a full replacement workflow.

## Tracking File Conventions

* Research notes stay under `.copilot-tracking/research/`.
* Planning and validation evidence stay under `.copilot-tracking/plans/` and `.copilot-tracking/details/`.
* Implementation and validation results stay under `.copilot-tracking/changes/` and related review logs.
* Use plain-text workspace-relative paths in tracking documents for AI consumption.
