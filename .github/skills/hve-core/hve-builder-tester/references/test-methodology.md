---
description: 'Black-box design, behavior decisions, fidelity, artifact dispatch, profiles, and containment for HVE tests.'
---
<!-- markdownlint-disable-file -->
# HVE Artifact Test Methodology

Use this reference to design one complete behavior run without overstating what executed.

## Black-Box Scenarios

A scenario exercises the target through its documented interface and describes only user-visible inputs and expected behavior. Keep the target path, internal headings, authoring history, expected answer, profile metadata, and test framing out of scenario text. The dispatch wrapper carries target and containment metadata.

Design the smallest set that covers material requirements. Use one isolation scenario for a single target and add a together scenario only when connected artifacts have integration behavior. Assign stable IDs, map requirements to observable signals, and record intentionally untested behavior.

Before execution, confirm that each scenario:

* Can be understood without target internals
* Has observable success or failure signals
* Exercises behavior rather than repeating documentation
* Fits the selected fidelity and containment boundary

## Fidelity

| Fidelity     | Execution                                                                                                            | Supported claims                                                                              |
|--------------|----------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------|
| `simulation` | `HVE Artifact Tester` follows the target literally in a contained sandbox and emulates unavailable or unsafe actions | Contract interpretation, instruction clarity, handoffs, documented outputs, and stop behavior |
| `native`     | The registered target receives the black-box scenario directly                                                       | Observed activation, output, and stop behavior for that run and profile                       |

Simulation is the default. Native fidelity requires all of these conditions:

1. The host can activate the target.
2. The target is read-only or an enforced sandbox or hook contains every write.
3. The caller accepts residual side-effect risk.
4. Pre-run and post-run workspace state can expose unexpected changes.

If requested native fidelity cannot meet these conditions, obtain acceptance before substituting simulation. Otherwise return Deferred and state what would make native execution safe and available.

## Runtime-Behavior Decision

Ask whether the target or assessed change can make a model take a different action or produce different output.

* Prompts, agents, subagents, and skills are behavior-bearing. A skill's loaded references, templates, and assets are part of that behavior.
* An instruction change is behavior-bearing when it changes a rule or convention. Pure formatting, comments, and link repair are not.
* Standalone documentation that no executable artifact loads has no runtime behavior.

For no runtime behavior, record `Satisfied-and-skipped`, execution `Not run`, verdict `Not applicable`, fidelity `Not applicable`, and the evidence-backed reason. When HVE Builder calls this skill, it has already classified the frozen candidate as Major or selected a behavior-bearing review target.

## Artifact Dispatch

| Kind         | Simulation                                                      | Native when eligible                                               |
|--------------|-----------------------------------------------------------------|--------------------------------------------------------------------|
| Skill        | `HVE Artifact Tester` with skill pointer and sandbox wrapper    | Semantically activate the registered skill                         |
| Prompt       | `HVE Artifact Tester` with prompt pointer and sandbox wrapper   | Invoke through the host prompt surface when exposed                |
| Instructions | `HVE Artifact Tester` with matching-path context                | Use a host-created matching-path context with enforced containment |
| Agent        | `HVE Artifact Tester` with agent pointer and sandbox wrapper    | Dispatch the registered agent by name                              |
| Subagent     | `HVE Artifact Tester` with subagent pointer and sandbox wrapper | Dispatch the registered subagent by name                           |

Never silently substitute simulation for native execution. Agent and subagent `tools` configuration remains outside test design, execution, and grading.

## Profile Selection

Use the Reasoning Profile Model Map in the skill body. Prefer explicit target metadata; otherwise infer profile from responsibility. Run the executor at the target profile and independent grading at the higher of Medium and that profile.

Label a run as proxy evidence when the selected target profile is unavailable or target metadata maps to no canonical profile. A proxy verdict does not establish behavior at the intended profile. Record this limitation in the durable report because sandbox evidence may be removed.

## Sandbox and Evidence

* Allocate `.copilot-tracking/sandbox/{{YYYY-MM-DD}}-{{topic}}-{{run-number}}` without overwriting another run.
* Record targets, types, candidate revision, profile and model, fidelity, containment, groupings, purpose, requirements, requirement mapping, and pre-run workspace state in `run-state.md`.
* The lead writes `run-state.md`, `test-design.md`, `test-log.md`, and `test-review.md` from its own work and returned evidence.
* Distinguish observed, simulated, and emulated actions in `test-log.md`. Record post-run state and treat an unexpected out-of-sandbox write as blocking.
* Write the durable report before cleaning the sandbox. Retain transient evidence only when requested.
* Use plain-text workspace-relative paths in tracking logs and Markdown links only in durable human-facing output.
