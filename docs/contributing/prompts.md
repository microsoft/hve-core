---
title: 'Contributing Slash Commands to HVE Core'
description: 'Why HVE Core no longer accepts prompt files and how to contribute a reusable slash command as a skill'
sidebar_position: 4
author: Microsoft
ms.date: 2026-10-31
ms.topic: how-to
keywords:
  - contributing
  - prompts
  - slash commands
  - skills
  - standards
---

HVE Core no longer accepts prompt files (`.prompt.md`). Contribute a reusable slash command as a user-invocable skill, and follow [Contributing Skills](skills.md) for the package structure, frontmatter, scripts, tests, and validation rules.

⚙️ Common Standards: See [AI Artifacts Common Standards](ai-artifacts-common.md) for shared requirements (XML blocks, markdown quality, RFC 2119, validation, testing).

## Why Prompt Files Are No Longer Accepted

Earlier versions of HVE Core accepted prompt files under `.github/prompts/`, and VS Code's Local agent harness listed each one as a slash command. VS Code now uses the Copilot agent harness by default, the Copilot SDK runtime that also runs Copilot CLI. That harness does not load prompt files, so HVE Core ships none and builds its slash commands as skills.

The prompt and chat mode frontmatter schemas remain in `scripts/linting/schemas/` until a separate change retires them.

## Map a Prompt File to a Skill

A user-invocable skill takes the place of a prompt file. The skill's `name` becomes the slash command, `argument-hint` shows the expected arguments, and the user's message supplies the values. The skill body describes each input in an `Inputs` section.

| Prompt file                           | User-invocable skill                                                               |
|---------------------------------------|------------------------------------------------------------------------------------|
| File under `.github/prompts/`         | `SKILL.md` in `.github/skills/{package-id}/<skill-name>/`                          |
| Slash command named after the file    | Slash command named after the skill's `name`                                       |
| `argument-hint`                       | `argument-hint` in the skill frontmatter, with the same conventions                |
| `${input:...}` variables              | Values from the user's message, described in the body's `Inputs` section           |
| `agent` field that runs a named agent | Workflow steps in the skill body; add a thin agent only for a distinct entry point |
| `model` field                         | No skill field; give model-specific work to a subagent that sets `model`           |

A skill that drafts release notes could use this frontmatter:

```yaml
---
name: release-notes
description: 'Drafts release notes from the commits between two refs. Use when preparing a release summary.'
argument-hint: '[from=<tag>] [to=HEAD] [format={markdown|text}]'
license: MIT
user-invocable: true
---
```

Its body names each argument and its default:

```markdown
## Inputs

* `from` (optional): tag or commit to start after. Defaults to the latest tag.
* `to` (optional): commit to end at. Defaults to `HEAD`.
* `format` (optional): `markdown` (default) or `text`.
```

A user then types `/release-notes from=v3.1.0 format=text`, and the skill reads the values from that message.

## Choose Who Can Start the Skill

Two optional fields control invocation. The [Invocation Control Matrix](skills.md#invocation-control-matrix) in Contributing Skills covers every combination.

* `user-invocable` defaults to `true`, which lists the skill in the `/` menu. Set it to `false` to hide the slash command.
* `disable-model-invocation: true` stops Copilot from loading the skill on its own, so the skill runs only when a user types its slash command at the start of a message. HVE Core sets it on skills with side effects, such as `git-commit`, `git-merge`, and `git-setup`.

Manual-only skills have limits in Copilot CLI: naming one inside a sentence does not run it, and non-interactive `copilot -p` runs cannot reach it ([github/copilot-cli#4438](https://github.com/github/copilot-cli/issues/4438)). Leave `disable-model-invocation` unset unless the skill must never start without an explicit command.

## Invoke the Command

Type `/` in chat, pick the skill, and add any arguments in the same message. In VS Code, the install route decides the command name:

* Plugin installs, from the marketplace or from source, add the plugin name as a prefix, so HVE Core's Research skill appears as `/hve-core:rpi-research`.
* Skills copied into a project's own `.github/skills` folder appear without the prefix, as `/rpi-research`.

## Move Between Workflow Phases

The Copilot harness has no handoff buttons. Users move between phases by invoking the next skill, such as `/rpi-plan`, or by working with the RPI Agent. When a skill's workflow continues elsewhere, use the `Handoff` section from the skill template in the `hve-artifact-authoring` skill to name the next owner, such as the slash command to run next.

## Authoring with the HVE Builder Skill

The `hve-builder` skill is the lifecycle entrypoint for instructions, agents, subagents, and skills. It applies the standards in [Contributing Skills](skills.md), runs a review pass against its requirements catalog and rubric, and resolves a single overall outcome. It can also turn an existing prompt file into a skill and keeps the prompt's contract unless you ask for a change.

Start it with `/hve-builder` (`/hve-core:hve-builder` for plugin installs) followed by your targets and requirements, or ask for the work in natural language. Its argument hint is `[targets=...] [mode=create,improve,refactor] [requirements=...]`.

### Modes

| Mode       | Write authority              | Use when                                          |
|------------|------------------------------|---------------------------------------------------|
| `create`   | Creates new source artifacts | The target skill does not exist yet               |
| `improve`  | Edits existing source        | An existing skill needs new or corrected behavior |
| `refactor` | Edits existing source        | Cleanup must preserve current behavior            |
| `replace`  | Rewrites existing source     | The artifact needs wholesale replacement          |
| `review`   | Read-only; writes evidence   | You want review findings without source changes   |
| `validate` | Read-only; writes evidence   | You want host validation results only             |

Modes can combine in one run. When you name none, the skill applies `create`, `improve`, and `refactor` together within the requested outcome. It runs `replace` only on request and asks a question only when explicit directions conflict.

### Review Pass

`hve-builder` completes the source changes and local validation, then runs a review pass against its requirements catalog and review rubric. The main agent reviews the candidate itself by default. It may dispatch the `HVE Builder Reviewer` subagent for a fresh-context review when the change alters a decision rule, stage gate, write authority, or safety behavior, or when its own context is deep in the authoring.

The reviewer returns severity-graded findings as suggestions. The main agent verifies each one at its cited location, applies the required corrections as one batch, reruns the checks those corrections affect, and records the review evidence against the reviewed revision. Optional wording polish does not warrant another cycle, and repeated failures without a supported new approach stop with the unresolved findings. A read-only review returns findings without gaining source-write authority.

### Evidence

Runs write author, review, and validation evidence under
`.copilot-tracking/hve-builder/{{YYYY-MM-DD}}/` unless you supply a different evidence
root. Read-only modes change nothing else.

Authoring standards for all artifact kinds live in
`.github/instructions/hve-core/hve-builder.instructions.md`.

## Automated Validation

Validate a new or changed skill with the commands in [Contributing Skills](skills.md#automated-validation). When you add a skill, run `npm run docs:generate` to scaffold its reference page under `docs/reference/skills/`, then author the page as the [asset reference documentation guide](asset-docs.md) describes.

All checks **MUST** pass before merge.

## Related Documentation

* [Contributing Skills](skills.md) - Skill package structure, frontmatter, tests, and validation
* [AI Artifacts Common Standards](ai-artifacts-common.md) - Shared standards for all contributions
* [Contributing Custom Agents](custom-agents.md) - Agent files, skill preloading, and subagents
* [Contributing Instructions](instructions.md) - Technology-specific standards
* [Pull Request Template](https://github.com/microsoft/hve-core/blob/main/.github/PULL_REQUEST_TEMPLATE.md) - Submission requirements

## Getting Help

See [AI Artifacts Common Standards - Getting Help](ai-artifacts-common.md#getting-help) for support resources. User-invocable skills such as `git-commit` and `rpi-research` show working slash commands, and the [hve-builder](../reference/skills/hve-core/hve-builder) skill can draft and validate a new one.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
