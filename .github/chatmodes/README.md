---
title: GitHub Copilot Chat Modes
description: Specialized AI assistants for planning, research, prompt engineering, and PR reviews
author: HVE Core Team
ms.date: 2025-11-05
ms.topic: guide
keywords:
  - copilot
  - chat modes
  - ai assistants
  - task planning
  - code review
estimated_reading_time: 4
---

# GitHub Copilot Chat Modes

Specialized GitHub Copilot behaviors for common development workflows. Each chat mode is optimized for specific tasks with custom instructions and context.

## Quick Start

Invoke chat modes in GitHub Copilot Chat using `@` syntax:

```
@task-planner Create a plan to add Docker SHA validation
@pr-review Review this pull request for security issues
```

**Requirements:** GitHub Copilot subscription, VS Code with Copilot extension

## Available Chat Modes

| Chat Mode | Purpose | Key Constraint |
|-----------|---------|----------------|
| `@task-planner` | Creates 3-file plan sets (plan, details, prompt) | Requires research first; never implements code |
| `@task-researcher` | Produces research documents with evidence-based recommendations | Research-only; never plans or implements |
| `@prompt-builder` | Engineers and validates instruction/prompt files | Dual-persona system with auto-testing |
| `@pr-review` | 4-phase PR review with tracking artifacts | Review-only; never modifies code |

## Chat Mode Details

### `@task-planner`
**Creates:** Three interconnected files per task:
- Plan checklist: `.copilot-tracking/plans/YYYYMMDD-task-plan.instructions.md`
- Implementation details: `.copilot-tracking/details/YYYYMMDD-task-details.md`
- Implementation prompt: `.copilot-tracking/prompts/implement-task.prompt.md`

**Workflow:** Validates research → Creates plan files → User implements separately  
**Critical:** Automatically calls `@task-researcher` if research missing; treats ALL user input as planning requests (never implements actual code)

### `@task-researcher`
**Creates:** Single authoritative research document:
- `.copilot-tracking/research/YYYYMMDD-topic-research.md`
- Subagent files: `.copilot-tracking/research/YYYYMMDD-topic-subagent/task-research.md`

**Workflow:** Deep tool-based research → Document findings → Consolidate to ONE approach → Hand off to planner  
**Critical:** Research-only specialist; uses `runSubagent` tool; continuously refines document; never plans or implements

### `@prompt-builder`
**Creates:** Instruction files AND prompt files:
- `.github/instructions/*.instructions.md`
- `.copilot-tracking/prompts/*.prompt.md`

**Workflow:** Research sources → Draft → Auto-validate with Prompt Tester → Iterate (up to 3 cycles)  
**Critical:** Dual-persona system; uses XML-style blocks (`<!-- <example-*> -->`); links to authoritative sources; minimal inline examples

### `@pr-review`
**Creates:** Review tracking files in normalized branch folders:
- `.copilot-tracking/pr/review/{normalized-branch}/in-progress-review.md`
- `.copilot-tracking/pr/review/{normalized-branch}/pr-reference.xml`
- `.copilot-tracking/pr/review/{normalized-branch}/handoff.md`
- `.copilot-tracking/pr/review/{normalized-branch}/hunk-*.txt`

**Workflow:** 4 phases (Initialize → Analyze → Collaborative Review → Finalize)  
**Critical:** Review-only; never modifies code; evaluates 8 dimensions (functional correctness, design, idioms, reusability, performance, reliability, security, documentation)

## Common Workflows

**Planning a Feature:**
1. `@task-researcher` - Create research document with findings
2. Review research, provide decisions on approach
3. Clear context or start new chat
4. `@task-planner` - Generate 3-file plan set (attach research doc)
5. Use implementation prompt to execute (separate step)

**Code Review:**
1. `@pr-review` - Automatically runs 4-phase protocol
2. Collaborate during Phase 3 (review items)
3. Receive `handoff.md` with final PR comments

**Creating Instructions:**
1. `@prompt-builder` - Draft instruction file with conventions
2. Auto-validates with Prompt Tester persona
3. Iterates up to 3 times for quality
4. Delivered to `.github/instructions/`

## Important Notes

- **Linting Exemption:** Files in `.copilot-tracking/**` are exempt from repository linting rules
- **Mode Switching:** User must manually switch between chat modes (e.g., from researcher to planner)
- **Research First:** Task planner requires completed research; will automatically invoke researcher if missing
- **No Implementation:** Task planner and researcher never implement actual project code—only create planning artifacts

## Tips

- Be specific in your requests for better results
- Provide context about what you're working on
- Review generated outputs before using
- Chain modes together for complex tasks

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
