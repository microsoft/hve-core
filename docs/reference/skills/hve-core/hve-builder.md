---
title: hve-builder
description: "Create, improve, refactor, review, or validate prompts, instructions, agents, subagents, and skills, and build or extend HVE workflows. Use when authoring or upgrading a Copilot customization artifact, or when connecting a workflow such as rpi-research or rpi-plan to project-specific knowledge, tools, or conventions."
sidebar_position: 5
author: Microsoft
ms.date: 2026-09-04
ms.topic: reference
keywords:
  - skill
  - hve-core
  - hve-builder
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                         |
|-------------|-------------------------------------------------------------------------------|
| Kind        | skill                                                                         |
| Source      | `.github/skills/hve-core/hve-builder`                                         |
| Invocation  | Invoked directly as `/hve-builder`, or loaded on demand by referencing agents |
| Interactive | No                                                                            |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Create, improve, refactor, review, or validate prompts, instructions, agents, subagents, and skills, and build or extend HVE workflows. Use when authoring or upgrading a Copilot customization artifact, or when connecting a workflow such as rpi-research or rpi-plan to project-specific knowledge, tools, or conventions.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `hve-builder` whenever a prompt, instruction file, agent, subagent, or skill is being created, upgraded from a draft or ad hoc instruction set, refactored, replaced, reviewed, or validated. It applies the instruction-quality requirements catalog, runs one independent static review, and gates a Major change behind one behavior test.

Use it also to build or extend HVE workflows. When a team wants `rpi-research` and `rpi-plan` to draw on internal knowledge, `hve-builder` reads those workflows' discovery and dispatch contracts and produces the skill or subagent that connects them.

Use `hve-builder-tester` directly when an existing artifact needs a behavior test without any change. Use `vally-tests` for conformance-test authoring, and `rpi-research` for open-ended research that precedes a build decision.

## Example usage

Ask to make `rpi-research` and `rpi-plan` use an internal design-document corpus. The skill reads both workflows, notes that each selects helpers whose name or description marks them for research or planning, and creates a skill that documents where the corpus lives, how to run its indexing script, and how to cite results.

When the corpus is large enough that indexing would crowd out the parent's context, it adds a research specialist subagent that runs the index in an isolated lane and returns cited evidence to `rpi-research`. It then runs local validation, one fresh-context static review, and, because the change is Major, one `hve-builder-tester` run before reporting the outcome with evidence links.
