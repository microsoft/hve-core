---
title: Asset reference documentation
description: How contributors generate, author, and validate reference pages for agents, prompts, instructions, and skills
sidebar_position: 12
author: Microsoft
ms.date: 2026-07-18
ms.topic: how-to
keywords:
  - asset documentation
  - generated documentation
  - agents
  - prompts
  - instructions
  - skills
  - documentation drift
estimated_reading_time: 7
---

Every documentable agent, prompt, instruction, and skill has a paired page in the
[Asset Catalog](../reference/README.md). Treat that page as part of the artifact,
not as optional follow-up documentation. The generator keeps source metadata in
sync, while contributors own the usage guidance that requires human judgment.

## Which assets require a page

The generator discovers collection-scoped assets under `.github/` and creates one
reference page for each asset. Root-level repo-specific artifacts and files under
deprecated directories are excluded.

| Source asset                                               | Reference page                                 |
|------------------------------------------------------------|------------------------------------------------|
| `.github/agents/<path>/<name>.agent.md`                    | `docs/reference/agents/<path>/<name>.md`       |
| `.github/prompts/<path>/<name>.prompt.md`                  | `docs/reference/prompts/<path>/<name>.md`      |
| `.github/instructions/<path>/<name>.instructions.md`       | `docs/reference/instructions/<path>/<name>.md` |
| `.github/skills/<path>/<skill>/SKILL.md` and support files | `docs/reference/skills/<path>/<skill>.md`      |

Nested paths are preserved. For example,
`.github/agents/hve-core/subagents/phase-implementor.agent.md` maps to
`docs/reference/agents/hve-core/subagents/phase-implementor.md`.

## Know which regions you own

An asset page combines generated data with a human-authored tail. The boundary is
deliberate so metadata can refresh without erasing usage guidance.

| Region                                                               | Owner       | How to update it                             |
|----------------------------------------------------------------------|-------------|----------------------------------------------|
| YAML frontmatter                                                     | Generator   | Update the source asset and regenerate       |
| Metadata table between the `metadata` markers                        | Generator   | Update the source asset and regenerate       |
| `What it does` heading and content through the `overview` end marker | Generator   | Update the source description and regenerate |
| `When to use it`                                                     | Contributor | Edit the reference page                      |
| `How to use it`, when the asset is interactive                       | Contributor | Edit the reference page                      |
| `Example usage`                                                      | Contributor | Edit the reference page                      |

The authored tail starts after this marker:

```markdown
<!-- END AUTO-GENERATED: overview -->
```

`npm run docs:generate` preserves everything after that marker byte-for-byte.
Do not edit generated frontmatter, marker blocks, the `What it does` heading, or
catalog index pages by hand. A later generation run will replace those edits.

> [!CAUTION]
> Do not remove or rename the `AUTO-GENERATED` markers. The generator refuses to
> rewrite a page with damaged overview markers because rebuilding it could discard
> the authored tail.

## Update an asset and its page

Use this sequence whenever you add, change, move, or remove a documentable asset:

1. Edit the source artifact under `.github/`.
2. Run `npm run docs:generate` from the repository root.
3. Review the generated diff under `docs/reference/`. Confirm new, moved, and
   removed pages match the source change.
4. Update the authored tail of the paired page. Remove `<!-- asset-docs:stub -->`
   from each section after replacing its placeholder text.
5. Run `npm run docs:generate:check` to confirm a second generation pass reports
   no drift.
6. Run `npm run lint:asset-docs` to validate full-repository coverage, orphaned
   pages, required structure, and generated-region sync.
7. Run `npm run lint:md` and `npm run lint:md-links` before submitting the pull
   request.

For a new asset, generate its page before writing the authored sections. For an
existing asset, regenerate first so source-derived content is current, then review
the preserved authored tail for behavioral drift.

## Write useful authored sections

Use the authored tail to explain decisions that cannot be derived safely from
frontmatter alone:

* `When to use it` identifies the right scenarios, prerequisites, and nearby
  alternatives.
* `How to use it` explains invocation and the important steps for an interactive
  agent, prompt, or skill.
* `Example usage` shows representative input, the expected execution flow or
  output, and a clear success signal.

Keep examples specific enough to test. Avoid repeating the generated description
or promising behavior that the source artifact does not define.

### Draft examples with Prompt Builder

For user-invocable agents and skills, use the
[Prompt Builder](../reference/agents/hve-core/prompt-builder.md) authoring path to
develop and review a representative example while creating or improving the source
artifact. Prompt Builder routes the request through the HVE Builder lifecycle, so
the example can reflect reviewed behavior rather than an invented happy path.

Select **Prompt Builder** from the agent picker and provide both the source asset
and its paired reference page. A focused request can use this shape:

```text
Use /prompt-build to improve this asset and draft one representative usage example.
Include the user request, invocation, expected output, and success indicators so I
can add the verified example to the authored Example usage section.
```

Copy only the reviewed example into the authored tail. Do not ask Prompt Builder or
another model to rewrite generated regions.

## Understand the CI gate

Local and pull request validation use the same validator at different scopes:

| Context                   | Scope                | Enforcement                                                                |
|---------------------------|----------------------|----------------------------------------------------------------------------|
| `npm run lint:asset-docs` | Full repository      | Coverage, orphans, structure, and generated-region sync                    |
| Pull request validation   | Changed assets/pages | The same checks, limited to paths affected relative to the configured base |

The changed-files scope prevents unrelated pre-existing findings from blocking a
pull request. It still catches a changed source with a missing or stale page, a
changed page with no source, and renames or deletions that leave an orphan.

The generator and CI gate do not author human judgment. Stub detection starts as a
warning and becomes blocking by asset kind through the completeness rollout.

## Follow the completeness rollout

Authored-content enforcement is promoted incrementally so contributors can backfill
the catalog without making unrelated pull requests repair every existing stub at
once:

1. [Instructions (#2361)](https://github.com/microsoft/hve-core/issues/2361):
   require `When to use it`; `How to use it` is not applicable and `Example usage`
   is optional.
2. [Prompts (#2362)](https://github.com/microsoft/hve-core/issues/2362): require
   `When to use it`, `How to use it`, and `Example usage`.
3. [Skills (#2363)](https://github.com/microsoft/hve-core/issues/2363): require all
   applicable authored sections, with richer multi-mode examples where needed.
4. [Agents (#2364)](https://github.com/microsoft/hve-core/issues/2364): require all
   applicable authored sections, including orchestration, delegation, and handoff
   behavior where relevant.

Until enforcement is enabled for a kind, the validator can report authored stubs as
warnings. New and materially changed assets should still receive complete authored
sections now; the rollout changes enforcement timing, not the documentation quality
target.

## Resolve common failures

| Finding            | Resolution                                                                                |
|--------------------|-------------------------------------------------------------------------------------------|
| Missing page       | Run `npm run docs:generate`, then author the new page tail                                |
| Generated sync     | Update the source asset and run `npm run docs:generate`; do not patch the generated block |
| Orphaned page      | Restore the source asset or delete the obsolete page, then regenerate catalog indexes     |
| Missing markers    | Restore the expected markers from the template or delete and re-scaffold an unedited page |
| Authored stub      | Replace placeholder prose, remove the stub sentinel, and rerun validation                 |
| Inaccurate example | Re-test the source behavior and update only the authored `Example usage` section          |

If regeneration produces an unexpected broad diff, stop and inspect the source asset,
collection state, and generator output before committing. Generated churn is a signal
to investigate, not a reason to accept the diff wholesale.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
