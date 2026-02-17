---
description: "Authoring standards for prompt engineering artifacts including prompts, agents, instructions, and skills"
applyTo: '**/*.prompt.md, **/*.agent.md, **/*.instructions.md, **/SKILL.md'
---

# Prompt Builder Instructions

Authoring standards for prompt engineering artifacts govern how prompt, agent, instructions, and skill files are created and maintained. Apply these standards when creating or modifying any of these file types.

## File Types

This section defines file type selection criteria, authoring patterns, and validation checks. Keep prompt and agent files focused. When an artifact exceeds approximately 5000 tokens of instruction content, consider extracting reusable guidance into a shared instructions file or delegating to subagents.

### Prompt Files

*Extension*: `.prompt.md`

Purpose: Single-session workflows where users invoke a prompt and Copilot executes to completion.

Characteristics:

* Single invocation completes the workflow.
* Frontmatter includes `agent: agent-name` to delegate to an agent. Quote the value only when the agent name contains spaces.
* Activation lines are optional and apply only to prompt files; agent files and instructions files do not include them. Include a `---` followed by an activation instruction when the workflow start point is not obvious, such as prompts using a generic agent, prompts without an `agent:` field, or prompts where the protocol entry point needs clarification. Omit the activation line when delegating to a custom agent whose phases or steps already define the workflow.
* Use `#file:` only when the prompt must pull in the full contents of another file.
* When the full contents are not required, refer to the file by path or to the relevant section.
* Example: `#file:path/to/file.md` pulls in the full file contents at that location.
* Input variables are supported; see the Input Variables section for syntax.

*Naming*: Use lowercase kebab-case matching the prompt's purpose (for example, `prompt-refactor.prompt.md`, `git-commit-message.prompt.md`).

Consider adding sequential steps when the prompt involves multiple distinct actions that benefit from ordered execution. Simple prompts that accomplish a single task do not need protocol structure.

#### Agent Delegation

Prompts that set `agent:` to a custom agent inherit the agent's protocol, including its phases, steps, and subagent orchestration.
Avoid adding Required Phases, Required Steps, or Required Protocol sections that duplicate or conflict with the parent agent's protocol.
Instead, reference specific phases or sections from the parent agent when the prompt customizes or limits the agent's behavior (for example, "Follow Phase 1 only" or "Skip Phase 2").
Use a Required Protocol section to add execution meta-rules not defined by the parent agent, such as iteration constraints, scope boundaries, or phase sequencing.
Reserve Required Steps for prompt files that define their own workflow independent of the delegated agent's protocol.

Prompts extending agent behavior focus on what differs from the default: scoped inputs, additional requirements, or workflow restrictions.

```markdown
---
description: "Refactors prompt files through iterative improvement"
agent: prompt-builder
argument-hint: "[promptFiles=...] [requirements=...]"
---

# Prompt Refactor

## Inputs

* ${input:promptFiles}: (Optional) Existing target prompt file(s). Defaults to the current open file.
* ${input:requirements}: (Optional) Additional requirements or objectives.

## Requirements

1. Refactor promptFiles with a focus on cleaning up, consolidating, and removing confusing or duplicate instructions.
2. Consider any additional requirements provided by the user.
```

#### Requirements Sections

Requirements sections are optional. Use them to extend user-provided requirements, guide the agent toward specific objectives, or narrow the agent's default scope. Requirements sections provide context the agent uses alongside the user's conversation rather than substituting for the agent's own protocol.

#### Input Variables

Input variables allow prompts to accept user-provided values or use defaults. The recommended pattern is:

`* ${input:varName:defaultValue}: (Optional/Required) Description text.`

* `${input:topic}` is a required input, inferred from user prompt, attached files, or conversation.
* `${input:chat:true}` is an optional input with default value `true`.
* `${input:baseBranch:origin/main}` is an optional input defaulting to `origin/main`.

An Inputs section documents available variables for user awareness. Prompts without input variables do not need an Inputs section.

```markdown
## Inputs

* ${input:topic}: (Required) Primary topic or focus area.
* ${input:chat:true}: (Optional, defaults to true) Include conversation context.
```

#### Argument Hints

The `argument-hint` frontmatter field shows users expected inputs in the VS Code prompt picker:

* Keep hints brief with required arguments first, then optional arguments.
* Use `[]` for positional arguments and `key=value` for named parameters.
* Use `{option1|option2}` for enumerated choices and `...` for free-form text.

```yaml
argument-hint: "topic=... [chat={true|false}]"
```

Typical section order for prompt files: H1 title, Inputs, Requirements or Protocol, activation line (if needed).

Validation guidelines:

* When steps are used, follow the Step-Based Protocols section for structure.
* Document input variables in an Inputs section when present.

### Agent Files

*Extension*: `.agent.md`

Purpose: Agent files support both conversational workflows (multi-turn interactions with a specialized assistant) and autonomous workflows (task execution with minimal user interaction).

*Naming*: Use lowercase kebab-case matching the agent's role (for example, `task-planner.agent.md`, `prompt-builder.agent.md`). The `name:` frontmatter field matches the filename without extension.

Frontmatter defines available `tools` and optional `handoffs` to other agents.

#### Conversational Agents

Conversational agents guide users through multi-turn interactions:

* Users guide the conversation through different activities or stages.
* State persists across conversation turns via planning files when needed.
* Typically represents a domain expert or specialized assistant role.

Consider adding phases when the workflow involves distinct stages that users move between interactively. Simple conversational assistants that respond to varied requests do not need protocol structure. Follow the Phase-Based Protocols section for phase structure guidelines.

#### Autonomous Agents

Autonomous agents execute tasks with minimal user interaction:

* Executes autonomously after receiving initial instructions.
* Typically completes a bounded task and reports results.
* May run subagents for parallelizable work.

Use autonomous agents when the workflow benefits from task execution rather than conversational back-and-forth.

No frontmatter field distinguishes conversational from autonomous agents. The distinction is conveyed through protocol structure: conversational agents use phase-based protocols for multi-turn interaction, while autonomous agents use step-based protocols for bounded task execution.

#### Subagents

Subagents are agent files that execute specialized tasks on behalf of parent agents.

Characteristics:

* Optionally include `user-invocable: false` frontmatter to prevent direct user invocation.
* Frontmatter includes `tools:` listing the tools available to the subagent.
* Typically live under `.github/agents/subagents/` to separate them from user-facing agents.
* Parent agents declare subagent dependencies in their `agents:` frontmatter.
* Referenced using glob paths like `.github/agents/**/name.agent.md` so resolution works regardless of whether the subagent is at the root or in the `subagents/` folder.
* Cannot run their own subagents; only the parent agent orchestrates subagent calls.

Create subagents when a parent agent needs to parallelize work or delegate a specialized, repeatable task. When the workflow is linear and does not benefit from isolated execution, keep the logic within the parent agent or use a prompt file.

Subagents follow the same authoring standards as other agent files. Include a Response Format section defining the structured output the subagent returns to its parent.

#### Subagent Structural Template

All subagents in the codebase follow a canonical section pattern. Use this template when creating new subagents. Include a Required Protocol section when the subagent has execution constraints, repetition rules, or side-effect boundaries; omit it for simpler subagents where the Required Steps section is self-contained. For instance, a research-only subagent that reads files and writes findings needs no Required Protocol because its steps are self-contained.

```markdown
# Agent Name                    <!-- H1 matching the agent name -->

Restate purpose from frontmatter description.

## Purpose                      <!-- Bulleted objectives -->

* First objective.
* Second objective.

## Inputs                       <!-- Required and optional inputs -->

* Required input with description.
* (Optional) Optional input with description.

## Output Artifact Name         <!-- Named per context: Execution Log, etc. -->

Create and update the artifact progressively documenting:

* Findings and decisions.
* Evidence and references.

## Required Steps               <!-- Pre-requisite + numbered steps -->

### Pre-requisite: Setup

1. Create the output artifact with placeholders if it does not already exist.
2. Read and follow instructions from referenced files in full.
3. Load context from provided inputs.

### Step 1: Core Work

1. Execute the primary task.
2. Update the output artifact progressively.

## Required Protocol            <!-- Omit if Required Steps are self-contained -->

1. Follow all Required Steps.
2. Repeat as needed to ensure completeness.
3. Finalize the output artifact.

## Response Format              <!-- Structured return to parent agent -->

Return structured findings including:

* Path to the output artifact.
* Status of the work.
* Key details and recommendations.
* Clarifying questions.
```

### Instructions Files

*Extension*: `.instructions.md`

Purpose: Auto-applied guidance based on file patterns. Instructions define conventions, standards, and patterns that Copilot follows when working with matching files.

Characteristics:

* Frontmatter includes `applyTo` with glob patterns (for example, `**/*.py`).
* Applied automatically when editing files matching the pattern.
* Define coding standards, naming conventions, and best practices.

*Naming*: Use lowercase kebab-case matching the domain or technology (for example, `commit-message.instructions.md`, `csharp.instructions.md`). Instructions files may live in subdirectories organized by topic (for example, `csharp/csharp.instructions.md`).

#### Recommended Sections

Instructions files typically include these sections based on codebase patterns:

* H1 Title reflecting the domain or technology.
* Scope or applicability statement.
* Core conventions and standards as bulleted rules.
* Code examples in fenced blocks demonstrating correct patterns.
* Patterns to avoid, when relevant.
* Validation guidance or tooling references.

Validation guidelines:

* Include `applyTo` frontmatter with valid glob patterns.
* Content defines standards and conventions.
* Wrap examples in fenced code blocks.

### Skill Files

*File Name*: `SKILL.md`

*Location*: `.github/skills/<skill-name>/SKILL.md`

Purpose: Self-contained packages that bundle documentation with executable scripts for specific tasks. Skills differ from prompts and agents by providing concrete utilities rather than conversational guidance.

Characteristics:

* Bundled with bash and PowerShell scripts in the same directory.
* Provides step-by-step instructions for task execution.
* Includes prerequisites, parameters, and troubleshooting sections.

Skill directory structure:

```text
.github/skills/<skill-name>/
├── SKILL.md                    # Main skill definition (required)
├── scripts/                    # Self-contained executables (optional)
│   ├── <action>.sh             # Bash script for macOS/Linux
│   └── <action>.ps1            # PowerShell for Windows; provide both for cross-platform
├── references/                 # Agents load on demand; keep files focused (optional)
│   └── REFERENCE.md            # Detailed technical reference
├── assets/                     # Templates, images, data files (optional)
│   └── templates/              # Document or configuration templates
└── examples/
    └── README.md               # Usage examples (recommended)
```

### Skill Content Structure

Skill files include these sections in order:

1. Title (H1): Clear heading matching skill purpose.
2. Overview: Brief explanation of what the skill does.
3. Prerequisites: Platform-specific installation requirements.
4. Quick Start: Basic usage with default settings.
5. Parameters Reference: Table documenting all options with defaults.
6. Script Reference: Usage examples for bash and PowerShell.
7. Troubleshooting: Common issues and solutions.
8. Attribution: Attribution in `description:` frontmatter and standard footer.

### Progressive Disclosure

Structure skills for efficient context usage:

1. Metadata (~100 tokens): The `name` and `description` frontmatter fields load at startup for all skills.
2. Instructions (<5000 tokens recommended): The full *SKILL.md* body loads when the skill activates.
3. Resources (as needed): Files in `scripts/`, `references/`, or `assets/` load only when required.

Keep the main *SKILL.md* focused. Move detailed reference material to separate files.

### File References

When referencing other files in the skill, use relative paths from the skill root:

```markdown
See [the reference guide](references/REFERENCE.md) for details.

Run the extraction script:
scripts/extract.py
```

Keep file references one level deep from *SKILL.md*. Avoid deeply nested reference chains.

Validation guidelines:

* Frontmatter follows the Frontmatter Requirements section, including `name` and `description` fields.
* Provide parallel script implementations for bash and PowerShell when targeting cross-platform use.
* Document prerequisites for each supported platform.
* Keep *SKILL.md* focused; move detailed reference material to `references/`.
* Additional sections can be added between Parameters Reference and Troubleshooting as needed.

#### Attribution

Artifacts include attribution as a suffix in the `description:` frontmatter field using the format `- Brought to you by organization/repository-name`:

```yaml
description: 'Tests prompt files in a sandbox environment - Brought to you by microsoft/hve-core'
```

Skill files also include a standard attribution footer as the last line of body content:

```markdown
> Brought to you by organization/repository-name
```

## Frontmatter Requirements

This section defines frontmatter field requirements for prompt engineering artifacts.

Maturity is tracked in `collections/*.collection.yml` item metadata, not in frontmatter. Do not include a `maturity` field in artifact frontmatter. Set maturity on the artifact's matching collection item entry; when omitted, maturity defaults to `stable`.

### Required Fields

All prompt engineering artifacts include this frontmatter field:

* `description:` - Brief description of the artifact's purpose. Required for all file types. Write descriptions as concise sentence fragments or single sentences. Keep under 120 characters when possible. Descriptions appear in tool pickers and search results, so front-load the most important information.

### Conditionally Required Fields

These fields are required depending on the file type:

* `name:` - Artifact identifier. Required for agent files and skill files. For agents, use lowercase kebab-case matching the filename without extension. For skills, match the skill directory name using lowercase kebab-case.
* `applyTo:` - Glob patterns defining which files trigger the instructions. Required for instructions files only.
* `agents:` - List of subagent dependencies. Required for parent agents that run subagents. Each entry is the subagent name without path or extension (for example, `codebase-researcher`).

### Optional Fields

Optional fields available by file type:

* `tools:` - Tool restrictions for agents and subagents. When omitted, all tools are accessible. When specified, list only tools available in the current VS Code context.
* `handoffs:` - Agent handoff declarations. Each entry includes `label` (display text, supports emoji), `agent` (target agent name), and optionally `prompt` (slash command to invoke) and `send` (boolean, auto-send the prompt when `true`).
* `user-invocable:` - Boolean. Set to `false` to hide the agent from the user and prevent direct invocation. Defaults to `true` when omitted. Use for subagents that should not appear in the agent picker.
* `disable-model-invocation:` - Boolean. Set to `true` to prevent Copilot from automatically invoking the agent. Use for agents that run subagents, agents that cause side effects (git operations, backlog management, deployments), or agents that should only run when explicitly requested. Defaults to `false` when omitted.
* `agent:` - Agent delegation for prompt files.
* `argument-hint:` - Hint text for prompt picker display.
* `model:` - Model specification. Accepts any valid model identifier string (for example, `gpt-4o`, `claude-sonnet-4`). When omitted, the default model is used.

### Frontmatter Examples

Agent with tools and subagents:

```yaml
---
name: prompt-builder
description: 'Orchestrates prompt engineering workflows'
disable-model-invocation: true
agents:
  - prompt-tester
  - prompt-evaluator
  - researcher-subagent
handoffs:
  - label: "💡 Update/Create"
    agent: prompt-builder
    prompt: "/prompt-build "
    send: false
---
```

Subagent with tool restrictions:

```yaml
---
name: prompt-tester
description: 'Tests prompt files in a sandbox environment'
user-invocable: false
tools:
  - read_file
  - create_file
  - run_in_terminal
---
```

Prompt file with agent delegation:

```yaml
---
description: 'Builds and validates prompt engineering artifacts'
agent: prompt-builder
argument-hint: "files=... [promptFiles=...] [requirements=...]"
---
```

Instructions file:

```yaml
---
description: "Required instructions for creating commit messages"
applyTo: '**'
---
```

## Protocol Patterns

Protocol patterns apply to prompt and agent files. Skill files follow their own content structure defined in the Skill Content Structure section rather than step-based or phase-based protocols.

Give each step or phase an accurate summary that indicates the grouping of prompt instructions it contains.

### Step-Based Protocols

Step-based protocols define groupings of sequential prompt instructions that execute in order. Add this structure when the workflow benefits from explicit ordering of distinct actions.

Structure guidelines:

* A `## Required Steps` section contains all steps and provides an overview of how the protocol flows.
* Protocol steps contain groupings of prompt instructions that execute as a whole group, in order.

Step conventions:

* Format steps as `### Step N: Short Summary` within the Required Steps section.
* Include prompt instructions to follow while implementing the step.
* Steps can repeat or move to a previous step based on instructions.

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

Phase-based protocols define groups of instructions for iterating on user requests through conversation. Add this structure when the workflow involves distinct stages that users move between interactively.

Structure guidelines:

* A `## Required Phases` section contains all phases and provides an overview of how the protocol flows.
* Protocol phases contain groupings of prompt instructions that execute as a whole group.
* Protocol steps (optional) can be added inside phases when a phase has a series of ordered actions.
* Conversation guidelines include instructions on interacting with the user through each of the phases.

Phase conventions:

* Format phases as `### Phase N: Short Summary` within the Required Phases section.
* Announce phase transitions and summarize outcomes when completing phases.
* Include instructions on when to complete the phase and move onto the next phase.
* Completing the phase can be signaled from the user or from some ending condition.

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

When a phase contains multiple ordered actions, nest steps inside the phase using a lower heading level:

```markdown
## Required Phases

### Phase 1: Execution and Evaluation

Orchestrates executing and evaluating prompt files iteratively.

#### Step 1: Execute Prompt Files

* Run the tester subagent with target prompt file paths.
* Collect execution findings from the sandbox.

#### Step 2: Evaluate Results

* Run the evaluator subagent with execution log paths.
* Review severity-graded findings.

#### Step 3: Interpret and Decide

1. Read the evaluation log to understand current state.
2. Move to Phase 2 if modifications are needed, or finalize if complete.
```

### Shared Protocol Placement

Protocols can be shared across multiple files by placing the protocol into a `{{name}}.instructions.md` file. Follow the `#file:` usage guidance from the Prompt Files section when referencing shared protocol files.

### Required Protocol

A Required Protocol section defines meta-rules governing how steps or phases execute. This section is distinct from Required Steps (the actual work instructions) and Required Phases (the conversational stages).

Required Protocol typically specifies:

* Execution ordering and constraints (for example, all side effects stay within a sandbox folder).
* Repetition rules (for example, repeat Required Steps until the output is complete).
* Finalization actions (for example, clean up and interpret the output artifact).
* Side-effect boundaries (for example, read-only operations outside the sandbox).

Place the Required Protocol section after Required Steps or Required Phases:

```markdown
## Required Protocol

1. All execution and side effects stay within the sandbox folder.
2. Follow all Required Steps against the target files.
3. Repeat the Required Steps as needed to ensure completeness.
4. Finalize the output artifact and interpret it for the response.
```

### Intermediate Output Files

Subagents and autonomous agents often define a progressive output artifact that captures work in progress. Specify intermediate output files with three elements:

* Where the file lives: A path pattern using placeholders (for example, `.copilot-tracking/sandbox/{{YYYY-MM-DD}}-{{topic}}-{{run}}/execution-log.md`).
* What gets documented: A bulleted list of content types the file captures (decisions, findings, evidence, questions).
* When it updates: State that the file is updated progressively as work proceeds, not written once at the end.

```markdown
## Execution Log

Create and update an *execution-log.md* file in the sandbox folder, progressively documenting:

* Each grouping of instructions followed and the reasoning behind actions taken.
* Decisions made when facing ambiguity and the rationale for each.
* Files created or modified within the sandbox and why.
* Observations about prompt clarity and completeness.
```

### Sandbox Environment

Agents that manage testing or validation use sandbox folders to isolate side effects:

* Sandbox root is `.copilot-tracking/sandbox/`.
* Naming convention follows `{{YYYY-MM-DD}}-{{topic}}-{{run-number}}` (for example, `2026-01-13-git-commit-001`).
* Test and execution agents create and edit files only within the assigned sandbox folder.
* Sandbox structure mirrors the target folder structure for realistic testing.
* Sandbox files persist for review and are cleaned up after validation completes.
* Cross-run continuity: Subagents can read and reference files from prior sandbox runs when iterating. Evaluation agents compare outputs across runs when validating incremental changes.

## Prompt Writing Style

Prompt instructions have the following characteristics:

* Written with proper grammar and formatting.
* Use protocol-based structure with descriptive language when phases or ordered steps are needed.
* Use `*` bulleted lists for groupings and `1.` ordered lists for sequential instruction steps.
* Use **bold** only for human readability when drawing attention to a key concept.
* Use *italics* only for human readability when introducing new concepts, file names, or technical terms.
* Lines of prose content serve as prompt instructions. Blank lines, horizontal rules, code blocks, and section headers are structural elements rather than instructions.
* Bulleted and ordered lists can appear without a title instruction when the section heading already provides context.

### Voice in Different Contexts

Guidance voice is the default for prompt instructions and general guidance. Imperative voice applies to subagent action steps and direct autonomous execution. Both styles are appropriate in their respective contexts.

### User-Facing Responses

When instructions describe how to respond to users in conversation:

* Format file references as markdown links: `[filename](path/to/file)`.
* Format URLs as markdown links: `[display text](https://example.com)`.
* Use workspace-relative paths for file links.
* Do not wrap file paths or links in backticks. Backticks prevent the conversation viewer from rendering clickable links.
* Use placeholders like `{{YYYY-MM-DD}}` or `{{task}}` for dynamic path segments.

```markdown
<!-- Avoid backticks around file paths -->
2. Attach or open `.copilot-tracking/plans/2026-01-24-task-plan.instructions.md`.

<!-- Use markdown links for file references -->
2. Attach or open [2026-01-24-task-plan.instructions.md](.copilot-tracking/plans/2026-01-24-task-plan.instructions.md).

<!-- Use markdown links for URLs -->
See the [official documentation](https://docs.example.com/guide) for details.
```

### Patterns to Avoid

The following patterns provide limited value as prompt instructions:

* ALL CAPS directives and emphasis markers.
* Condition-heavy and overly branching instructions. Prefer providing a phase-based or step-based protocol framework.
* List items where each item has a bolded title line. For example, `* **Line item** - Avoid adding line items like this`.
* Forcing prompt instruction lists to have three or more items when fewer suffice.
* Avoid using XML tags to organize prompt instruction content. XML comments used by codebase tooling for section extraction are unrelated to this prohibition.

## Prompt Design Principles

Successful prompts demonstrate these qualities:

* Clarity: Each prompt instruction can be followed without guessing intent.
* Consistency: Prompt instructions produce similar results with similar inputs.
* Alignment: Prompt instructions match the conventions or standards provided by the user.
* Coherence: Prompt instructions avoid conflicting with other prompt instructions in the same or related prompt files.
* Calibration: Prompts provide just enough instruction to complete the user requests, avoiding overt specificity without being too vague.
* Correctness: Prompts provide instruction on asking the user whenever unclear about progression, avoiding guessing.

## Subagent Prompt Criteria

Prompt instructions for subagents keep the subagent focused on specific tasks.

Tool invocation:

* Run the named agent with `runSubagent` or `task` tools. If using the `runSubagent` tool then include instructions for the subagent to read and follow all instructions from the corresponding `.github/agents/` file.
* Reference subagent files using glob paths like `.github/agents/**/codebase-researcher.agent.md` so resolution works regardless of whether the subagent is at the root or in the `subagents/` folder.
* Subagents do not run their own subagents (see the Subagents section).

Task specification:

* Specify which custom agents or instructions files to follow.
* Prompt instruction files can be selected dynamically when appropriate (for example, "Find related instructions files and have the subagent read and follow them").
* Indicate the types of tasks the subagent completes.
* Provide the subagent a step-based protocol when multiple steps are needed.
* Subagents complete their work directly without orchestrating other subagents.

Response format:

* Provide a structured response format or criteria for what the subagent returns.
* When the subagent writes its response to files, specify which file to create or update.
* Allow the subagent to respond with clarifying questions to avoid guessing.

Execution patterns:

* Prompt instructions can loop and call the subagent multiple times until the task completes.
* Multiple subagents can run in parallel when work allows (for example, document researcher collects from documents while GitHub researcher collects from repositories).

Environment and output:

* Direct test and execution subagents to follow the Sandbox Environment guidelines.
* Define progressive output artifacts following the Intermediate Output Files pattern.
* Use cross-run continuity as described in Sandbox Environment when iterating.

Input specification:

* List all required inputs (target files, run number, sandbox path, purpose and requirements) and optional inputs (prior run paths, test scenarios) when invoking the subagent.
* Use consistent input naming across subagent invocations within the same parent agent.

Progressive feedback loops:

* Repeat subagent invocations with answers to clarifying questions until the task completes.
* Collect findings from completed subagent runs and feed them into subsequent invocations.
* Read subagent output artifacts progressively and integrate findings into parent-level documents.

## External Source Integration

When referencing SDKs, APIs, tools, frameworks, etc., for prompt instructions:

* Prefer official repositories with recent activity.
* Extract only the smallest snippet demonstrating the pattern for few-shot examples.
* Get official documentation using tools and from the web for accurate prompt instructions and examples.
* Use MCP tools such as `context7` and `microsoft-docs` to retrieve current references and documentation when available. These Model Context Protocol integrations provide access to up-to-date library documentation and official Microsoft content.
* Use fetch webpage and github repo tools as research sources for external patterns and examples when available.
* Instruct researcher subagents to gather external documentation when the parent agent needs SDKs, APIs, tools, frameworks, etc., context.

## Prompt Quality Criteria

Every item applies to the entire file. Validation fails if any item is not satisfied. Mark items as N/A when the criteria do not apply to the artifact type (for example, subagent criteria do not apply to instructions files).

* [ ] File structure follows the File Types guidelines for the artifact type.
* [ ] Frontmatter includes required fields and follows Frontmatter Requirements.
* [ ] Protocols follow Protocol Patterns when step-based or phase-based structure is used.
* [ ] Instructions match the Prompt Writing Style.
* [ ] Instructions follow all Prompt Design Principles.
* [ ] Subagent prompts follow Subagent Prompt Criteria when running subagents.
* [ ] External sources follow External Source Integration when referencing SDKs or APIs.
* [ ] Few-shot examples are in correctly fenced code blocks and match the instructions exactly.
* [ ] The user's request and requirements are implemented completely.
