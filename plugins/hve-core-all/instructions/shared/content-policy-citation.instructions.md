---
description: "Content-policy and terms-of-service guardrails for public output and eval stimuli"
applyTo: '**/*.agent.md, **/*.prompt.md, **/*.instructions.md, **/SKILL.md, **/.github/workflows/*.md, **/.github/workflows/**/*.md, **/.github/hooks/**'
---

# Content Policy Output Guards

## Scope

These rules apply whenever an agent, skill, instruction, prompt, workflow, or hook produces content that can leave the local agent context. Covered surfaces include:

* Public GitHub and Azure DevOps output, including PR descriptions, PR review comments, issue titles, issue bodies, issue comments, generated review summaries, and workflow comments.
* Vally eval stimuli and imported eval corpora that may be committed, executed, or surfaced in CI reports.
* Workflow logs or artifacts that are likely to be attached to PRs, issues, or automated summaries.

These rules do not apply to private reasoning. Internal logs and step outputs that are never posted publicly may contain operational status, but they must not quote or paraphrase flagged content.

## Vally Stimulus Guard

Vally conformance tests must verify benign, documented artifact behavior. Do not author, import, or commit stimuli whose purpose is to elicit policy-violating output, bypass safeguards, reveal hidden instructions, extract secrets or PII, map refusal boundaries, or provoke model-refusal text for scoring.

When a requested eval would test a prohibited or terms-of-service-sensitive boundary, refuse the stimulus at category level without drafting payload text. Route legitimate safety assessment requests to the responsible AI, security, or content-safety planning workflow instead of embedding the scenario in Vally eval specs.

Use category labels only for internal refusal routing, opaque counters, or existing taxonomy references. Do not put payload examples, paraphrased prohibited requests, or quoted flagged content into eval prompts, expected outputs, grader descriptions, PR summaries, or issue comments.

## Public Output Guard

Before writing content to a GitHub issue, PR body, PR review, PR comment, workflow comment, or other public collaboration surface, scan the content for suspected content-policy or terms-of-service concerns and for internal classification artifacts copied from planning files.

If public output must flag a concern, use only neutral wording and the minimum reference needed for remediation. Do not include category names, sub-anchors, rationale details, payload examples, quoted snippets, or paraphrases of the flagged content.

## Citation Rules

* Cite the file path and line range only. Do not include a category label, a sub-anchor, a quoted snippet, or a paraphrase of the flagged content in the public output.
* Link only to the top-level anchor `https://learn.microsoft.com/legal/ai-code-of-conduct`. Never deep-link to in-page sections.
* Use neutral, uniform phrasing across all concerns. Reference template: `This line may not align with our content policies. Please review against [Microsoft content policies](https://learn.microsoft.com/legal/ai-code-of-conduct) before merging.` Adapt minimally for the surface without disclosing the underlying concern.
* Do not persist private classification artifacts. Per-finding category, sub-anchor, rationale, and quoted or paraphrased content stay in memory and are discarded once the public output is emitted. Any aggregate metrics persisted, such as logs or summaries, must be opaque counters without category breakdowns or content excerpts.

## Rationale

Posted output must not amplify or signpost flagged content. The same neutral surface is the only surface, regardless of which concern triggered the flag.
