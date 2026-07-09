---
description: 'Skill-forward artifact-type selection, delegation analysis, and load-timing and authority routing for hve-builder.'
---
<!-- markdownlint-disable-file -->
# Artifact Type and Load-Timing Routing

Use this reference during the intake step to decide which artifact type solves the request and to route each fact by when it should load and how strongly it should bind. This operationalizes the Agent architecture, Agents and subagents, and Instruction-file architecture categories in the requirements catalog.

## Choose the artifact type: skill-forward, subagent-forward

Prefer a skill-forward and subagent-forward shape. Match the need to the earliest row below whose "when to choose" description fits, and author a later type only when no earlier row expresses the need. Agents and prompts are opt-in: reach for them only when the caller specifically asks.

| Preference | Choose                                    | When to choose it                                                                                                                                                                 | Activation                                          |
|------------|-------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------|
| 1          | Skill (`SKILL.md`)                        | The need is reusable capability or domain knowledge that can bundle its own resources, references, and scripts and load on demand.                                                | Semantic match on its description, or `/skill-name` |
| 2          | Subagent (`.agent.md` under `subagents/`) | The need is context isolation, high-volume or parallel work, or a responsibility best run at a specific reasoning-level model.                                                    | Dispatched by a parent agent or skill               |
| 3          | Instruction file (`.instructions.md`)     | The need is a path-scoped convention for files being created or edited, applied to whoever touches them (agents, skills, subagents, or human maintainers), via an `applyTo` glob. | Auto-applied by an `applyTo` glob                   |
| 4          | Agent (`.agent.md`)                       | A multi-turn role or a bounded autonomous workflow is specifically requested.                                                                                                     | Selected as a chat mode or agent                    |
| 5          | Prompt (`.prompt.md`)                     | A repeatable single-session slash command is specifically requested.                                                                                                              | Invoked as `/name`                                  |
| Note       | Tool                                      | A concrete capability rather than guidance is needed. It is declared in an agent's tools frontmatter, not authored here.                                                          | Declared in frontmatter                             |

When a single request spans several types, split it: for example a skill for the workflow and shared scripts, subagents for isolated or tier-specific work, and an instruction file for the conventions both share. Propose the split and confirm scope before authoring.

## Guiding questions

* Does it carry reusable capability, domain knowledge, or scripts that should load on demand? That points to a skill.
* Does it need context isolation, high-volume or parallel work, or a specific reasoning-level model? That points to a subagent.
* Is it a path-scoped convention that should auto-apply to a set of files whenever they are created or edited, regardless of who touches them? That points to an instruction file with an `applyTo` glob.
* Was a multi-turn role or bounded autonomous workflow specifically requested? That points to an agent.
* Was a repeatable single-session slash command specifically requested? That points to a prompt.
* Does it need a capability rather than guidance? That points to a tool.

## Route each fact by load timing and authority

For every rule or fact the artifact would carry, place it where it loads at the right time and binds with the right force. This keeps always-loaded surfaces short and moves enforcement off advisory prose.

| Load timing     | Home                                                  | Use for                                                                                       |
|-----------------|-------------------------------------------------------|-----------------------------------------------------------------------------------------------|
| Always loaded   | Root agent instruction file (AGENTS.md or equivalent) | Durable, non-inferable, project-wide facts: key commands, non-default conventions, invariants |
| Scoped by path  | Path-scoped instruction file with an `applyTo` glob   | Conventions that apply only to some files or languages                                        |
| On demand       | Skill body and its references                         | Recurring workflows and domain knowledge needed only sometimes                                |
| Deferred detail | Skill references, templates, and assets               | Full schemas, long examples, and reusable skeletons                                           |
| Delegated       | Subagent                                              | Isolated, high-volume, or verification work returning a summary                               |

| Authority | Home                                                     | Use for                                                          |
|-----------|----------------------------------------------------------|------------------------------------------------------------------|
| Advisory  | Instruction and skill prose                              | Guidance the model should follow and can override with judgment  |
| Enforced  | Hooks, permission modes, pipeline checks, strict schemas | Non-negotiable rules that must hold regardless of model judgment |

A single requirement often splits across both axes. For example, "do not write to protected paths" belongs in advisory prose for context and in an enforced hook for the guarantee.

## Delegation analysis

Treat delegation as a first-class architecture decision, not an afterthought. During intake, before settling the shape, analyze what the skill or agent being authored could hand to a subagent.

* Identify functionality a low-reasoning-effort subagent could own: isolated research, high-volume reads, mechanical checks, fresh-context review, or tier-specific execution. Author it to the `.agent.md` subagent convention and dispatch it with `runSubagent` or `task`.
* Weigh delegating against inlining. Delegating buys context isolation, parallelism, and a right-sized model per responsibility; inlining is simpler for tightly coupled, low-volume, or latency-sensitive steps. Prefer making, updating, or reusing a subagent over inlining coordination, orchestration, or workflow logic.
* Design the agentic loop explicitly: dispatch a subagent and act on its return, dispatch more subagents when the work fans out, orchestrate several in parallel when their work is independent, and chain one subagent's output into the next when the work is sequential.
* Favor reuse. Check whether an existing subagent already covers the responsibility before creating a new one, and prefer extending or adjusting an existing subagent over duplicating it.

## Worked example: compact skill plus one low-reasoning worker

A recurring "profile a CSV and summarize it" need is reusable capability, so it is a skill; the profiling itself is mechanical and high-volume, so it is delegated to one dedicated low-reasoning worker subagent.

Skill frontmatter, a compact playbook skill:

```yaml
---
name: csv-profiler
description: "Profile a CSV and summarize its columns, types, and null rates. Use when a request asks to profile CSV data."
user-invocable: true
---
```

Subagent dispatch line in the skill's Flow: dispatch `CSV Profiler Worker` with the CSV path and the output path, then read its returned summary.

Worker subagent (`.agent.md` under `subagents/`), pinned to a fixed low tier because it always runs there:

```yaml
---
name: CSV Profiler Worker
description: "Profiles a CSV with a bundled script and returns a summary. Use when profiling CSV data."
user-invocable: false
model:
  - MAI-Code-1-Flash (copilot)
  - Claude Haiku 4.5 (copilot)
tools:
  - search/fileSearch
  - read/readFile
  - edit/createFile
---
```

Because the worker targets a low-reasoning model, its body names the tool order: use `search/fileSearch` to locate the CSV, `read/readFile` to confirm the header, then run the bundled profiling script and write the summary with `edit/createFile`.

Parent-owned test step: the skill's Flow tests HVE artifacts through the `/hve-builder-tester` sub-skill dispatch at the Low tier, the tier the worker targets, to exercise the skill and worker together in a sandbox before the run is treated as complete. Route HVE-artifact testing through `/hve-builder-tester` rather than dispatching `HVE Artifact Tester` directly; the tester skill owns the sandbox setup, black-box test-prompt design, execution, and the runtime-log review.

## Placement heuristics

* Put a fact in the root file only when it is durable, non-inferable, and project-wide. If code or standard conventions already reveal it, leave it out.
* When the root file grows past the host's published size guidance, move the overflow into path-scoped rules rather than trimming meaning.
* When guidance is needed only for a recurring task, package it as a skill so it loads on demand instead of always.
* When a rule must hold regardless of model judgment, back it with an enforced control and keep the prose as explanation, not as the guarantee.
* When knowledge is reused across hosts, keep one source of truth and link or import it rather than copying.

## Reuse before authoring

Before creating any new artifact, check whether an existing one already covers the need. Survey the available subagents, skills, and instruction files, not only the obvious match. Prefer reusing an existing artifact as it stands; when it almost fits, prefer adjusting or extending it over duplicating it; create a new artifact only when no existing one can be reasonably adapted. Weigh a small change to a shared artifact against a new one that repeats most of it. For external research during authoring, reuse the existing `Researcher Subagent` rather than creating a new research worker.
