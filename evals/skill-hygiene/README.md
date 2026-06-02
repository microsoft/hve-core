---
title: Skill Hygiene
description: 'Lint-based skill hygiene suite for .github/skills/ delivered via vally lint'
author: HVE Core Team
ms.date: 2026-05-24
---

This directory documents the **skill hygiene** suite. It is the only suite that ships through `vally lint` rather than `vally eval` and so contains no `eval.yaml`.

## Purpose

Skill hygiene applies fast, deterministic structural checks to every `SKILL.md` under `.github/skills/`. It does not invoke a model or run an executor. It answers a single inner-loop question: *is the skill well-formed?*

## How it runs

* Local: `npm run eval:lint:skills` (wraps `vally lint .github/skills/`).
* CI: the `Run skill hygiene lint` step inside the `eval-lint` job in [`pr-validation.yml`](../../.github/workflows/pr-validation.yml). The step is gated on the changed-artifact manifest containing at least one entry with `kind: skill` and is authoritative; a non-zero exit code blocks the pull request.

## Coverage

The lint sweep iterates every `SKILL.md` discovered under `.github/skills/`. Current corpus (20 skills across 8 collection directories):

| Collection         | Skill                       |
|--------------------|-----------------------------|
| `coding-standards` | `python-foundational`       |
| `experimental`     | `customer-card-render`      |
| `experimental`     | `powerpoint`                |
| `experimental`     | `tts-voiceover`             |
| `experimental`     | `video-to-gif`              |
| `experimental`     | `vscode-playwright`         |
| `github`           | `gh-code-scanning`          |
| `gitlab`           | `gitlab`                    |
| `installer`        | `hve-core-installer`        |
| `jira`             | `jira`                      |
| `security`         | `owasp-agentic`             |
| `security`         | `owasp-cicd`                |
| `security`         | `owasp-docker`              |
| `security`         | `owasp-infrastructure`      |
| `security`         | `owasp-llm`                 |
| `security`         | `owasp-mcp`                 |
| `security`         | `owasp-top-10`              |
| `security`         | `secure-by-design`          |
| `security`         | `security-reviewer-formats` |
| `shared`           | `pr-reference`              |

New skills added under `.github/skills/<collection>/<slug>/SKILL.md` are picked up automatically. No manifest update is required.

## Graders

Tier 1 ships with the two hygiene graders registered by `vally lint` in Vally 0.4.0. `skill-size` is deferred per **PD-01 Option A** in the planning log and tracked under **WI-08**; it activates in **Phase 15** alongside other custom grader plugin work.

| Grader         | Status   | Behavior                                                                       |
|----------------|----------|--------------------------------------------------------------------------------|
| `orphan-files` | Active   | Flags files inside the skill directory not referenced by `SKILL.md`.           |
| `valid-refs`   | Active   | Flags markdown references that escape the skill directory or 404.              |
| `skill-size`   | Deferred | Exported by `@microsoft/vally` but not registered by `vally lint` (see WI-08). |

`vally lint` also auto-runs `spec-compliance` (frontmatter and structural checks). It is registered upstream and will surface in the lint report, but it is not enumerated as part of the Tier 1 hygiene coverage promised by the research.

## Why not `eval.yaml`?

The other four suites under `evals/` use `vally eval` because they need a model in the loop to grade non-deterministic output. Skill hygiene is purely structural; every check is a fast static read of the file system.

Authoring an `eval.yaml` that references the hygiene grader types (`orphan-files`, `skill-size`, `valid-refs`) would fail at runtime with "Unknown grader type" because Vally 0.4.0's eval grader registry does not expose them (see **DR-05** evidence and **DD-03** in the planning log).

The `vally lint` subcommand already implements exactly this contract: discover skills, run registered static graders, emit a per-skill pass/fail report. Reusing it preserves the anti-aggregate-grader policy and keeps the inner-loop cost at zero tokens.

## Anti-patterns

* Do not add an `eval.yaml` to this directory.
* Do not gate the workflow step on anything other than `kind: skill` in the changed-artifact manifest.
* Do not switch the workflow step to `continue-on-error: true`. The suite is authoritative.

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
