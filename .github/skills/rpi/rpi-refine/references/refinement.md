---
description: "Reference protocol for subtractive RPI refinement review across four fresh-context lenses, depth tiers, outcome vocabulary, and planning handoff."
---

# RPI Refine Reference

## Subtractive posture

`rpi-refine` complements `rpi-review`. While `rpi-review` checks whether the implementation met its planned requirements and acceptance criteria, `rpi-refine` asks what can be removed, simplified, consolidated, or reworked across everything the session touched so the codebase, docs, tests, domain model, and configuration settle into a cleaner state.

Apply three governing checks to every candidate finding:

1. Prefer subtraction over addition. Look first for code, branches, wrappers, tests, documents, prose, dependencies, and configuration that can be deleted, merged, or moved to their canonical home.
2. Trace backward from outcomes to inputs. Deep conditional trees, compensating flags, and layered helpers often collapse into a short linear path when read from the required output back to the caller.
3. Protect real trust boundaries while cutting speculative internal guards. Never recommend removing input validation, path or workspace containment, authentication, authorization, secret redaction, or untrusted-content checks. Inside trusted internal call paths, flag redundant defensive checks and swallowed exceptions where letting an unexpected state fail fast (without corrupting durable state or causing unintended downstream changes) or handling errors higher up the stack makes behavior clearer. Any refinement that touches a security or trust boundary routes to `rpi-plan` with its security rationale, never directly to `rpi-implement`.

## Four subtractive lenses

Assess every area the session worked in across these four lenses:

### Lens 1: Logic, branching, error boundaries, and performance

* Logic lines, helpers, or state variables added during implementation that can be deleted, inlined, or simplified.
* Deep branching or nested conditionals where reading backward from the target result uncovers a flatter control path.
* Unnecessary internal defensive checks or speculative edge-case branches that never occur under established invariants, where failing fast is safe or where exceptions belong at a higher error boundary. Exclude all trust-boundary, containment, auth, secret, and untrusted-input checks.
* Runtime waste: slow loops or repeated work that can run faster, missing caching where memory trades cleanly for speed, excessive memory allocation or retention, and synchronous CPU-blocking calls on I/O paths.

### Lens 2: Conventions, SDKs, libraries, and language versions

* Missed codebase conventions, existing internal utilities, existing SDK methods, or platform APIs that duplicate what was written by hand.
* Leftover code, types, or flags from mistaken early assumptions that were corrected later without cleaning up the scaffolding.
* Dependencies or modules added when straightforward language or standard-library code suffices, or custom logic written where an already-approved library or module solves the problem cleanly.
* Unused features of the current language, runtime, or framework version that simplify the implementation, plus concrete opportunities to upgrade to a newer version when compatible and non-breaking, stating the practical reasons to offer the upgrade.

### Lens 3: Assumptions, architecture, abstractions, and tests

* Base assumptions in the initial design that turned out wrong and now have compensating logic stacked on top holding behavior together when the underlying model should be redesigned.
* Missing abstractions that leave repeated structural plumbing scattered across files, or premature design patterns and indirection layers applied where plain data and functions are clearer.
* Temporary migration shims, compatibility glue, or helper code that served an intermediate step and is no longer needed.
* Workarounds built around outdated design or architectural restrictions, plus architecture records, diagrams, or module boundaries that should be updated to match new functionality.
* Redundant or brittle tests, production branches written only to appease flawed prior tests, or "almost-right" tests that drove extra production workarounds and follow-on test patches.
* Sharp edges, ambiguous contracts, or naming pitfalls that should be fixed now so future agents and humans do not trip over them.

### Lens 4: Documents, domain language, and infrastructure

* Unneeded documents created during the session, or documentation and rule updates placed in the wrong file when another file owns that concept.
* Missing or muddled domain terms where defining a clear domain concept and aligning code, types, and docs to it eliminates translation glue.
* Conflicting rules, redundant filler, confusing phrasing, or AI-sounding prose (staged contrasts, throat-clearing run-ups, inflated claims, decorative bolding, or chatbot residue).
* Unwarranted infrastructure additions or configuration changes, compensating workarounds layered onto those config changes, and stale pre-existing or newly added configuration and infrastructure that should be cleaned up.
* Broader alternative designs that would simplify the completed work.

Each `RF-xxx` finding sets `* Dimension:` to one concise label: `Logic and branching`, `Error boundaries`, `Performance and resources`, `Conventions`, `Dependencies and SDKs`, `Language and version features`, `Assumptions and architecture`, `Tests`, `Future mistake prevention`, `Documents and domain language`, or `Infrastructure and configuration`.

## Fresh-context helpers

The refinement parent owns verified findings, IDs, decisions, and the artifact. Subagents are never mandatory, and `subagents=none` or an environment without a dispatch tool runs the same four lenses directly in the parent context.

When a dispatch tool is available and `Subagent use` permits subagents, prefer dispatching `RPI Refiner` in one parallel batch right after initializing the `-refinement.md` skeleton with `Review execution: started`, before reading the full implementation diffs yourself. Fresh subagent context avoids inheriting the rationale that justified unnecessary complexity during implementation.

* Scope each lane to one lens (or a subset of touched directories for a large diff) and pass: the lens question, the changed-file list and relevant plan or changes paths, the active review depth (`surface`, `standard`, or `deep`), the security and trust-boundary exclusion rule, and any explicit caller exclusions. Do not pass a list of expected findings.
* Select each lane's reasoning effort when dispatching:
  * `low` for mechanical inventory checks, such as spotting unused exports, duplicate config keys, or untouched leftover files.
  * `high` for convention, SDK, documentation, language-idiom, and test-redundancy comparisons across touched files.
  * `max` for backward-path logic simplification, base-assumption and architectural rework, error-boundary placement, security-adjacent boundary checks, and CPU/memory/I/O analysis. In `deep` depth, use `max` for every non-mechanical lane.
  * Honor any user- or caller-set effort override. If a dispatch fails because the model does not support the requested effort, retry once with `reasoning_effort` set to `medium` and record that fallback.
* Verify every candidate at its cited workspace path before recording an `RF-xxx` finding. Discard candidates that propose additive ceremony, violate confirmed user direction, or weaken a trust boundary. Record each lane's scope, effort, effort source, and verification result under `### Scope and Evidence`.

## Depth tiers

| Depth      | When used                                                                                  | Boundary                                                                                                                                                  |
|------------|--------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------|
| `surface`  | Repeated RPI loop in the same session that introduced significant changes, or user request | Inspect only files and contracts changed in the latest loop for leftover scaffolding, dead branches, misplaced edits, AI slop, and unneeded local guards. |
| `standard` | Default for standalone `/rpi-refine` and initial session Review                            | Assess all touched code, tests, docs, domain language, dependencies, and config across all four lenses once, focusing on material net simplifications.    |
| `deep`     | Explicit user request only                                                                 | Trace backward across call graphs, module boundaries, test suites, runtime version features, and config layers more broadly within the task's scope.      |

## Separate execution from outcome

Execution status records whether the review pass ran:

* `Complete`
* `Partial`
* `Blocked`

Assessed and final outcome record what the completed work needs:

* `Clean`: no material subtractive, simplification, or redesign findings within the assessed boundary
* `Refinements identified`: concrete removals, simplifications, test cleanups, doc tightenings, or local refactorings are warranted within the current design
* `Redesign needed`: flawed base assumptions, domain boundaries, or architectural workarounds warrant replanning in `rpi-plan` or a dedicated new RPI session
* `Residual cleanup`: only optional, non-blocking cleanups or version-upgrade opportunities remain for follow-up
* `Not accepted`: blocked boundary or critical structural/work-around hazard prevents accepting the current state

## Finding and routing rules

Each `RF-xxx` finding uses marker `<!-- rpi:refinement id=RF-001 -->` above `### RF-001 [Severity]: Title` and records its scope, dimension, current state with workspace-relative paths and symbols or headings, what to remove or rework, impact, checkable resolution condition, proposed destination, and smallest useful next action. Describe the simplified target state without dictating a rigid line-by-line patch when local judgment applies.

Route each accepted finding once:

* `rpi-plan`: multi-step refactorings, flawed base-assumption redesigns, new domain definitions, architectural boundary updates, test-suite restructurings, and any refinement touching a security or trust boundary. In an active RPI session, accepted `rpi-plan` findings become new `Pxx` planning phases on the current plan for a repeated loop, or seed a separate RPI session when the rework spans a broader boundary.
* `rpi-implement`: isolated, well-bounded deletions, dead-code or leftover removals, prose tightenings, or straightforward SDK substitutions that fit cleanly inside accepted plan requirements without changing contracts or security boundaries.
* `rpi-research`: version-upgrade compatibility checks, unfamiliar SDK or runtime investigations, or benchmark evidence needed before deciding whether to rework a path.
* `follow-up`: optional out-of-scope cleanups, broader infrastructure tidy-ups, or non-urgent runtime/framework upgrade offers with their rationale.

## Parent decision protocol and walkthrough

Record every decision in `## Parent Decision Record` under `### Decision History` using sequential `FD-001`, `FD-002`, ... IDs (`participation`, `walkthrough`, `execution`, `outcome`, each `RF-xxx`, and `continuation`). Never edit or remove earlier rows; refresh `### Current Disposition` from the latest event per subject. On recovery, `Parent Decision Record` governs over stale session projections.

For `user-owned` or `user-retained` participation, persist each pending `RF-xxx` finding first, then present the refinement record and cited files as Markdown links and explain in plain language:

* What exists right now and what can be removed, simplified, or reworked
* Why cutting or reworking it matters (complexity, maintenance risk, performance, or future missteps)
* The proposed destination (`rpi-plan`, `rpi-implement`, `rpi-research`, or `follow-up`) and suggested action
* Any trade-off or uncertainty, such as whether a broader redesign belongs in a new RPI session

Call the host's question tool (`ask_user` or `vscode_askQuestions`) when available, one finding per turn, with freeform input enabled and these options:

* `Use suggested action: [plain-language action]` (recommended)
* `Route to new RPI session` (when the finding involves broader redesign, domain redefinition, or version upgrade)
* `Gather more information`
* `Keep current implementation (skip)`
* `Finish refinement decisions`
* `Answered in the canvas` (included while an RPI Workflow canvas shows the session; collect the answer via `take_feedback`)

Append each answer as an `FD-xxx` event before moving to the next finding. When no actionable `RF-xxx` findings exist, skip the walkthrough without asking for acknowledgment.

## Conversation protocol

After persisting `### Scope and Evidence` and `### Opening Refinement State` with execution `started`, send one concise opening message:

```markdown
## RPI Refine: [Task] | [surface, standard, or deep]

[Interpreted subtractive review goal.]

* Scope and touched surfaces: [code, tests, docs, domain, config, or bounded Pxx/Pxx-Txx]
* Review depth: [surface, standard default, or explicit-user deep]
* Lenses and helpers: [parallel RPI Refiner lenses or direct parent pass]
* Current blockers: [active blockers]
* Relevant links: [Markdown links when available]

This starting boundary evolves only through verified workspace and artifact evidence.
```

Omit Current blockers when none exist and Relevant links when none exist. Suppress routine lens narration; send a continual update only when execution becomes `Partial` or `Blocked`, a user decision is needed, or the completed record is ready. Pair optional markers (`✅`, `⚠️`, `⛔`) with text.
