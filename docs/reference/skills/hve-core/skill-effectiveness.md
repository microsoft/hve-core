---
title: skill-effectiveness
description: "Use when authoring or reviewing a native Vally baseline-versus-with-skill evaluation, with separate protected offline grading and existing-skill or repository-derived candidate entry routes."
sidebar_position: 9
author: Microsoft
ms.date: 2026-10-23
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
Use when authoring or reviewing a native Vally baseline-versus-with-skill evaluation, with separate protected offline grading and existing-skill or repository-derived candidate entry routes.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this supervised authoring workflow when you want to compare a realistic task
with and without a complete skill package. Start from an existing skill or derive
a source-grounded candidate from a repository, then use the same native Vally
comparison path.

Repository-derived intake requires explicitly reading and applying the
commit-pinned public canonical policy before target-source inspection; unavailable
activation stops that route. Evidence notes retain claim/method decisions and
unknowns. Visual review covers visible properties only, with accessibility method
selection routed to the canonical accessibility skill rather than copied criteria.

The workflow helps select fair inputs and relevant executable, source-grounded,
or rendered-image evidence. It does not deliver an automatic adoption verdict,
provide universal candidate containment, or establish general effectiveness.

Candidate collection stages public fixtures and checks completion/delivery only.
A separate grade-only spec authenticates a reviewed private checker and consumes
one original native trial record with one completed, operator-bound submission
snapshot. Keep readonly checker/submission inputs separate from writable scratch,
and preserve original results alongside explicitly linked new grades.
A native pass alone does not authenticate the arm/snapshot pairing.
Optional text review uses a separate spec and approved one-submission directory,
not the executable grading view. Follow the
[staging contract](https://github.com/microsoft/hve-core/blob/main/.github/skills/hve-core/skill-effectiveness/references/experiment-method.md#separate-public-grading-and-review-inputs)
for protected inputs, provenance and remaining runtime gates.

Default templates do not enforce candidate or grader containment. An optional
Windows-native candidate profile applies the supported command sandbox using
normal local sign-in, without inherited Copilot/GitHub token variables.
Authoring and
model-free validation remain available; untrusted execution waits for the
selected profile's security verification. The released-API adapter supports fresh
environment-scoped sessions only, rejecting default/resume requests. Completed
model-free checks cover tested Linux boundaries and the selected Windows command
policy, not arbitrary images, full Python/browser tasks, offline graders or
successful model tasks. Generic provider/BYOK behavior remains unchanged.
The reusable package is cross-platform; only the opt-in Windows profile is
Windows-specific. With approval, candidate Node/Python tools can be separated
from offline Jupyter execution and browser rendering. Disclose identical
candidate limitations to both arms and retain full executed and visual evidence.
The optional Linux rendering regression exercises actual Chromium user-namespace
sandboxing and Mermaid images without model calls; it requires an approved
pinned image/profile and does not qualify the full native grading route.
For complete repository checkouts, optional explicit empty client mode
suppresses nested instruction discovery while retaining the unchanged
empty-instruction startup guard. Qualify the complete staged sources in both
arms rather than extrapolating from a small synthetic workspace.
See the
[execution evidence and limits](https://github.com/microsoft/hve-core/blob/main/.github/skills/hve-core/skill-effectiveness/references/experiment-method.md#completed-model-free-evidence-and-limits).

Authoring and model-free tests do not authorize paid execution. Candidate runs,
prompt graders, and image reviews require explicit approval of the run plan and
budget. Before any invocation, read and apply the
[supervised run policy](https://github.com/microsoft/hve-core/blob/main/.github/skills/hve-core/skill-effectiveness/references/experiment-method.md#execute-an-approved-run-plan)
for retries, usage limits, unknown usage and security prerequisites. Omitted paid
aliases and timeouts are not financial enforcement: manual execution remains
possible, and a required enforced ceiling must come from the provider/runtime.

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

Start with
[Author Your First A/B Evaluation](https://github.com/microsoft/hve-core/blob/main/.github/skills/hve-core/skill-effectiveness/references/first-evaluation.md).
It shows the minimum inputs, an authoring-only request, expected files, a
complete pair and exact lint/dry-run commands. Two planned arms are not completed
trials or proof that the skill helps.

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
