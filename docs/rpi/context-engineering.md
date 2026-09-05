---
title: "Context Engineering: Why AI Context Management Matters"
description: Understand how long RPI lifecycles accumulate context and how durable artifacts support deliberate resumption
sidebar_position: 3
author: Microsoft
ms.date: 2026-07-15
ms.topic: concept
keywords:
  - context engineering
  - recency bias
  - context window
  - clear context
  - compact
  - rpi-agent
  - phase skipping
estimated_reading_time: 7
---

You begin a long RPI lifecycle through `RPI Agent` or `/rpi-quick` to add a feature. The research-readiness assessment reuses adequate evidence or activates research for a demonstrated gap. Planning, implementation, and review then leave durable task evidence. In the same conversation, you ask for a second feature: "Now add input validation to the API endpoint."

The conversation jumps straight to writing code without reassessing whether the new task has adequate evidence, an approved plan, or a decision-critical gap. The output compiles. Tests pass. But the validation logic misses three edge cases, ignores the validation patterns already established in your codebase, and introduces a naming convention that contradicts every other validator in the project.

It looks right but produces shallow work. The problem isn't the AI's capability. The problem is what the AI can _see_.

## The Root Cause: LLM Recency Bias

Large language models process conversations as sequences of tokens with limited attention. Every message you send and every response you receive becomes part of that sequence, competing for the model's focus.

At the start of a conversation, system prompt instructions occupy roughly 3K tokens. The model follows them closely because they represent most of what it can see. After a long RPI lifecycle, a conversation can grow to 50K, 100K, or even 200K tokens of implementation output, file contents, tool results, and validation logs.

Those 3K tokens of instructions now compete against 50K+ tokens of recent implementation context. The model doesn't forget the instructions. It deprioritizes them because more recent tokens receive disproportionate attention weight.

The result is predictable. After completing implementation work, the dominant pattern in the conversation can become "implement and validate." When you make a new request, the model may pattern-match to that behavior rather than reassessing research readiness, planning evidence, and the next responsible lifecycle concept.

> [!WARNING]
> A concrete failure sequence:
>
> 1. A long lifecycle creates plan, implementation, and review evidence for one task.
> 2. The conversation grows to 50K+ tokens with implementation output, file contents, and tool results.
> 3. A new task jumps directly to implementation without a readiness assessment, producing shallow output that misses edge cases.

## What Context Engineering Is

Context engineering is the practice of deliberately managing what information an AI model can see when processing a request. Instead of treating the conversation as a growing log that the model will "figure out," you treat context as a finite resource that requires active management.

Four concepts define the discipline:

* Context window: the total token capacity a model considers when generating a response. Current models range from 128K to 200K tokens, but performance degrades well before the limit.
* Token budget: how those tokens distribute between system prompt instructions, conversation history, and tool outputs. A 200K context window doesn't mean 200K tokens of useful capacity. System prompts, conversation scaffolding, and tool metadata all consume tokens before your actual content arrives.
* Conversation length degradation: instruction adherence drops as conversations grow. A 3K system prompt that dominates a 10K conversation (30% of tokens) becomes background noise in a 200K conversation (1.5% of tokens).
* The gap between "using AI tools" and "engineering with AI tools": using AI means typing requests and accepting outputs. Engineering with AI means controlling the inputs, managing the context, and understanding how the model's behavior changes as conversations evolve.

## Why /clear Works

`/clear` removes competing signals. The mechanism is straightforward:

* It eliminates the 50K to 200K tokens of accumulated implementation context that cause recency bias.
* It restores the token ratio so that system prompt instructions receive more attention again.
* A new lifecycle concept or task can begin from a cleaner context when that helps the work.
* Artifacts carry context through files on disk, not through chat history.

Starting a new chat achieves the same result through a different mechanism. Both approaches reset the token ratio. `/clear` keeps you in the same editor window. A new chat creates a fresh session. Use either when a long lifecycle has accumulated context, when changing tasks, or when the current conversation no longer supports the next action.

## Restoring Context After /clear

`/clear` removes chat history, but a task can resume from its durable artifacts. Those artifacts live in `.copilot-tracking/` (gitignored), not in chat history, so they survive the clear. Bring the relevant task evidence back into the agent's view.

Two mechanisms work reliably:

* Open the file in the editor before invoking the next agent. Copilot Chat reads files visible in the active editor tab.
* Reference the file path explicitly in your prompt message so the agent knows where to look.

### What to Open at Each Transition

| Transition or resumption point | Open or Reference                                                                                                                                                                                                              |
|--------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Research, when it runs → Plan  | `.copilot-tracking/research/{{YYYY-MM-DD}}/{{task_slug}}-research.md`                                                                                                                                                          |
| Plan → Implement               | `.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md`, `.copilot-tracking/details/{{YYYY-MM-DD}}/{{task_slug}}-phase-details.md`, and `.copilot-tracking/reviews/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan-critique.md` |
| Implement → Review             | `.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md` with the plan, details, and critique                                                                                                                       |
| Review → Follow-up             | `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/{{task_slug}}-review.md`                                                                                                                                                        |

When resuming a plan or phase-details artifact, navigate by the stable task ID, `Pxx`, `Pxx-Txx`, headings, and `<!-- rpi:... -->` markers such as `<!-- rpi:phase id=P01 -->` or `<!-- rpi:task id=P01-T01 -->`.

When multiple artifact sets exist, open the relevant file or reference its path explicitly so the resumed work uses the intended task identity.

> [!TIP]
> For longer workflows spanning multiple sessions, resume from the dated RPI artifacts and stable task identifiers. These files preserve evidence and progress without relying on chat history.

## The /compact Alternative

`/compact` takes a different approach. Instead of removing conversation history entirely, it summarizes the history into a condensed form that preserves key context while reducing the token count.

`/compact` remains available as a typed command but is no longer offered as an agent handoff button. It was removed from agent handoffs because Autopilot mode could trigger compaction loops that degraded context unpredictably.

When to use `/compact`:

* Mid-phase, when a conversation grows long but you need to continue the current task
* When you want to retain awareness of prior decisions without carrying the full token weight

When to use `/clear` instead:

* When changing lifecycle concepts and a fresh context will improve the next action
* When switching to a different task entirely
* When agent behavior has visibly degraded

For session persistence, resume from the dated RPI artifacts rather than relying on `/compact`. Open or reference only the files needed for the next action so the fresh context remains focused.

The tradeoff is precision. `/compact` summaries lose detail because the model decides what to keep and what to discard. Critical nuances from earlier in the conversation may not survive the summarization.

| Command or action | Effect                             | Use when                             |
|-------------------|------------------------------------|--------------------------------------|
| `/clear`          | Removes all conversation history   | Changing concepts, switching tasks   |
| `/compact`        | Summarizes history, reduces tokens | Mid-phase, conversation growing long |
| New chat          | Starts with a fresh context        | Starting unrelated work              |
| Open artifacts    | Restores selected durable evidence | Resuming an existing RPI task        |

## Long-Lifecycle Context

`RPI Agent` is a user-selected lifecycle wrapper, and `/rpi-quick` is a skill-based full-flow entry point. They activate the same phase skills and may coordinate a long task, but neither guarantees that every run executes fresh research or all lifecycle concepts in one conversation.

When a lifecycle spans planning, implementation, review, and follow-up, tokens can accumulate across the task. Research readiness remains conditional: adequate evidence can be reused, while a demonstrated gap activates research. A context reset does not change those decisions; it lets you resume the next responsible action from the durable artifact set.

Use `/clear` or `/compact` when the conversation has accumulated irrelevant detail, then reference the stable task ID and the plan, phase details, critique, changes, or review record that establishes the next action.

## Recognizing Context Degradation

Context degradation produces observable symptoms. Catching them early prevents wasted effort.

* The agent skips a readiness assessment. It jumps from your request directly to writing code without checking available evidence, planning, or decisions.
* The agent ignores explicit instructions from its system prompt. Evidence, formatting, or convention requirements disappear from the output.
* Output quality drops. Analysis becomes shallow, edge cases go unaddressed, and the agent repeats the same patterns instead of investigating alternatives.
* The agent echoes earlier conversation patterns. Instead of following new instructions for a new task, it reproduces the structure and approach of the previous task.

## Common Pitfalls

| Pitfall                                              | What Happens                                        | Solution                                                      |
|------------------------------------------------------|-----------------------------------------------------|---------------------------------------------------------------|
| Reusing a long lifecycle conversation for a new task | Recency bias bypasses readiness and evidence checks | Reset context, then begin from the new task's evidence        |
| Long accumulated sessions                            | Token budget is consumed by history                 | Use `/compact` or start a new chat                            |
| Mixing unrelated tasks                               | Cross-contamination between task contexts           | Use `/clear` and resume from the relevant durable artifacts   |
| Ignoring degradation signs                           | Progressively worse output quality                  | Recognize the signs and reset or compact context deliberately |

## Next Steps

* [Why RPI?](why-rpi): the psychology behind phase separation
* [RPI Overview](./): complete workflow guide
* [Using RPI Together](using-together): phase transitions and handoffs

---

<!-- markdownlint-disable MD036 -->
_🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers._
<!-- markdownlint-enable MD036 -->
