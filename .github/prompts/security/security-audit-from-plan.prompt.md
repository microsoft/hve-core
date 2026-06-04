---
name: security-audit-from-plan
agent: Security Auditor
description: "Audits an existing security plan against current repo state and produces a gap-analysis artifact - Brought to you by microsoft/hve-core"
argument-hint: "[projectSlug=<slug>] [planPath=.copilot-tracking/security-plans/<slug>] [scope=path/to/dir] [priorReport=path]"
---

# Security Audit from Plan

> [!CAUTION]
> **Disclaimer:** This prompt is an assistive tool only. It does not replace professional security review boards, penetration testing teams, compliance auditors, or other qualified human reviewers. The gap analysis it produces consists of suggested observations and considerations to support a user's own internal security review. All findings, drift assessments, and handoff recommendations must be independently reviewed and validated by appropriate security and compliance reviewers before use.

Activate the `Security Auditor` agent to compare an existing security plan to the current state of the repository and emit a gap-analysis artifact. The auditor reuses `Security Reviewer` for current-state scanning, never modifies plan artifacts or source code, and only writes under `.copilot-tracking/security-audits/`.

## Default Exclusions

Planning and agent-customization artifacts are **excluded by default** from audit findings. The auditor announces this before scanning and records it in every report.

* Excluded paths: `.copilot-tracking/**`, `docs/planning/**`, `docs/adrs/**`, `.github/agents/**`, `.github/prompts/**`, `.github/instructions/**`, `.github/skills/**`
* Excluded file globs: `*.prompt.md`, `*.agent.md`, `*.instructions.md`, `SKILL.md`
* To override, pass `${input:scope}` pointing at any of the above. The user-provided scope wins and is reported as a warning.

## Inputs

* `${input:projectSlug}`: (Optional) Slug under `.copilot-tracking/security-plans/`. The agent uses it for plan resolution and audit artifact directory naming.
* `${input:planPath}`: (Optional) Explicit path to a plan directory containing `state.json`. Takes precedence over `projectSlug`.
* `${input:scope}`: (Optional) Pass-through scope hint forwarded to `Security Reviewer` as-is. When omitted, the agent derives a scope hint from the plan's component inventory and lets Reviewer auto-profile. Overlap with default-excluded prefixes is honored and warned; the user's scope is never silently rewritten.
* `${input:priorReport}`: (Optional) Prior `Security Reviewer` report path to provide incremental comparison context.

## Requirements

1. Resolve the source plan using the agent's Plan Resolution Order. When no plan exists, stop and direct the user to run `/security-capture` or `/security-plan-from-prd` first. Never proceed without a baseline plan.
2. Invoke `Security Reviewer` in `audit` mode. Do not pass `targetSkill` or a specific-skills list — Reviewer must auto-profile so that skills absent from the original plan can still surface as newly introduced threats or AI/supply-chain handoff signals.
3. Apply the agent's Comparison Model and write a single gap-analysis report at `.copilot-tracking/security-audits/<project-slug>/security-audit-{{YYYY-MM-DD}}-{{NNN}}.md` using the fixed Report Format sections.
4. Treat `.copilot-tracking/security-plans/**`, `.copilot-tracking/security/**`, and all application source code as read-only.
5. End with a completion block listing the audit path, counts per delta category, baseline-completeness flag, and recommended handoffs. Do not auto-dispatch Security Planner, SSSC Planner, or RAI Planner.

## Scope Note

This prompt is intentionally **not** part of the `project-planning` collection. It is a repository-state developer workflow that operates on existing planning artifacts, not a planning entry point. Use `/security-capture` or `/security-plan-from-prd` to create or extend a plan.
