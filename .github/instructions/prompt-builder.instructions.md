---
description: 'Authoring standards for prompt engineering artifacts including file types, protocol patterns, writing style, and quality criteria - Brought to you by microsoft/hve-core'
applyTo: '**/*.prompt.md, **/*.agent.md, **/*.instructions.md, **/SKILL.md'
maturity: stable
---

# Prompt Builder Instructions

These instructions define authoring standards for prompt engineering artifacts. Apply these standards when creating or modifying prompt, agent, instructions, or skill files.

## File Types

This section defines file type selection criteria, authoring patterns, and validation checks.

### Prompt Files

*Extension*: `.prompt.md`

Purpose: Single-session workflows where users invoke a prompt and Copilot executes to completion.

Characteristics:

* Single invocation completes the workflow.
* Frontmatter includes `agent: 'agent-name'` to delegate to an agent.
* Content ends with `---` followed by an activation instruction.
* Use `#file:` only when the prompt must pull in the full contents of another file.
* When the full contents are not required, refer to the file by path or to the relevant section.
* Input variables use `${input:variableName}` or `${input:variableName:defaultValue}` syntax.

Consider adding sequential steps when the prompt involves multiple distinct actions that benefit from ordered execution. Simple prompts that accomplish a single task do not need protocol structure.

#### Input Variables

Input variables allow prompts to accept user-provided values or use defaults:

* `${input:topic}` is a required input, inferred from user prompt, attached files, or conversation.
* `${input:chat:true}` is an optional input with default value `true`.
* `${input:baseBranch:origin/main}` is an optional input defaulting to `origin/main`.

An Inputs section documents available input variables:

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

Validation guidelines:

* When steps are used, follow the Step-Based Protocols section for structure.
* Document input variables in an Inputs section when present.

### Agent Files

*Extension*: `.agent.md`

Purpose: Agent files support both conversational workflows (multi-turn interactions with a specialized assistant) and autonomous workflows (task execution with minimal user interaction).

#### Conversational Agents

Conversational agents guide users through multi-turn interactions:

* Users guide the conversation through different activities or stages.
* State persists across conversation turns via planning files when needed.
* Frontmatter defines available `tools` and optional `handoffs` to other agents.
* Typically represents a domain expert or specialized assistant role.

Consider adding phases when the workflow involves distinct stages that users move between interactively. Simple conversational assistants that respond to varied requests do not need protocol structure. Follow the Phase-Based Protocols section for phase structure guidelines.

#### Autonomous Agents

Autonomous agents execute tasks with minimal user interaction:

* Executes autonomously after receiving initial instructions.
* Frontmatter defines available `tools` and optional `handoffs` to other agents.
* Typically completes a bounded task and reports results.
* May dispatch subagents for parallelizable work.

Use autonomous agents when the workflow benefits from task execution rather than conversational back-and-forth.

### Instructions Files

*Extension*: `.instructions.md`

Purpose: Auto-applied guidance based on file patterns. Instructions define conventions, standards, and patterns that Copilot follows when working with matching files.

Characteristics:

* Frontmatter includes `applyTo` with glob patterns (for example, `**/*.py`).
* Applied automatically when editing files matching the pattern.
* Define coding standards, naming conventions, and best practices.

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

### Optional Directories

#### scripts/

Contains executable code that agents run to perform tasks:

* Scripts are self-contained or clearly document dependencies.
* Include helpful error messages and handle edge cases gracefully.
* Provide parallel implementations for bash and PowerShell when targeting cross-platform use.

#### references/

Contains additional documentation that agents read when needed:

* *REFERENCE.md* for detailed technical reference material.
* Domain-specific files such as `finance.md` or `legal.md`.
* Keep individual reference files focused; agents load these on demand.

#### assets/

Contains static resources:

* Templates for documents or configuration files.
* Images such as diagrams or examples.
* Data files such as lookup tables or schemas.

#### Skill Content Structure

Skill files include these sections in order:

1. **Title (H1)**: Clear heading matching skill purpose.
2. **Overview**: Brief explanation of what the skill does.
3. **Prerequisites**: Platform-specific installation requirements.
4. **Quick Start**: Basic usage with default settings.
5. **Parameters Reference**: Table documenting all options with defaults.
6. **Script Reference**: Usage examples for bash and PowerShell.
7. **Troubleshooting**: Common issues and solutions.
8. **Attribution Footer**: Standard footer with attribution.

### Progressive Disclosure

Structure skills for efficient context usage:

1. **Metadata** (~100 tokens): The `name` and `description` frontmatter fields load at startup for all skills.
2. **Instructions** (<5000 tokens recommended): The full *SKILL.md* body loads when the skill activates.
3. **Resources** (as needed): Files in `scripts/`, `references/`, or `assets/` load only when required.

Keep the main *SKILL.md* under 500 lines. Move detailed reference material to separate files.

### File References

When referencing other files in the skill, use relative paths from the skill root:

```markdown
See [the reference guide](references/REFERENCE.md) for details.

Run the extraction script:
scripts/extract.py
```

Keep file references one level deep from *SKILL.md*. Avoid deeply nested reference chains.

Validation guidelines:

* Include `name` frontmatter matching the skill directory name (required).
* Include `description` frontmatter (required).
* Include `maturity` frontmatter (required).
* Provide parallel script implementations for bash and PowerShell when targeting cross-platform use.
* Document prerequisites for each supported platform.
* Keep *SKILL.md* under 500 lines; move detailed reference material to `references/`.
* Additional sections can be added between Parameters Reference and Troubleshooting as needed.

## Frontmatter Requirements

This section defines frontmatter field requirements for prompt engineering artifacts.

### Required Fields

All prompt engineering artifacts include these frontmatter fields:

* `description:` - Brief description of the artifact's purpose.
* `maturity:` - Lifecycle stage: `experimental`, `preview`, `stable`, or `deprecated`.

Note: VS Code shows a validation warning for the `maturity:` field as it's not in VS Code's schema. This is expected; the field is required by the HVE-Core codebase for artifact lifecycle tracking. Ignore VS Code validation warnings for the `maturity:` attribute.

### Optional Fields

Optional fields vary by file type:

* `name:` - Skill identifier (required for skill files only). Must match the skill directory name using lowercase kebab-case.
* `applyTo:` - Glob patterns (required for instructions files only).
* `tools:` - Tool restrictions for agents. When omitted, all tools are accessible. When specified, list only tools available in the current VS Code context.
* `handoffs:` - Agent handoff declarations for agents. Use `agent:` for the target reference.
* `agent:` - Agent delegation for prompt files.
* `argument-hint:` - Hint text for prompt picker display.
* `model:` - Model specification.

### Tool Availability

When authoring prompts that reference specific tools:

* Verify tool availability in the current VS Code context before including in `tools:` frontmatter.
* When a user references tools not available in the active context, inform them which tools need to be enabled.
* Do not include tools that VS Code flags as unknown.

## Protocol Patterns

Protocol patterns apply to prompt and agent files. Skill files follow their own content structure defined in the Skill Content Structure section rather than step-based or phase-based protocols.

### Step-Based Protocols

Step-based protocols define groupings of sequential prompt instructions that execute in order. Add this structure when the workflow benefits from explicit ordering of distinct actions.

Structure guidelines:

* A `## Required Steps` section contains all steps and provides an overview of how the protocol flows.
* Protocol steps contain groupings of prompt instructions that execute as a whole group, in order.

Step conventions:

* Format steps as `### Step N: Short Summary` within the Required Steps section.
* Give each step an accurate short summary that indicates the grouping of prompt instructions.
* Include prompt instructions to follow while implementing the step.
* Steps can repeat or move to a previous step based on instructions.

Activation line: End the prompt file with a horizontal rule (`---`) followed by an instruction to begin.

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
* Give each phase an accurate short summary that indicates the grouping of prompt instructions.
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

### Shared Protocol Placement

Protocols can be shared across multiple files by placing the protocol into a `{{name}}.instructions.md` file. Use `#file:` only when the full contents of the protocol file are needed; otherwise, refer to the file by path or to the relevant section.

## Prompt Writing Style

Prompt instructions have the following characteristics:

* Guide the model on what to do, rather than command it.
* Written with proper grammar and formatting.

Additional characteristics:

* Use protocol-based structure with descriptive language when phases or ordered steps are needed.
* Use `*` bulleted lists for groupings and `1.` ordered lists for sequential instruction steps.
* Use **bold** only for human readability when drawing attention to a key concept.
* Use *italics* only for human readability when introducing new concepts, file names, or technical terms.
* Each line other than section headers and frontmatter requirements is treated as a prompt instruction.
* Follow standard markdown conventions and instructions for the codebase.
* Bulleted and ordered lists can appear without a title instruction when the section heading already provides context.

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

Prefer guidance style over command style:

```markdown
<!-- Avoid command style -->
You must search the folder and you will collect all conventions.

<!-- Use guidance style -->
Search the folder and collect conventions into the research document.
```

### Patterns to Avoid

The following patterns provide limited value as prompt instructions:

* ALL CAPS directives and emphasis markers.
* Second-person commands with modal verbs (will, must, shall). For example, "You will" or "You must."
* Condition-heavy and overly branching instructions. Prefer providing a phase-based or step-based protocol framework.
* List items where each item has a bolded title line. For example, `* **Line item** - Avoid adding line items like this`.
* Forcing prompt instruction lists to have three or more items when fewer suffice.
* XML-style groupings of prompt instructions. Use markdown sections for grouping related prompt instructions instead.

## Prompt Key Criteria

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

* Include an explicit instruction to use the runSubagent tool when dispatching a subagent.
* When runSubagent is unavailable, follow the subagent instructions directly or stop if runSubagent is required for the task.

Task specification:

* Specify which custom agents or instructions files to follow.
* Prompt instruction files can be selected dynamically when appropriate (for example, "Find related instructions files and have the subagent read and follow them").
* Indicate the types of tasks the subagent completes.
* Provide the subagent a step-based protocol when multiple steps are needed.

Response format:

* Provide a structured response format or criteria for what the subagent returns.
* When the subagent writes its response to files, specify which file to create or update.
* Allow the subagent to respond with clarifying questions to avoid guessing.

Execution patterns:

* Prompt instructions can loop and call the subagent multiple times until the task completes.
* Multiple subagents can run in parallel when work allows (for example, document researcher collects from documents while GitHub researcher collects from repositories).

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
