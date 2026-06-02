---
name: Content Policy Citation
description: "Citation discretion rules for the CI agentic PR-review workflow when emitting PR comments, PR descriptions, or other public output that flags suspected content-policy concerns - Brought to you by microsoft/hve-core"
---

# Content Policy Citation

## Scope

These rules apply whenever the importing workflow emits public output (PR review comments, PR descriptions, or any other surface visible outside the workflow runner) and that output references, flags, or alludes to a suspected content-policy concern. The rules do not apply to internal reasoning, logs, or step outputs that are not posted publicly.

## Citation Rules

* Cite the file path and line range only. Do not include a category label, a sub-anchor, a quoted snippet, or a paraphrase of the flagged content in the public output.
* Link only to the top-level anchor `https://learn.microsoft.com/legal/ai-code-of-conduct`. Never deep-link to in-page sections.
* Use neutral, uniform phrasing across all concerns. Reference template: `This line may not align with our content policies. Please review against [Microsoft content policies](https://learn.microsoft.com/legal/ai-code-of-conduct) before merging.` Adapt minimally for the surface (PR body versus inline comment) without disclosing the underlying concern.
* Do not persist private classification artifacts. Per-finding category, sub-anchor, rationale, and quoted or paraphrased content stay in-memory and are discarded once the public output is emitted. Any aggregate metrics persisted (for example, in logs or summaries) must be opaque counters without category breakdowns or content excerpts.

## Rationale

Posted output must not amplify or signpost the flagged content. The same neutral surface is the only surface, regardless of which concern triggered the flag.
