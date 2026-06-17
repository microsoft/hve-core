---
name: accessibility
description: "Consolidated accessibility skill entrypoint for WCAG 2.2, ARIA Authoring Practices, cognitive accessibility, Section 508, EN 301 549, and the Accessibility Planner playbook."
license: MIT
user-invocable: false
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-06-17"
---

# Accessibility — Skill Entry

This skill is the consolidated entrypoint for accessibility guidance in HVE Core. It links to the framework references, the phase-based playbook references, and the scanner CLI entrypoint.

## Framework references

* [WCAG 2.2](references/frameworks/wcag-22.md)
* [ARIA Authoring Practices Guide](references/frameworks/aria-apg.md)
* [Cognitive Accessibility Guidance](references/frameworks/coga.md)
* [Section 508](references/frameworks/section-508.md)
* [EN 301 549](references/frameworks/en-301-549.md)

## Phase references

* [Capture and exploration](references/phases/capture-and-exploration.md)
* [Framework selection](references/phases/framework-selection.md)
* [Impact assessment](references/phases/impact-assessment.md)
* [Review and backlog handoff](references/phases/review-and-backlog-handoff.md)

## Tooling

* Scanner CLI entrypoint: [scripts/scan.py](scripts/scan.py)

## Usage notes

* Treat this skill as the default accessibility entrypoint for planning and review workflows.
* Open the reference that matches the current phase or the framework you need to apply.
* Use the scanner CLI when you need normalized findings from an accessibility scan.
