---
title: Agent Behavior Suite
description: 'Per-agent behavioral evals assembled from per-agent stimulus partials and graded against five class recipes'
author: HVE Core Team
ms.date: 2026-06-24
---

## Purpose

This suite covers every user-invocable hve-core agent with at least one functional stimulus and at least one functional grader, so a regression in any single agent's behavior is detectable from a per-agent eval run.

The complement to [baseline-equivalence](../baseline-equivalence/README.md) is intentional: baseline-equivalence asserts the customization layer does not alter underlying model behavior beyond documented divergences, while agent-behavior asserts each agent actually performs its declared job.

The suite is organized around five behavioral classes (research-writer, code-reviewer, code-implementor, workitem-manager, planner-coach). Every parent agent belongs to exactly one class, and class membership selects the stimulus shape and grader template used in [stimuli/](stimuli/). The 44-agent inventory at the bottom of this document is the authoritative class assignment.

## Layout

```text
evals/agent-behavior/
├── README.md           # this file
├── AGENTS.yml          # authoritative inventory (slug, path, class, cost_tier)
├── eval.yaml           # generated executable spec - do not edit by hand
└── stimuli/
    └── <agent-slug>.yml  # one partial per user-invocable agent (47 files)
```

The partials in [stimuli/](stimuli/) are the source of truth for stimuli. The top-level [eval.yaml](eval.yaml) is regenerated from those partials by [scripts/evals/Build-AgentBehaviorSpec.ps1](../../scripts/evals/Build-AgentBehaviorSpec.ps1). The inventory at [AGENTS.yml](AGENTS.yml) is regenerated from the agent frontmatter on disk by [scripts/evals/Build-AgentInventory.ps1](../../scripts/evals/Build-AgentInventory.ps1) and the agent-behavior generator only reads slugs whose partials exist in [stimuli/](stimuli/).

## Generator Workflow

The generator concatenates every [stimuli/](stimuli/) partial, prepends the file banner, and writes the result to [eval.yaml](eval.yaml). It auto-injects `tags.agent: <slug>` on every stimulus from the partial filename. Partials must declare `tags.category` explicitly.

```bash
# Regenerate the spec from partials
pwsh -NoProfile -File scripts/evals/Build-AgentBehaviorSpec.ps1 -Force

# Drift check (CI-safe): exit 0 if eval.yaml matches rendered output, exit 1 + diff if not
pwsh -NoProfile -File scripts/evals/Build-AgentBehaviorSpec.ps1 -WhatIf
```

When the drift check fails, a unified diff is written to [logs/agent-behavior-spec-drift.diff](../../logs/agent-behavior-spec-drift.diff). Inspect that file, re-run the generator with `-Force`, and commit the regenerated [eval.yaml](eval.yaml) alongside any stimulus partial change in the same commit.

The drift check is wired into the repository's `eval:lint:vally` npm script in [package.json](../../package.json) so vally lint cannot pass while [eval.yaml](eval.yaml) is out of sync with the partials.

## Class Recipes

Each parent agent belongs to exactly one class. The class selects the stimulus shape (a generic prompt the agent should reasonably respond to) and the functional grader (a regex over the agent's response that captures one declared behavior of the class). Placeholder partials authored in Phase 1 use these templates; Phase 2 replaces each placeholder with a tuned, class-specific stimulus per [the plan](../../.copilot-tracking/plans/2026-05-25/per-agent-vally-eval-coverage-plan.instructions.md).

| Class           | Members | Prompt Theme                                                    | Grader Regex (case-insensitive)                           |
|-----------------|---------|-----------------------------------------------------------------|-----------------------------------------------------------|
| research-writer | 9       | Investigate or document a topic and return a structured writeup | `(summary\|findings\|recommendation\|outline\|sections?)` |
| code-reviewer   | 7       | Review a diff or artifact and surface concerns                  | `(issue\|risk\|severity\|finding\|recommend\|line \d+)`   |
| code-implementor  | 6       | Implement or modify code to satisfy a spec                            | `(```\|patch\|diff\|file:\|edit\|add\|modify)`                                             |
| workitem-manager  | 8       | Convert a raw request into a backlog draft                            | `(title\|summary\|description\|acceptance\|priority\|severity\|repro\|steps)`              |
| planner-coach     | 15      | Plan, sequence, or coach the user through a non-trivial task          | `(plan\|step \d+\|next\|approach\|consider\|recommend\|phase)`                             |

The grader counts a stimulus as passing when the regex matches the agent's response at least once. This is a behavioral smoke gate: the suite asserts the agent produced an output shaped like its job, not that the output is correct. Correctness is the responsibility of the per-agent integration tests and the baseline-equivalence harness, not this suite.

### Path Separators in Tracking-File Graders

Graders that assert a tracking-file write (`tracking-file-write` and any pattern referencing a `.copilot-tracking/...` path) must accept a hyphen as a path separator in addition to forward and back slashes. Use the separator class `[-/\\]` rather than `[/\\]`:

```yaml
# Correct - tolerates flattened paths
config:
  pattern: '(?i)\.copilot-tracking[-/\\]research'

# Fragile - misses flattened paths
config:
  pattern: '(?i)\.copilot-tracking[/\\]research'
```

vally executes each stimulus in an isolated temporary sandbox. When an agent writes to `.copilot-tracking/`, the sandbox can flatten the path segments by replacing slashes with hyphens (for example, reporting `.copilot-tracking-research-...` instead of `.copilot-tracking/research/...`). A grader pinned to slash-only separators silently misses that write and produces a false negative.

Apply `[-/\\]` only to positive separator classes inside tracking-file path patterns. Do not change:

* Negated separator classes such as `[^/\\\s]` - adding a hyphen alters the negation set and changes matching semantics.
* Prose or other regex contexts where `[/\\]` is not acting as a path separator.

### Canonical phase-marker Pattern

The `phase-marker-present` grader used by the planner-coach class must use the canonical permissive pattern below. Every stimulus that declares this grader uses the identical pattern so phase-detection behavior is consistent across all planner-coach agents:

```yaml
config:
  pattern: '(?im)(^\s*(#{2,3}\s|step\s+\d+|phase\s+\d+|\d+[.)])|\|\s*\d+\s*[—–-]|\bphases?\b)'
```

The pattern is permissive by design. A planner-coach agent signals structured, sequenced work in several valid ways, and the grader must accept all of them:

* `(?im)` - case-insensitive and multiline, so `Phase`, `phase`, and `PHASE` all match and `^` anchors to any line.
* `^\s*` - tolerates leading whitespace so indented list items and nested sections still count.
* `#{2,3}\s` - matches `##` or `###` markdown headings.
* `step\s+\d+` / `phase\s+\d+` / `\d+[.)]` - matches `Step 1`, `Phase 2`, and both `1.` and `1)` numbered list forms.
* `\|\s*\d+\s*[—–-]` - matches a numbered table cell such as `| 1 — Discovery`, including em-dash, en-dash, and hyphen.
* `\bphases?\b` - a prose fallback that matches inline mentions like `four consolidation phases` when no leading marker is present.

The strict earlier pattern `(?m)^(##|###|Step \d+|Phase \d+|\d+\.)` produced false negatives: a model could return valid, well-sequenced output whose phase structure appeared in a bold inline phrase or a table cell rather than on a leading heading or numbered line. The canonical pattern closes those gaps while remaining a behavioral smoke gate, not a correctness check.

When authoring or updating a planner-coach stimulus, copy the canonical pattern verbatim rather than hand-writing a variant.

### Class 1: research-writer

Agents that investigate topics, analyze data, or produce structured documents as their primary output.

**Members (8):** task-researcher, adr-creation, brd-builder, meeting-analyst, network-isa95-planner, prd-builder, system-architecture-reviewer, ux-ui-designer

**Required Graders:**

* `tracking-file-write` - Validates the agent writes to `.copilot-tracking/` (or the appropriate tracking directory declared in the agent's scope).
* `no-source-edit` - Validates the agent does not modify source code files (disallowed pattern: `(?i)(\.cs|\.py|\.ts|\.js|\.go|\.rs|\.java|package\.json)` edits outside tracking scope).
* `topic-coverage` - Validates the output contains key terminology from the prompt topic (agent-specific regex, tuned per stimulus).

**Optional Graders:**

* `header-present` - When the agent's `.agent.md` includes a `Start responses with:` directive, validates the header appears. Pattern: `^## 🔬 Task Researcher:` (adjusted per agent's declared prefix).

#### Worked Example: task-researcher

```yaml
# evals/agent-behavior/stimuli/task-researcher.yml
stimuli:
  - name: task-researcher-creates-research-doc
    prompt: |
      Research the question "What npm scripts validate markdown in this repository?"
      and produce a research document. Limit the work to one pass and tell me
      where you wrote the document.
    tags:
      category: agent-behavior
    graders:
      - type: output-matches
        name: header-present
        config:
          pattern: '^## 🔬 Task Researcher:'
      - type: output-matches
        name: tracking-file-write
        config:
          pattern: '(?i)\.copilot-tracking/research'
      - type: output-matches
        name: topic-coverage
        config:
          pattern: '(?i)(npm|script|lint|markdown|validate)'
      - type: output-matches
        name: no-source-edit
        config:
          pattern: '(?i)(\.cs|\.py|\.ts|\.js|package\.json)'
          negate: true
```

### Class 2: code-reviewer

Agents that analyze code, diffs, or artifacts and surface issues, risks, or recommendations.

**Members (7):** code-review, dependency-reviewer, rai-reviewer, accessibility-reviewer, security-reviewer, supply-chain-reviewer, task-reviewer

**Required Graders:**

* `findings-table-present` - Validates the output contains a structured findings table (pattern: `(?m)^\|.*\|.*\|` or similar markdown table marker).
* `severity-vocab` - Validates severity vocabulary is used (pattern: `(?i)(critical|high|medium|low|info|severity)`).
* `no-source-edit` - Validates the agent does not modify source code files.

**Optional Graders:**

* `header-present` - No code-reviewer agents currently declare a `Start responses with:` directive. This grader is omitted for all 7 members of this class.

#### Worked Example: code-review

```yaml
# evals/agent-behavior/stimuli/code-review.yml
stimuli:
  - name: code-review-identifies-security
    prompt: |
      Review this diff and identify any security concerns:
      ```diff
      -password = input("Enter password: ")
      +password = getpass("Enter password: ")
      ```
    tags:
      category: agent-behavior
    graders:
      - type: output-matches
        name: findings-table-present
        config:
          pattern: '(?m)^\|.*\|.*\|'
      - type: output-matches
        name: severity-vocab
        config:
          pattern: '(?i)(security|credential|password|risk|severity)'
      - type: output-matches
        name: no-source-edit
        config:
          pattern: '(?i)(\.cs|\.py|\.ts|\.js|package\.json)'
          negate: true
```

### Class 3: code-implementor

Agents that generate, modify, or produce runnable code as their primary output.

**Members (6):** eval-dataset-creator, gen-data-spec, gen-jupyter-notebook, gen-streamlit-dashboard, task-implementor, test-streamlit-dashboard

**Required Graders:**

* `source-edit-present` - Validates the agent writes or edits code files (pattern: `` (?i)(```|created|modified|edited|file:.*\.(py|cs|ts|js)) ``).
* `lint-invocation` - Validates the agent mentions or runs lint commands before completion (pattern: `(?i)(npm run lint|ruff|pylint|eslint|validation|format)`).
* `scope-respect` - Validates writes stay within the documented scope. For `task-implementor`, this means no edits outside the files explicitly mentioned in the prompt. For data-science agents, this means outputs stay under the data output folder.

**Optional Graders:**

* `header-present` - Only `task-implementor` declares a `Start responses with: ## ⚡ Task Implementor:` directive. Other code-implementor agents omit this grader.

#### Worked Example: task-implementor

```yaml
# evals/agent-behavior/stimuli/task-implementor.yml
stimuli:
  - name: task-implementor-edits-source
    prompt: |
      Implement a simple "hello world" function in a new file called `hello.py`.
      Use proper Python conventions and add a docstring.
    tags:
      category: agent-behavior
    graders:
      - type: output-matches
        name: header-present
        config:
          pattern: '^## ⚡ Task Implementor:'
      - type: output-matches
        name: source-edit-present
        config:
          pattern: '(?i)(```python|created.*hello\.py|file:.*hello\.py)'
      - type: output-matches
        name: lint-invocation
        config:
          pattern: '(?i)(ruff|pylint|lint|format|validate)'
      - type: output-matches
        name: scope-respect
        config:
          pattern: 'hello\.py'
```

### Class 4: workitem-manager

Agents that convert user requests, PRDs, or triage input into work item drafts (ADO, GitHub, Jira).

**Members (8):** ado-backlog-manager, ado-prd-to-wit, agile-coach, github-backlog-manager, issue-triage, jira-backlog-manager, jira-prd-to-wit, product-manager-advisor

**Required Graders:**

* `field-vocab-present` - Validates work-item field vocabulary appears in the output. Pattern varies by platform:
  * ADO: `(?i)(title|description|acceptance criteria|iteration|area path|priority|work item type)`
  * GitHub: `(?i)(title|body|label|milestone|assignee)`
  * Jira: `(?i)(summary|description|issue type|priority|component|sprint)`
* `no-source-edit` - Validates the agent does not modify source code files.
* `tracking-file-write` - Validates the agent writes to `.copilot-tracking/workitems/` or `.copilot-tracking/github-issues/` or `.copilot-tracking/jira-issues/`.

**Optional Graders:**

* `header-present` - No workitem-manager agents currently declare a `Start responses with:` directive. This grader is omitted for all 8 members of this class.

#### Worked Example: github-backlog-manager

```yaml
# evals/agent-behavior/stimuli/github-backlog-manager.yml
stimuli:
  - name: github-backlog-manager-creates-issue-draft
    prompt: |
      The app crashes when I click the "Submit" button on the contact form.
      Generate a GitHub issue draft for this bug.
    tags:
      category: agent-behavior
    graders:
      - type: output-matches
        name: field-vocab-present
        config:
          pattern: '(?i)(title|body|label|steps to reproduce|expected|actual)'
      - type: output-matches
        name: tracking-file-write
        config:
          pattern: '(?i)\.copilot-tracking/(github-issues|workitems)'
      - type: output-matches
        name: no-source-edit
        config:
          pattern: '(?i)(\.cs|\.py|\.ts|\.js|package\.json)'
          negate: true
```

### Class 5: planner-coach

Agents that sequence work, plan tasks, coach the user through a process, or orchestrate multi-phase workflows.

**Members (15):** accessibility-planner, agentic-workflows, documentation, dt-coach, dt-learning-tutor, experiment-designer, memory, pptx, prompt-builder, rai-planner, rpi-agent, security-planner, sssc-planner, task-challenger, task-planner

**Required Graders:**

* `phase-marker-present` - Validates the output contains numbered phases, steps, or structured sections. Use the canonical permissive pattern documented in [Canonical phase-marker Pattern](#canonical-phase-marker-pattern): `(?im)(^\s*(#{2,3}\s|step\s+\d+|phase\s+\d+|\d+[.)])|\|\s*\d+\s*[—–-]|\bphases?\b)`.
* `no-source-edit` - Validates the agent does not modify source code files.
* `tracking-file-write` - Validates the agent writes to `.copilot-tracking/plans/` or `.copilot-tracking/dt/` or `.copilot-tracking/security-plans/`.

**Optional Graders:**

* `header-present` - Only `task-planner` declares a `Start responses with:` directive. Others omit this grader.

#### Worked Example: task-planner

```yaml
# evals/agent-behavior/stimuli/task-planner.yml
stimuli:
  - name: task-planner-creates-plan
    prompt: |
      Plan the implementation of a "forgot password" feature for a web app.
      Break it into phases with clear success criteria.
    tags:
      category: agent-behavior
    graders:
      - type: output-matches
        name: header-present
        config:
          pattern: '^## 📋 Task Planner:'
      - type: output-matches
        name: phase-marker-present
        config:
          pattern: '(?im)(^\s*(#{2,3}\s|step\s+\d+|phase\s+\d+|\d+[.)])|\|\s*\d+\s*[—–-]|\bphases?\b)'
      - type: output-matches
        name: tracking-file-write
        config:
          pattern: '(?i)\.copilot-tracking/plans'
      - type: output-matches
        name: no-source-edit
        config:
          pattern: '(?i)(\.cs|\.py|\.ts|\.js|package\.json)'
          negate: true
```

## How to Add a Stimulus

The harness does not need code changes to onboard a new agent or add a stimulus to an existing one:

1. Add or edit the partial at [stimuli/](stimuli/)`<agent-slug>.yml`. A partial is a list of stimulus objects. The shape mirrors a single entry under `tests:` in a vally spec, minus the `agent:` tag (the generator injects that automatically from the filename). Partials must declare `tags.category` and at least one grader.
2. Run `pwsh -NoProfile -File scripts/evals/Build-AgentBehaviorSpec.ps1 -Force` to regenerate [eval.yaml](eval.yaml).
3. Commit the partial and the regenerated [eval.yaml](eval.yaml) in the same commit. The drift check in `npm run eval:lint:vally` will reject the change otherwise.

For an entirely new agent, also re-run [Build-AgentInventory.ps1](../../scripts/evals/Build-AgentInventory.ps1) so [AGENTS.yml](AGENTS.yml) picks up the new slug, then update the inventory table at the bottom of this README. Agents whose frontmatter declares `user-invocable: false` are excluded from this suite by design.

## Onboarded Agents

The inventory lists every user-invocable hve-core parent agent and its class assignment. The Phase 1 partials in [stimuli/](stimuli/) are placeholders carrying a `notes: 'TODO(phase-2): replace with <class> class recipe ...'` marker; Phase 2 swaps each placeholder for a class-specific stimulus. Class membership is stable across that transition.

| Agent                        | Class            | Cost Tier | Agent File                                                                                                                                           |
|------------------------------|------------------|-----------|------------------------------------------------------------------------------------------------------------------------------------------------------|
| accessibility-planner        | planner-coach    | light     | [.github/agents/accessibility/accessibility-planner.agent.md](../../.github/agents/accessibility/accessibility-planner.agent.md)                     |
| accessibility-reviewer       | code-reviewer    | light     | [.github/agents/accessibility/accessibility-reviewer.agent.md](../../.github/agents/accessibility/accessibility-reviewer.agent.md)                   |
| ado-backlog-manager          | workitem-manager | light     | [.github/agents/ado/ado-backlog-manager.agent.md](../../.github/agents/ado/ado-backlog-manager.agent.md)                                             |
| ado-prd-to-wit               | workitem-manager | light     | [.github/agents/ado/ado-prd-to-wit.agent.md](../../.github/agents/ado/ado-prd-to-wit.agent.md)                                                       |
| adr-creation                 | research-writer  | light     | [.github/agents/project-planning/adr-creation.agent.md](../../.github/agents/project-planning/adr-creation.agent.md)                                 |
| agentic-workflows            | planner-coach    | light     | [.github/agents/agentic-workflows.agent.md](../../.github/agents/agentic-workflows.agent.md)                                                         |
| agile-coach                  | workitem-manager | light     | [.github/agents/project-planning/agile-coach.agent.md](../../.github/agents/project-planning/agile-coach.agent.md)                                   |
| brd-builder                  | research-writer  | light     | [.github/agents/project-planning/brd-builder.agent.md](../../.github/agents/project-planning/brd-builder.agent.md)                                   |
| code-review                  | code-reviewer    | light     | [.github/agents/coding-standards/code-review.agent.md](../../.github/agents/coding-standards/code-review.agent.md)                                   |
| dependency-reviewer          | code-reviewer    | light     | [.github/agents/dependency-reviewer.agent.md](../../.github/agents/dependency-reviewer.agent.md)                                                     |
| documentation                | planner-coach    | light     | [.github/agents/hve-core/documentation.agent.md](../../.github/agents/hve-core/documentation.agent.md)                                               |
| dt-coach                     | planner-coach    | light     | [.github/agents/design-thinking/dt-coach.agent.md](../../.github/agents/design-thinking/dt-coach.agent.md)                                           |
| dt-learning-tutor            | planner-coach    | light     | [.github/agents/design-thinking/dt-learning-tutor.agent.md](../../.github/agents/design-thinking/dt-learning-tutor.agent.md)                         |
| eval-dataset-creator         | code-implementor | light     | [.github/agents/data-science/eval-dataset-creator.agent.md](../../.github/agents/data-science/eval-dataset-creator.agent.md)                         |
| experiment-designer          | planner-coach    | light     | [.github/agents/experimental/experiment-designer.agent.md](../../.github/agents/experimental/experiment-designer.agent.md)                           |
| gen-data-spec                | code-implementor | light     | [.github/agents/data-science/gen-data-spec.agent.md](../../.github/agents/data-science/gen-data-spec.agent.md)                                       |
| gen-jupyter-notebook         | code-implementor | light     | [.github/agents/data-science/gen-jupyter-notebook.agent.md](../../.github/agents/data-science/gen-jupyter-notebook.agent.md)                         |
| gen-streamlit-dashboard      | code-implementor | light     | [.github/agents/data-science/gen-streamlit-dashboard.agent.md](../../.github/agents/data-science/gen-streamlit-dashboard.agent.md)                   |
| github-backlog-manager       | workitem-manager | light     | [.github/agents/github/github-backlog-manager.agent.md](../../.github/agents/github/github-backlog-manager.agent.md)                                 |
| issue-triage                 | workitem-manager | light     | [.github/agents/issue-triage.agent.md](../../.github/agents/issue-triage.agent.md)                                                                   |
| jira-backlog-manager         | workitem-manager | light     | [.github/agents/jira/jira-backlog-manager.agent.md](../../.github/agents/jira/jira-backlog-manager.agent.md)                                         |
| jira-prd-to-wit              | workitem-manager | light     | [.github/agents/jira/jira-prd-to-wit.agent.md](../../.github/agents/jira/jira-prd-to-wit.agent.md)                                                   |
| meeting-analyst              | research-writer  | light     | [.github/agents/project-planning/meeting-analyst.agent.md](../../.github/agents/project-planning/meeting-analyst.agent.md)                           |
| memory                       | planner-coach    | light     | [.github/agents/hve-core/memory.agent.md](../../.github/agents/hve-core/memory.agent.md)                                                             |
| network-isa95-planner        | research-writer  | light     | [.github/agents/project-planning/network-isa95-planner.agent.md](../../.github/agents/project-planning/network-isa95-planner.agent.md)               |
| pptx                         | planner-coach    | light     | [.github/agents/experimental/pptx.agent.md](../../.github/agents/experimental/pptx.agent.md)                                                         |
| prd-builder                  | research-writer  | light     | [.github/agents/project-planning/prd-builder.agent.md](../../.github/agents/project-planning/prd-builder.agent.md)                                   |
| product-manager-advisor      | workitem-manager | light     | [.github/agents/project-planning/product-manager-advisor.agent.md](../../.github/agents/project-planning/product-manager-advisor.agent.md)           |
| prompt-builder               | planner-coach    | light     | [.github/agents/hve-core/prompt-builder.agent.md](../../.github/agents/hve-core/prompt-builder.agent.md)                                             |
| rai-planner                  | planner-coach    | light     | [.github/agents/rai-planning/rai-planner.agent.md](../../.github/agents/rai-planning/rai-planner.agent.md)                                           |
| rai-reviewer                 | code-reviewer    | light     | [.github/agents/rai-planning/rai-reviewer.agent.md](../../.github/agents/rai-planning/rai-reviewer.agent.md)                                         |
| rpi-agent                    | planner-coach    | light     | [.github/agents/hve-core/rpi-agent.agent.md](../../.github/agents/hve-core/rpi-agent.agent.md)                                                       |
| security-planner             | planner-coach    | light     | [.github/agents/security/security-planner.agent.md](../../.github/agents/security/security-planner.agent.md)                                         |
| security-reviewer            | code-reviewer    | light     | [.github/agents/security/security-reviewer.agent.md](../../.github/agents/security/security-reviewer.agent.md)                                       |
| sssc-planner                 | planner-coach    | light     | [.github/agents/security/sssc-planner.agent.md](../../.github/agents/security/sssc-planner.agent.md)                                                 |
| supply-chain-reviewer        | code-reviewer    | light     | [.github/agents/security/supply-chain-reviewer.agent.md](../../.github/agents/security/supply-chain-reviewer.agent.md)                               |
| system-architecture-reviewer | research-writer  | light     | [.github/agents/project-planning/system-architecture-reviewer.agent.md](../../.github/agents/project-planning/system-architecture-reviewer.agent.md) |
| task-challenger              | planner-coach    | light     | [.github/agents/hve-core/task-challenger.agent.md](../../.github/agents/hve-core/task-challenger.agent.md)                                           |
| task-implementor             | code-implementor | light     | [.github/agents/hve-core/task-implementor.agent.md](../../.github/agents/hve-core/task-implementor.agent.md)                                         |
| task-planner                 | planner-coach    | light     | [.github/agents/hve-core/task-planner.agent.md](../../.github/agents/hve-core/task-planner.agent.md)                                                 |
| task-researcher              | research-writer  | light     | [.github/agents/hve-core/task-researcher.agent.md](../../.github/agents/hve-core/task-researcher.agent.md)                                           |
| task-reviewer                | code-reviewer    | light     | [.github/agents/hve-core/task-reviewer.agent.md](../../.github/agents/hve-core/task-reviewer.agent.md)                                               |
| test-streamlit-dashboard     | code-implementor | light     | [.github/agents/data-science/test-streamlit-dashboard.agent.md](../../.github/agents/data-science/test-streamlit-dashboard.agent.md)                 |
| ux-ui-designer               | research-writer  | light     | [.github/agents/project-planning/ux-ui-designer.agent.md](../../.github/agents/project-planning/ux-ui-designer.agent.md)                             |

The inventory totals 48 user-invocable parent agents. Subagent-only agents (`codebase-profiler`, `finding-deep-verifier`, `report-generator`, `skill-assessor`) declare `user-invocable: false` in their frontmatter and are excluded from this suite; they remain covered by their parent agents' stimuli and by the dependency-map dispatch path documented in [evals/baseline-equivalence/README.md](../baseline-equivalence/README.md).

## Related Suites

* [evals/baseline-equivalence/README.md](../baseline-equivalence/README.md) - Asserts the customization layer does not alter model behavior beyond documented divergences. Pairs cleanly with this suite: baseline-equivalence detects unintentional behavior change, agent-behavior detects regressions in the intentional behavior each agent declares.
* [docs/contributing/evals-ci.md](../../docs/contributing/evals-ci.md) - PR-tier and nightly-tier dispatch, the manifest-driven changed-artifact lane, and the stimulus-index reverse map shared with this suite.

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
