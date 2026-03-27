---
title: Agentic Workflows
description: End-to-end process flow for AI-driven issue triage, implementation, and review workflows in hve-core
author: HVE Core Team
ms.date: 2026-03-27
ms.topic: concept
sidebar_position: 4
keywords:
  - agentic workflows
  - issue triage
  - automated implementation
  - pr review
  - github copilot
  - process flow
---

hve-core uses GitHub Agentic Workflows to automate the journey from issue creation through implementation and code review. Three event-driven workflows connect specialized agents into a pipeline where each stage triggers the next through labels, pull requests, and GitHub events.

## End-to-End Process Flow

```mermaid
flowchart TD
    subgraph TRIGGER["Issue Created or Labeled"]
        A["New issue opened<br/>or labeled needs-triage"]
    end

    subgraph TRIAGE["Issue Triage Workflow"]
        B["Read issue title, body,<br/>and template metadata"]
        C["Classify by type<br/>and component"]
        D["Detect duplicates<br/>via keyword search"]
        E["Assess issue quality"]
        F{"Scope too broad<br/>for single deliverable?"}
        G["Decompose into<br/>sub-issues"]
        H{"Passes all<br/>agent-ready criteria?"}
        I["Apply labels,<br/>remove needs-triage"]
        J["Add agent-ready label"]
        K["Leave for human<br/>review"]
    end

    subgraph IMPLEMENT["Issue Implementation Workflow"]
        L["Read issue and<br/>acceptance criteria"]
        M["Research codebase:<br/>files, patterns, conventions"]
        N["Plan minimal<br/>change set"]
        O["Implement changes"]
        P["Verify against<br/>acceptance criteria"]
        Q["Open pull request<br/>referencing the issue"]
    end

    subgraph REVIEW["PR First-Pass Review Workflow"]
        R["Detect PR opened<br/>or ready for review"]
        S["Analyze diff against<br/>coding standards"]
        T["Check conventions,<br/>security, quality"]
        U{"Review passed?"}
        V["Add review-passed label"]
        W["Add needs-revision label<br/>with inline comments"]
    end

    subgraph HUMAN["Human Review"]
        X["Maintainer reviews<br/>and merges"]
    end

    A --> B
    B --> C
    C --> D
    D --> E
    E --> F
    F -- Yes --> G
    G --> I
    F -- No --> H
    H -- Yes --> I
    I --> J
    H -- No --> I
    I --> K
    J --> L
    L --> M
    M --> N
    N --> O
    O --> P
    P --> Q
    Q --> R
    R --> S
    S --> T
    T --> U
    U -- Yes --> V
    V --> X
    U -- No --> W
    W -.-> O
```

## Workflow Details

### Issue Triage

The triage workflow activates when an issue is opened or receives the `needs-triage` label. It runs the [Issue Triage Agent](https://github.com/microsoft/hve-core/blob/main/.github/agents/github/issue-triage.agent.md), which performs these steps in sequence:

1. Read the issue title, body, labels, and template metadata.
2. Classify by type using conventional commit title patterns (`feat:`, `fix:`, `docs:`, etc.) and map to labels like `feature`, `bug`, `documentation`, or `maintenance`.
3. Classify by component based on template dropdowns or body content, applying scope labels such as `agents`, `prompts`, `instructions`, or `skills`.
4. Search for duplicate issues using extracted keywords and flag potential matches with confidence qualifiers.
5. Assess quality by checking for specific scope, actionable acceptance criteria, and internal consistency. Request missing information when needed.
6. Decompose oversized issues into sub-issues when the scope spans multiple components or contains independent acceptance criteria. Each sub-issue is created via the GitHub API and linked to the parent.
7. Apply determined labels and remove `needs-triage`.
8. Evaluate `agent-ready` eligibility. Issues that are scoped to a single well-defined change, reference specific files, pass quality checks, and are not duplicates or security issues receive the `agent-ready` label.

> [!TIP]
> The triage agent does not close issues, assign users, or modify issue titles. It only classifies, labels, and optionally decomposes.

### Issue Implementation

The implementation workflow activates when an issue receives the `agent-ready` label. It imports the [Task Implementor Agent](https://github.com/microsoft/hve-core/blob/main/.github/agents/hve-core/task-implementor.agent.md) and follows a streamlined procedure:

1. Read the issue title, description, and acceptance criteria.
2. Search the codebase for relevant files, existing patterns, and applicable instruction files under `.github/instructions/`.
3. Outline the minimal change set needed to satisfy the issue.
4. Implement the changes, mirroring existing architecture, naming, and data flow patterns.
5. Verify changes compile, follow conventions, and satisfy acceptance criteria.
6. Open a pull request referencing the issue with a clear description.

If the issue is ambiguous or too large, the agent posts a comment requesting clarification instead of guessing.

> [!NOTE]
> The implementation agent keeps PRs small and focused. It does not add tests, documentation, or refactoring beyond what the issue explicitly requests.

### PR First-Pass Review

The review workflow activates when a pull request is opened or marked ready for review. It imports the [PR Review Agent](https://github.com/microsoft/hve-core/blob/main/.github/agents/hve-core/pr-review.agent.md) and evaluates the diff across several dimensions:

1. Functional correctness against requirements and acceptance criteria.
2. Design and architecture alignment with established patterns.
3. Convention compliance with instruction files and coding standards.
4. Security considerations including input validation, authentication, and dependency safety.
5. Performance and scalability impact.
6. Reliability, observability, and error handling.

The review produces inline comments on specific lines and a summary review. PRs that pass receive the `review-passed` label; those needing changes receive `needs-revision` with actionable feedback.

## Workflow Configuration

All three workflows are defined as GitHub Agentic Workflow markdown files under `.github/workflows/` and compiled to lock files using `gh aw compile`:

| Workflow File             | Lock File                       | Trigger                                | Agent                  |
|---------------------------|---------------------------------|----------------------------------------|------------------------|
| `issue-triage.md`         | `issue-triage.lock.yml`         | Issue opened or labeled `needs-triage` | Issue Triage Agent     |
| `issue-implement.md`      | `issue-implement.lock.yml`      | Issue labeled `agent-ready`            | Task Implementor Agent |
| `pr-first-pass-review.md` | `pr-first-pass-review.lock.yml` | PR opened or marked ready for review   | PR Review Agent        |

Each workflow file declares permissions, safe output limits, and activation guards that prevent unintended execution.

## Label-Driven Handoffs

Labels serve as the event bus connecting workflows. Each label transition triggers the next stage:

```mermaid
stateDiagram-v2
    [*] --> needs_triage: Issue opened
    needs_triage --> classified: Triage removes needs-triage,<br/>adds type + component labels
    classified --> agent_ready: Triage adds agent-ready<br/>(if criteria met)
    classified --> human_review: Criteria not met,<br/>awaits human labeling
    agent_ready --> pr_opened: Implementation agent<br/>opens PR
    pr_opened --> review_passed: Review agent approves
    pr_opened --> needs_revision: Review agent requests changes
    needs_revision --> pr_opened: Author pushes fixes
    review_passed --> merged: Maintainer merges
    merged --> [*]
```

## Interactive Agent Workflows

Beyond the automated GitHub event-driven pipeline, hve-core provides interactive agents invoked through VS Code Copilot Chat. These agents support the manual side of the development lifecycle.

### RPI Orchestration

The [RPI Agent](https://github.com/microsoft/hve-core/blob/main/.github/agents/hve-core/rpi-agent.agent.md) runs a five-phase iterative cycle: Research, Plan, Implement, Review, and Discover. It delegates to four specialized subagents:

| Agent            | Role                                                           |
|------------------|----------------------------------------------------------------|
| Task Researcher  | Deep codebase and domain analysis, produces research documents |
| Task Planner     | Creates phased implementation plans with validation steps      |
| Task Implementor | Executes plans through subagent delegation and tracks changes  |
| Task Reviewer    | Validates completed work against plans and conventions         |

Each agent hands off to the next through structured artifacts stored in `.copilot-tracking/`.

### Prompt Engineering

The [Prompt Builder](https://github.com/microsoft/hve-core/blob/main/.github/agents/hve-core/prompt-builder.agent.md) orchestrates a three-phase workflow for creating and refining AI artifacts (agents, prompts, instructions, skills):

1. Execute and evaluate prompt files using sandbox testing
2. Research findings and best practices
3. Apply modifications based on evaluation results

It delegates to Prompt Tester, Prompt Evaluator, Prompt Updater, and Researcher subagents.

### Security Review

The [Security Reviewer](https://github.com/microsoft/hve-core/blob/main/.github/agents/security/security-reviewer.agent.md) orchestrates OWASP-based vulnerability assessment through four subagents: Codebase Profiler, Skill Assessor, Finding Deep Verifier, and Report Generator. It supports audit, diff, and plan modes.

### Code Review

The [Functional Code Review](https://github.com/microsoft/hve-core/blob/main/.github/agents/code-review/functional-code-review.agent.md) agent analyzes branch diffs for logic errors, edge case gaps, and error handling deficiencies before code reaches a pull request. The [PR Review](https://github.com/microsoft/hve-core/blob/main/.github/agents/hve-core/pr-review.agent.md) agent provides comprehensive review after PR creation.

### Documentation Operations

The [Doc Ops](https://github.com/microsoft/hve-core/blob/main/.github/agents/hve-core/doc-ops.agent.md) agent audits documentation for style compliance, accuracy against implementation, and coverage gaps.

### Backlog Management

The [GitHub Backlog Manager](https://github.com/microsoft/hve-core/blob/main/.github/agents/github/github-backlog-manager.agent.md) coordinates five workflows (discovery, triage, sprint planning, execution, and quick add) for managing issue lifecycles. The [ADO Backlog Manager](https://github.com/microsoft/hve-core/blob/main/.github/agents/ado/ado-backlog-manager.agent.md) provides equivalent capabilities for Azure DevOps work items.

### Project Planning

Five agents support upstream planning activities:

| Agent                        | Purpose                                  |
|------------------------------|------------------------------------------|
| BRD Builder                  | Business Requirements Documents          |
| PRD Builder                  | Product Requirements Documents           |
| ADR Creation                 | Architecture Decision Records            |
| Architecture Diagram Builder | Visual system architecture diagrams      |
| Security Plan Creator        | Security assessment and mitigation plans |

## How It All Connects

```mermaid
flowchart LR
    subgraph AUTOMATED["Automated Pipeline"]
        direction TB
        TRIAGE["Issue Triage<br/><i>event-driven</i>"]
        IMPL["Issue Implementation<br/><i>event-driven</i>"]
        REVIEW["PR First-Pass Review<br/><i>event-driven</i>"]
        TRIAGE -- "agent-ready label" --> IMPL
        IMPL -- "opens PR" --> REVIEW
    end

    subgraph INTERACTIVE["Interactive Agents"]
        direction TB
        RPI["RPI Orchestration"]
        PB["Prompt Builder"]
        SR["Security Reviewer"]
        CR["Code Review"]
        DOC["Doc Ops"]
        BM["Backlog Manager"]
        PP["Project Planning"]
    end

    subgraph ARTIFACTS["Shared Artifacts"]
        direction TB
        INST["Instructions<br/>.github/instructions/"]
        TRACK[".copilot-tracking/<br/>plans, research, changes"]
        LABELS["GitHub Labels<br/>and Milestones"]
    end

    AUTOMATED --> INST
    INTERACTIVE --> INST
    RPI --> TRACK
    BM --> LABELS
    TRIAGE --> LABELS
```

The automated pipeline and interactive agents share instruction files for consistent coding standards. Interactive agents produce tracking artifacts that inform implementation. The automated pipeline uses GitHub labels as its coordination mechanism, while interactive agents coordinate through `.copilot-tracking/` files.

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
