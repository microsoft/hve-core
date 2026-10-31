---
title: Reusable Slash Commands
description: Build a reusable slash command as a skill, because the Copilot harness does not load prompt files
author: Microsoft
ms.date: 2026-10-31
ms.topic: how-to
keywords:
  - slash commands
  - skills
  - prompt files
  - SKILL.md
  - copilot
estimated_reading_time: 7
---

## Prompt Files and the Copilot Harness

HVE Core targets the Copilot harness, the Copilot SDK runtime that is VS Code's default agent harness and also runs Copilot CLI. That harness does not load prompt files (`.prompt.md`), and HVE Core ships none. Build a reusable slash command as a skill instead: a folder under `.github/skills/` with a `SKILL.md` file, which a user runs by typing `/` and the skill's name. HVE Core's own entry points, such as `/rpi-research` and `/rpi-plan`, work this way.

If you have written prompt files before, their features map to skills as follows:

| Prompt file feature                   | Skill counterpart                                                    |
|---------------------------------------|----------------------------------------------------------------------|
| `.github/prompts/<name>.prompt.md`    | `.github/skills/<name>/SKILL.md`                                     |
| Command name taken from the file name | Command name taken from the `name` field, which matches the folder   |
| `description` and `argument-hint`     | The same fields in the skill's frontmatter                           |
| `${input:name}` variables             | An Inputs section in the body, with values from the user's message   |
| `#file:` references                   | Relative links to skill files, or workspace paths named in the body  |
| `agent`, `tools`, and `model` fields  | No skill equivalent; pair the skill with an agent when you need them |

## Skill Basics

A slash command skill holds a workflow that a person starts on demand. Copilot discovers `.github/skills` at any folder depth, so you can group skills in package folders without changing any settings:

```text
.github/skills/
├── contoso/
│   ├── release-notes/
│   │   ├── SKILL.md
│   │   └── references/
│   │       └── categories.md
│   └── sprint-summary/
│       └── SKILL.md
└── shared/
    └── standup-notes/
        └── SKILL.md
```

Type `/` in Copilot Chat to list the commands. A skill in your repository's own `.github/skills` folder appears under its name, such as `/release-notes`. In VS Code, a skill installed through a plugin carries the plugin name as a prefix, so HVE Core's research skill appears as `/hve-core:rpi-research`.

Skills differ from the other artifact types in when they load. Instructions apply to matching files without being asked, and an agent is a multi-turn role that the user selects in the agent picker. A skill loads when someone runs its command, when its description matches the task at hand, or when an agent preloads or activates it.

## Creating a Slash Command Skill

A `SKILL.md` file combines YAML frontmatter with a Markdown body that holds the workflow. Here is a complete example for generating release notes:

```markdown
---
name: release-notes
description: "Generates release notes from recent commits and merged pull requests. Use when preparing a release summary."
argument-hint: "[since=<tag>] [audience={internal|public}]"
user-invocable: true
disable-model-invocation: true
---

# Release Notes

Produce release notes from the commit history and the pull requests merged
since the requested tag.

## Inputs

* `since` (optional): Tag or commit to start from. Defaults to the most recent
  release tag.
* `audience` (optional): `internal` or `public`. Defaults to `internal`.

## Requirements

1. Group changes using the categories in
   [references/categories.md](references/categories.md).
2. Include PR numbers and brief descriptions for each entry.
3. Highlight breaking changes at the top with migration guidance.
4. Use past tense for all entries.
5. Leave internal ticket links out of notes for the `public` audience.
```

Frontmatter fields:

* `name` (required): Lowercase kebab-case name of up to 64 characters that matches the skill's folder. The slash command uses it.
* `description` (required): Says what the skill does and when to use it. Copilot compares it with the task when it decides whether to load the skill without a command.
* `argument-hint` (optional): Shows the arguments the command expects as hint text.
* `user-invocable` (optional): Controls whether the command appears in the `/` menu. It defaults to `true`.
* `disable-model-invocation` (optional): Hides the skill from the model when set to `true`, so only its slash command loads it. It defaults to `false`.

Skills also accept `license`, `compatibility`, and `metadata`. Skill frontmatter does not declare `tools`, `model`, `skills`, or `applyTo`; those fields belong to agents and instructions.

The body holds the instructions Copilot follows. Give each input an entry in an Inputs section with its default, so the model knows what to look for in the user's message and what to assume when the user leaves a value out.

## Inputs and Arguments

A skill gets its input from the user's message. Type the arguments after the command:

```text
/release-notes since=v3.1.0 audience=public
```

The `argument-hint` shows the expected form, and the Inputs section tells the model what each value means. Skills have no `${input:...}` placeholders, so the Inputs section is also where each default lives.

Keep files that the command always needs in the skill folder, and link them from the body with paths relative to the skill root, such as `references/categories.md`. Copilot loads the `SKILL.md` body when the command runs, and the agent reads a linked file when the body calls for it. For a file elsewhere in the workspace, name its path in the body so the agent reads it. Prompt files pulled in both kinds of file with `#file:`, which the Copilot harness does not load.

## Choosing Who Starts the Command

Two fields decide who can start a skill:

| `user-invocable` | `disable-model-invocation` | Slash command | Loaded without a command |
|------------------|----------------------------|---------------|--------------------------|
| `true` (default) | `false` (default)          | Yes           | Yes                      |
| `true`           | `true`                     | Yes           | No                       |
| `false`          | `false`                    | No            | Yes                      |

Set `disable-model-invocation: true` when only a person should start the command, as HVE Core does for `git-commit` and `git-merge`. A manual-only skill runs only when you type its slash command at the start of a message. In Copilot CLI, asking for one by name in a sentence fails, and non-interactive `copilot -p` runs cannot reach it ([github/copilot-cli#4438](https://github.com/github/copilot-cli/issues/4438)).
Because only the slash command loads such a skill, an agent cannot activate it either. Leave the field unset for a skill that agents should use.

Set `user-invocable: false` for a skill that supports agents and needs no command of its own. HVE Core's `disclaimer-language` skill works this way: agents preload it, and it stays out of the `/` menu.

## Commands and Agents

Skill frontmatter has no `agent` field, so a skill cannot hand its work to a custom agent the way a prompt file could. Instead, an agent uses the skill: it preloads a skill it needs from the start by listing it under `skills:`, and it activates other skills by name when its `tools` list includes `skill`.
HVE Core's RPI Agent works this way. It activates `rpi-research`, `rpi-plan`, and the other phase skills as a session moves between phases, and you can run the same skills yourself as `/rpi-research` or `/rpi-plan`.

Skills also have no `tools` or `model` field. When a command needs its own tool list, model, or multi-turn role, pair it with an agent:

```yaml
---
name: Contoso Design Reviewer
description: "Drafts architecture proposals from requirements without changing source - Brought to you by contoso/engineering"
tools:
  - read
  - search
  - skill
skills:
  - design-proposal
---
```

This agent starts with the `design-proposal` skill loaded. It can read files, search, and load skills, and it has no `edit` or `execute` access. See [Creating Custom Agents](custom-agents) for the full field set.

## Converting a Prompt File

To move an existing `.prompt.md` file to a skill:

1. Create a folder under `.github/skills/`, such as `.github/skills/contoso/release-notes/`, and move the prompt body into a `SKILL.md` file there.
2. Add a `name` that matches the folder, and keep the `description` and `argument-hint`.
3. Replace each `${input:...}` placeholder with an Inputs entry that names the input and its default.
4. Replace each `#file:` reference with a relative link to a file copied into the skill folder, or with a workspace path named in the body.
5. Remove the `agent`, `tools`, and `model` fields. If the command relied on them, pair the skill with an agent as described in [Commands and Agents](#commands-and-agents).
6. Set `disable-model-invocation: true` if only a person should start the command.
7. Delete the prompt file, since Copilot does not load it.

Then type `/` in Copilot Chat and confirm that the new command appears.

## Authoring with HVE Builder

Use `hve-builder` create or improve mode to author a slash command skill and run its quality gates through one lifecycle:

```text
Use hve-builder with mode=create,
targets=.github/skills/contoso/release-notes/SKILL.md, and
requirements="A manual-only slash command; use sprint-summary as a known
structural reference".
```

Provide existing skills, applicable instructions, and any agent that uses the skill as known references during intake. HVE Builder can also turn an existing prompt file into a skill when you name the prompt file in the requirements:

```text
Use hve-builder with mode=create,
targets=.github/skills/contoso/sprint-summary/SKILL.md, and
requirements="Convert .github/prompts/contoso/sprint-summary.prompt.md into a
slash command skill and keep its inputs".
```

Use review mode for read-only assessment:

```text
Use hve-builder with mode=review and
targets=.github/skills/contoso/release-notes/SKILL.md.
```

The report covers purpose, activation, architecture, issues by severity, and the overall outcome. Review it before sharing the command with the team.

Use refactor mode to consolidate overlapping commands without intentionally changing their supported behavior:

```text
Use hve-builder with mode=refactor,
targets=.github/skills/contoso/*/SKILL.md, and requirements="merge similar
reporting commands into one skill with arguments".
```

> [!TIP]
> Run `hve-builder` review mode on existing skills before creating new ones.
> The evidence often shows that an existing skill can be improved instead.

## Role Scenarios

**Adventure Works' PM** creates a sprint-planning skill at `.github/skills/adventure-works/sprint-planning/SKILL.md` with `argument-hint: "sprint=<number>"` and `disable-model-invocation: true`. The skill scopes planning to the requirements tagged for the given sprint. PMs across the team type `/sprint-planning sprint=14` and continue with `/rpi-plan` when the work needs a full implementation plan.

**Fabrikam's Data Scientist** builds a notebook-review skill that analyzes Jupyter notebooks for reproducibility issues. The skill checks for hardcoded paths, missing dependency declarations, and undocumented data transformations, and it links the team's notebook conventions from `references/notebook-conventions.md` in its own folder. Because `disable-model-invocation` stays unset, Copilot also loads the skill when someone asks for a notebook review without typing the command.

**Contoso's Tech Lead** writes a design-proposal skill that turns a set of requirements into an architecture proposal. A skill has no `tools` field, so the tech lead pairs it with the Contoso Design Reviewer agent shown earlier. That agent preloads the skill and has no `edit` or `execute` access, so it drafts proposals in chat without changing source code.

For the full skill frontmatter schema, naming conventions, and validation rules, see [Contributing: Skills](../contributing/skills).

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
