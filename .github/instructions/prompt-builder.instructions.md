---
description: 'Authoring standards for prompt engineering artifacts including file types, protocol patterns, writing style, and quality criteria - Brought to you by microsoft/hve-core'
applyTo: '**/*.prompt.md, **/*.agent.md, **/*.instructions.md, **/SKILL.md, .claude/agents/*.md'
maturity: stable
---

# Prompt Builder Instructions

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

* Orchestrator agents dispatch subagents via Task, manage phases, and synthesize results.
* Leaf agents perform direct work using a step-based protocol and return structured responses. Leaf agents do not dispatch further Tasks.

Frontmatter:

* Declares `name`, `description`, and optionally `tools` (comma-separated) and `model` (`inherit` for parent model).
* Include `Task` in tools only when the agent dispatches subagents. Leaf subagents omit `Task`.

Recommended body sections: Core Principles, Tool Usage, Required Steps or Phases, Structured Response (for leaf agents), Operational Constraints, File Locations.

Execution contexts:

* Standalone (via skill without `context: fork`): Runs in the main session, can dispatch Task subagents (one level deep).
* Forked (via skill with `context: fork`): Runs as an isolated subagent without conversation history. Cannot dispatch Tasks. Results are summarized and returned to the invoking context.
* Dispatched (via Task call): Runs as a Task, cannot dispatch further Tasks; falls back to direct tool usage.

Agents designed for Task dispatch include an Execution Mode Detection section with fallback behavior for when the Task tool is unavailable.

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
├── SKILL.md                    # Main skill definition (required)
├── scripts/                    # Executable scripts (optional)
│   ├── <action>.sh             # Bash script for macOS/Linux
│   └── <action>.ps1            # PowerShell script for Windows
├── references/                 # Additional documentation (optional)
│   └── REFERENCE.md            # Detailed technical reference
├── assets/                     # Static resources (optional)
│   └── templates/              # Document or configuration templates
└── examples/
    └── README.md               # Usage examples (recommended)
```

The `scripts/` directory contains self-contained executable code with parallel bash and PowerShell implementations for cross-platform use. The `references/` directory holds focused technical reference files loaded on demand. The `assets/` directory stores templates, images, and data files.

Content structure (sections in order):

1. Title (H1), Overview, Prerequisites, Quick Start.
2. Parameters Reference table, Script Reference with bash and PowerShell examples.
3. Troubleshooting, Attribution Footer.

Validation:

* Include `name`, `description`, and `maturity` frontmatter.
* Provide parallel bash and PowerShell scripts for cross-platform use.

#### Agent-Based Skills

*Location*: `.claude/skills/<skill-name>/SKILL.md`

Three agent-based skill patterns exist:

* Delegation Skills delegate to a named agent via `agent:` frontmatter. The agent runs in the main conversation context with Task tool access.
* Orchestrator Skills contain full orchestration logic in the skill body and dispatch subagents directly via the Task tool.
* Forked Skills use `context: fork` to run as isolated subagents without Task tool access.

##### Delegation Skills

Lightweight entry points that delegate to agents via `agent:` frontmatter. The skill body passes `$ARGUMENTS` with mode-specific directives controlling which phases the agent executes. Multiple skills can share a single agent by providing different mode directives.

* Frontmatter delegates to an agent via `agent:` which loads `.claude/agents/<agent>.md`.
* `$ARGUMENTS` in the body receives user input at invocation.
* No bundled scripts; agents use tools directly.
* When the skill does not orchestrate subagents, set `context: fork` for isolated execution.
* Set `disable-model-invocation: true` for skills requiring explicit user invocation only.

Content structure:

1. Frontmatter with `name`, `description`, `maturity`, and optional `context`, `agent`, `argument-hint`, `disable-model-invocation`.
2. Title (H1) matching the skill purpose.
3. Activation sentence incorporating `$ARGUMENTS`.
4. Mode Directives section (H2) specifying phase scope and behavior.

Frontmatter fields:

| Field                      | Required | Description                                                                                    |
| -------------------------- | -------- | ---------------------------------------------------------------------------------------------- |
| `name`                     | Yes      | Skill identifier in lowercase kebab-case matching the directory name.                          |
| `description`              | Yes      | Brief description shown in the skill picker and agent registry.                                |
| `maturity`                 | Yes      | Lifecycle stage: `experimental`, `preview`, `stable`, or `deprecated`.                         |
| `context`                  | No       | Set to `fork` for isolated subagent execution without Task tool access. Omit for main conversation context. |
| `agent`                    | No       | Without `context: fork`: delegates to `.claude/agents/<agent>.md`. With `context: fork`: selects subagent type (`Explore`, `Plan`, `general-purpose`, or custom). |
| `argument-hint`            | No       | Hint text shown in the skill picker (for example, `"file=... [requirements=...]"`).            |
| `disable-model-invocation` | No       | Set to `true` to prevent the model from invoking this skill automatically.                     |

##### Mode Directives

The Mode Directives section controls which phases the delegated agent executes and what behavioral emphasis to apply.

Structure:

* Opening line naming the mode and phase scope.
* Descriptive label (for example, "Build mode behavior:").
* Bulleted list of mode-specific behavioral instructions.
* Optional closing instruction for discovering instructions files or proceeding with phases.

Phase scope patterns:

* Full workflow: "following the full 5-phase workflow: Baseline, Research, Build, Validate, Iterate".
* Limited scope: "Execute Phase 1 only" with instructions to skip remaining phases.

##### Multi-Skill Agent Delegation

Multiple skills can delegate to the same agent with different mode directives. The agent reads directives from the invoking skill body. The `argument-hint` can vary per skill (for example, a read-only skill omits `[requirements=...]`).

| Skill          | Mode     | Phase Scope   | argument-hint                    |
| -------------- | -------- | ------------- | -------------------------------- |
| prompt-build   | build    | Full workflow  | `"file=... [requirements=...]"`  |
| prompt-refactor | refactor | Full workflow | `"file=... [requirements=...]"` |
| prompt-analyze | analyze  | Phase 1 only  | `"file=..."`                     |

Example skill with frontmatter and mode directives (build mode, full workflow):

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

Build or improve the following prompt engineering artifact:

$ARGUMENTS

## Mode Directives

Operate in build mode following the full 5-phase workflow: Baseline, Research, Build, Validate, Iterate.

Build mode behavior:

* Create new artifacts or improve existing ones through all five phases.
* When no explicit requirements are provided and an existing file is referenced, refactor and improve all instructions in that file.
* When a non-prompt file is referenced, search for related prompt artifacts and update them, or build a new one.

Discover applicable `.github/instructions/*.instructions.md` files based on file types and technologies involved, and proceed with the Required Phases.
```

For limited-scope modes (such as analyze), the opening line restricts phase scope ("Execute Phase 1 only") and behavioral instructions skip remaining phases.

Validation:

* Include `name`, `description`, `maturity`, and `agent` frontmatter.
* Include `$ARGUMENTS` when the skill accepts user input.
* Include a Mode Directives section when the skill controls agent mode selection.
* Keep the body concise; follow the Progressive Disclosure guidelines for size limits.

##### Orchestrator Skills

Skills that contain full orchestration logic in their body without `agent:` frontmatter. The skill dispatches subagents directly via the Task tool.

* No `agent:` frontmatter; the skill body serves as the orchestrator.
* Dispatches `.claude/agents/<subagent>.md` via the Task tool directly from the skill body.
* Single-purpose: one skill dispatches one or more subagent instances for a specific workflow.
* Self-contained: all orchestration logic lives in one file.

When to use instead of delegation skills:

* The workflow has a single purpose that does not need multiple modes.
* All orchestration logic fits naturally in the skill body.
* Agent reuse across multiple skills is not needed.

Content structure:

1. Frontmatter with `name`, `description`, `maturity`, and optionally `disable-model-invocation`, `argument-hint`.
2. Title (H1) matching the skill purpose.
3. Core Principles, Subagent Delegation, Execution Mode Detection, File Locations.
4. Required Phases with phase-based protocol.
5. Output Templates and Response Format.

Include an Execution Mode Detection section with fallback behavior for when the Task tool is unavailable. When the Task tool is available, dispatch subagent instances. When it is unavailable, read the subagent file and perform all work directly.

Validation:

* Include `name`, `description`, `maturity` frontmatter. No `agent:` field.
* Include `$ARGUMENTS` when the skill accepts user input.
* Include an Execution Mode Detection section for Task tool fallback.
* Keep the body concise; follow the Progressive Disclosure guidelines for size limits.

##### Forked Skills

Skills with `context: fork` that run as isolated subagents. The skill content becomes the subagent's task prompt. The subagent does not have access to conversation history. Results are summarized and returned to the main conversation.

* Forked skills cannot dispatch subagents via the Task tool. This is an architectural constraint; subagents cannot spawn other subagents.
* The `agent` field selects the subagent configuration rather than delegating to an agent file.
* Use `disable-model-invocation: true` for skills that should not be auto-triggered.

When to use `context: fork`:

* Self-contained leaf tasks that do not need conversation history or subagent delegation.
* Read-only research or codebase exploration.
* Deployment or build procedures that follow a fixed procedure.
* Code review or summarization tasks operating on explicit inputs.

Avoid `context: fork` for:

* Orchestrator skills that dispatch subagents via the Task tool.
* Skills that need access to conversation history for context-dependent decisions.
* Guideline-only skills without explicit task instructions.

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

Validation:

* Include `name`, `description`, `maturity` frontmatter.
* Set `context: fork` in frontmatter.
* Include explicit task instructions with `$ARGUMENTS`; guideline-only content is not suitable for forked execution.

### Progressive Disclosure

Structure skills for efficient context loading. Keep *SKILL.md* under 500 lines; move detailed reference to separate files. Use relative paths from the skill root, one level deep.

1. Metadata (`name`, `description`) loads at startup for all skills (~100 tokens).
2. Full *SKILL.md* body loads on activation (<5000 tokens recommended).
3. Files in `scripts/`, `references/`, or `assets/` load only when required.

## Frontmatter Requirements

### Required Fields

All prompt engineering artifacts include:

* `description:` - Brief description of the artifact's purpose.
* `maturity:` - Lifecycle stage: `experimental`, `preview`, `stable`, or `deprecated`.

VS Code shows a validation warning for `maturity:` as it is not in VS Code's schema. This is expected; the field is required by the HVE-Core codebase. Ignore this warning.

### Optional Fields

* `name:` - Skill or agent identifier. Required for skills; use lowercase kebab-case matching the directory name.
* `applyTo:` - Glob patterns (required for instructions files).
* `tools:` - Comma-separated tool list for agents. When omitted, defaults are provided. Include `Task` only when the agent dispatches subagents. Leaf subagents omit `Task`.
* `handoffs:` - Agent handoff declarations using `agent:` for the target.
* `agent:` - Without `context: fork`: delegates orchestration to `.claude/agents/<agent>.md` in the main conversation context with Task tool access. With `context: fork`: selects the subagent type (`Explore`, `Plan`, `general-purpose`, or custom) for isolated execution without Task tool access.
* `argument-hint:` - Hint text for prompt picker display.
* `model:` - Set to `inherit` for parent model, or specify a model name.
* `context:` - Set to `fork` for isolated subagent execution. Forked skills cannot dispatch subagents via the Task tool. Omit for main conversation context with full tool access.
* `disable-model-invocation:` - Set to `true` to prevent automatic invocation.
* `mcpServers:` - MCP server dependencies for Claude Code agents. Comma-separated server names (for example, `microsoft-docs, context7`).

Common tools: `Task`, `TaskOutput`, `TaskStop`, `Read`, `Write`, `Edit`, `Glob`, `Grep`, `Bash`, `WebFetch`, `TodoWrite`, `AskUserQuestion`, `Skill`.

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

### Patterns to Avoid

* ALL CAPS directives and emphasis markers.
* Second-person commands with modal verbs ("You will", "You must").
* Condition-heavy and overly branching instructions.
* List items with bolded title lines (for example, `* **Line item** - description`).
* Forcing lists to three or more items when fewer suffice.
* XML-style groupings of prompt instructions.

## Prompt Key Criteria

Successful prompts demonstrate these qualities:

* Clarity: Each prompt instruction can be followed without guessing intent.
* Consistency: Prompt instructions produce similar results with similar inputs.
* Alignment: Prompt instructions match the conventions or standards provided by the user.
* Coherence: Prompt instructions avoid conflicting with other prompt instructions in the same or related prompt files.
* Calibration: Prompts provide just enough instruction to complete the user requests, avoiding overt specificity without being too vague.
* Correctness: Prompts provide instruction on asking the user whenever unclear about progression, avoiding guessing.

## Subagent Prompt Criteria

Dispatch and specification:

* Include an explicit instruction to use the dispatch tool (`runSubagent` or `Task`).
* For Task-based dispatch: read the subagent file (`.claude/agents/<subagent>.md`), construct a prompt combining agent content with context from prior phases, and call `Task(subagent_type="general-purpose", prompt=<constructed prompt>)`.
* When the dispatch tool is unavailable, perform the subagent instructions directly.
* Task nesting is limited to one level deep. Design agents to fall back to direct tool usage when dispatched.
* Specify which agents or instructions files to follow, and indicate the task types the subagent completes.
* Provide a step-based protocol when multiple steps are needed.
* Skills and agents that dispatch subagents include an Execution Mode Detection section with fallback instructions for when the Task tool is unavailable.

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
