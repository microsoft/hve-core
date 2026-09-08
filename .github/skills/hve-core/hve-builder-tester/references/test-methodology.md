---
description: 'Black-box design, behavior decisions, fidelity, artifact dispatch, profiles, and containment for HVE tests.'
---
<!-- markdownlint-disable-file -->
# HVE Artifact Test Methodology

Use this reference to design one complete behavior run without overstating what executed.

## Black-Box Scenarios

A scenario exercises the target through its documented interface using a realistic user request and any necessary fixture data. Keep the target path, internal headings, authoring history, expected answer, grading assertions, profile metadata, and test framing out of scenario text. Record expected behavior separately in the design for the grader. The dispatch wrapper carries target and containment metadata; the executor does not receive the grading assertions.

Design the smallest set that covers material requirements. Isolation describes which targets run together, not the number of scenarios. Use as many independent requests as needed to distinguish the target's material decisions, and add together scenarios when connected artifacts have integration behavior. Assign stable IDs, map requirements to observable signals, and record intentionally untested behavior. For maintenance changes, cover required behavior that must survive as well as the corrected decision; do not infer equivalence from a single successful example.

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

Simulation is the default. Native fidelity requires an explicit caller request and all of these conditions:

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

Use the Reasoning Profile Resolution in the skill body. Prefer explicit target metadata; otherwise infer profile from responsibility. Run the executor at the target profile and independent grading at the higher of Medium and that profile.

Bind the resolved model using the host dispatch API's model-selection field or equivalent enforced host configuration. Record the requested model, accepted host selection or runtime metadata, and actual model if the host reports it. Passing a model name in prompt text or receiving a worker's self-report does not verify selection.

Label a run as proxy evidence when the selected profile is unavailable, target metadata maps to no canonical profile, host binding cannot be verified, or the reported model differs from the selection. A proxy verdict does not establish behavior at the intended profile. Record the discrepancy and any undisclosed runtime identity in the durable report. If intended-profile evidence is required, record that coverage gap as Partial rather than claiming completion.

## Sandbox and Evidence

* Allocate `.copilot-tracking/sandbox/{{YYYY-MM-DD}}-{{topic}}-{{run-number}}` without overwriting another run.
* Record targets, types, candidate revision, profile and model, fidelity, containment, groupings, purpose, requirements, requirement mapping, and pre-run workspace state in `run-state.md`.
* The lead writes `run-state.md`, `test-design.md`, `test-log.md`, and `test-review.md` from its own work and returned evidence.
* Distinguish observed, simulated, and emulated actions in `test-log.md`. Record post-run state and treat an unexpected out-of-sandbox write as blocking.
* Write the durable report before cleaning the sandbox. Preserve scenario inputs, requirement mapping, decisive trace excerpts, and the grader's rationale in that report or durable companion evidence. Findings must remain assessable after transient files are removed; sandbox paths alone are not evidence retention. Retain the full sandbox only when requested.
* Use plain-text workspace-relative paths in tracking logs and Markdown links only in durable human-facing output.
