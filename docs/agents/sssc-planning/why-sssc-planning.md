---
title: Why SSSC Planning?
description: The reasoning behind structured supply chain security assessment and how it compares to manual approaches
sidebar_position: 2
sidebar_label: Why SSSC Planning?
keywords:
  - supply chain security
  - OpenSSF Scorecard
  - why
tags:
  - agents
  - security
author: Microsoft
ms.date: 2026-03-18
ms.topic: concept
estimated_reading_time: 6
---

Supply chain security assessment tends to go one of two ways. Teams either run the OpenSSF Scorecard CLI once and react to whatever score it returns, or they rely on senior engineers who carry the adoption roadmap in their heads. Both approaches break down as repositories grow, teams onboard new members, and compliance targets shift.

The SSSC Planner exists to close that gap. It provides a repeatable structure that inventories existing capabilities, maps them to industry standards, identifies gaps with concrete adoption paths, and produces work items that are specific enough to act on.

## The Core Insight

Most supply chain security gaps do not come from missing awareness. They come from missing adoption paths. A team knows that dependency pinning matters, but without a structured workflow that classifies the gap, identifies the reusable workflow to adopt, and sizes the effort, the improvement stalls. The SSSC Planner makes the process explicit: every repository gets the same 27-capability inventory, the same 20-check Scorecard mapping, and the same six-category adoption framework.

## How Each Phase Helps

### Phase 1: Project Scoping

Scoping forces the team to articulate the target repository's technology stack, package managers, CI platform, and release strategy before any assessment begins. This prevents the common failure mode of running a Scorecard check without understanding what the repository actually builds or deploys.

### Phase 2: Supply Chain Assessment

Inventorying 27 capabilities across hve-core and physical-ai-toolchain ensures that no existing security tool is overlooked. The three-source classification (hve-core unique, PAT unique, shared) prevents teams from building what already exists.

### Phase 3: Standards Mapping

Mapping capabilities to OpenSSF Scorecard checks, SLSA Build levels, Best Practices Badge criteria, Sigstore maturity, and SBOM standards anchors the analysis in established frameworks. This gives reviewers and auditors a shared vocabulary and reduces the risk of reinventing guidance that already exists.

### Phase 4: Gap Analysis

Classifying each gap into one of six adoption categories (reusable workflow, workflow copy/modify, workflow + script, platform configuration, new capability, N/A) with T-shirt effort sizing turns abstract gaps into concrete adoption steps. Prioritization by Scorecard risk level ensures Critical gaps are addressed first.

### Phase 5: Backlog Generation

Converting gaps into backlog items with adoption steps and acceptance criteria closes the loop between analysis and action. Priority derivation from risk level (Critical → P1, High → P2, Medium → P3, Low → P4) and dual-platform support (ADO + GitHub) ensure items are ready for immediate triage.

### Phase 6: Review and Handoff

The review phase validates completeness, generates Scorecard improvement projections (current vs. projected score per check), SLSA level assessment, and Badge readiness evaluation. These projections give stakeholders a clear picture of the return on investment before any work begins.

## Quality Comparison

| Dimension              | Manual Scorecard Review            | SSSC Planner                                               |
|------------------------|------------------------------------|------------------------------------------------------------|
| Coverage consistency   | Varies by who runs the CLI         | Same 27-capability inventory every time                    |
| Standards traceability | Scorecard score only               | Scorecard, SLSA, Badge, Sigstore, SBOM mapped per check    |
| Gap identification     | Score-based without adoption paths | Six adoption categories with effort sizing                 |
| Backlog quality        | Generic "improve score" items      | Specific items with adoption steps and acceptance criteria |
| Knowledge transfer     | Lost when engineers leave          | Captured in plan artifacts and state files                 |
| Improvement projection | Not available                      | Per-check Scorecard projections, SLSA and Badge readiness  |

## Learning Curve

Adoption does not need to be all-or-nothing. Teams can scale up incrementally:

1. **Start with Capture mode** on a single repository to see the full six-phase flow.
2. **Switch to From-PRD or From-BRD mode** once requirement artifacts are routinely available.
3. **Use From-Security-Plan mode** to extend an existing security analysis with supply chain coverage.
4. **Adjust autonomy tiers** to match your team's comfort level with agent-generated work items.

## Choosing Your Approach

The right entry mode depends on what artifacts already exist and how much context the agent needs to gather.

| Starting point                 | Recommended mode   | Reason                                            |
|--------------------------------|--------------------|---------------------------------------------------|
| PRD available                  | From-PRD           | Seeds Phase 1 from existing product requirements  |
| BRD available                  | From-BRD           | Seeds Phase 1 from existing business requirements |
| Completed security plan exists | From-Security-Plan | Inherits scope from Security Planner state file   |
| No formal requirements         | Capture            | Gathers scope through structured interview        |

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
