---
title: Agents Conformance Checks
description: Nine conformance checks the vally-tests skill emits for .agent.md artifacts (including consolidated subagent structural template), with contract citations, stimulus shapes, and Vally grader recommendations
---
<!-- markdownlint-disable-file -->

# Agents Conformance Checks

## Overview

This reference enumerates the nine conformance checks the `vally-tests` skill knows how to express for `.agent.md` artifacts, covering both top-level agents and subagents. The conformance taxonomy research carries an eleven-entry list; this reference consolidates the research's separate "Subagent H1 Heading Matches Name" and "Required Subagent Sections" entries into a single structural-template check and omits the retired source-attribution check, matching the count published in `SKILL.md`.

The canonical eval target for this kind, per `eval-suite-routing.md`, is `evals/agent-behavior/stimuli/<slug>.yml` where `<slug>` is the agent filename minus the `.agent.md` suffix (for example `rpi-agent.agent.md` routes to `evals/agent-behavior/stimuli/rpi-agent.yml`). New stimulus blocks are appended to that file's `stimuli:` array (creating the file from the standard preamble if it does not exist) and tagged `tags.advisory: true`. Authors MUST run every candidate stimulus through `refusal-taxonomy.md` before emission and refuse any match.

Grader recommendations below name the literal Vally `type:` keywords, `output-matches` and `prompt`. [grader-catalog.md](./grader-catalog.md) maps the conceptual aliases used elsewhere in this skill (`regex`, `semantic_similarity`) to those keywords.

## Contract Summary

| Check | Topic                                 | Contract source                                                                 |
|-------|---------------------------------------|---------------------------------------------------------------------------------|
| 1     | Frontmatter and metadata              | hve-builder.instructions.md, Frontmatter and Portability                        |
| 2     | Conversational vs autonomous protocol | Observed convention; hve-builder.instructions.md, Outcome and Structure         |
| 3     | Next agent named in the body          | hve-builder.instructions.md, Frontmatter and Portability                        |
| 4     | Subagent user-invocable flag          | hve-builder.instructions.md, Frontmatter and Portability                        |
| 5     | Subagent structural template          | Observed convention; hve-builder.instructions.md, Delegate Deliberately         |
| 6     | Skill preloads and named activation   | hve-builder.instructions.md, Frontmatter and Portability                        |
| 7     | Tool restrictions                     | hve-builder.instructions.md, Frontmatter and Portability                        |
| 8     | Subagent delegation by name           | hve-builder.instructions.md, Delegate Deliberately; Frontmatter and Portability |
| 9     | Phase and step heading conventions    | Observed convention; hve-builder.instructions.md, Outcome and Structure         |

The Copilot harness does not support the `agents`, `handoffs`, or `argument-hint` agent frontmatter fields, and the agent frontmatter schema rejects them. Do not author checks that ask about them; test the body text that names subagents and next agents instead.

## Stimulus Staging and Grading

Every check asks an agent to report what a specific `.agent.md` artifact declares. The agent-behavior suite does not stage `.github/agents/` globally, so a stimulus that names an unstaged artifact cannot be answered and fails on every trial. Apply these rules to every check below:

* Stage the artifact under test at the path the stimulus names, with a source path relative to the compiled suite file (`evals/agent-behavior/eval.yaml` for agents):

  ```yaml
  agent_environment:
    files:
      - src: ../../.github/agents/<package>/<name>.agent.md
        dest: .github/agents/<package>/<name>.agent.md
  ```

  Stage any other file the question depends on, such as an instruction file or skill the target says it requires, so the agent does not halt on a missing dependency.
* End the stimulus with: "If the file cannot be read, report the task as blocked without inventing its declarations." A blocked reply is then distinguishable from an invented one.
* Grade the reply, not the file. Output graders read the agent's answer, so assert the reported value (a name, a flag value, heading words) rather than frontmatter syntax such as `^description:`. Validate file-only properties, such as required frontmatter fields, with frontmatter linting instead of a reply grader.
* Accept the formats a correct answer uses: backticked values, sentences, and bulleted, numbered, or inline lists. Constrain order only when order is the behavior under test.
* Guard every negated grader against truthful denial, and keep positive and negated checks in separate graders.
* Before appending, probe each pattern offline against answers that must pass and answers that must fail.

[grader-robustness.md](./grader-robustness.md) owns the detailed mounting, order, proximity, and negation rules and the offline probe. The patterns below are starting shapes; substitute the target's actual values and re-probe them.

## Conformance Checks

### Check 1: Required Frontmatter Fields

* Contract source: `hve-builder.instructions.md`, Frontmatter and Portability.
* Testable behavior: agent frontmatter MUST include a non-empty `description:` field written as concise trigger metadata AND a `name:` field carrying the human-readable agent name (for example `RPI Agent`).
* Suggested stimulus: stage the artifact and ask the agent to report the human-readable name declared in its frontmatter and to restate its declared description verbatim.
* Grader recommendation: `output-matches` asserting the reported name, for example `(?i)\bRPI Agent\b`, plus a second `output-matches` asserting a distinctive clause of the declared description. Add a separate negated `output-matches` rejecting the filename slug reported as the name, guarded so a file-name mention does not fire, for example `(?i)(?<!file\s?)\bname\s*(?:is|:)\s*.{0,3}rpi-agent\b(?!\.agent\.md)`.
* Evidence: `.github/agents/hve-core/rpi-agent.agent.md` and `.github/agents/hve-core/documentation.agent.md` follow this pair.

### Check 2: Conversational vs Autonomous Protocol Distinction

* Contract source: observed repository convention. `hve-builder.instructions.md`, Outcome and Structure, asks for one consistent structural convention but does not name these headings.
* Testable behavior: conversational agents in this repository present their workflow as `## Required Phases` (multi-turn, user-guided); autonomous agents present it as `## Required Steps` (task execution, minimal user interaction). The protocol type chosen matches the agent's purpose as stated in its description.
* Suggested stimulus: stage the artifact and ask whether it runs conversationally or autonomously and which section heading carries its protocol.
* Grader recommendation: `prompt` with rubric "Does the agent's protocol type (Phases vs Steps) match the conversational vs autonomous purpose stated in its description?".
* Evidence: `.github/agents/project-planning/backlog-manager.agent.md` uses Required Phases consistent with its conversational purpose.

### Check 3: Next Agent Named in the Body

* Contract source: `hve-builder.instructions.md`, Frontmatter and Portability. The harness does not support a `handoffs:` frontmatter field, so an agent that passes its result on describes the next agent to switch to in its body.
* Testable behavior: an agent that hands its result to another agent names that next agent in its body by the agent's human-readable `name:` rather than a filename, a path, or a `handoffs:` entry. The check does not apply to an agent that hands off to no one.
* Suggested stimulus: stage the artifact and ask which agent it says takes over when its workflow ends, identifying that agent the way the artifact does.
* Grader recommendation: `output-matches` asserting the next agent's human-readable name, for example `(?i)\bBacklog Manager\b`. Add a separate negated `output-matches` rejecting a next agent identified by its file path, for example `(?i)agent\s*:\s*.{0,3}[\w/-]*\.agent\.md`.
* Evidence: `.github/agents/project-planning/functional-planner.agent.md` hands its finalized plan to the `Backlog Manager` in its Handoff section, and the `functional-planner-handoff-target-and-label` stimulus applies this check.

### Check 4: Subagent user-invocable Flag

* Contract source: `hve-builder.instructions.md`, Frontmatter and Portability.
* Testable behavior: files under `.github/agents/**/subagents/` SHOULD set `user-invocable: false` in frontmatter to keep subagents out of the user-facing agent picker. Top-level agents omit the flag or set it to `true`.
* Suggested stimulus: stage the artifact and ask for the value its frontmatter declares for `user-invocable` and how a user reaches it given that value.
* Grader recommendation: for a subagent, `output-matches` associating the field with an affirmative value in the same sentence in either order, for example ``(?im)(?<![\s\S])(?![\s\S]*(?:\b(?:not|never|no|omits?|omitted|lacks?)\b|\b\w+n[\x27\u2019]t\b)[\s`*_~]+(?:(?!(?:true|because|since|as|so|given|hence|thus)\b)\w+[\s`*_~]+){0,2}(?:user-invocable[\s`*_~]*:[\s`*_~]*)?\bfalse\b)[\s\S]*?(?:^|[.!?](?=\s|$))(?=(?:[^.!?\n]|[.!?](?=\S))*(?:\buser-invocable\b(?:[^.!?\n]|[.!?](?=\S)){0,40}\bfalse\b|\bfalse\b(?:[^.!?\n]|[.!?](?=\S)){0,60}\buser-invocable\b))(?!(?:[^.!?\n]|[.!?](?=\S))*\bfalse\b[\s`*_~]*(?:is|are)\s+(?:absent|not\s+(?:set|declared|present))\b)(?:[^.!?\n]|[.!?](?=\S))*``. Sentences end only at `.`, `!`, or `?` followed by whitespace, so file names such as `.agent.md` stay inside their sentence. This accepts `user-invocable: false, not true`, "the `user-invocable` value is set to `false`", "`false` is the declared value for `user-invocable`", "the flag is not true and `user-invocable: false`", and "it is not selectable because `user-invocable: false`", while rejecting negated or absent values anywhere in the reply, such as "the value is not `false`", "the frontmatter does not declare `user-invocable: false`", "the frontmatter omits `user-invocable: false`", and "`user-invocable: false` is absent". Add an `output-matches` asserting that the reply names the dispatching parent or orchestrator, and a separate guarded negated `output-matches` rejecting a claim that the subagent is selectable from the agent picker. For a top-level agent, assert that the reply reports the flag as omitted or `true`.
* Evidence: any subagent under `.github/agents/**/subagents/` carrying `user-invocable: false`; top-level agents such as `.github/agents/hve-core/rpi-agent.agent.md` do not declare the flag.

### Check 5: Subagent Structural Template

* Contract source: observed repository convention. `hve-builder.instructions.md`, Delegate Deliberately, requires a delegated task to define its inputs, write boundary, and return shape, but does not prescribe section headings.
* Testable behavior: subagent files in this repository present the following structure:
  * An H1 heading whose text matches the frontmatter `name:` field exactly.
  * A Purpose section that states the subagent's objectives.
  * An Inputs section that distinguishes required from optional inputs.
  * A Required Steps section with numbered steps.
  * An optional Required Protocol section for meta-rules and execution constraints.
  * A Response Format section that defines the structured return to the parent.
* Suggested stimulus: stage the artifact and ask for every level-one and level-two section heading in order, exactly as written, and whether its first heading matches the frontmatter name. "Top-level headings" alone is ambiguous: hosted replies sometimes list only the H1.
* Grader recommendation: one `output-matches` per required section asserting the heading words in the reply, case-sensitive for single words so ordinary prose does not satisfy them: `\bPurpose\b`, `\bInputs\b`, `(?i)Required\s+Steps`, `(?i)Response\s+Format`. These accept numbered, bulleted, and inline lists. Add an `output-matches` asserting that the reply confirms the H1 matches the name.
* Evidence: `.github/agents/security/subagents/cve-analyzer.agent.md` follows this structure: `# CVE Analyzer`, Purpose, Inputs, Required Steps, Required Protocol, and Response Format.

### Check 6: Skill Preloads and Named Activation

* Contract source: `hve-builder.instructions.md`, Frontmatter and Portability. The harness does not support a `handoffs:` frontmatter field and does not load `#file:` directives, so an agent preloads the skills it needs at start with `skills:` and activates other skills by name in its body.
* Testable behavior: skills the agent needs when it starts appear in its `skills:` frontmatter, and the body activates every other skill it depends on by its stable name.
* Suggested stimulus: stage the artifact and the skills it names, then ask which skills it preloads at start and which it activates by name during its workflow, identifying each by name.
* Grader recommendation: one `output-matches` per declared preload and per named activation, for example `(?i)\bdisclaimer-language\b`, `(?i)\buntrusted-content-boundary\b`, and `(?i)\bplanner-identity\b`. These accept backticked, bulleted, and inline lists. Do not constrain order.
* Evidence: `.github/agents/privacy/privacy-planner.agent.md` preloads `disclaimer-language` and `untrusted-content-boundary`, and its body activates `planner-identity` and `privacy-standards` at session start.

### Check 7: Tool Restrictions Format

* Contract source: `hve-builder.instructions.md`, Frontmatter and Portability.
* Testable behavior: tool configuration is user-managed. When an agent declares `tools:`, Copilot recognizes its tool aliases and MCP names and ignores names it does not recognize; an empty list grants every tool. An agent cannot load a skill by name without `skill` in its list, and subagents never receive `ask_user`.
* Suggested stimulus: stage the artifact and ask whether its declared tools fit the role its description states, distinguishing the declared grants from what the host actually enforces.
* Grader recommendation: `prompt` with a rubric that rewards reasoning from the artifact's own declared tools and description, rejects invented tools, and rejects claims that a tool grant enforces a boundary only the artifact's own policy provides. Keep the rubric's expected tool families out of the stimulus text so the reply is not taught the answer.
* Evidence: a subagent under `.github/agents/**/subagents/` such as `.github/agents/hve-core/subagents/rpi-researcher.agent.md` shows the `tools:` field shape.

### Check 8: Subagent Delegation by Human-Readable Name

* Contract source: `hve-builder.instructions.md`, Delegate Deliberately and Frontmatter and Portability. The harness does not support an `agents:` frontmatter field, so a parent describes the subagents it delegates to in its body, and the subagent tool selects them by name.
* Testable behavior: a parent that delegates names each subagent in its body, and in its invocation text, by the human-readable `name:` from the subagent's frontmatter (for example "Dispatch the `BRD Quality Reviewer` subagent"). Naming or invoking a subagent by filename or by file path is non-conforming.
* Suggested stimulus: stage the parent artifact and ask which subagents it delegates to and how it invokes one of them, identifying each the way the artifact does.
* Grader recommendation: `output-matches` asserting the subagent's human-readable name, for example `(?i)\bBRD Quality Reviewer\b`. Add a separate negated `output-matches` rejecting invocation by filename, guarded against truthful denial including contractions, for example `(?i)(?<!(?:\b(?:not|never|without)|n[\x27\u2019]t)\s+(?:\w+\s+){0,3})\b(?:runs?|invokes?|invoked|calls?)\s+\S*\.agent\.md\b`.
* Evidence: `.github/agents/project-planning/brd-builder.agent.md` dispatches `BRD Quality Reviewer` by its human-readable name.

### Check 9: Phase and Step Heading Consistency

* Contract source: observed repository convention. `hve-builder.instructions.md`, Outcome and Structure and Writing, asks for one consistent structural convention and clear headings but does not prescribe these forms.
* Testable behavior: phases in this repository take the form `### Phase N: Short Summary` and steps take the form `### Step N: Short Summary`, each with a descriptive summary after the colon.
* Suggested stimulus: stage the artifact and ask for its phase or step headings in order, exactly as written.
* Grader recommendation: `output-matches` asserting every expected heading summary in order with any intervening text, for example `(?is)Phase\s+1:\s+Platform and Intent Classification[\s\S]*Phase\s+2:\s+Workflow Dispatch[\s\S]*Phase\s+3:\s+Summary and Handoff` for the Evidence artifact below. Sequence is the behavior under test, so this is the one check where an ordered pattern is correct; it still accepts numbered, bulleted, and backticked lists.
* Evidence: `.github/agents/project-planning/backlog-manager.agent.md` demonstrates the heading shape across phases.

## Cross-References

* Skill index: [SKILL.md](../SKILL.md).
* Grader catalog and selection rules: [grader-catalog.md](./grader-catalog.md).
* Refusal categories and regex source of truth: [refusal-taxonomy.md](./refusal-taxonomy.md).
* Eval target routing for `agent` kind (per-slug stimulus files): [eval-suite-routing.md](./eval-suite-routing.md).
