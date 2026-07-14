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
* Generated tracking Markdown starts with `<!-- markdownlint-disable-file -->` and uses plain-text workspace-relative paths. Do not use markdown links, backticks around paths, or `#file:` directives in tracking artifacts.
* Tracking artifacts are ordinary Markdown. Do not add `applyTo` metadata or create a `.instructions.md` tracking artifact.

## Handoff Expectations

* Keep the parent skill response compact and evidence-first. Write full detail to the tracking file that the phase owns.
* When a handoff is required, name the next phase and the expected artifact path instead of inlining the downstream workflow.

## RPI Research Evidence Ownership

* The primary research artifact owns synthesized questions, findings, canonical evidence IDs, current and unresolved decisions, planning readiness, and user research decisions.
* A delegated worker artifact owns the full evidence for its assigned lane. Its return contains compact status, provenance, and artifact pointers so the parent can synthesize without duplicating raw evidence.
* Persist user answers, unanswered questions, resulting decisions, and selected further-research items in the primary research artifact before the next research action.

## Tracking File Conventions

* Primary research notes stay under `.copilot-tracking/research/{{YYYY-MM-DD}}/{{task_slug}}-research.md`.
* Subagent research outputs stay under `.copilot-tracking/research/subagents/{{YYYY-MM-DD}}/{{task_slug}}-subagent-research.md`.
* Planning evidence stays under `.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md`.
* Phase details stay under `.copilot-tracking/details/{{YYYY-MM-DD}}/{{task_slug}}-phase-details.md`.
* Plan critique evidence stays under `.copilot-tracking/reviews/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan-critique.md`.
* Implementation evidence stays under `.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md`.
* Review evidence stays under `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/{{task_slug}}-review.md`.
* HVE Builder stage evidence stays under `.copilot-tracking/hve-builder/{{YYYY-MM-DD}}/{{artifact_slug}}-{{stage}}-{{attempt}}.md`. Scan existing files and increment `{{attempt}}` rather than overwriting another run.
* Keep `.copilot-tracking/` paths and other internal planning, research, or implementation artifact references out of production code, code comments, documentation strings, and commit messages. Internal artifacts guide implementation logic; comments stay self-contained and may cite public materials such as RFCs, specifications, or official documentation.
* For the research phase, keep writes inside `.copilot-tracking/research/` except for subagent outputs or workflow tracking files that the current execution explicitly requires.
* When material gaps remain, re-enter the current phase and update the dated artifact rather than skipping ahead.

## RPI Identity and Marker Conventions

* Use one stable task ID across the plan, phase details, critique, changes, and review records.
* Use `Pxx` for phases and `Pxx-Txx` for tasks. Place `<!-- rpi:phase id=P01 -->` or `<!-- rpi:task id=P01-T01 -->` immediately before the matching heading.
* Use `AM-xxx` only in the plan amendment register.
* Use `CHG-xxx` and `DIV-xxx` only in the changes record. Link every significant `DIV-xxx` to its `AM-xxx` amendment and affected plan or detail sections.
* Use `PC-xxx` only in the plan critique and `RV-xxx` only in the review record.
* Use stable IDs, markers, and headings to navigate. Do not maintain line numbers, line ranges, or detail-line verification.
