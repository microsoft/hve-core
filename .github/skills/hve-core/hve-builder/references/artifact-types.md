---
description: 'Responsibility-based artifact architecture, delegation analysis, model fit, and load-timing and authority routing for hve-builder.'
---
<!-- markdownlint-disable-file -->
# Artifact Architecture and Routing

Use this reference during intake to decompose the request by responsibility, choose each artifact's activation surface, and route facts by load timing and authority. Artifact types are complementary rather than a universal preference ladder.

## Choose by responsibility and activation

Choose every type whose responsibility is independently necessary. Prefer skills for reusable on-demand capability and subagents for isolated work, but do not force a path-scoped convention into a skill or a user entry point into a subagent merely because of ranking.

The Choose Artifacts by Responsibility section of `hve-builder.instructions.md` holds the canonical responsibility, form, and activation table. That surface is always loaded whenever a target artifact is edited, so it is the copy that has to exist; restating it here would only create drift. This reference therefore depends on that instruction file, and both ship in the same package. Keep them together when redistributing the skill.

When a request spans responsibilities, split it deliberately: a skill may own the workflow, subagents may isolate execution and review, an instruction file may govern matching paths, and a prompt may provide a user entry point. Confirm only splits that widen the caller's write boundary or product surface.

Selecting an agent tool set is outside this routing. Apply the Tool-configuration boundary in [requirements-catalog.md](requirements-catalog.md).

## Route each fact by load timing and authority

For every rule or fact the artifact would carry, place it where it loads at the right time and binds with the right force. This keeps always-loaded surfaces short and moves enforcement off advisory prose.

| Load timing     | Home                                                  | Use for                                                                                       |
|-----------------|-------------------------------------------------------|-----------------------------------------------------------------------------------------------|
| Always loaded   | Root agent instruction file (AGENTS.md or equivalent) | Durable, non-inferable, project-wide facts: key commands, non-default conventions, invariants |
| Scoped by path  | Path-scoped instruction file with an `applyTo` glob   | Conventions that apply only to some files or languages                                        |
| On demand       | Skill body and its references                         | Recurring workflows and domain knowledge needed only sometimes                                |
| Deferred detail | Skill references, templates, and assets               | Full schemas, long examples, and reusable skeletons                                           |
| Delegated       | Subagent                                              | Isolated, high-volume, tier-specific, or verification work returning a summary                |

| Authority | Home                                                     | Use for                                                          |
|-----------|----------------------------------------------------------|------------------------------------------------------------------|
| Advisory  | Instruction and skill prose                              | Guidance the model should follow and can override with judgment  |
| Enforced  | Hooks, permission modes, pipeline checks, strict schemas | Non-negotiable rules that must hold regardless of model judgment |

A single requirement often splits across both axes. For example, "do not write to protected paths" belongs in advisory prose for context and in an enforced control for the guarantee. Choose that enforced home from the Authority table rather than defaulting to a hook.

## Delegation analysis

Treat delegation as a first-class architecture decision, not an afterthought. During intake, before settling the shape, analyze what the skill or agent being authored could hand to a subagent.

* Identify functionality a focused subagent could own: high-volume discovery, mechanical checks, fresh-context review, or profile-specific execution. Match the model to the responsibility; fresh-context review usually needs more judgment than mechanical validation.
* Weigh delegating against inlining. Delegate when context isolation, parallelism, or a distinct model responsibility repays the dispatch; keep tightly coupled, low-volume, or latency-sensitive work in the current context.
* Design the loop explicitly: define dispatch inputs, owned evidence, return schema, stage gate, and which later step consumes the result. Parallelize only independent work.
* Favor reuse. Check whether an existing subagent already covers the responsibility before creating a new one, and prefer extending or adjusting an existing subagent over duplicating it.
* Make the contract executable. A create-only worker writes its owned log once; progressive logs require edit capability. A parent that dispatches subagents declares its allowed agent set.

## Extending an existing workflow

When the request adds project-specific capability to a workflow such as `rpi-research`, `rpi-plan`, or `code-review`, extend it rather than fork it. Read the workflow's skill first and capture how it discovers helpers (name and description matching, registration) and what it passes on dispatch. Then choose the artifact by where the work should run:

* A skill when the knowledge should load into the workflow's own context and be applied while it works: source locations, indexing steps, query and citation conventions, and bundled scripts. The workflow stays in control and nothing is isolated.
* A subagent when gathering is high-volume, parallelizable, or would crowd out the parent's working context: a lane worker that gathers and indexes, then returns a bounded summary and an evidence pointer.
* Both when a skill holds the reusable corpus instructions and scripts and a thin subagent activates that skill for isolated lanes.

Example: a team wants `rpi-research` and `rpi-plan` to draw on an internal design-document corpus. A skill whose name or description marks it for use during research and planning documents where the corpus lives, how to run its indexing script, and how to cite results; both workflows discover it through their helper-selection rules. If the corpus is large enough that indexing would flood the parent's context, add a research specialist subagent that runs the index in an isolated lane and returns findings to `rpi-research`. [extending-hve-builder.md](extending-hve-builder.md) works this example through each workflow's contract.

## Choose the model profile

The `model:` field is optional and omitted by default. An omitted subagent model inherits the invoking parent's model; an omitted directly invoked agent or prompt uses the current session or model-picker selection. Omission keeps the choice with the user, who sees the models their plan and client offer.

When a stable profile is needed, select High, Medium, or Low from the responsibility before touching `model:`:

* High is the deepest reasoning profile. Omit `model:` for a High responsibility unless the caller supplies a model. The strongest available model changes often and varies by plan and client, so pinning one removes the user's ability to pick it.
* Medium covers semantic discovery, architecture, authoring, research, and calibrated review. Declare `model:` only when the artifact must run at a predictable profile regardless of the session, for example a fresh-context reviewer that should not inherit a Low parent.
* Low covers bounded, literal, mechanical execution. Declaring `model:` is common here, because pinning a fast, low-cost model is the point.

Agent and subagent frontmatter accepts only a single scalar string for `model:`; the Copilot CLI's frontmatter parser rejects an array value and drops the artifact entirely. A prompt may instead declare an ordered list, which the host uses for availability fallback within the selected profile; the list never replaces profile selection. Use the exact model-picker name with the `(copilot)` suffix.

### Resolve current model names

Do not copy model names from this reference or from sibling artifacts; models are added, renamed, and retired several times a year. Resolve them at authoring time from GitHub's own documentation, and record the source and date in the authoring evidence.

1. Fetch the supported-models page in the GitHub Copilot docs (`docs.github.com`, under `copilot/reference/ai-models/supported-models`). It lists every current model, per-client availability, the retirement table with suggested replacements, and which models support configurable reasoning levels.
2. Fetch the model-comparison page beside it (`copilot/reference/ai-models/model-comparison`). Its "Recommended models by task" table groups models by task area. Map task areas to profiles: deep reasoning, debugging, and long-horizon autonomous work are High; general-purpose coding and agent tasks and agentic software development are Medium; fast help with simple or repetitive tasks is Low.
3. When the rendered pages are unavailable, search the `github/docs` repository for the same content under `content/copilot/reference/ai-models/`. The source uses Liquid variables for some names, so prefer the rendered page when both are reachable.
4. Confirm the candidate is available in the target client (VS Code, Copilot CLI, or the coding agent) and does not appear in the retirement table with a past date. For a prompt fallback list, order models within the profile by the comparison page's description, strongest fit first.

These locations and headings describe where the information lives today. If they move, search the Copilot documentation for the current model list and task comparison rather than treating the paths above as fixed.

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

Worker subagent (`.agent.md` under `subagents/`), pinned to a fixed Low profile because it always runs there. The model name below was resolved from the supported-models page when this example was written; resolve a current one when authoring.

```yaml
---
name: CSV Profiler Worker
description: "Profiles a CSV with a bundled script and returns a summary. Use when profiling CSV data."
user-invocable: false
model: GPT-5.6 Luna (copilot)
---
```

The worker body defines its bounded input and structured summary without selecting a tool configuration or order.

Parent-owned test step: classify the complete change after static findings and local validation are closed. The `hve-builder` skill records a supported skip for Minor and Medium changes. For a Major change, freeze the source boundary and invoke `hve-builder-tester` at most once as the final stage in that HVE Builder run. The tester owns fidelity, execution, evidence integrity, independent grading, and cleanup; do not dispatch `HVE Artifact Tester` directly.

## Placement heuristics

* Put a fact in the root file only when it is durable, non-inferable, and project-wide. If code or standard conventions already reveal it, leave it out.
* When the root file grows past the host's published size guidance, move the overflow into path-scoped rules rather than trimming meaning.
* When guidance is needed only for a recurring task, package it as a skill so it loads on demand instead of always.
* When a rule must hold regardless of model judgment, back it with an enforced control and keep the prose as explanation, not as the guarantee.
* When knowledge is reused across hosts, keep one source of truth and link or import it rather than copying.

## Reuse before authoring

Before creating any new artifact, first classify caller-provided facts, known targets, and already-supplied extension metadata. When non-obvious reuse discovery, an extension survey, or another open-ended workspace exploration is needed, activate `rpi-research` through the HVE Builder stage-dispatch bridge rather than scanning directly. Prefer reusing an existing artifact as it stands; when it almost fits, prefer adjusting or extending it over duplicating it; create a new artifact only when no existing one can be reasonably adapted. Weigh a small change to a shared artifact against a new one that repeats most of it. Keep bounded reads of already-known targets and supplied references in their lifecycle stage. Use `rpi-research` for every decision-critical internal, external, or hybrid research activity rather than creating a local research worker.
