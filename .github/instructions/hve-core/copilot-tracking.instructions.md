---
description: "Shared .copilot-tracking conventions for RPI, HVE Builder, and compatibility workflow evidence"
applyTo: '.copilot-tracking/research/**, .copilot-tracking/plans/**, .copilot-tracking/details/**, .copilot-tracking/changes/**, .copilot-tracking/reviews/**, .copilot-tracking/sandbox/**, .copilot-tracking/prompts/**, .copilot-tracking/walkthroughs/**, .copilot-tracking/hve-builder/**'
---

# Copilot Tracking Conventions

Apply these conventions whenever an RPI, HVE Builder, or compatibility workflow writes intermediate, working, or scratch artifacts under `.copilot-tracking/`.

## Core Rules

* Default to `.copilot-tracking/` for every intermediate, working, or scratch file a skill produces. This file-based tracking takes precedence over memory: persist durable working state to the dated tracking artifact rather than relying on session, conversation, or working memory.
* Persist research, planning, details, changes, and review outputs under `.copilot-tracking/` using the conventions below.
* Use `{{task_slug}}` for task slugs and `{{YYYY-MM-DD}}` for dates. Keep `{{task_slug}}` lower-kebab-case.

## Handoff Expectations

* Keep the parent skill response compact and evidence-first. Write full detail to the tracking file that the phase owns.
* When a handoff is required, name the next phase and the expected artifact path instead of inlining the downstream workflow.

## Tracking File Conventions

* Primary research notes stay under `.copilot-tracking/research/{{YYYY-MM-DD}}/{{task_slug}}-research.md`.
* Subagent research outputs stay under `.copilot-tracking/research/subagents/{{YYYY-MM-DD}}/{{task_slug}}-subagent-research.md`.
* Planning evidence stays under `.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.instructions.md`.
* Planning log evidence stays under `.copilot-tracking/plans/logs/{{YYYY-MM-DD}}/{{task_slug}}-log.md`.
* Details and validation evidence stay under `.copilot-tracking/details/{{YYYY-MM-DD}}/{{task_slug}}-details.md`.
* Implementation and validation results stay under `.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md`.
* Review evidence stays under `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/{{task_slug}}-review.md`.
* HVE Builder stage evidence stays under `.copilot-tracking/hve-builder/{{YYYY-MM-DD}}/{{artifact_slug}}-{{stage}}-{{attempt}}.md`. Scan existing files and increment `{{attempt}}` rather than overwriting another run.
* Generated `.copilot-tracking/**` markdown artifacts include `<!-- markdownlint-disable-file -->` near the top because tracking files are exempt from repository markdownlint rules.
* Use plain-text workspace-relative paths in tracking documents for AI consumption.
* Keep `.copilot-tracking/` paths and other internal planning, research, or implementation artifact references out of production code, code comments, documentation strings, and commit messages. Internal artifacts guide implementation logic; comments stay self-contained and may cite public materials such as RFCs, specifications, or official documentation.
* For the research phase, keep writes inside `.copilot-tracking/research/` except for subagent outputs or workflow tracking files that the current execution explicitly requires.
* When material gaps remain, re-enter the current phase and update the dated artifact rather than skipping ahead.
