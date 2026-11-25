---
description: 'Responsibility-based artifact architecture, delegation analysis, model fit, and load-timing and authority routing for hve-builder.'
---
<!-- markdownlint-disable-file -->
# Artifact Architecture and Routing

Use this reference during intake to decompose the request by responsibility, choose each artifact's activation surface, and route facts by load timing and authority. Artifact types are complementary rather than a universal preference ladder.

## Choose by responsibility and activation

Choose every type whose responsibility is independently necessary. Prefer skills for reusable on-demand capability and subagents for isolated work, but do not force a path-scoped convention into a skill or a user entry point into a subagent merely because of ranking.

The Choose Artifacts by Responsibility section of `hve-builder.instructions.md` holds the canonical responsibility, form, and activation table. Confirm that the host loaded it; otherwise read that instruction by its stable name before routing. Do not assume path matching loads it in every host or read-only review context. This reference depends on that instruction file, and both ship in the same package. Keep them together when redistributing the skill.

When a request spans responsibilities, split it deliberately: a skill may own the workflow, subagents may isolate execution and review, an instruction file may govern matching paths, and a user-invocable skill may provide a slash-command entry point. Confirm only splits that widen the caller's write boundary or product surface.

Selecting an agent tool set is outside this routing. Apply the Tool-configuration boundary in [requirements-catalog.md](requirements-catalog.md).

## Route each fact by load timing and authority

For every rule or fact the artifact would carry, place it where it loads at the right time and binds with the right force. This keeps always-loaded surfaces short and moves enforcement off advisory prose.

### Load timing

* Always loaded: put durable, non-inferable, project-wide facts in the root agent instruction file, such as AGENTS.md or its equivalent. Include key commands, non-default conventions, and invariants.
* Scoped by path: put conventions limited to particular files or languages in path-scoped instructions with an `applyTo` glob.
* On demand: put recurring workflows and knowledge needed only sometimes in a skill body and its references.
* Deferred detail: put full schemas, long examples, and reusable skeletons in skill references, templates, and assets.
* Delegated: put isolated, high-volume, profile-specific, or verification work returning a summary in a subagent.

### Authority

* Advisory: instruction and skill prose states behavioral requirements subject to instruction precedence. It does not provide a deterministic enforcement guarantee.
* Enforced: hooks, permission modes, pipeline checks, and strict schemas implement non-negotiable rules that must hold regardless of model judgment.

A single requirement often splits across both axes. For example, "do not write to protected paths" belongs in advisory prose for context and in an enforced control for the guarantee. Choose the control that enforces the requirement rather than defaulting to a hook.

## Delegation analysis

Treat delegation as a first-class architecture decision, not an afterthought. During intake, before settling the shape, analyze what the skill or agent being authored could hand to a subagent.

* Identify functionality a focused subagent could own: high-volume discovery, mechanical checks, or fresh-context review.
* Weigh delegating against inlining. Delegate when context isolation, parallelism, or a distinct model responsibility repays the dispatch; keep tightly coupled, low-volume, or latency-sensitive work in the current context.
* Design the loop explicitly: define dispatch inputs, owned evidence, return schema, stage gate, and which later step consumes the result. Parallelize only independent work.
* Favor reuse. Check whether an existing subagent already covers the responsibility before creating a new one, and prefer extending or adjusting an existing subagent over duplicating it.
* Make the contract executable. A create-only worker writes its owned log once; progressive logs require edit capability. A parent that dispatches subagents declares its allowed agent set.

## Extending an existing workflow

When the request adds project-specific capability to a workflow such as `rpi-research`, `rpi-plan`, or `code-review`, extend it rather than fork it. Read the workflow's skill first and capture how it discovers extensions (description matching, registration), whether an extension is required or optional, and what it passes when it uses one. For the RPI phases, the description is the whole contract: the phase reads it to decide when to call the extension, what to give it, and what to expect back. Then choose the artifact by where the work should run:

* A skill when the knowledge should load into the workflow's own context and be applied while it works: source locations, indexing steps, query and citation conventions, and bundled scripts. The workflow stays in control and nothing is isolated.
* A subagent when gathering is high-volume, parallelizable, or would crowd out the parent's working context: a helper that gathers, then returns source pointers, excerpts, and brief notes that the workflow verifies before recording anything.
* Both when a skill holds the reusable corpus instructions and scripts and a thin subagent activates that skill for isolated gathering.

Example: a team wants `rpi-research` and `rpi-plan` to draw on an internal design-document corpus. A skill whose description marks it for use during research and planning documents where the corpus lives, how to run its indexing script, and how to cite results; both workflows activate it through their skill-selection rules. If the corpus is large enough that searching it would flood the research context, add a research helper subagent that searches the corpus for one bounded question and returns source pointers to `rpi-research`, which reads and records the evidence itself. [extending-hve-builder.md](extending-hve-builder.md) works this example through each workflow's contract.

## Leave model selection to the host

Omit model and reasoning-effort fields in agent definitions and dispatches unless the current request or applicable persistent user instructions explicitly require a value for that target. Omission lets the host resolve its preferences; it does not establish which model ran. An explicit [custom agent model](https://docs.github.com/en/copilot/reference/custom-agents-configuration) is a scalar. A per-call override is separate: use the field and value supported by the dispatch tool, not a copied model-picker label. Report an unsupported request instead of silently substituting another value.

## Worked example: compact skill plus one bounded worker

A recurring "profile a CSV and summarize it" need is reusable capability, so it is a skill; the profiling itself is mechanical and high-volume, so it is delegated to one dedicated worker subagent.

Skill frontmatter, a compact playbook skill:

```yaml
---
name: csv-profiler
description: "Profile a CSV and summarize its columns, types, and null rates. Use when a request asks to profile CSV data."
user-invocable: true
---
```

Subagent dispatch line in the skill's Flow: dispatch `CSV Profiler Worker` with the CSV path and the output path, then read its returned summary.

Worker subagent (`.agent.md` under `subagents/`):

```yaml
---
name: CSV Profiler Worker
description: "Profiles a CSV with a bundled script and returns a summary. Use when profiling CSV data."
user-invocable: false
---
```

The worker body defines its bounded input and structured summary without selecting a tool configuration or order.

Parent-owned review step: after local validation closes, run the review pass against the complete candidate. Review it yourself, or dispatch `HVE Builder Reviewer` when fresh context would help, then verify each finding at its cited location before recording it. The parent fixes required findings and reviews the revised candidate under the workflow contract's convergence rules; the reviewer never edits source or writes evidence.

## Placement heuristics

* Put a fact in the root file only when it is durable, non-inferable, and project-wide. If code or standard conventions already reveal it, leave it out.
* When the root file grows past the host's published size guidance, move the overflow into path-scoped rules rather than trimming meaning.
* When guidance is needed only for a recurring task, package it as a skill so it loads on demand instead of always.
* When a rule must hold regardless of model judgment, back it with an enforced control and keep the prose as explanation, not as the guarantee.
* When knowledge is reused across hosts, keep one source of truth and link or import it rather than copying.

## Reuse before authoring

Before creating any new artifact, first classify caller-provided facts, known targets, and already-supplied extension metadata. When non-obvious reuse discovery, an extension survey, or another open-ended workspace exploration is needed, activate `rpi-research` through the HVE Builder stage-dispatch bridge rather than scanning directly. Prefer reusing an existing artifact as it stands; when it almost fits, prefer adjusting or extending it over duplicating it; create a new artifact only when no existing one can be reasonably adapted. Weigh a small change to a shared artifact against a new one that repeats most of it. Keep bounded reads of already-known targets and supplied references in their lifecycle stage. Use `rpi-research` for every decision-critical internal, external, or hybrid research activity rather than creating a local research worker.
