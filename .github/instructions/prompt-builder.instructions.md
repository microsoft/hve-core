---
description: 'Authoring standards for prompt engineering artifacts including file types, protocol patterns, writing style, and quality criteria - Brought to you by microsoft/hve-core'
applyTo: '**/*.prompt.md, **/*.agent.md, **/*.instructions.md, **/SKILL.md'
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
* Reference tools in body text using `#tool:<tool-name>` syntax (for example, `#tool:search`, `#tool:web`). For MCP tools, use `#tool:<server>/<tool>` (for example, `#tool:github/add_issue_comment`). Specific tools within a tool set use `#tool:<set>/<tool>` (for example, `#tool:search/listDirectory`, `#tool:web/githubRepo`). Backticks should not be used around #tool: references in prompt and agent files.
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

Agent files support conversational workflows (multi-turn interactions) and autonomous workflows (task execution with minimal user interaction). Frontmatter requires `name` and defines available `tools`, `agents`, and optional `handoffs`.

#### Conversational Agents

* Users guide the conversation through different stages; state persists via planning files when needed.
* Add phases when the workflow involves distinct interactive stages. Follow the Phase-Based Protocols section.

#### Autonomous Agents

* Execute autonomously after receiving initial instructions and report results.
* May dispatch subagents for parallelizable work.

### Instructions Files

*Extension*: `.instructions.md`

Auto-applied guidance based on file patterns. Define conventions, standards, and patterns for matching files.

* Frontmatter includes `applyTo` with glob patterns (for example, `**/*.py`).
* Wrap examples in fenced code blocks.

### Skill Files

*File Name*: `SKILL.md`

Agent Skills are folders of instructions, scripts, and resources that Copilot loads on demand to perform specialized tasks. Skills follow an open standard ([agentskills.io](https://agentskills.io)) and work across VS Code, Copilot CLI, and Copilot coding agent.

*Location*: `.github/skills/<skill-name>/SKILL.md`

Directory structure:

```text
.github/skills/<skill-name>/
├── SKILL.md          # Main skill definition (required)
├── scripts/          # Bash (.sh) and PowerShell (.ps1) scripts
├── references/       # Technical reference files loaded on demand
├── assets/           # Templates, images, and data files
└── examples/         # Usage examples (recommended)
```

Frontmatter requires `name` (lowercase kebab-case, max 64 characters) and `description` (capabilities and when to use, max 1024 characters). HVE-Core convention also includes `maturity`.

Body content structure:

1. Title (H1), overview of what the skill helps accomplish, and when to use it.
2. Step-by-step procedures and guidelines.
3. References to included scripts or resources using relative paths.

Reference files within the skill directory using relative paths (for example, `[test script](./test-template.js)`).

#### Skill Validation

All skills include `name` and `description` frontmatter (`maturity` by HVE-Core convention). Additional validation:

* Scripts provide parallel bash and PowerShell implementations for cross-platform use.
* Description states both what the skill does and when to use it, enabling Copilot to decide when to load it.

Follow the Progressive Disclosure guidelines for size limits.

### Progressive Disclosure

Structure skills for efficient context loading. Keep *SKILL.md* under 500 lines; move detailed reference to separate files. Use relative paths from the skill root, one level deep.

1. Metadata (`name`, `description`) loads at startup for all skills (~100 tokens). Copilot uses this to decide relevance.
2. Full *SKILL.md* body loads on activation (<5000 tokens recommended).
3. Files in `scripts/`, `references/`, or `assets/` load only when referenced.

## Frontmatter Requirements

### Required Fields

All prompt engineering artifacts include:

* `description:` - Brief description of the artifact's purpose.
* `maturity:` - Lifecycle stage: `experimental`, `preview`, `stable`, or `deprecated`. Required by HVE-Core convention for all artifacts; only formally required in the skill schema, other schemas default to `stable`. VS Code shows a validation warning for this field; this is expected and can be ignored.

### Optional Fields

* `name:` - Identifier for skill and agent files. Required for both; use lowercase kebab-case (matching the directory name for skills or the file name stem for agents).
* `applyTo:` - Glob patterns (required for instructions files).
* `tools:` - YAML array of tool names for agents. When omitted, defaults are provided. Not required when `agents:` is specified. Include `agent` only when the agent dispatches subagents without using the `agents:` property. Use human-readable tool names with `#tool:` syntax (for example, `search`, `fetch`, `agent`). For MCP tools, use the `<server>/<tool>` format (for example, `github/add_issue_comment`). To include all tools from an MCP server, use `<server>/*`.
* `handoffs:` - Array of handoff objects with required `label`, `agent`, `prompt` fields and an optional `send` boolean.
* `target:` - Target environment: `vscode` or `github-copilot`. Agents only.
* `agents:` - YAML array of agent names available as subagents in this agent. Use `*` to allow all agents, or `[]` to prevent subagent use. When specified, a separate `tools:` declaration is not required.
* `argument-hint:` - Hint text for prompt picker display.
* `model:` - Set to `inherit` for parent model, or specify a model name. Supports a single model name (string) or a prioritized list of models (array) where the system tries each in order.
* `disable-model-invocation:` - Set to `true` to prevent the agent from being invoked as a subagent by other agents. Use when the agent should only be triggered explicitly by users.
* `user-invokable:` - Set to `false` to hide the agent from the agents dropdown in chat. Agents with `user-invokable: false` remain accessible as subagents. Use for subagent-only agents.
* `mcp-servers:` - Array of MCP server configuration objects for agents targeting `github-copilot`.

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

* Reference subagents by name (for example, "Use the research agent to gather context") rather than referencing the dispatch tool directly.
* When #tool:agent is unavailable, perform the subagent instructions directly.
* Specify which agents or instructions files the subagent follows, and indicate the task types the subagent completes.
* Restrict available subagents using the `agents:` frontmatter property when the orchestrator should only use specific subagents.
* Provide a step-based protocol when multiple steps are needed.

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
