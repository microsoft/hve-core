---
description: 'Responsibility-based artifact architecture, delegation analysis, model fit, and load-timing and authority routing for hve-builder.'
---
<!-- markdownlint-disable-file -->
# Artifact Architecture and Routing

Use this reference during intake to decompose the request by responsibility, choose each artifact's activation surface, and route facts by load timing and authority. Artifact types are complementary rather than a universal preference ladder.

## Choose by responsibility and activation

Choose every type whose responsibility is independently necessary. Prefer skills for reusable on-demand capability and subagents for isolated work, but do not force a path-scoped convention into a skill or a user entry point into a subagent merely because of ranking.

| Responsibility                                                                     | Choose                                    | Activation                                  |
|------------------------------------------------------------------------------------|-------------------------------------------|---------------------------------------------|
| Reusable workflow, domain knowledge, bundled references, templates, or scripts     | Skill (`SKILL.md`)                        | Semantic description match or `/skill-name` |
| Isolated, high-volume, parallel, fresh-context, mechanical, or model-specific work | Subagent (`.agent.md` under `subagents/`) | Parent dispatch by stable `name`            |
| Convention that applies whenever matching paths are edited                         | Instruction file (`.instructions.md`)     | Automatic `applyTo` match                   |
| User-selected multi-turn role or bounded autonomous workflow                       | Agent (`.agent.md`)                       | Agent picker or explicit handoff            |
| Repeatable, parameterized user entry point                                         | Prompt (`.prompt.md`)                     | Slash invocation                            |
| Concrete action capability                                                         | Tool                                      | Native registration in agent frontmatter    |

When a request spans responsibilities, split it deliberately: a skill may own the workflow, subagents may isolate execution and review, an instruction file may govern matching paths, and a prompt may provide a user entry point. Confirm only splits that widen the caller's write boundary or product surface.

## Guiding questions

* Does it carry reusable capability, domain knowledge, references, templates, or scripts that should load on demand? That points to a skill.
* Does it need context isolation, high-volume or parallel work, or a specific reasoning-level model? That points to a subagent.
* Is it a convention that applies whenever matching paths are edited? That points to an instruction file.
* Was a multi-turn role or bounded autonomous workflow specifically requested? That points to an agent.
* Is a parameterized slash entry point needed for users? That points to a prompt.
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

* Identify functionality a focused subagent could own: high-volume discovery, mechanical checks, fresh-context review, or profile-specific execution. Match the model to the responsibility; fresh-context review usually needs more judgment than mechanical validation.
* Weigh delegating against inlining. Delegating buys context isolation, parallelism, and a right-sized model per responsibility; inlining is simpler for tightly coupled, low-volume, or latency-sensitive steps. Prefer making, updating, or reusing a subagent over inlining coordination, orchestration, or workflow logic.
* Design the loop explicitly: define dispatch inputs, owned evidence, return schema, stage gate, and which later step consumes the result. Parallelize only independent work.
* Favor reuse. Check whether an existing subagent already covers the responsibility before creating a new one, and prefer extending or adjusting an existing subagent over duplicating it.
* Make the contract executable. A create-only worker writes its owned log once; progressive logs require edit capability. A parent that dispatches subagents declares the `agent` tool and its allowed agent set.

## Choose the model profile

The `model:` field is optional. An omitted subagent model inherits the invoking parent's model; an omitted directly invoked agent or prompt model uses the current session or model-picker selection. When a stable profile is needed, select High, Medium, or Low from the responsibility before authoring `model:`. Use Low for bounded, literal, mechanical execution with explicit tool order, Medium for semantic discovery, architecture, authoring, research, and calibrated review, and High only when the responsibility requires the deepest reasoning profile. Declare the selected profile's exact ordered list:

* High: `GPT-5.6 Sol (copilot)`, `Claude Opus 4.8 (copilot)`, `GPT-5.5 (copilot)`
* Medium: `GPT-5.6 Terra (copilot)`, `Claude Sonnet 5 (copilot)`, `MAI-Code-1-Flash (copilot)`
* Low: `GPT-5.6 Luna (copilot)`, `MAI-Code-1-Flash (copilot)`, `Claude Haiku 4.5 (copilot)`

The list order provides availability fallback within the selected profile; it never replaces profile selection.

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
  - GPT-5.6 Luna (copilot)
  - MAI-Code-1-Flash (copilot)
  - Claude Haiku 4.5 (copilot)
tools:
  - search/fileSearch
  - read/readFile
  - edit/createFile
---
```

Because the worker targets Luna, its body names the tool order: use `search/fileSearch` to locate the CSV, `read/readFile` to confirm the header, then run the bundled profiling script and write the summary with `edit/createFile`.

Parent-owned test step: the skill tests the workflow through the `hve-builder-tester` skill at the Low profile. Select simulation or native fidelity explicitly and report the evidence limitation. Do not dispatch `HVE Artifact Tester` directly; the tester skill owns design, fidelity, evidence integrity, grading, and cleanup.

## Placement heuristics

* Put a fact in the root file only when it is durable, non-inferable, and project-wide. If code or standard conventions already reveal it, leave it out.
* When the root file grows past the host's published size guidance, move the overflow into path-scoped rules rather than trimming meaning.
* When guidance is needed only for a recurring task, package it as a skill so it loads on demand instead of always.
* When a rule must hold regardless of model judgment, back it with an enforced control and keep the prose as explanation, not as the guarantee.
* When knowledge is reused across hosts, keep one source of truth and link or import it rather than copying.

## Reuse before authoring

Before creating any new artifact, check whether an existing one already covers the need. Survey the available subagents, skills, and instruction files, not only the obvious match. Prefer reusing an existing artifact as it stands; when it almost fits, prefer adjusting or extending it over duplicating it; create a new artifact only when no existing one can be reasonably adapted. Weigh a small change to a shared artifact against a new one that repeats most of it. For external research during authoring, reuse the existing `Researcher Subagent` rather than creating a new research worker.
