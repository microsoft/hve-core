---
title: Agents Conformance Checks
description: Nine conformance checks the vally-tests skill emits for .agent.md artifacts (including consolidated subagent structural template), with contract citations, stimulus shapes, and Vally grader recommendations
---
<!-- markdownlint-disable-file -->

# Agents Conformance Checks

## Overview

This reference enumerates the nine conformance checks the `vally-tests` skill knows how to express for `.agent.md` artifacts, covering both top-level agents and subagents. The conformance taxonomy research carries an eleven-entry list; this reference consolidates the research's separate "Subagent H1 Heading Matches Name" and "Required Subagent Sections" entries into a single structural-template check and omits the retired source-attribution check, matching the count published in `SKILL.md`.

The canonical eval target for this kind, per `eval-suite-routing.md`, is `evals/agent-behavior/stimuli/<slug>.yml` where `<slug>` is the agent filename minus the `.agent.md` suffix (for example `task-researcher.agent.md` routes to `evals/agent-behavior/stimuli/task-researcher.yml`). New stimulus blocks are appended to that file's `stimuli:` array (creating the file from the standard preamble if it does not exist) and tagged `tags.advisory: true`. Authors MUST run every candidate stimulus through `refusal-taxonomy.md` before emission and refuse any match.

Grader identifiers below use the Vally CLI 0.4.0 catalog (`semantic_similarity`, `contains`, `regex`, `json_schema`) per `grader-catalog.md`. Where the research phrasing recommended `output-matches`, the equivalent here is `regex`; where it recommended `llm-grader`, the equivalent is `semantic_similarity`.

## Contract Summary

| Topic                                 | Section in hve-builder.instructions.md             |
|---------------------------------------|----------------------------------------------------|
| Frontmatter and metadata              | Frontmatter Requirements; File Types > Agent Files |
| Tool restrictions                     | File Types > Agent Files                           |
| Handoff pattern                       | File Types > Agent Files                           |
| Conversational vs autonomous protocol | File Types > Agent Files                           |
| Subagent pattern                      | File Types > Subagents                             |
| Subagent structural template          | File Types > Subagents                             |
| Subagent invocation                   | Referencing Other Artifacts                        |
| Phase and step heading conventions    | File Types > Agent Files                           |

## Conformance Checks

### Check 1: Required Frontmatter Fields

* Contract source: `hve-builder.instructions.md`, Frontmatter Requirements and File Types > Agent Files.
* Testable behavior: agent frontmatter MUST include a non-empty `description:` field under 120 characters AND a `name:` field carrying the human-readable agent name (for example `Task Researcher`).
* Suggested stimulus: ask the assistant to introduce a named agent by its human-readable name and to summarize what it does in one sentence.
* Grader recommendation: `regex` with pattern `(?m)^description:\s*['"].{1,120}['"]` combined with `(?m)^name:\s*['"][^'"\n]+['"]`.
* Evidence: `.github/agents/hve-core/task-researcher.agent.md` L1-L3 and `.github/agents/hve-core/task-planner.agent.md` follow this pair.

### Check 2: Conversational vs Autonomous Protocol Distinction

* Contract source: `hve-builder.instructions.md`, File Types > Agent Files.
* Testable behavior: conversational agents MUST present their workflow as `## Required Phases` (multi-turn, user-guided); autonomous agents MUST present their workflow as `## Required Steps` (task execution, minimal user interaction). The protocol type chosen MUST match the agent's purpose as stated in its description.
* Suggested stimulus: ask the assistant whether a named agent runs conversationally or autonomously and to name the section heading that carries its protocol.
* Grader recommendation: `semantic_similarity` with rubric "Does the agent's protocol type (Phases vs Steps) match the conversational vs autonomous purpose stated in its description?".
* Evidence: `.github/agents/hve-core/task-researcher.agent.md` L74-L130 uses Required Phases consistent with its conversational purpose.

### Check 3: Subagent Dependencies Declared in Frontmatter

* Contract source: `hve-builder.instructions.md`, File Types > Subagents.
* Testable behavior: omit `agents:` when a parent may invoke any available subagent. Use an explicit array when the parent has a fixed allowlist, including `agents: []` when it may invoke none. Fixed entries MUST use each subagent's human-readable `name:` rather than a filename or path. A wildcard string is non-conforming.
* Suggested stimulus: ask whether a named parent has unrestricted, fixed, or empty subagent access and, for a fixed set, which human-readable names it declares.
* Grader recommendation: use `semantic_similarity` with rubric "Does the response distinguish omitted `agents:` as unrestricted access from explicit fixed arrays, accept `[]` as an empty fixed set, reject wildcard strings, and use human-readable names for fixed entries?" A single mandatory-list regex cannot represent all valid modes.
* Evidence: `.github/agents/hve-core/prompt-builder.agent.md` omits `agents:` for unrestricted dispatch; `.github/agents/hve-core/task-researcher.agent.md` declares a fixed `Researcher Subagent` array; `.github/agents/security/subagents/cve-analyzer.agent.md` declares `agents: []`.

### Check 4: Subagent user-invocable Flag

* Contract source: `hve-builder.instructions.md`, File Types > Subagents.
* Testable behavior: files under `.github/agents/**/subagents/` SHOULD set `user-invocable: false` in frontmatter to keep subagents out of the user-facing agent picker. Top-level agents omit the flag or set it to `true`.
* Suggested stimulus: ask the assistant whether a named subagent is user-invocable and how a user would reach it.
* Grader recommendation: `regex` with positive pattern `(?m)^user-invocable:\s*false` evaluated on subagent files, and negate pattern `(?m)^user-invocable:\s*false` on non-subagent files.
* Evidence: any subagent under `.github/agents/**/subagents/` carrying `user-invocable: false`; top-level agents such as `.github/agents/hve-core/task-researcher.agent.md` do not declare the flag.

### Check 5: Subagent Structural Template

* Contract source: `hve-builder.instructions.md`, File Types > Subagents (the canonical subagent section pattern: H1 matching the name, Purpose, Inputs, a named output artifact, Required Steps, an optional Required Protocol, and a Response Format).
* Testable behavior: subagent files MUST present the following structure:
  * An H1 heading whose text matches the frontmatter `name:` field exactly.
  * A Purpose section that states the subagent's objectives.
  * An Inputs section that distinguishes required from optional inputs.
  * An Output artifact section that names the file or tracking artifact the subagent updates progressively.
  * A Required Steps section that opens with a Pre-requisite step and continues with numbered steps.
  * OPTIONAL Required Protocol section for meta-rules and execution constraints.
  * A Response Format section that defines the structured return to the parent.
* Suggested stimulus: ask the assistant to summarize the section structure of a named subagent and to confirm that the H1 matches the frontmatter name.
* Grader recommendation: `regex` with pattern `(?m)^#\s+\S` AND `(?m)^##\s+Purpose\b` AND `(?m)^##\s+Inputs\b` AND `(?m)^##\s+Required\s+Steps\b` AND `(?m)^##\s+Response\s+Format\b`.
* Evidence: the subagent section pattern in `hve-builder.instructions.md`, File Types > Subagents; `.github/agents/hve-core/task-researcher.agent.md` L1 and L11 confirm the H1-matches-name pairing for a top-level agent.

### Check 6: Handoff Pattern Structure

* Contract source: `hve-builder.instructions.md`, File Types > Agent Files.
* Testable behavior: when an agent declares `handoffs:`, each entry MUST include `label:` (display text, MAY contain emoji) and `agent:` (human-readable agent name from the target agent's `name:` field). Each entry MAY include `prompt:` (slash command) and `send:` (boolean for auto-send).
* Suggested stimulus: ask the assistant which other agents a named agent can hand off to and what label each handoff carries.
* Grader recommendation: `regex` with pattern `(?ms)^handoffs:\s*\n(?:\s*-\s+label:\s+\S.+\n\s+agent:\s+["']?[A-Z][A-Za-z0-9 ]+["']?\s*\n(?:\s+(?:prompt|send):.+\n)*)+`.
* Evidence: `.github/agents/hve-core/task-researcher.agent.md` L8-L12 demonstrates label, agent, prompt, and send fields together.

### Check 7: Tool Restrictions Format

* Contract source: `hve-builder.instructions.md`, File Types > Agent Files.
* Testable behavior: when an agent declares `tools:`, the value MUST be a list of valid tool identifiers available in this VS Code context. When the `tools:` field is omitted, the agent inherits the default tool set.
* Suggested stimulus: ask the assistant which tools a named agent restricts itself to and why those tools fit its purpose.
* Grader recommendation: `semantic_similarity` with rubric "Are the declared tools valid identifiers from the VS Code tool surface, and is the restriction set appropriate for the agent's stated purpose?".
* Evidence: a subagent under `.github/agents/**/subagents/` such as `.github/agents/hve-core/subagents/hve-artifact-tester.agent.md` shows the `tools:` field shape.

### Check 8: Subagent Invocation by Human-Readable Name

* Contract source: `hve-builder.instructions.md`, Referencing Other Artifacts.
* Testable behavior: parent-agent invocation text MUST reference a subagent by the human-readable `name:` from the subagent's frontmatter (for example "Run `Researcher Subagent`"). Invocation by filename or by file path is non-conforming.
* Suggested stimulus: ask the assistant how a named parent agent invokes one of its declared subagents.
* Grader recommendation: `regex` with positive pattern `(?i)\brun\s+[A-Z][A-Za-z0-9 ]+\s+Subagent\b` and negate pattern `(?i)[A-Za-z0-9_-]+\.agent\.md`.
* Evidence: `.github/agents/hve-core/task-researcher.agent.md` L31-L35 reads "Run `Researcher Subagent`".

### Check 9: Phase and Step Heading Consistency

* Contract source: `hve-builder.instructions.md`, File Types > Agent Files.
* Testable behavior: phases MUST take the form `### Phase N: Short Summary` and steps MUST take the form `### Step N: Short Summary`, each with a descriptive summary after the colon.
* Suggested stimulus: ask the assistant to list the phase or step headings of a named agent in order.
* Grader recommendation: `regex` with pattern `(?m)^###\s+(?:Phase|Step)\s+\d+:\s+\S.+`.
* Evidence: `.github/agents/hve-core/task-researcher.agent.md` L74-L130 demonstrates the heading shape across phases.

## Cross-References

* Skill index: [SKILL.md](../SKILL.md).
* Grader catalog and selection rules: [grader-catalog.md](./grader-catalog.md).
* Refusal categories and regex source of truth: [refusal-taxonomy.md](./refusal-taxonomy.md).
* Eval target routing for `agent` kind (per-slug stimulus files): [eval-suite-routing.md](./eval-suite-routing.md).
