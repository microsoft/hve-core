---
title: Using the DT Coach
description: Guide to using the dt-coach agent for AI-assisted Design Thinking sessions
author: Microsoft
ms.date: 2026-02-25
ms.topic: tutorial
keywords:
  - dt-coach
  - design thinking
  - agent
  - copilot
estimated_reading_time: 8
---

The DT Coach is a custom agent that guides you through the nine Design Thinking methods. It works WITH you to discover problems and develop solutions rather than prescribing answers.

## When to Use DT Coach

Use the DT Coach when your project involves:

* 🔍 Unclear requirements needing user-centered discovery
* 👥 Multiple stakeholders with potentially conflicting needs
* 🏭 Complex domains spanning organizational or technical boundaries
* 🔄 Iteration needs where early prototyping can save rework later
* 🤝 User adoption as a success factor, not just technical correctness

## What It Does

1. Coaches through all nine methods using a Think/Speak/Empower philosophy
2. Manages session state so you can pause and resume across conversations
3. Enforces quality appropriate to each space (rough in Problem, scrappy in Solution, functional in Validation)
4. Guides transitions between methods based on exit signals rather than arbitrary timelines
5. Prepares handoffs to RPI agents when your DT session reaches a natural exit point

> [!NOTE]
> The DT Coach never prescribes solutions. It shares observations, asks questions, and offers choices. You drive the thinking; the coach helps you think more clearly.

## Output Artifacts

DT Coach creates session artifacts at:

```text
.copilot-tracking/dt/{project-slug}/
```

This directory contains:

* `coaching-state.md` — Session state with method progress, transition log, and recovery points
* `method-{NN}-*/` — Per-method working artifacts (notes, themes, prototypes)
* Handoff artifacts when transitioning to RPI agents

## How to Use DT Coach

### Option 1: Select the Custom Agent (Recommended)

1. Open GitHub Copilot Chat (`Ctrl+Alt+I`)
2. Click the agent picker dropdown at the top
3. Select **DT Coach**
4. Describe your project or problem area

### Option 2: Start from a DT Prompt

Use `/dt-method-next` to have the coach assess where you are and guide you to the next appropriate method.

### Starting a Session

Describe the project context you want to explore. The coach begins with Method 1 (Scope Conversations) to help discover the real problem behind your initial request.

```text
I'm working on improving the incident response process for our manufacturing
plant. Operators currently rely on paper checklists and radio communication.
We've been asked to "build a digital dashboard" but I'm not sure that's
the right solution.
```

The coach responds with observations and a guiding question, never a solution. You drive the conversation forward.

### Navigating Methods

The coach tracks your progress through each method and signals when exit conditions are met. You can:

* Continue deeper in the current method
* Advance to the next method when exit signals are satisfied
* Return to an earlier method if new information warrants it

> [!TIP]
> Method progression is non-linear. The coach supports backward movement without framing it as regression. Revisiting Method 2 after reaching Method 5 is a sign of thoroughness, not failure.

### Pausing and Resuming

Session state persists in `.copilot-tracking/dt/{project-slug}/coaching-state.md`. When you return to a project after clearing context or starting a new chat:

1. Open the coaching state file in your editor
2. Select DT Coach
3. The coach reads the state file and picks up where you left off

## Example Interaction

**You:** "Our plant managers want a real-time dashboard showing equipment status. Can you help me think through this?"

**DT Coach:** "I'm noticing you've been given a solution ('real-time dashboard') rather than a problem. That's a great signal we should start with Method 1 to understand what's actually driving this request. What happens today when a piece of equipment needs attention? How do plant managers currently find out?"

**You:** "They usually hear about issues during shift handoffs or when something breaks down."

**DT Coach:** "So there's a time gap between when something starts going wrong and when anyone acts on it. That's interesting because it shifts the question from 'how do we show status?' to 'how do we close the awareness gap?' Want to explore who else is affected by this delay, or dig deeper into what happens during that gap?"

## Tips

* Start broad, narrow later. Resist the urge to jump to solutions in early methods. The Problem Space exists to ensure you solve the right problem.
* Trust the exit signals. Each method has specific criteria that indicate when you have enough evidence to advance. The coach tracks these for you.
* Keep artifacts rough. In the Problem and Solution spaces, polished output actually hurts. Scrappy artifacts invite honest feedback from stakeholders.
* Use industry context. If your domain is manufacturing, healthcare, or energy, mention it early. The coach adjusts vocabulary and stakeholder archetypes accordingly.

## Common Pitfalls

* Skipping methods. Jumping from Method 1 to Method 4 misses critical research and synthesis. Each method builds on the output of the previous one.
* Over-polishing early. Spending time on visual design in Method 5 or 6 violates the anti-polish stance and reduces the quality of feedback.
* Treating method progression as linear-only. New findings in later methods often warrant revisiting earlier ones. This is a feature, not a bug.
* Ignoring stakeholder diversity. Designing for only the most obvious user group leads to solutions that fail for everyone else.

## Next Steps

* [Design Thinking Guide](README.md) — Overview of all nine methods and three spaces
* [DT to RPI Integration](dt-rpi-integration.md) — How DT outputs feed into the RPI workflow
* [DT Learning Tutor](dt-learning-tutor.md) — Curriculum-based training across all methods

> Brought to you by microsoft/hve-core

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
