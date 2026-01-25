---
description: 'Comprehensive coding guidelines and instructions for hve-core'
---

# General Instructions

Items in the Highest Priority Rules section from attached instructions files override any conflicting guidance.

<!-- <highest-priority-rules> -->
## Priority Rules

* Conventions and styling from the codebase take precedence for all changes.
* Instructions files not already attached are read before deciding on edits.
* Breaking changes are acceptable.
* Backward-compatibility layers or legacy support are added only when explicitly requested.
* Tests, scripts, and one-off markdown docs are created or modified only when explicitly requested.

Rules for comments:

* Remain brief and factual, describing behavior, intent, invariants, and edge cases.
* Thought processes, step-by-step reasoning, and narrative comments do not appear in code.
* Comments that contradict current behavior are removed or updated.
* Temporal markers (phase references, dates, task IDs) are removed from code files during any edit.

Rules for fixing errors:

* Proactively fix any problem encountered while working in the codebase, even when unrelated to the original request.
* Root-cause fixes are preferred over symptom-only patches.
* Further investigation of the codebase or through tools is always allowed.
<!-- </highest-priority-rules> -->

<!-- <project-structure> -->
## Project Structure

This repository contains documentation, scripts, and tooling for the HVE (Hyper Velocity Engineering) Core project.

### Directory Organization

The project is organized into these main areas:

* Documentation (`docs/`) - Getting started guides, templates, RPI workflow documentation, and contribution guidelines.
* Scripts (`scripts/`) - Automation for linting, security validation, extension packaging, and development tools.
* Skills (`.github/skills/`) - Self-contained skill packages with scripts and documentation.
* Extension (`extension/`) - VS Code extension source and packaging.
* GitHub Configuration (`.github/`) - Workflows, instructions, prompts, agents, and issue templates.
* Logs (`logs/`) - Output from validation and analysis scripts.

### Scripts Organization

Scripts are organized by function:

* Development Tools (`scripts/dev-tools/`) - PR reference generation utilities.
* Extension (`scripts/extension/`) - Extension packaging and preparation.
* Linting (`scripts/linting/`) - Markdown validation, link checking, frontmatter validation, and PowerShell analysis.
* Security (`scripts/security/`) - Dependency pinning validation and SHA staleness checks.
* Library (`scripts/lib/`) - Shared utilities such as verified downloads.

### Skills Organization

Skills are self-contained packages providing guidance and utilities:

### Documentation Structure

* Getting Started (`docs/getting-started/`) - Installation and first workflow guides with multiple setup methods.
* RPI (`docs/rpi/`) - Task researcher, planner, and implementor workflow documentation.
* Contributing (`docs/contributing/`) - Guidelines for instructions, prompts, agents, and AI artifacts.
* Templates (`docs/templates/`) - Templates for custom agents, instructions, and prompts.

### Copilot Tracking

The `.copilot-tracking/` directory (gitignored) contains AI-assisted workflow artifacts:

* Work Items (`.copilot-tracking/workitems/`) - ADO work item discovery and planning.
* Pull Requests (`.copilot-tracking/pr/`) - PR reference generation, handoff, and review tracking.
* Changes (`.copilot-tracking/changes/`) - Change tracking and implementation logs.
* Plans (`.copilot-tracking/plans/`) - Task planning documents.
* Details (`.copilot-tracking/details/`) - Task plan implementation details.
* Research (`.copilot-tracking/research/`) - Technical research findings.
* Subagent (`.copilot-tracking/subagent/`) - Subagent research outputs organized by date.
* ADRs (`.copilot-tracking/adrs/`) - Architecture Decision Record drafts.
* BRD Sessions (`.copilot-tracking/brd-sessions/`) - Business requirements document session state.
* PRD Sessions (`.copilot-tracking/prd-sessions/`) - Product requirements document session state.
* GitHub Issues (`.copilot-tracking/github-issues/`) - GitHub issue search and tracking logs.

All tracking files use markdown format with frontmatter and follow patterns from `.github/instructions/ado-*.instructions.md`.
<!-- </project-structure> -->

<!-- <script-operations> -->
## Script Operations

* Scripts follow instructions provided by the codebase for convention and standards.
* Scripts used by the codebase have an `npm run` script for ease of use.

PowerShell scripts follow PSScriptAnalyzer rules from `PSScriptAnalyzer.psd1` and include proper comment-based help. Validation runs via `npm run psscriptanalyzer` with results output to `logs/`.
<!-- </script-operations> -->
