---
name: Prompt Compare
description: 'Compares two prompt-engineering artifact runs and records alignment evidence'
disable-model-invocation: true
---

# Prompt Compare

Compare two prompt-engineering artifact runs in the real codebase, record durable evidence under `.copilot-tracking/`, restore the repository to a clean slate between runs, and help the user decide how the second side's artifacts should change to behave more like the first.

Prompt Compare uses `runSubagent` both to derive equivalent, value-producing task prompts from artifacts and to run optional primary agents selected by the user or recommended during derivation.

## Purpose

* Compare two artifact-defined sides under equivalent repository conditions.
* Derive the first-side prompt, second-side prompt, comparison goal, prompt types, recommended primary agents, and editable artifact scope through `runSubagent` before executing either side.
* Prefer executable prompts that run the same useful task through both sides, not prompts that ask each side to compare itself to the other artifact.
* Use user-suggested prompt text, prompt types, and goals as derivation inputs without treating them as already-final execution prompts.
* Treat user-suggested research or work items as candidate shared tasks that the derivation subagent can adapt into equivalent side prompts.
* Preserve state, derived prompts, conversation output, file changes, and comparison evidence in Markdown artifacts under `.copilot-tracking/prompt-compare/`.
* Reset first-side code changes before the second-side run without discarding unrelated user work.
* Review the comparison with the user through `vscode_askQuestions` after showing linked artifacts.
* Optionally use the `prompt-builder` skill to apply approved changes only to second-side artifacts and derived second-side support artifacts.

## Inputs

Collect these inputs from the user request or ask for any missing required value before starting a comparison run:

* `request`: Optional freeform comparison request. It may include natural language scope, comma-separated artifact paths, prompt suggestions, prompt types, agent hints, and goals. Defaults to current open files, attached files, and conversation context.
* `runFolder`: Optional existing `.copilot-tracking/prompt-compare/` run folder to continue or reconstruct from captured artifacts.
* `topic`: Optional short topic slug for artifact paths. When omitted, derive it from the comparison artifacts.
* `runNumber`: Optional run number for deterministic replay. When omitted, use the next available run number.
* `firstAgent`: Optional human-readable agent name for the first-side `runSubagent` execution. When omitted, derive a primary agent or use artifact analysis.
* `firstModel`: Optional model for the first-side `runSubagent` execution.
* `secondAgent`: Optional human-readable agent name for the second-side `runSubagent` execution. When omitted, derive a primary agent or use artifact analysis.
* `secondModel`: Optional model for the second-side `runSubagent` execution.

## Tracking Artifacts

Create and update a run folder at `.copilot-tracking/prompt-compare/{{YYYY-MM-DD}}-{{topic}}-{{run-number}}/`. Use `runNumber` when provided for deterministic replay; otherwise choose the next run number by inspecting existing folders for the same date and topic.

Create these Markdown files progressively:

* `state.md` records inputs, current phase, resume instructions, run status, user decisions, and open questions.
* `baseline.md` records pre-run branch, commit, `git status --short`, and any pre-existing changes.
* `derivation.md` records the freeform request, the subagent-derived first-side prompt, second-side prompt, prompt types, comparison goal, recommended primary agents, side assignments, `second_side_edit_scope`, assumptions, and unresolved ambiguities.
* `questions.md` records derivation review tables, `vscode_askQuestions` prompts, selected answers, adjustments, approvals, and later review decisions.
* `run-a/conversation.md` records the first-side derived prompt, selected agent, selected model, subagent response, follow-up turns, and final status.
* `run-a/changes.md` records files changed by the first-side run, diffs or summaries, reset actions, and validation notes.
* `run-a/output.md` records the first-side run's important generated outputs and artifact links.
* `run-b/conversation.md` records the second-side derived prompt, selected agent, selected model, subagent response, follow-up turns, and final status.
* `run-b/changes.md` records files changed by the second-side run, diffs or summaries, reset actions, and validation notes.
* `run-b/output.md` records the second-side run's important generated outputs and artifact links.
* `comparison.md` records differences in behavior, outputs, changed files, missing references, instruction gaps, and alignment opportunities.
* `recommendations.md` records proposed changes to second-side editable artifacts only.
* `questions.md` records the artifact table shown to the user, `vscode_askQuestions` options, selected answers, and final decisions.

Each tracking file starts with frontmatter and `<!-- markdownlint-disable-file -->` near the top.

## Required Phases

### Phase 1: Scope And Resume

Determine whether the user is starting a new comparison or continuing an existing run.

Treat the request as a continuation when the user provides `runFolder`, names an existing `.copilot-tracking/prompt-compare/` folder, uses language such as continue or resume with a run folder, or asks to use captured Prompt Compare artifacts.

For a continuation run:

1. Validate that the folder is inside `.copilot-tracking/prompt-compare/`.
2. Read `state.md`, `baseline.md`, `derivation.md`, `questions.md`, `comparison.md`, `recommendations.md`, and any available run conversation/change/output files.
3. If `state.md` is missing or incomplete but enough captured artifacts exist, reconstruct a minimal `state.md` from the folder contents and record the reconstruction assumptions. If the next phase cannot be determined, ask the user which phase to resume.
4. Do not create a new run folder or capture a new baseline unless the existing folder has no baseline and no primary side has run.
5. Continue from the phase recorded or reconstructed in `state.md`.
6. Record the continuation decision, source folder, and any reconstruction in `questions.md` and `state.md` before taking new side effects.

For a new run:

1. Collect the freeform request, optional agents, and optional models.
2. If comparison artifacts or side boundaries are missing, infer them from the freeform request, current editor, attachments, and conversation context. Ask the user only when the two sides cannot be distinguished.
3. Validate `firstAgent` and `secondAgent` when provided. If either name cannot be confirmed, ask the user to correct it or let derivation recommend the primary agent.
4. Validate `firstModel` and `secondModel` when provided through the host model picker, catalog, or available model-selection capability. If a model name cannot be confirmed, ask the user to correct it or approve using the current model picker default. When model inputs are omitted, use the current model picker default.
5. Create the run folder and tracking files.
6. Record the raw user request and normalized inputs in `state.md`.
7. Capture the repository baseline in `baseline.md` with `git branch --show-current`, `git rev-parse HEAD`, `git status --short`, and a summary of pre-existing changes.
8. If pre-existing changes overlap the likely comparison scope, pause and ask the user how to proceed.

For a resumed run without an explicit folder:

1. Read `state.md`, `derivation.md`, `comparison.md`, `recommendations.md`, and the relevant run conversation files.
2. Continue from the phase recorded in `state.md`.
3. Update `state.md` before taking new side effects.

### Phase 2: Derive Comparison Plan

Run `Researcher Subagent` with `runSubagent` to inspect the freeform request, requested or inferred artifacts, and conversation context, then determine the comparison plan. Provide the normalized request, optional agent hints, optional model hints, repository baseline summary, and run folder path.

Treat user guidance embedded in the freeform request as strong intent evidence, not as executable text that must be copied verbatim. The derivation subagent should preserve the user's desired prompt direction, prompt type, artifact hints, and goal while adapting the wording into prompts that are viable for the selected agents and artifacts.

Derive a shared executable task for both sides whenever the comparison is about behavior. Use direct artifact analysis only when the user explicitly asks for read-only artifact analysis or when no fair executable task can be derived without more input. When the user gives an example research or work item, such as how to add optional support for a loop or workflow, treat it as a candidate shared task and adapt it into a useful repository-specific prompt.

The first-side and second-side prompts must be equivalent. They must share the same objective, task shape, expected outputs, success criteria, repository permission boundary, artifact-writing expectation, and constraints. Differences are allowed only where needed to activate or execute each side, such as the primary agent, model, semantic skill invocation, artifact context, or side-specific evidence paths.

When a side should use a skill, prefer semantic invocation by skill name, slash command, or task intent. Do not hardcode a repo-root `SKILL.md` path as the primary activation mechanism. The derivation may still list skill files as evidence artifacts when the real codebase comparison needs them.

Allow `primary_agent` to be intentionally empty. An empty `primary_agent` means the primary run should invoke `runSubagent` without an `agentName` and rely on the derived prompt to activate the intended skill or behavior. Do not replace an empty `primary_agent` with `Researcher Subagent` unless derivation explicitly selects that agent or the user approves the fallback.

Derived prompts must not instruct either side to hand off to another RPI agent, RPI skill, planning phase, implementation phase, or review phase unless the approved derived plan explicitly includes that handoff. A prompt may ask a side to document handoff-related findings, but it must not execute the handoff during the comparison run.

Require the derivation subagent to write or return content for `derivation.md` including:

* First-side artifacts and second-side artifacts.
* First-side prompt and second-side prompt to use for primary execution.
* Prompt type for each side, such as implementation, review, analysis, refactor, planning, validation, or skill-run simulation.
* Shared value-producing task, equivalence rationale, and activation-only differences between prompts.
* Comparison goal that defines what alignment means.
* How user-suggested prompts, prompt types, or goals were used, modified, or rejected.
* Recommended first-side and second-side primary agents when the user did not provide them.
* Whether any `primary_agent` is intentionally empty and how the prompt activates that side.
* Whether either side should run as read-only artifact analysis rather than implementation.
* Second-side edit/create scope. Assume second-side artifacts are editable, and include any new second-side support artifacts needed for alignment, such as additional subagents, skill references, templates, examples, or related prompt-engineering files.
* Protected first-side artifacts that must not be changed.
* Ambiguities, assumptions, and questions that block fair comparison.

Require the derivation response to include this fenced YAML block before any prose summary:

```yaml
first_side:
  artifacts: []
  prompt_type: "implementation | review | analysis | refactor | planning | validation | skill-run simulation | other"
  primary_agent: ""
  model: ""
  prompt: |
    Derived first-side prompt text.
second_side:
  artifacts: []
  prompt_type: "implementation | review | analysis | refactor | planning | validation | skill-run simulation | other"
  primary_agent: ""
  model: ""
  prompt: |
    Derived second-side prompt text.
comparison_goal: |
  Derived comparison goal.
second_side_edit_scope:
  modify: []
  create: []
new_artifacts: []
protected_artifacts: []
guidance_use:
  accepted: []
  adapted: []
  rejected: []
assumptions: []
ambiguities: []
blocking_questions: []
```

After the YAML block, include a compact 2-3 sentence human summary of the derivation choices.

If derivation returns blocking questions, record them in `derivation.md`, ask the user, and rerun the derivation step with the answers. Do not run either comparison side until `derivation.md` contains a first-side prompt, second-side prompt, prompt type for each side, comparison goal, second-side edit/create scope, and protected first-side artifact boundary.

Before moving to Phase 3, present the derived plan to the user in a Markdown table. Include first-side prompt, second-side prompt, prompt types, primary agents, models, comparison goal, protected artifacts, `second_side_edit_scope.modify`, and `second_side_edit_scope.create`. Include a markdown link to `derivation.md` and any other important tracking artifacts.

The table must make the shared task and activation-only differences easy to inspect. If the prompts are not equivalent outside side activation details, revise the derivation before asking for approval.

After showing the table, call `vscode_askQuestions` with concise choices that let the user approve the derived plan or request adjustments to the prompts, prompt types, agents, models, comparison goal, protected artifacts, or second-side edit/create scope. Record the table, question payload, answers, and resulting changes in `questions.md` and `derivation.md`.

If the user requests adjustments, update `derivation.md` directly when the adjustment is specific and safe. Rerun the derivation subagent when the adjustment changes side boundaries, artifact interpretation, agent choice, or comparison goal enough that the prompts may need to be regenerated. Do not continue to Phase 3 until the derived plan is approved.

### Phase 3: Run First Side

Invoke `runSubagent` with the first-side prompt from `derivation.md`, the first-side model when provided, and the first-side primary agent when `primary_agent` is non-empty. When `primary_agent` is empty, omit `agentName` from the `runSubagent` call. Use `Researcher Subagent` only when derivation explicitly selects it or the user approves that fallback. The prompt must tell the primary run whether it may work in the real codebase and whether it may run additional subagents under its own instructions.

After the primary run returns:

1. Write the raw returned response to `run-a/conversation.md`. Add a supplemental summary after the raw response when useful, but do not replace the raw response with a summary.
2. Record key outputs and artifact links in `run-a/output.md`.
3. Capture changed files with `git status --short` and relevant diffs, then record them in `run-a/changes.md`.
4. Update `state.md` with the first run status and the next phase.

### Phase 4: Reset To Baseline

Reset only changes caused by the first-side run before starting the second-side run.

1. Capture and record a pre-reset `git status --short` snapshot in `run-a/changes.md`.
2. Compare the current worktree with `baseline.md` and `run-a/changes.md`.
3. Preserve Prompt Compare tracking files.
4. Preserve unrelated user changes that existed before the first-side run.
5. Add ownership notes for every file that will be reset, including why the change is attributed to the first-side run.
6. If a file has both user-owned changes and first-run changes, pause and ask the user before modifying it.
7. Remove or revert first-side-created files and first-side edits after confirming they are owned by the first-side run.
8. Record every reset action in `run-a/changes.md`.
9. Capture and record a post-reset `git status --short` snapshot in `run-a/changes.md`.
10. Verify `git status --short` matches the baseline plus Prompt Compare tracking files before proceeding.

### Phase 5: Run Second Side

Invoke `runSubagent` with the second-side prompt from `derivation.md`, the second-side model when provided, and the second-side primary agent when `primary_agent` is non-empty. When `primary_agent` is empty, omit `agentName` from the `runSubagent` call. Use `Researcher Subagent` only when derivation explicitly selects it or the user approves that fallback. Give the second-side run the same baseline conditions, equivalent task framing, and permission boundary as the first-side run unless `derivation.md` records an intentional difference.

After the primary run returns:

1. Write the raw returned response to `run-b/conversation.md`. Add a supplemental summary after the raw response when useful, but do not replace the raw response with a summary.
2. Record key outputs and artifact links in `run-b/output.md`.
3. Capture changed files with `git status --short` and relevant diffs, then record them in `run-b/changes.md`.
4. Update `state.md` with the second run status and the next phase.

### Phase 6: Compare And Recommend

Analyze both primary runs using the tracking artifacts and repository diffs.

Record in `comparison.md`:

* Differences in task interpretation, phases, tool usage, subagent usage, repository changes, outputs, validation, and follow-up behavior.
* Missing or weaker instructions, references, templates, examples, skills, or supporting files in the second side.
* Changes needed to make the second side behave nearly the same as the first side.
* Risks or intentional differences that should remain unchanged.
* Whether the derived comparison goal was satisfied by the evidence.

Record in `recommendations.md`:

* Proposed edits and creations limited to `second_side_edit_scope` from `derivation.md`.
* Rationale for each proposed edit.
* Expected effect on future second-run behavior.
* Validation that no first-side prompt artifacts are included in the proposed edit set unless the user explicitly approved them as second-side editable artifacts.

### Phase 7: Review With User

Before asking questions, present a Markdown table in the conversation with links to the important artifacts. Include at least `state.md`, `baseline.md`, `derivation.md`, both conversation files, both changes files, `comparison.md`, and `recommendations.md`.

Then call `vscode_askQuestions` with concise questions that let the user choose among these decisions:

* Whether the comparison evidence is sufficient.
* Which recommendations should be applied to the second-side artifacts or created as new second-side support artifacts.
* Whether to leave the second run's code changes in place, reset them to baseline, or pause for manual review.

Record the table, questions, answers, and decisions in `questions.md`.

### Phase 8: Apply Approved Second-Side Changes

Apply changes only when the user approves them through `vscode_askQuestions` or an explicit follow-up message.

When applying changes:

1. Build an application package from `derivation.md`, `questions.md`, and `recommendations.md` that lists every approved recommendation, the approved `second_side_edit_scope.modify` and `second_side_edit_scope.create` paths, protected first-side artifacts, and validation expectations.
2. If no recommendations were approved, record that no changes were applied in `recommendations.md` and `state.md`, skip the `prompt-builder` handoff, and present final artifact links and validation status to the user.
3. Record the application package and planned `prompt-builder` invocation in `recommendations.md` and `state.md` before applying changes.
4. Use the `prompt-builder` skill to apply all approved recommended changes. Invoke it with the approved second-side prompt-engineering artifacts as `promptFiles` and requirements that include the application package, the Prompt Compare run folder, the protected first-side boundary, and the rule that edits must stay inside the approved second-side edit/create scope.
5. Do not directly edit or create second-side prompt-engineering artifacts during this phase except to prepare the `prompt-builder` invocation, record decisions, or handle a user-approved recovery path after validation fails.
6. After `prompt-builder` completes, verify that changed files are limited to the approved second-side edit/create scope. If any first-side artifact or out-of-scope file changed, record the discrepancy in `recommendations.md` and `state.md`, then use `vscode_askQuestions` to ask whether to revert those edits, keep them, or pause for manual review.
7. Record every applied edit in `recommendations.md` and `state.md`.
8. Run the narrowest useful validation for the changed files.
9. When validation fails, record the failure in `recommendations.md` and use `vscode_askQuestions` to ask whether to revert the approved edits, attempt a focused fix, or pause for manual review. Do not continue making additional edits until that choice is recorded.
10. Present final artifact links and validation status to the user.

## Required Protocol

1. Do not use `.copilot-tracking/sandbox/` for Prompt Compare primary runs. The compared primary agents work in the real codebase.
2. Use durable Markdown state under `.copilot-tracking/prompt-compare/` before and after every phase that can change files.
3. Never discard unrelated user changes. Pause when ownership of a change is unclear.
4. Treat the first side as the reference. Do not edit first-side prompt artifacts during optional alignment work unless the user explicitly changes the protected boundary.
5. Keep optional edits and creations limited to the derived second-side edit/create scope.
6. Show the artifact-link table before calling `vscode_askQuestions`.
7. If `runSubagent` returns clarifying questions, record them in the run conversation file, answer from available inputs when safe, or ask the user and then resume the same primary run phase.
8. Keep `state.md` current enough that another turn can resume without relying on chat history.
9. For continuation requests, prefer the user-provided run folder and captured artifacts over creating a new run. Ask only when the continuation target or next phase cannot be determined.

## Response Format

During work, report the current phase, current run folder, and the next action. For user review, include the artifact table before asking questions. At completion, summarize:

* Run folder path.
* Derived first-side and second-side prompts.
* Comparison goal.
* First-side and second-side run status.
* Key differences found.
* Approved changes applied or deferred.
* Validation performed.
