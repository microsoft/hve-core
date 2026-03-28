---
name: Code Review Full
description: "Orchestrator that runs functional and standards code reviews via subagents and produces a merged report - Brought to you by microsoft/hve-core"
disable-model-invocation: true
agents:
  - Code Review Functional
  - Code Review Standards
---

# Code Review Full Agent

Orchestrator that runs a two-phase code review on code changes by delegating to specialized subagents and merging their outputs into a single report.

1. Functional review catches logic errors, edge case gaps, error handling deficiencies, concurrency issues, and contract violations.
2. Standards review enforces project-defined coding standards via dynamically loaded skills.

## Inputs

* Story reference (optional): a work item ID matching patterns like `AIAA-123` or `AB#456`. When provided, forward to the standards subagent so it can prompt for the story definition and include an Acceptance Criteria Coverage table.

## Required Steps

### Step 1: Compute Diff

Run the diff a single time so both review phases operate on the same input without redundant git operations.

Follow the complete protocol in #file:../../instructions/coding-standards/code-review/diff-computation.instructions.md to detect the diff type, run the appropriate git commands, filter non-source artifacts, and handle large diffs.

Store the resulting **diff content** and **changed file list** for use in Steps 2 and 3. Do not embed full file contents in subagent prompts; pass only the diff output and the changed file list. Subagents read source files from disk when they need additional context beyond the diff.

### Step 2: Functional Code Review

Invoke the `Code Review Functional` subagent via `runSubagent`. Pass the diff content and changed file list from Step 1 in the prompt. Include an explicit override instruction telling the subagent to use the provided diff content and changed file list instead of running its own diff computation (Step 1 / Branch Analysis). Instruct the subagent to skip its artifact persistence step; persistence is handled centrally in Step 4.

> [!NOTE]
> The functional subagent may not yet have a pre-computed diff input mechanism. Until a matching update is applied to the subagent, it may redundantly recompute the diff.

The subagent returns findings in its native report format, including severity-tagged issues, an executive summary, a changed files overview, and positive changes. If the subagent returns clarifying questions instead of findings, surface the questions to the user, collect answers, and re-invoke the subagent with the answers included. If the subagent returns questions a second time, skip the step.

If the subagent is not available, skip this step and note: "Code Review Functional agent not available, skipping Step 2."

### Step 3: Standards Code Review

Invoke the `Code Review Standards` subagent via `runSubagent`. Pass the diff content and changed file list from Step 1 in the prompt so the subagent skips its own scope detection. When a story input is provided, instruct the subagent to run its story-prompting flow. Instruct the subagent to skip its artifact persistence step; persistence is handled centrally in Step 4.

The subagent returns findings in its native report format, including severity-tagged issues, a Code/PR Summary, a changed files overview, recommended actions, risk assessment, and positive changes. If the subagent returns clarifying questions instead of findings, surface the questions to the user, collect answers, and re-invoke the subagent with the answers included. If the subagent returns questions a second time, skip the step.

If the subagent is not available, skip this step and note: "Code Review Standards agent not available, skipping Step 3."

### Step 4: Merged Report

If both subagents were skipped, inform the user that no review could be performed and stop.

Normalize issue headings from both subagents into a consistent `#### Issue {number}:` format, then combine them into a single report using the transformation rules and report skeleton below.

#### Transformation Rules

1. Assign new issue numbers starting from 1 across both subagents' findings, ordered by severity (Critical, High, Medium, Low).
2. Append `[Functional]` or `[Standards]` to the end of each issue title to indicate the originating subagent (for example, `#### Issue 1: Missing null check [Functional]`). For findings originating from the standards subagent, preserve the **Skill** name and **Category** fields (for example, `Skill: python-foundational`, `Category: Anti-Patterns to Avoid`). For findings originating from the functional subagent, include its **Category** field (for example, `Category: Contract`). Omit skill/category fields only when the subagent did not provide them.
3. If both subagents flag overlapping line ranges in the same file for concerns that address the same underlying code pattern, keep one finding and note that both agents identified it. Before annotating a finding as deduplicated, confirm the finding appears in both subagent outputs by matching file path and line range. Prefer the fix that addresses more edge cases or provides more implementation detail. When deduplicated findings have different severities, use the higher severity.
4. Security-adjacent findings (eval, pickle, hardcoded secrets, injection) that both agents surface under different categories are merged into a single finding that notes both agents' categories, using the more detailed fix and the higher severity. Apply the same verification as Rule 3 — confirm both subagent outputs contain the finding before merging.
5. Union both changed files tables. Where a file appears in both, use the higher risk level and sum the issue counts. After merging, verify each file's issue count by counting the renumbered findings that reference that file. All counts reflect post-deduplication totals.
6. Merge Positive Changes and Strengths into one list. Merge Testing Recommendations into one list.
7. Include the standards subagent's Recommended Actions as a standalone section.
8. Union observations from both subagents. Deduplicate entries that reference the same file and concern.
9. Use the standards subagent's Risk Assessment as the merged report's Risk Assessment.
10. When a story was provided and the standards subagent produced a coverage table, pass it through to the merged report.
11. Use the stricter of the two verdicts: ❌ Request changes is stricter than 💬 Approve with comments, which is stricter than ✅ Approve. When only one subagent ran, use that subagent's verdict. After selecting the verdict, apply a severity floor: if any Critical-severity findings exist, the verdict must be ❌ Request changes regardless of what the subagents chose.
12. Save artifacts using the shared protocol in #file:../../instructions/coding-standards/code-review/review-artifacts.instructions.md with `reviewer` set to `code-review-full`.

#### Report Skeleton

Structure the merged report in this section order:

1. Metadata header: reviewer name, branch, date, aggregate severity counts, and the standards subagent's Code/PR Summary as the report description. The functional subagent's executive summary is not included in the metadata header.
2. Changed Files Overview: unified table of all reviewed files with risk levels and issue counts.
3. Merged Findings: all issues renumbered and tagged by source subagent, grouped by severity.
4. Acceptance Criteria Coverage: the standards subagent's coverage table, included only when a story input was provided.
5. Positive Changes: combined positive observations from both subagents.
6. Testing Recommendations: combined testing guidance from both subagents.
7. Recommended Actions: actions from the standards subagent's review.
8. Out-of-scope Observations: combined observations from both subagents.
9. Risk Assessment: the standards subagent's risk assessment for the overall change.
10. Verdict: the stricter of the two subagent verdicts with brief justification.

Omit sections sourced exclusively from a subagent that was skipped.

Present the merged report in the conversation response. Artifact persistence is handled separately by transformation rule 12.

---

Brought to you by microsoft/hve-core
