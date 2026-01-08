---
title: Why the RPI Workflow Works
description: The psychology, research, and principles behind the Research-Plan-Implement framework, plus guidance on when to use RPI vs rpi-agent
author: Microsoft
ms.date: 2026-01-05
ms.topic: concept
keywords:
  - rpi workflow
  - ai constraints
  - research first
  - hallucination prevention
  - ai coding
estimated_reading_time: 8
---

AI coding assistants are brilliant at simple tasks. Ask for a function that reverses a string, and you'll get working code in seconds. Ask for a feature that touches twelve files across three services, and you'll get something that looks right, compiles cleanly, and breaks everything it touches.

If you've spent hours debugging AI-generated code that ignored your project's conventions, used variable names that don't match anything in your codebase, or confidently called APIs that don't exist, you're not alone. The problem isn't that AI is incapable. The problem is that we're asking it to do too many things at once.

## The Real Problem

Here's what took us a while to figure out: AI is doing exactly what it's designed to do. When you ask it to "build a feature," it generates plausible output quickly. The issue is that "plausible" and "correct" aren't the same thing.

> [!WARNING]
> **The failure mode you'll recognize**
>
> You: "Build me a Terraform module for Azure IoT"
>
> AI: *immediately generates 2000 lines of code*
>
> Reality: Missing dependencies, wrong variable names, outdated patterns, breaks existing infrastructure

Why does this happen? Because AI can't tell the difference between investigating and implementing. When you ask for code, it writes code. It doesn't stop to verify that the variable naming convention it chose matches your existing modules. It doesn't check whether the resource it's creating already exists. It doesn't ask itself whether the API it's calling is current or deprecated.

AI writes first and thinks never. Not because it's broken, but because that's the only mode it has when you give it unrestricted access to both research and implementation.

## The Counterintuitive Insight

The solution isn't teaching AI to be smarter. It's preventing AI from doing certain things at certain times.

RPI (Research → Plan → Implement) works by separating AI work into three distinct phases, each handled by a specialized mode:

* [Task Researcher](task-researcher.md): investigates your codebase and external sources, producing verified findings with citations
* [Task Planner](task-planner.md): transforms research into actionable implementation plans with clear success criteria
* [Task Implementor](task-implementor.md): executes plans methodically, following established patterns discovered during research

The magic happens because each phase starts fresh. When you clear context between phases, the implementation session doesn't carry forward the assumptions from research. It only has the documented artifacts: verified findings, explicit decisions, and cited evidence.

### The Difference in Practice

**Without RPI**, AI thinks: "This looks like a reasonable variable name. I'll use `prefix`."

**With RPI**, Task Researcher finds: "12 existing modules in this repository use `resource_prefix`, not `prefix`. See [variables.tf#L47](../infrastructure/modules/base/variables.tf#L47) for the established pattern."

When AI knows it cannot implement during research, it stops optimizing for "plausible code" and starts optimizing for "verified truth." The constraint changes the goal.

## What Happens in Each Phase

Understanding what AI does differently in each phase helps explain why separation works.

### Research Phase: Investigating, Not Guessing

Task Researcher knows it will never write the code. This single constraint transforms its behavior:

* Searches for existing patterns instead of inventing new ones.
* Cites specific files and line numbers as evidence.
* Questions its own assumptions because it can't hide them in implementation.
* Documents dependencies, APIs, and conventions with precision.

The output is a research document that anyone can verify. No tribal knowledge. No "I think this is how it works."

### Planning Phase: Sequencing, Not Improvising

Task Planner receives verified research and transforms it into actionable steps. Because it can't implement, it focuses entirely on:

* Breaking work into logical, sequenced tasks.
* Identifying dependencies between changes.
* Defining clear success criteria for each step.
* Anticipating edge cases before code is written.

The plan becomes a contract. When implementation begins, the AI follows the plan rather than making decisions on the fly.

### Implementation Phase: Following, Not Inventing

Task Implementor has one job: execute the plan using the patterns documented in research. This is where the payoff becomes obvious:

* No time wasted rediscovering conventions.
* No "creative" decisions that break existing patterns.
* No assumptions about how things work, only verified facts.
* Clear accountability when something goes wrong.

## The Quality Difference

RPI produces measurably different outcomes than traditional AI coding:

| Aspect                 | Traditional Approach                               | RPI Approach                                 |
|------------------------|----------------------------------------------------|----------------------------------------------|
| **Pattern matching**   | Invents plausible patterns                         | Uses verified existing patterns              |
| **Traceability**       | "The AI wrote it this way"                         | "Research document cites lines 47-52"        |
| **Knowledge transfer** | Tribal knowledge in your head                      | Research documents anyone can follow         |
| **Rework**             | Frequent, after discovering assumptions were wrong | Rare, because assumptions are verified first |

### The Paradigm Shift

Stop asking AI: "Write this code."

Start asking: "Help me research, plan, then implement with evidence."

RPI treats AI as a research partner first, code generator second. The code comes last, after the hard work of understanding is complete.

## The Learning Curve

Let's be honest: your first RPI workflow will feel slower. You're learning a new process, building muscle memory for context clearing, and adjusting to the handoff between phases.

By your third feature, the workflow feels natural. The research phase becomes faster because you know what questions to ask. The planning phase tightens because you recognize what level of detail works for your codebase. Implementation becomes almost mechanical.

The value compounds over time. Research documents accumulate into institutional memory. New team members can read how past decisions were made. Patterns get documented once and referenced forever.

## Choosing Your Workflow: RPI vs rpi-agent

HVE Core provides two workflow options. The right choice depends on the task, not personal preference.

### Strict RPI: When Quality Matters Most

Use the three-phase workflow ([Task Researcher](task-researcher.md) → [Task Planner](task-planner.md) → [Task Implementor](task-implementor.md)) when:

* 🔍 **Deep research needed**: new frameworks, external APIs, compliance requirements
* 📁 **Multi-file changes**: pattern discovery across the codebase
* 👥 **Team handoff**: artifacts document decisions for others
* 🔧 **Long-term maintenance**: work you'll maintain and evolve over time

**The workflow:**

1. Invoke Task Researcher → produces research document with citations
2. Clear context, invoke Task Planner → produces implementation plan
3. Clear context, invoke Task Implementor → implements following the plan

### rpi-agent: When Simplicity Fits

Use the [autonomous agent](../../.github/agents/rpi-agent.agent.md) when:

* ✅ **Clear scope**: straightforward feature or bug fix
* ✅ **Minimal research**: codebase-only investigation
* ✅ **Quick iteration**: active development with fast feedback loops

**The workflow:** Single rpi-agent session that handles research and implementation together.

### Matching Tool to Task

| Factor                | Strict RPI                     | rpi-agent                   |
|-----------------------|--------------------------------|-----------------------------|
| Research depth        | Deep, verified, cited          | Moderate, inline            |
| Context contamination | Eliminated via `/clear`        | Possible                    |
| Audit trail           | Complete artifacts             | Summary only                |
| Best for              | Complex, unfamiliar, team work | Simple, familiar, solo work |

### Escalation Path

rpi-agent can hand off to Task Researcher when it encounters complexity beyond its scope. This hybrid approach gives you speed for simple tasks and depth when needed. You don't have to decide upfront; start with rpi-agent and escalate if the task reveals hidden complexity.

## Next Steps

Ready to try it yourself?

* [Your First RPI Workflow](../getting-started/first-workflow.md): 15-minute hands-on tutorial
* [Using the Modes Together](using-together.md): context management and handoffs
* [RPI Overview](README.md): the three modes explained

---

🤖 *Crafted with precision by ✨Copilot using the RPI workflow*
