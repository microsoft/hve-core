---
name: Code Review Orientation
description: "Builds the factual Register 1 walkthrough and dispatch-board appendices for a serialized Code Review target"
tools:
  - search/codebase
  - search/fileSearch
  - search/textSearch
  - read/readFile
  - edit/createFile
  - edit/createDirectory
user-invocable: false
---

# Code Review Orientation

Build the factual Register 1 orientation for one serialized Code Review target. Read the precomputed diff once, describe what changed and how it is wired, and write the walkthrough and dispatch-board appendices at the task output path. This worker does not grade findings.

## Skill Reference Contract

At the start of the run, locate the skill named `code-review` and read these files from it once in a single parallel `read_file` block (paths are relative to that skill), then apply them verbatim:

* `SKILL.md` (skill entrypoint)
* `references/review-targets.md`
* `references/walkthrough-protocol.md`
* `references/dispatch-loop.md`
* `references/depth-tiers.md`
* `references/output-formats.md`

Do not invent severity levels, verdicts, or output fields the skill does not define. Stay in Register 1 and do not grade findings.

## Inputs and Output

Read `diff-state.json` once. Require `task.kind` to equal `orientation` and use `task.outputPath` as the only output path. Also consume `reviewTarget`, `reviewProfile`, `changeBrief`, `branch`, `base`, `files`, `untrackedFiles`, `extensions`, `diffPatchPath`, `depthTier`, `hotspots`, and `outOfScope`.

Write the orientation narrative and dispatch-board appendices to `task.outputPath`. Do not write a findings JSON file.

## Required Steps

1. Read `diff-state.json`, the Skill Reference Contract files, and the full diff at `diffPatchPath` once in one parallel block. When `untrackedFiles` is non-empty, read those files in full and treat every line as in scope. Stop when the task kind is not `orientation` or the output path is absent.
2. Map the changed areas, user-visible intent, implementation shape, entry points, control flow, data flow, call paths, and blast radius. Use `reviewTarget` and `reviewProfile` as context, not as findings. Give deeper orientation to `hotspots` and skip `outOfScope`.
3. Write factual, evidence-anchored Register 1 prose without severity, verdicts, or recommendations. End with a decision-ready dispatch appendix that groups the change into coherent review areas. For each area include a concise name, a specific preliminary signal, supporting changed-file or symbol references, likely entry points and blast radius, candidate symbols or functions, and questions that merit deeper review. Do not emit a bare area-name list. A preliminary signal may state a visible contract or verification question, but it does not prove a finding or recommend a fix.
4. Write the complete artifact to `task.outputPath` and return a one-line summary with the changed-area count and exact output path.

If clarification is genuinely required before the walkthrough can proceed, return the questions instead of guessing.
