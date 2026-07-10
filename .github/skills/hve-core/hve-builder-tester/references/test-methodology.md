---
description: 'Black-box scenarios, simulation and native fidelity rules, artifact dispatch, runtime-behavior decisions, and containment evidence.'
---
<!-- markdownlint-disable-file -->
# HVE Artifact Test Methodology

Use this reference to decide what needs behavior testing, choose a defensible fidelity, compose black-box scenarios, and preserve evidence without overstating what ran.

## Black-box test-prompt principle

A black-box scenario exercises the target through its documented interface, using only its stated purpose, inputs, outputs, and user-visible behavior. Scenario text never references:

* the artifact's file path or name,
* its internal step numbering or section headings,
* the fact that this is a test,
* its authoring history.

`HVE Artifact Test Designer` may inspect internals to design coverage, but its emitted scenario stays black-box. The lead adds a separate dispatch wrapper containing the artifact pointer, profile, fidelity, and sandbox controls. Do not leak those controls into the scenario.

## Fidelity modes

Every run records one fidelity:

| Fidelity     | What runs                                                                                                                          | Claims the evidence supports                                                                            |
|--------------|------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------|
| `simulation` | `HVE Artifact Tester` reads the target and follows it literally in a contained sandbox, emulating unavailable or unsafe dispatches | Contract interpretation, instruction clarity, handoff consistency, and expected tool-selection behavior |
| `native`     | The registered target agent, subagent, or semantically activated skill receives the black-box scenario directly                    | Observed activation, tool selection, outputs, and stop behavior for that run and model profile          |

Simulation is the safe default. Native fidelity is permitted only when all conditions hold:

1. The host can activate the target natively.
2. The target is read-only, or an enforced sandbox or hook contains every write. A prose instruction to remain in a folder is not enforcement.
3. The caller approved any residual side-effect risk.
4. The lead captures pre-run and post-run workspace status and can identify unexpected changes.

When native fidelity was requested but a condition fails, return Deferred unless the caller explicitly accepts simulation as a lower-fidelity substitute. Record the substitution and limitation in the report.

## Runtime-behavior decision

Test only what has runtime behavior to exercise. The decision rule:

* Ask whether the artifact or change could cause a model to take a different action or produce different output. Yes means behavior-bearing; no means satisfied-and-skipped with a recorded reason.
* By type: prompts, agents, subagents, and skills always carry runtime behavior and are tested. A skill's own references, templates, and assets under its directory are part of the skill's runtime behavior (the skill loads and acts on them), so they are tested with the skill, not skipped. Only standalone documentation that no executable artifact loads (for example top-level docs and READMEs) carries no runtime behavior and is skipped with a reason. An instruction file carries runtime behavior when a change adds or alters a rule or convention that steers model actions, and none when the change is purely editorial.
* By change: on a behavioral type, a change that provably cannot alter model actions (formatting, link fixes, comment-only edits, or a reference path change with no rule change) has no runtime behavior to exercise for that change; record the reason. Modifications applied by linters or formatters are formatting-only by definition and do not require re-testing.

## Artifact dispatch

The lead selects profile, fidelity, grouping, and wrapper. The Designer supplies only the black-box scenario.

| Kind         | Simulation dispatch                                               | Native dispatch when eligible                                                                   |
|--------------|-------------------------------------------------------------------|-------------------------------------------------------------------------------------------------|
| skill        | `HVE Artifact Tester` with a skill pointer and sandbox wrapper    | Generic subagent invocation whose task semantically activates the named skill                   |
| prompt       | `HVE Artifact Tester` with a prompt pointer and sandbox wrapper   | Host prompt invocation only when the harness exposes it; otherwise unavailable                  |
| instructions | `HVE Artifact Tester` with a simulated matching-path context      | Host-created matching-path context only when enforced containment exists; otherwise unavailable |
| agent        | `HVE Artifact Tester` with an agent pointer and sandbox wrapper   | Dispatch the registered agent by `name`                                                         |
| subagent     | `HVE Artifact Tester` with a subagent pointer and sandbox wrapper | Dispatch the registered subagent by `name`                                                      |

For simulation, the wrapper says which target to read, where side effects may occur, which profile is in use, and which scenario to follow. For native execution, the target receives the scenario and containment boundary but not the artifact path, internal headings, or expected answer.

## Profile selection

Use the canonical ordered Medium profile (`GPT-5.6 Terra`, `Claude Sonnet 5`, `MAI-Code-1-Flash`) or Low profile (`GPT-5.6 Luna`, `MAI-Code-1-Flash`, `Claude Haiku 4.5`), with the `(copilot)` suffix in frontmatter. Prefer explicit target metadata. Otherwise choose Low for literal, bounded, mechanical responsibilities and Medium for semantic synthesis, architecture, authoring, or calibrated review. Use the first available model in the selected profile's order. When the target declares another profile, label the selected profile as a proxy and avoid equivalence claims.

## Sandbox and run-state conventions

* Resolve the run folder as `.copilot-tracking/sandbox/{{YYYY-MM-DD}}-{{topic}}-{{run-number}}` by scanning existing folders for the date and topic and incrementing the run number.
* Write `run-state.md` with targets and types, profile and model, fidelity, containment controls, isolation and together sets, purpose, requirements, and pre-run workspace status.
* The Designer writes `test-design.md`, the executor writes `test-log.md`, and the Reviewer writes `test-review.md`, all in the run folder.
* The canonical test log distinguishes observed, simulated, and emulated actions and records post-run workspace status. Any unexpected out-of-sandbox change blocks a clean verdict.
* Clean up after review unless retention was requested. Write the durable report outside the sandbox first.

## File reference formatting

Files under .copilot-tracking/ are consumed by AI agents, not humans clicking links. When citing workspace files in sandbox logs, use plain-text workspace-relative paths, not markdown links or #file: directives, because VS Code resolves them and reports missing-target errors that flood the Problems tab.

> Brought to you by microsoft/hve-core
