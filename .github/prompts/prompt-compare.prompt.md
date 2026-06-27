---
description: 'Compare two prompt-engineering artifact runs and capture alignment evidence'
agent: Prompt Compare
argument-hint: "[freeform comparison request, artifact paths, or guidance]"
---

# Prompt Compare

## Inputs

* ${input:request}: Optional freeform comparison request. It may include natural language scope, comma-separated artifact paths, prompt suggestions, prompt types, agent hints, and goals. Defaults to current open files, attached files, and conversation context.
* ${input:runFolder}: Optional existing `.copilot-tracking/prompt-compare/` folder to continue or reconstruct from captured artifacts.
* ${input:firstAgent}: Optional human-readable agent name to use for the first side.
* ${input:secondAgent}: Optional human-readable agent name to use for the second side.

Freeform text after `/prompt-compare` is treated as `${input:request}`.

Artifact references may be comma-separated, newline-separated, or described in natural language. Prompt Compare may also infer them from the current editor, attachments, conversation context, or the derivation subagent.

Continuation requests may provide a run folder directly, for example:

```text
/prompt-compare continue .copilot-tracking/prompt-compare/2026-06-25-rpi-research-vs-task-researcher-1
```

Example invocation:

```text
/prompt-compare Compare the RPI agent behavior with the RPI skill behavior. Use the agent as the reference, make the skill-driven side the candidate, and identify what the skill side needs to create or change to match the agent run.
```

Research-task comparison example:

```text
/prompt-compare Compare Task Researcher to the rpi-research skill. Use the agent as the reference and the skill as the candidate. Use the same research task for both sides: how to best add optional Wiggum loop support to the RPI agents and RPI skills. Keep the side prompts equivalent except for activation details and do not hand off to planning.
```

Minimal invocation:

```text
/prompt-compare Compare the current agent and prompt files and show what the second side needs to change.
```

## Requirements

1. Follow the `Prompt Compare` agent workflow from scope through optional approved edits.
2. Use `runSubagent` during derivation to inspect the freeform request, comparison artifacts, and user guidance, then determine viable first-side prompt, second-side prompt, comparison goal, prompt types, recommended primary agents when needed, and second-side edit/create scope.
3. Derive executable, value-producing task prompts when comparing behavior. Do not default to prompts that ask each side to compare itself to the other artifact unless the user explicitly asks for read-only artifact analysis.
4. Keep first-side and second-side prompts equivalent: same objective, task shape, expected outputs, success criteria, repository permission boundary, artifact-writing expectation, and constraints. Differences should be limited to side activation details such as primary agent, model, semantic skill invocation, artifact context, or evidence paths.
5. Treat user-provided examples or ideas as candidate shared tasks that derivation may adapt into useful repository-specific prompts.
6. Allow an intentionally empty primary agent field. When a derived `primary_agent` is empty, invoke `runSubagent` without an explicit `agentName` instead of forcing a fallback agent.
7. Invoke skills semantically by skill name, slash command, or task intent. Do not use a repo-root `SKILL.md` path as the primary activation mechanism, though skill files may still appear as evidence artifacts.
8. Do not include handoffs to `rpi-plan` or any other RPI agent, skill, or phase unless the approved derived plan explicitly includes that handoff.
9. After derivation and before any primary run, present the derived prompts, prompt types, agents, models, comparison goal, protected first-side artifacts, second-side edit/create scope, shared task, and activation-only differences to the user, then call `vscode_askQuestions` so the user can approve or adjust them.
10. Do not continue past derivation until the user's review decision is recorded and the derived plan is approved after any requested updates.
11. Treat `${input:firstAgent}` and `${input:secondAgent}` as optional execution hints, not required inputs.
12. Use `${input:request}` as non-authoritative input: preserve user intent, but let the derivation subagent adapt suggested prompts, prompt types, goals, and artifact references into runnable prompts for the selected agents and artifacts.
13. Follow the agent-owned derivation YAML schema when recording derived prompts, prompt types, goals, second-side edit/create scope, protected artifacts, and guidance usage.
14. Let the agent-owned derivation schema decide `second_side_edit_scope.modify` and `second_side_edit_scope.create`.
15. Support comparisons between agents, prompts, instructions, skills, templates, examples, references, and related prompt-engineering artifacts.
16. Use the real codebase for both primary runs and do not use `.copilot-tracking/sandbox/` for the compared executions.
17. Store durable state, user guidance, derived prompts, user review decisions, raw subagent responses, supplemental summaries, outputs, changed-file evidence, comparison findings, recommendations, and user decisions under `.copilot-tracking/prompt-compare/`.
18. Start or continue from `${input:runFolder}` or an existing `.copilot-tracking/prompt-compare/` folder when the request identifies one, reusing captured artifacts instead of creating a duplicate run.
19. Reset first-side code changes before starting the second-side run while preserving unrelated user changes and Prompt Compare tracking files.
20. Present a Markdown table with links to the important tracking artifacts before calling `vscode_askQuestions`.
21. If applying alignment changes, modify or create only files in the derived second-side edit/create scope, including support files such as subagents, skill references, templates, examples, or related prompt-engineering files. Do not change first-side prompt artifacts.
22. When validation fails after approved edits, ask the user whether to revert, attempt a focused fix, or pause for manual review.
