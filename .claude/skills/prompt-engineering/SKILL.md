---
name: prompt-engineering
description: Authoring standards for prompt engineering artifacts including file types, protocol patterns, writing style, and quality criteria.
maturity: stable
user-invocable: false
---

# Prompt Engineering

Authoring standards for prompt engineering artifacts. Apply when creating or modifying prompt, agent, instructions, or skill files.

## File Types

### Prompt Files

*Extension*: `.prompt.md`

Single-session workflows where users invoke a prompt and the agent executes to completion.

* Frontmatter includes `agent: 'agent-name'` to delegate to an agent.
* Content ends with `---` followed by an activation instruction.
* Use `#file:` only when the full contents of another file are needed; otherwise refer by path.
* Input variables use `${input:variableName}` or `${input:variableName:defaultValue}` syntax.

Add sequential steps when the prompt involves multiple distinct actions. Simple single-task prompts do not need protocol structure.

#### Input Variables

* `${input:topic}` - required input, inferred from user prompt, attached files, or conversation.
* `${input:chat:true}` - optional input with default value `true`.

```markdown
## Inputs

* ${input:topic}: (Required) Primary topic or focus area.
* ${input:chat:true}: (Optional, defaults to true) Include conversation context.
```

#### Argument Hints

The `argument-hint` frontmatter field shows expected inputs in the prompt picker. Keep hints brief with required arguments first. Use `[]` for positional arguments, `key=value` for named parameters, `{option1|option2}` for enumerated choices, and `...` for free-form text.

```yaml
argument-hint: "topic=... [chat={true|false}]"
```

Validation:

* Follow the Step-Based Protocols section when steps are used.
* Document input variables in an Inputs section when present.

### Agent Files

*Extension*: `.agent.md`

Agent files support conversational workflows (multi-turn interactions) and autonomous workflows (task execution with minimal user interaction). Frontmatter defines available `tools` and optional `handoffs`.

#### Conversational Agents

* Users guide the conversation through different stages; state persists via planning files when needed.
* Add phases when the workflow involves distinct interactive stages. Follow the Phase-Based Protocols section.

#### Autonomous Agents

* Execute autonomously after receiving initial instructions and report results.
* May dispatch subagents for parallelizable work.

#### Claude Agents

*Location*: `.claude/agents/<name>.md`

Behavioral instructions for specialized task execution, loaded by skills (via `agent:` frontmatter or inline) or passed to the Task tool.

Agent roles:

* *Orchestrator agents* dispatch subagents via Task, manage phases, and synthesize results.
* *Leaf agents* perform direct work using a step-based protocol and return structured responses without dispatching further Tasks.

Frontmatter declares `name`, `description`, and optionally `tools` (YAML array) and `model` (`inherit` for parent model). Include `Task` in tools only when the agent dispatches subagents.

Recommended body sections: Core Principles, Tool Usage, Required Steps or Phases, Structured Response (for leaf agents), Operational Constraints, File Locations.

#### Execution Contexts

Three execution contexts determine tool access and session behavior:

* *Standalone* (skill without `context: fork`): Runs in the main session with Task tool access for one-level-deep subagent dispatch.
* *Forked* (skill with `context: fork`): Runs as an isolated subagent without conversation history or Task tool access. Results are summarized and returned.
* *Dispatched* (via Task call): Runs as a subagent task without further Task dispatch; falls back to direct tool usage.

#### Task Tool Fallback

Skills and agents that dispatch subagents include an Execution Mode Detection section. When the Task tool is available, dispatch subagent instances. When unavailable, read the subagent file and perform all work directly. Task nesting is limited to one level deep.

### Instructions Files

*Extension*: `.instructions.md`

Auto-applied guidance based on file patterns. Define conventions, standards, and patterns for matching files.

* Frontmatter includes `applyTo` with glob patterns (for example, `**/*.py`).
* Wrap examples in fenced code blocks.

### Skill Files

*File Name*: `SKILL.md`

Skills provide task-specific entry points and are the recommended pattern for new artifacts. Two variants exist: script-based skills that bundle executable scripts, and agent-based skills. Convert existing commands (`.claude/commands/`) to agent-based skills.

#### Script-Based Skills

*Location*: `.github/skills/<skill-name>/SKILL.md`

Self-contained packages bundling documentation with executable scripts.

Directory structure:

```text
.github/skills/<skill-name>/
  SKILL.md          # Main skill definition (required)
  scripts/          # Bash (.sh) and PowerShell (.ps1) scripts
  references/       # Technical reference files loaded on demand
  assets/           # Templates, images, and data files
  examples/         # Usage examples (recommended)
```

Content structure (sections in order):

1. Title (H1), Overview, Prerequisites, Quick Start.
2. Parameters Reference table, Script Reference with bash and PowerShell examples.
3. Troubleshooting, Attribution Footer.

#### Agent-Based Skills

*Location*: `.claude/skills/<skill-name>/SKILL.md`

Four agent-based skill patterns exist:

* *Delegation skills* delegate to a named agent via `agent:` frontmatter. The agent runs in the main conversation context with Task tool access.
* *Orchestrator skills* contain full orchestration logic in the skill body and dispatch subagents directly via the Task tool.
* *Forked skills* use `context: fork` to run as isolated subagents without Task tool access.
* *Rules-based skills* provide guidelines, standards, or conventions loaded as context by other skills or agents.

All skill frontmatter fields are defined in Optional Fields. The `agent:` and `context:` fields behave differently depending on whether `context: fork` is set.

#### Delegation Skills

Lightweight entry points that delegate to agents via `agent:` frontmatter. The skill body passes `$ARGUMENTS` with mode-specific directives controlling which phases the agent executes. Multiple skills can share a single agent by providing different mode directives.

Content structure:

1. Frontmatter with `name`, `description`, `maturity`, and optional `context`, `agent`, `argument-hint`, `disable-model-invocation`.
2. Title (H1) matching the skill purpose.
3. Activation sentence incorporating `$ARGUMENTS`.
4. Mode Directives section (H2) specifying phase scope and behavior.

#### Mode Directives

The Mode Directives section controls which phases the delegated agent executes and what behavioral emphasis to apply.

Structure:

* Opening line naming the mode and phase scope.
* Descriptive label (for example, "Build mode behavior:").
* Bulleted list of mode-specific behavioral instructions.
* Optional closing instruction for discovering instructions files or proceeding with phases.

Phase scope patterns:

* Full workflow: "following the full 5-phase workflow: Baseline, Research, Build, Validate, Iterate".
* Limited scope: "Execute Phase 1 only" with instructions to skip remaining phases.

#### Multi-Skill Agent Delegation

Multiple skills can delegate to the same agent with different mode directives. The agent reads directives from the invoking skill body.

| Skill           | Mode     | Phase Scope  | argument-hint                   |
| --------------- | -------- | ------------ | ------------------------------- |
| prompt-build    | build    | Full workflow | `"file=... [requirements=...]"` |
| prompt-refactor | refactor | Full workflow | `"file=... [requirements=...]"` |
| prompt-analyze  | analyze  | Phase 1 only | `"file=..."`                    |

Example delegation skill (build mode):

```yaml
---
name: prompt-build
description: Build or improve prompt engineering artifacts following quality criteria.
maturity: stable
agent: prompt-builder
argument-hint: "file=... [requirements=...]"
disable-model-invocation: true
---
```

```markdown
# Prompt Build

Build or improve the following prompt engineering artifact: $ARGUMENTS

## Mode Directives

Operate in build mode following the full 5-phase workflow.

Build mode behavior:

* Create new artifacts or improve existing ones through all five phases.
* When no explicit requirements are provided, refactor and improve all instructions in the referenced file.
* When a non-prompt file is referenced, search for related prompt artifacts and update them, or build a new one.

Discover applicable `.github/instructions/*.instructions.md` files and proceed with the Required Phases.
```

For limited-scope modes (such as analyze), the opening line restricts phase scope ("Execute Phase 1 only") and behavioral instructions skip remaining phases.

#### Orchestrator Skills

Skills that contain full orchestration logic in their body without `agent:` frontmatter. The skill dispatches subagents directly via the Task tool. Appropriate when the workflow has a single purpose without multiple modes, all orchestration logic fits in the skill body, and agent reuse across multiple skills is not needed.

Content structure:

1. Frontmatter with `name`, `description`, `maturity`, and optionally `disable-model-invocation`, `argument-hint`.
2. Title (H1), Core Principles, Subagent Delegation, Execution Mode Detection, File Locations.
3. Required Phases with phase-based protocol.
4. Output Templates and Response Format.

Include an Execution Mode Detection section (see Task Tool Fallback).

#### Forked Skills

Skills with `context: fork` run as isolated subagents without conversation history or Task tool access. Results are summarized and returned to the main conversation. Subagents cannot spawn other subagents; this is an architectural constraint.

Appropriate for self-contained leaf tasks such as read-only research, build/deployment procedures, or code review operating on explicit inputs. Not appropriate for orchestrator skills needing subagent dispatch, skills requiring conversation history, or guideline-only content without task instructions.

The `agent` field with `context: fork`:

| Agent Value | Model | Tools | Use Case |
|-------------|-------|-------|----------|
| `Explore` | Haiku | Read-only (denied Write/Edit) | File discovery, code search |
| `Plan` | Inherits parent | Read-only (denied Write/Edit) | Codebase research for planning |
| `general-purpose` (default) | Inherits parent | All tools (except Task) | Multi-step operations |
| Custom (`.claude/agents/<name>`) | Per agent config | Per agent config (except Task) | Specialized workflows |

Example forked skill:

```yaml
---
name: deep-research
description: Research a topic thoroughly
context: fork
agent: Explore
---
```

```markdown
Research $ARGUMENTS thoroughly:

* Find relevant files using Glob and Grep.
* Read and analyze the code.
* Summarize findings with specific file references.
```

#### Rules-Based Skills

Guideline-only skills that provide rules or instructions for working on specific file types or tasks. These skills contain authoring standards, conventions, or quality criteria rather than executable workflows.

* Typically no `$ARGUMENTS` placeholder; the skill body contains instructional content.
* Frontmatter includes `user-invocable: false` since users do not invoke these directly.
* Never include `disable-model-invocation` frontmatter; the skill loads as context for other skills or agents, not as a user-invoked task.
* Referenced by other agents or skills via the `skills:` frontmatter field.

Content structure:

1. Frontmatter with `name`, `description`, `maturity`, and `user-invocable: false`.
2. Title (H1) and overview.
3. Instructional sections defining standards, conventions, or quality criteria.

Example rules-based skill:

```yaml
---
name: prompt-engineering
description: Authoring standards for prompt engineering artifacts.
maturity: stable
user-invocable: false
---
```

```markdown
# Prompt Engineering

Authoring standards for prompt engineering artifacts. Apply when creating or modifying prompt files.

## File Types

...standards and conventions...

## Quality Criteria

...checklist items...
```

#### Skill Validation

All skills include `name`, `description`, and `maturity` frontmatter. Additional validation by type:

* Script-based: Parallel bash and PowerShell scripts for cross-platform use.
* Delegation: `agent` frontmatter field, `$ARGUMENTS` for user input, and a Mode Directives section when controlling agent mode.
* Orchestrator: No `agent` field. Execution Mode Detection section for Task tool fallback. `$ARGUMENTS` for user input.
* Forked: `context: fork` in frontmatter. Explicit task instructions with `$ARGUMENTS`; guideline-only content is not suitable.
* Rules-based: `user-invocable: false` in frontmatter. No `disable-model-invocation` field. Instructional content only.

Follow the Progressive Disclosure guidelines for size limits.

### Progressive Disclosure

Structure skills for efficient context loading. Keep *SKILL.md* under 500 lines; move detailed reference to separate files. Use relative paths from the skill root, one level deep.

1. Metadata (`name`, `description`) loads at startup for all skills (~100 tokens).
2. Full *SKILL.md* body loads on activation (<5000 tokens recommended).
3. Files in `scripts/`, `references/`, or `assets/` load only when required.

## Frontmatter Requirements

### Required Fields

All prompt engineering artifacts include:

* `description:` - Brief description of the artifact's purpose.
* `maturity:` - Lifecycle stage: `experimental`, `preview`, `stable`, or `deprecated`. Required by HVE-Core convention for all artifacts; only formally required in the skill schema, other schemas default to `stable`. VS Code shows a validation warning for this field; this is expected and can be ignored.

### Optional Fields

* `name:` - Skill or agent identifier. Required for skills; use lowercase kebab-case matching the directory name.
* `applyTo:` - Glob patterns (required for instructions files).
* `tools:` - YAML array of tool names for agents. When omitted, defaults are provided. Include `Task` only when the agent dispatches subagents. Common tool names vary by platform; VS Code agents and Claude Code agents use different tool registries.
* `handoffs:` - Array of handoff objects with required `label`, `agent`, `prompt` fields and an optional `send` boolean.
* `target:` - Target environment: `vscode` or `github-copilot`. Agents only.
* `agent:` - Without `context: fork`: delegates orchestration to `.claude/agents/<agent>.md` in the main conversation context with Task tool access. With `context: fork`: selects the subagent type (`Explore`, `Plan`, `general-purpose`, or custom) for isolated execution without Task tool access. See Forked Skills for the agent value table.
* `argument-hint:` - Hint text for prompt picker display.
* `model:` - Set to `inherit` for parent model, or specify a model name.
* `context:` - Set to `fork` for isolated subagent execution. Forked skills run without conversation history and cannot dispatch subagents via Task. Omit for main conversation context with full tool access.
* `disable-model-invocation:` - Set to `true` to prevent automatic invocation. Not required for skills; include only on skills the user would not want automatically invoked, such as orchestrator skills like *task-researcher* or *prompt-builder* that execute multi-phase workflows.
* `user-invocable:` - Set to `false` to prevent the skill from appearing in the `/` command picker. Use for skills that provide rules or instructions as context for other skills and agents, rather than being invoked directly by users.
* `skills:` - YAML array of skill names loaded as context when the agent is dispatched.
* `mcp-servers:` - Array of MCP server configuration objects for Claude Code agents.

## Protocol Patterns

Protocol patterns apply to prompt and agent files. Skill files follow their own content structure.

### Step-Based Protocols

Sequential prompt instructions that execute in order. Add when the workflow benefits from explicit ordering.

* A `## Required Steps` section contains all steps.
* Format steps as `### Step N: Short Summary`.
* Steps can repeat or move to a previous step based on instructions.
* End the prompt with `---` followed by an activation instruction.

```markdown
## Required Steps

### Step 1: Gather Context

* Read the target file and identify related files in the same directory.
* Document findings in a research log.

### Step 2: Apply Changes

* Update the target file based on research findings.
* Return to Step 1 if additional context is needed.

---

Proceed with the user's request following the Required Steps.
```

### Phase-Based Protocols

Groups of instructions for iterating on user requests through conversation. Add when the workflow involves distinct interactive stages.

* A `## Required Phases` section contains all phases.
* Format phases as `### Phase N: Short Summary`.
* Announce phase transitions and summarize outcomes when completing phases.
* Steps (optional) can be added inside phases for ordered actions within a phase.

```markdown
## Required Phases

### Phase 1: Research

* Gather context from the user request and related files.
* Document findings and proceed to Phase 2 when research is complete.

### Phase 2: Build

* Apply changes based on research findings.
* Return to Phase 1 if gaps are identified during implementation.
* Proceed to Phase 3 when changes are complete.

### Phase 3: Validate

* Review changes against requirements.
* Return to Phase 2 if corrections are needed.
```

### Shared Protocol Placement

Share protocols across files by placing them in a `{{name}}.instructions.md` file. Use `#file:` only when full contents are needed; otherwise refer by path.

## Prompt Writing Style

* Guide the model on what to do, rather than command it.
* Use `*` bulleted lists for groupings and `1.` ordered lists for sequential steps.
* Use **bold** for key concepts and *italics* for new terms, file names, or technical terms.
* Each line other than headers and frontmatter is treated as a prompt instruction.
* Lists can appear without a title when the section heading provides context.

### User-Facing Responses

* Format file references and URLs as markdown links (not backticks, which prevent clickable rendering).
* Use placeholders like `{{YYYY-MM-DD}}` for dynamic path segments.
* Prefer guidance style over command style.

```markdown
<!-- Use markdown links for file references -->
2. Attach or open [2026-01-24-task-plan.instructions.md](.copilot-tracking/plans/2026-01-24-task-plan.instructions.md).

<!-- Use guidance style, not command style -->
Search the folder and collect conventions into the research document.
```

Follow *writing-style.instructions.md* for language conventions and patterns to avoid.

## Prompt Key Criteria

Successful prompts demonstrate these qualities:

* *Clarity*: Each prompt instruction can be followed without guessing intent.
* *Consistency*: Prompt instructions produce similar results with similar inputs.
* *Alignment*: Prompt instructions match the conventions or standards provided by the user.
* *Coherence*: Prompt instructions avoid conflicting with other prompt instructions in the same or related prompt files.
* *Calibration*: Prompts provide just enough instruction to complete the user requests, avoiding overt specificity without being too vague.
* *Correctness*: Prompts provide instruction on asking the user whenever unclear about progression, avoiding guessing.

## Subagent Prompt Criteria

Dispatch and specification:

* Include an explicit instruction to use the dispatch tool (`runSubagent` or `Task`).
* For Task-based dispatch: read the subagent file (`.claude/agents/<subagent>.md`), construct a prompt combining agent content with context from prior phases, and call `Task(subagent_type="general-purpose", prompt=<constructed prompt>)`.
* When the dispatch tool is unavailable, perform the subagent instructions directly (see Task Tool Fallback).
* Specify which agents or instructions files to follow, and indicate the task types the subagent completes.
* Provide a step-based protocol when multiple steps are needed.
* Include an Execution Mode Detection section with fallback instructions.

Response and execution:

* Provide structured response format or criteria for what the subagent returns.
* Leaf agents include a Structured Response section defining a markdown template with standardized fields for return values (for example: Question, Status, Output File, Key Findings, Potential Next Research, Clarifying Questions, Notes).
* When the subagent writes to files, specify which file to create or update. Subagents write findings to designated directories; the orchestrator reads those files to synthesize results.
* Allow clarifying questions to avoid guessing. Subagents may respond with clarifying questions; the orchestrator reviews and either dispatches follow-up subagents or escalates to the user.
* Prompt instructions can loop and call the subagent multiple times until the task completes.
* Multiple subagents can run in parallel when work allows.

## Prompt Quality Criteria

Every item applies to the entire file. Validation fails if any item is not satisfied.

* [ ] File structure follows the File Types guidelines for the artifact type.
* [ ] Frontmatter includes required fields and follows Frontmatter Requirements.
* [ ] Protocols follow Protocol Patterns when step-based or phase-based structure is used.
* [ ] Instructions match the Prompt Writing Style.
* [ ] Instructions follow all Prompt Key Criteria.
* [ ] Subagent prompts follow Subagent Prompt Criteria when dispatching subagents.
* [ ] External sources follow External Source Integration when referencing SDKs or APIs.
* [ ] Few-shot examples are in correctly fenced code blocks and match the instructions exactly.
* [ ] The user's request and requirements are implemented completely.

## External Source Integration

When referencing SDKs or APIs for prompt instructions:

* Prefer official repositories with recent activity.
* Extract only the smallest snippet demonstrating the pattern for few-shot examples.
* Get official documentation using tools and from the web for accurate prompt instructions and examples.
