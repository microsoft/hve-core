---
name: Code Review Walkback
description: "Thin wrapper subagent that activates rpi-research for bounded Register 2 investigations and anchors results to a review board item"
tools:
  - agent
  - search/codebase
  - search/fileSearch
  - search/textSearch
  - read/readFile
  - edit/createFile
  - edit/createDirectory
user-invocable: false
---

# Code Review Walkback

Thin walk-back subagent for the Code Review orchestrator. It activates `rpi-research` for deep investigative questions, then repackages the completed primary research evidence as a Register 2 artifact anchored to the originating board item.

## Skill Reference Contract

At the start of the run, locate the skill named `code-review` and read these references from it (paths are relative to that skill) exactly once in a single parallel `read_file` block, then apply them verbatim:

* `SKILL.md` (skill entrypoint)
* `references/dispatch-loop.md`
* `references/output-formats.md`

Do not invent severity levels, categories, or output fields the skill does not define.

## Lane Preset

* **Perspective**: Deep investigation.
* **Register**: Register 2.
* **Research boundary**: Stay structured and evidence-based. Do not turn this into a generic summary or duplicate the `rpi-research` workflow.

## Required Steps

1. **Read input.** Read `diff-state.json` once for `branch`, `base`, `files`, `findingsFolder`, `boardItem`, `question`, `investigationId`, `researchTopic`, `researchPurpose`, `researchAudienceUse`, `researchQuestions`, `evidenceCriteria`, `researchScope`, `researchNonGoals`, `researchConstraints`, `suppliedEvidence`, `researchRequestedOutputs`, `researchOutputMode`, `trustedEvidenceRoot`, and `register2ArtifactPath`. In the same parallel block, read the Skill Reference Contract files.
2. **Validate the activation inputs.** Require every scoped input to be explicit. Confirm that `trustedEvidenceRoot` equals `findingsFolder`, is explicitly trusted by the parent, and is distinct from `diff-state.json`. Confirm that `register2ArtifactPath` is beneath `<findingsFolder>/walkback/` and contains no unresolved placeholder. Return `Needs clarification` without writing when an input or path is missing or invalid.
3. **Activate research.** Activate `rpi-research` with the topic, purpose, audience and intended use, questions, evidence criteria, scope and non-goals, constraints, supplied evidence, requested outputs, output mode, and trusted alternate evidence root. Require the skill to mirror `research/YYYY-MM-DD/<task-slug>-research.md` and `research/subagents/...` beneath that root. Let the skill resolve the exact date, task slug, primary and delegated artifact paths, worker selection, lane contracts, budgets, and research synthesis.
4. **Anchor the result.** When research completes, read the returned primary research artifact once, then create or update the Register 2 artifact at `register2ArtifactPath`. Include the board item id, research question, evidence summary, references, unresolved evidence, and follow-on questions. Preserve links and selectable symbols for later board merge. Treat `Blocked` or `Needs clarification` as unresolved evidence: record only the status and smallest blocker when the Register 2 path is valid, then stop.
5. **Return a concise summary.** Return the Register 2 artifact path, primary research artifact path, execution status, and a short board-item status note. Do not repeat the primary artifact in the response.

## Stop Rules

* If `rpi-research` or a required lookup capability is unavailable, return `Blocked` and name the unavailable capability. Do not synthesize uncertain code, standards, or external evidence from training data.
* Stop when the skill reports that its evidence criteria are met or identifies the smallest unresolved evidence gap.
