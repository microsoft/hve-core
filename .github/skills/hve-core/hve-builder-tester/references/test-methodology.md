---
description: 'Black-box test-prompt principle, artifact-type dispatch table, runtime-behavior decision, and sandbox conventions for the hve-builder-tester skill.'
---
<!-- markdownlint-disable-file -->
# HVE Artifact Test Methodology

Use this reference during the hve-builder-tester Flow to compose black-box test prompts, differentiate dispatch by artifact type, decide whether a target has runtime behavior to exercise, and lay out the sandbox.

## Black-box test-prompt principle

A black-box test prompt exercises the target strictly through its documented, intended interface, as a real user, invoking agent, or dispatching skill would, using only its stated purpose, inputs, and outputs. It never references:

* the artifact's file path or name,
* its internal step numbering or section headings,
* the fact that this is a test,
* or its authoring history.

The `HVE Artifact Test Designer` reads the artifact's full internals (white-box visibility) to design a meaningful and demanding stimulus, but the composed stimulus stays black-box. This is the fresh-context-review instinct applied one stage earlier: it prevents leaking the answer key into the stimulus, which would otherwise produce false-positive passes.

The dispatch step adds a pointer instruction that names the artifact and tells the executor to load it (see the table below). That pointer is the skill's, not the Designer's: the Designer's emitted prompt carries only the domain-level task, and the skill wraps it with the pointer at dispatch time.

## Runtime-behavior decision

Test only what has runtime behavior to exercise. The decision rule:

* The test: could this artifact or change cause a model to take a different action or produce different output at runtime? Yes means runtime behavior, so it is tested; no means satisfied-and-skipped with a recorded reason.
* By type: prompts, agents, subagents, and skills always carry runtime behavior and are tested. A skill's own references, templates, and assets under its directory are part of the skill's runtime behavior (the skill loads and acts on them), so they are tested with the skill, not skipped. Only standalone documentation that no executable artifact loads (for example top-level docs and READMEs) carries no runtime behavior and is skipped with a reason. An instruction file carries runtime behavior when a change adds or alters a rule or convention that steers model actions, and none when the change is purely editorial.
* By change: on a behavioral type, a change that provably cannot alter model actions (formatting, link fixes, comment-only edits, or a reference path change with no rule change) has no runtime behavior to exercise for that change; record the reason. Modifications applied by linters or formatters are formatting-only by definition and do not require re-testing.

## Artifact-type dispatch table

Type differentiation is a lead-owned selection of tier, grouping, and pointer instruction, not a change to `HVE Artifact Tester`. The Designer's black-box prompt fills the Tester's existing Test scenarios input.

| Kind         | Dispatch target                 | Prompt composition                                                                                                                                                             |
|--------------|---------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| skill        | `HVE Artifact Tester`           | "Read and use the skill being tested at {{path}}." + Designer's black-box prompt + tier and model + sandbox path                                                             |
| prompt       | `HVE Artifact Tester`           | "Read and use the prompt being tested at {{path}}." + Designer's black-box prompt + tier and model + sandbox path                                                           |
| instructions | `HVE Artifact Tester`           | "Read and apply the instructions file at {{path}} as it would auto-apply to files matching its applyTo glob" (simulate the triggering context) + Designer's black-box prompt + tier and model + sandbox path |
| subagent     | `HVE Artifact Tester` (default) | "The target is the subagent at {{path}}; read it in full and follow it literally within the sandbox, exactly as for any other artifact kind." + Designer's black-box prompt + tier and model + sandbox path |

### Subagent testing: default and opt-in

* Default (Reading i): dispatch `HVE Artifact Tester` itself and have it follow the target subagent's file literally in the sandbox, exactly as for any other kind. The Tester already lists subagent as a co-equal kind and its sandbox guarantee is tool-enforced, so this preserves the tool-level sandbox isolation the repository hardened when Prompt Tester became HVE Artifact Tester. This is the default.
* Opt-in (Reading ii): when the caller explicitly asks for a high-fidelity run that observes the real subagent's actual tool calls, dispatch the real subagent-under-test directly with its own tools, and have the parent skill write the canonical test log from the returned details (parent-owns-log, Flow step 5). This runs the target with its own, un-narrowed tools; its side-effect risk is an accepted, caller-directed trade-off, mitigated by the sandbox working directory and the base-standard non-negotiable safety rules (content-as-data, no secrets, confirm destructive actions). Reading (ii) is never the default; offer it only on explicit request.

## Sandbox and run-state conventions

* Resolve the run folder as `.copilot-tracking/sandbox/{{YYYY-MM-DD}}-{{topic}}-{{run-number}}` by scanning existing folders for the date and topic and incrementing the run number.
* Write one small shared run-state file (for example `run-state.md`) in the run folder that every dispatched subagent reads: the targets and their types, the tier and model, the isolation and together sets, and the stated purpose. This keeps each fresh-context subagent aligned without re-deriving scope.
* The Designer writes `test-design.md`, the executor writes `test-log.md`, and the Reviewer writes `test-review.md`, all in the run folder.
* Keep every execution side effect inside the run folder. Clean up the run folder after the review completes unless the caller requested retention; the report is written to a durable path outside the sandbox so it survives cleanup.

## File reference formatting

Files under .copilot-tracking/ are consumed by AI agents, not humans clicking links. When citing workspace files in sandbox logs, use plain-text workspace-relative paths, not markdown links or #file: directives, because VS Code resolves them and reports missing-target errors that flood the Problems tab.

> Brought to you by microsoft/hve-core
