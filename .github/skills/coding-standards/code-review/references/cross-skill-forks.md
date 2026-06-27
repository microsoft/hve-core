---
title: Code Review Cross-Skill Forks
description: Specialist review registry and collection-aware gating for follow-up reviews.
ms.date: 2026-06-26
---

## Purpose

Some review board items warrant a specialist follow-up. The review loop should surface those follow-ups only when the relevant signals appear and the required capability is available in the current environment.

## Specialist review registry

| Concern                                                    | Detection signals                                                                                                           | Backing reviewer                                                                                                                                | Surfacing behavior                                                                                                                                                              |
|------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Security (deep)                                            | auth, authz, crypto, secrets, token, parsing, deserialization                                                               | `security-reviewer` agent (`.github/agents/security/security-reviewer.agent.md`)                                                                | Offer a handoff when the runtime catalog exposes the backing agent (or its skill); otherwise omit the offer and keep the main review flow intact.                               |
| Supply chain / SSSC                                        | dependency manifests, lockfiles, Dockerfiles, CI workflow files, build config                                               | `supply-chain-reviewer` agent (`.github/agents/security/supply-chain-reviewer.agent.md`)                                                        | Offer a handoff when the runtime catalog exposes the backing agent (or its skill); otherwise omit the offer and keep the main review flow intact.                               |
| Responsible AI                                             | LLM or model code, inference code, prompt code, AI SDK imports                                                              | `rai-reviewer` agent (`.github/agents/rai-planning/rai-reviewer.agent.md`)                                                                      | Offer a handoff when the runtime catalog exposes the backing agent (or its skill); otherwise omit the offer and keep the main review flow intact.                               |
| Accessibility (deep)                                       | UI, markup, templates, user-facing documents                                                                                | `accessibility-reviewer` agent (`.github/agents/accessibility/accessibility-reviewer.agent.md`)                                                 | Offer a handoff when the runtime catalog exposes the backing agent (or its skill); otherwise omit the offer and keep the main review flow intact.                               |
| Sustainability                                             | hot loops, polling, cron or batch jobs, heavy or N+1 queries, large payloads, container or image size, chatty network calls | Microsoft WAF Sustainability workload guidance (<https://learn.microsoft.com/azure/well-architected/sustainability/sustainability-get-started>) | Surface an active pointer to the Microsoft WAF Sustainability workload guidance with a dated directional caveat (guidance dated 2022-10-12); no installed reviewer is required. |
| Privacy                                                    | PII fields, user-data logging, retention or consent handling, telemetry of personal data                                    | None                                                                                                                                            | Surface a manual-review flag and note that no installed reviewer is available.                                                                                                  |
| GitLab-specific review comments or MR workflows            | GitLab-specific review context                                                                                              | GitLab review capability                                                                                                                        | Offer the GitLab poster fork when the matching capability is present; otherwise keep the main review flow intact.                                                               |
| Azure DevOps-specific review comments or work item linking | ADO-specific review context                                                                                                 | ADO review context                                                                                                                              | Offer the ADO poster fork when the matching capability is present; otherwise keep the main review flow intact.                                                                  |
| Repository workflow or PR hygiene concerns                 | GitHub or GitLab review context                                                                                             | GitHub or GitLab review capability                                                                                                              | Offer the GitHub poster fork when the matching capability is present; otherwise keep the main review flow intact.                                                               |

## Signals-fire-only rule

A concern is surfaced only when its detection signals appear in the diff or the file surface. No specialist follow-up is offered when no matching signal fires.

## Gating behavior

- Detect the available agent, skill, or capability in the runtime catalog before surfacing a follow-up.
- Keep the main review flow intact when no specialist follow-up is available.
- Present each follow-up as an optional extension to the current review rather than as a mandatory extra lane.

## Selection rule

Offer a specialist follow-up only when it adds clear review value. If the backing capability is unavailable or no matching signal fires, leave the board item reviewable through the core code-review workflow.
