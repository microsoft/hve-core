---
title: skill-effectiveness
description: "Use when creating, reviewing or improving a native Vally A/B evaluation of whether an Agent Skill helps on a realistic task, including deriving a candidate skill from repository knowledge."
sidebar_position: 9
author: Microsoft
ms.date: 2026-10-13
ms.topic: reference
keywords:
  - skill
  - hve-core
  - skill-effectiveness
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                 |
|-------------|---------------------------------------------------------------------------------------|
| Kind        | skill                                                                                 |
| Source      | `.github/skills/hve-core/skill-effectiveness`                                         |
| Invocation  | Invoked directly as `/skill-effectiveness`, or loaded on demand by referencing agents |
| Interactive | No                                                                                    |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Use when creating, reviewing or improving a native Vally A/B evaluation of whether an Agent Skill helps on a realistic task, including deriving a candidate skill from repository knowledge.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this supervised authoring workflow when you want to compare a realistic task
with and without a complete skill package. Start from an existing skill or derive
a source-grounded candidate from a repository, then use the same native Vally
comparison path.

The workflow helps select fair inputs and relevant executable, source-grounded,
or rendered-image evidence. It does not deliver an automatic adoption verdict,
enforce candidate isolation, or establish general effectiveness.

Authoring and model-free tests do not authorize paid execution. Candidate runs,
prompt graders, and image reviews require explicit scope, budget, and adequate
spending controls. The pinned runtime lacks the required hard credit cap.

### Choosing the right skill

* [hve-builder](hve-builder) helps you create, improve, and review a skill or other
  Copilot artifact against authoring and quality requirements.
* [vally-tests](vally-tests) helps you author conformance tests: does the artifact
  follow the behaviors it claims?
* skill-effectiveness helps you author a matched A/B comparison: does the same
  agent perform a realistic task better with the skill than without it?

These workflows are complementary. An artifact can meet authoring requirements
and pass conformance tests without demonstrating added task value. Use
skill-effectiveness when that added value is the question; ties, regressions,
and strong baseline performance are useful findings too.

## How to use it

Install or copy the complete skill using your chat host's supported mechanism,
then confirm that the host discovers it. Invoke `/skill-effectiveness` where
supported, or explicitly ask your agent to use the skill.

For standalone setup and model-free validation, use Node.js 24+ and follow the
[copy-and-test guide](https://github.com/microsoft/hve-core/blob/main/.github/skills/hve-core/skill-effectiveness/references/experiment-method.md#copy-and-test-the-reusable-skill).
`npm ci` installs dependencies; it does not install or register the skill with
the chat host. Authoring and validation do not authorize paid candidate runs
or model reviews.

## Example usage

```text
Use skill-effectiveness to author a baseline-versus-with-skill evaluation
for data-catalog on these public fixtures. Keep the task, model, tools, and
checks identical. Prepare native Vally files and evaluation notes only;
do not start candidates or model reviews.
```

For the repository-derived route:

```text
Inspect this pinned repository's extension contract. If its non-obvious
knowledge warrants a reusable skill, create a source-grounded candidate
outside the authoring package and propose a fair A/B task. Stop if no
candidate is defensible. Do not run paid evaluations.
```

Expected outputs include native eval and experiment YAML, public fixtures,
relevant task checks, a frozen focus skill, package configuration, and evaluation
notes. Preserve runtime failures and unavailable evidence separately from
measured task quality.
