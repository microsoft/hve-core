---
title: SSSC Planner Framework Opt-Out
description: Skip frameworks or individual controls that do not apply to your project, with an audit trail in the Phase 6 handoff
sidebar_position: 5
author: Microsoft
ms.date: 2026-04-18
ms.topic: how-to
keywords:
  - SSSC
  - supply chain
  - planner
  - opt-out
  - framework
---

The SSSC Planner ships with nine Framework Skills and discovers any custom Framework Skills you publish under `.github/skills/security/`. Not every framework applies to every project. The planner provides three opt-out paths, all of which are recorded in `state.json` and rendered in the Phase 6 handoff under **Excluded Frameworks and Controls**.

## When To Opt Out

Opt out when a framework's controls cannot apply to your project (for example, federal-contractor frameworks for an internal tool) or when a single control is structurally infeasible (for example, hermetic builds for a documentation-only repository). Do not opt out to hide work; every exclusion is logged with your reason.

## Path 1: Phase 1 Framework Applicability Gate

The planner presents every discovered framework during Phase 1 scoping. On hosts that support multi-select prompts, you receive a single checklist with the planner's default set pre-checked. On other hosts, you receive a single batched question listing every framework with safe defaults; reply with the ids you want to skip and a brief reason for each.

State is updated atomically:

```json
{
  "frameworks": [
    {
      "id": "cisa-sscm",
      "version": "2024-02",
      "skillPath": ".github/skills/security/cisa-sscm",
      "disabled": true,
      "disabledReason": "Internal hobby repo; not a federal contractor",
      "disabledAtPhase": "scoping"
    }
  ]
}
```

## Path 2: Mid-Flight State Patch

If a framework only becomes irrelevant once you reach Phase 2 or later (for example, when you discover the project is doc-only), edit `.copilot-tracking/sssc-plans/{project-slug}/state.json` directly and set `disabled: true`, `disabledReason: <why>`, and `disabledAtPhase: <current phase>`. The planner detects the change on its next turn, skips the framework in Phase 3 loading, and excludes its gaps from Phase 5 backlog generation.

## Path 3: Per-Control Suppression

When a framework mostly applies but a single control does not, suppress just that control. Append to `state.frameworks[<id>].suppressedControls[]`:

```json
{
  "id": "slsa",
  "version": "1.1",
  "skillPath": ".github/skills/security/slsa",
  "suppressedControls": [
    {
      "id": "build-l4-hermetic",
      "reason": "Documentation-only repo; no build to harden",
      "suppressedAtPhase": "gap-analysis"
    }
  ]
}
```

The framework remains enabled and continues to contribute gaps and work items for every other control.

## Worked Examples

### Skip CISA SSCM on a hobby repo

During Phase 1 the planner asks about applicable frameworks. Uncheck `cisa-sscm` and supply the reason `Not a federal contractor`. The Phase 6 handoff records:

```markdown
### Disabled Frameworks

| Framework | Version | Reason                   | Excluded at Phase |
|-----------|---------|--------------------------|-------------------|
| cisa-sscm | 2024-02 | Not a federal contractor | scoping           |
```

### Suppress SLSA Build L4 hermeticity for a docs-only repo

You keep SLSA enabled (the Source track still applies) but suppress the hermetic-build control. Edit state per Path 3 above. The Phase 6 handoff records:

```markdown
### Suppressed Controls

| Framework | Control           | Reason                                      | Suppressed at Phase |
|-----------|-------------------|---------------------------------------------|---------------------|
| slsa      | build-l4-hermetic | Documentation-only repo; no build to harden | gap-analysis        |
```

## Beyond the SSSC Planner

The three opt-out paths above are described against the SSSC Planner because that is the first host to implement them, but the underlying shape is deliberately host-neutral.
The `state.frameworks[].{ disabled, disabledReason, disabledAtPhase, suppressedControls }` structure is part of the shared host-agent contract documented in [Adopting Framework Skills in a New Host Agent](../customization/bring-your-own-framework.md#adopting-fsi-in-a-new-host-agent).
Any future planner or reviewer that adopts Framework Skills inherits the same three opt-out paths automatically: a Phase 1 style applicability gate, mid-flight state patching, and per-item suppression.
The RAI Planner and the Code Review Standards reviewer are the next hosts in line to surface this pattern, and they will use the same field names and the same audit-trail rendering so the user experience stays uniform across agents.

## Audit Trail

Every exclusion is recorded in three places:

| Location            | Purpose                                                                                                                   |
|---------------------|---------------------------------------------------------------------------------------------------------------------------|
| `state.json`        | The durable record consumed by every phase.                                                                               |
| `skills-loaded.log` | Phase 3 emits a `skipped: disabled` or `skipped: suppressed` annotation in place of the suppressed read.                  |
| Phase 6 handoff     | The `## Excluded Frameworks and Controls` appendix renders the full list with reasons and phases for reviewer visibility. |

---

🤖 *Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
