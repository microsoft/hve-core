---
description: "Refactors and cleans up prompt engineering artifacts through iterative improvement - Brought to you by microsoft/hve-core"
argument-hint: "[promptFiles=...] [requirements=...]"
agent: Prompt Builder
---

# Prompt Refactor

## Inputs

* (Optional) promptFiles - ${input:promptFiles}: Existing target prompt file(s) for creation or modification. Defaults to the current open file or attached file.
* (Optional) requirements - ${input:requirements}: Additional requirements or objectives.

## Prompt File(s) Requirements

1. Refactor the promptFiles with a focus on cleaning up instructions, consolidating instructions, removing confusing instructions, removing duplicate instructions or examples when they are not needed.
2. If user provided additional requirements in the conversation then be sure to also consider all of their requirements as well.

## Required Protocol

Follow all instructions in Required Phases, iterate and repeat Required Phases until promptFiles or related prompt file(s) meet the requirements.

## Evals-Authoring Offer

When a session creates or modifies a `prompt`, `instructions`, `agent`, or `skill` artifact, the Prompt Builder offers to author Vally conformance tests as part of session wrap-up. Frame this as a conversational offer rather than a gate. Present it at the natural session-end point and pick one of three responses based on the user's reply.

* `yes`: Dispatch the `Vally Test Author` subagent in `from-artifact` mode against every artifact touched in this session. When the artifact kind is `agent`, also trigger the supporting eval mechanics:
  * Regenerate per-agent surface signatures with `pwsh scripts/evals/New-AgentSurfaceSignatures.ps1`.
  * Author a stimulus partial at `evals/agent-behavior/stimuli/<slug>.yml` matching the agent's class recipe in `evals/agent-behavior/README.md` (one of `research-writer`, `code-reviewer`, `code-implementor`, `workitem-manager`, or `planner-coach`); assign the class through the manifest produced by `pwsh scripts/evals/Build-AgentInventory.ps1`.
  * Regenerate the behavioral eval spec with `pwsh scripts/evals/Build-AgentBehaviorSpec.ps1` and commit the resulting `evals/agent-behavior/eval.yaml`.
  * Invoke the `Prompt Tester` subagent on the new stimulus, then the `Prompt Evaluator` subagent on the resulting transcript.
  * Verify that `pwsh scripts/evals/Test-EvalSpec.ps1 -NewAgentsOnly` exits 0.
* `no`: Skip Vally test authoring for this session. Record the skip as a single line in the final handoff so the user can revisit it later.
* `corpus-import`: Surface the dedicated `/evals-import` prompt as the path for importing CSV or XLSX corpora into Vally eval suites; do not attempt a corpus import inline from this prompt.

When the user picks `yes` on an `agent` artifact, the gate mechanics from the steps above are surfaced in the Prompt Builder's final Handoff Status table.
