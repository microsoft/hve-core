---
title: Context Engineering — Why AI Context Management Matters
description: Understanding LLM recency bias, context windows, and why /clear is an engineering practice, not just a step
author: Microsoft
ms.date: 2026-02-19
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

You invoke `/rpi` to add a new feature. The agent researches your codebase, builds a plan, implements methodically, and produces clean, well-structured code. You're impressed. Then, in the same conversation, you ask for a second feature: "Now add input validation to the API endpoint."

The agent skips research entirely, skips planning, and jumps straight to writing code. The output compiles. Tests pass. But the validation logic misses three edge cases that a research phase would have uncovered, ignores the validation patterns already established in your codebase, and introduces a naming convention that contradicts every other validator in the project.

It looks right but produces shallow work. The problem isn't the AI's capability. The problem is what the AI can _see_.

## The Root Cause: LLM Recency Bias

Large language models process conversations as sequences of tokens with limited attention. Every message you send and every response you receive becomes part of that sequence, competing for the model's focus.

At the start of a conversation, system prompt instructions occupy roughly 3K tokens. The model follows them closely because they represent most of what it can see. After a full RPI cycle, the conversation has grown to 50K, 100K, or even 200K tokens of implementation output:  code, file contents, tool results, and validation logs.

Those 3K tokens of instructions now compete against 50K+ tokens of recent implementation context. The model doesn't forget the instructions. It deprioritizes them because more recent tokens receive disproportionate attention weight.

The result is predictable. After completing one implementation cycle, the dominant pattern in the conversation is "implement and validate." When you make a new request, the model pattern-matches to that dominant behavior rather than re-reading the phase ordering instructions that tell it to start with research.

> [!WARNING]
> A concrete failure sequence:
>
> 1. First `/rpi` request works correctly, executing all 5 phases in order
> 2. Conversation grows to 50K+ tokens with implementation output, file contents, and tool results
> 3. Second `/rpi` request skips directly to Phase 3 (implementation), producing shallow output that misses edge cases

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
* It restores the token ratio so that system prompt instructions dominate the model's attention again.
* Each phase gets a clean context where its specific instructions receive full attention weight.
* Artifacts (research documents, plans, implementation logs) carry context through files on disk, not through chat history.

Starting a new chat achieves the same result through a different mechanism. Both approaches reset the token ratio. `/clear` keeps you in the same editor window. A new chat creates a fresh session. The outcome is identical: the model sees instructions clearly because nothing competes for attention.

## Restoring Context After /clear

`/clear` removes chat history, but agents still need the artifacts from prior phases. Those artifacts live in `.copilot-tracking/` (gitignored), not in chat history, so they survive the clear. You need to bring them back into the agent's view.

Two mechanisms work reliably:

* Open the file in the editor before invoking the next agent. Copilot Chat reads files visible in the active editor tab.
* Reference the file path explicitly in your prompt message so the agent knows where to look.

### What to Open at Each Transition

| Transition              | Open or Reference                                                       |
|-------------------------|-------------------------------------------------------------------------|
| Research → Plan         | `.copilot-tracking/research/<topic>-research.md`                        |
| Plan → Implement        | `.copilot-tracking/plans/<topic>-plan.instructions.md`                  |
| Implement → Review      | `.copilot-tracking/changes/<topic>-changes.md` (plan and research help) |
| Review → Rework/Iterate | `.copilot-tracking/reviews/<topic>-review.md`                           |

The `/task-*` prompts attempt to auto-discover recent artifacts in `.copilot-tracking/`, but opening the file in the editor is more reliable, especially when multiple artifacts exist for different topics.

> [!TIP]
> For longer workflows spanning multiple sessions, use the **memory** agent to persist working state (file paths, decisions, progress) and the `/checkpoint` prompt to save and restore session context.

## The /compact Alternative

`/compact` takes a different approach. Instead of removing conversation history entirely, it summarizes the history into a condensed form that preserves key context while reducing the token count.

When to use `/compact`:

* Mid-phase, when a conversation grows long but you need to continue the current task
* When you want to retain awareness of prior decisions without carrying the full token weight
* When handoff buttons between phases embed transition context into the summary prompt

When to use `/clear` instead:

* Between phases, where each phase benefits from clean context
* When switching to a different task entirely
* When agent behavior has visibly degraded

The tradeoff is precision. `/compact` summaries lose detail because the model decides what to keep and what to discard. Critical nuances from earlier in the conversation may not survive the summarization.

| Command    | Effect                             | Use When                             |
|------------|------------------------------------|--------------------------------------|
| `/clear`   | Removes all conversation history   | Between phases, switching tasks      |
| `/compact` | Summarizes history, reduces tokens | Mid-phase, conversation growing long |
| New chat   | Fresh conversation, new context    | Starting unrelated work              |

## The rpi-agent Difference

rpi-agent runs all five phases in a single conversation. This design choice prioritizes convenience: one invocation handles everything. It also creates a specific vulnerability to context degradation.

With strict RPI, mandatory `/clear` commands between phases prevent token accumulation. Each phase starts fresh. The research agent never sees implementation tokens. The implementation agent never sees research exploration tokens.

With rpi-agent, tokens accumulate across all phases within one session. The first request works well because the conversation is short and instructions dominate. Subsequent requests in the same session face the full recency bias effect: 50K+ tokens of prior work competing against 3K tokens of phase ordering instructions.

The phase ordering instruction is advisory. It exists as prose in the agent's system prompt, not as a programmatic constraint. When recency bias shifts the model's attention toward recent implementation patterns, the advisory instruction loses its influence.

> [!TIP]
> Use `/clear` or `/compact` before making a second `/rpi` request in the same conversation.

## Recognizing Context Degradation

Context degradation produces observable symptoms. Catching them early prevents wasted effort.

* The agent skips phases. It jumps from your request directly to writing code, bypassing research and planning entirely.
* The agent ignores explicit instructions from its system prompt. Phase ordering, formatting rules, or convention requirements disappear from the output.
* Output quality drops. Analysis becomes shallow, edge cases go unaddressed, and the agent repeats the same patterns instead of investigating alternatives.
* The agent echoes earlier conversation patterns. Instead of following new instructions for a new task, it reproduces the structure and approach of the previous task.

## Common Pitfalls

| Pitfall                                | What Happens                              | Solution                                    |
|----------------------------------------|-------------------------------------------|---------------------------------------------|
| Multiple `/rpi` calls without clearing | Recency bias causes phase skipping        | Use `/clear` before each new `/rpi` request |
| Long accumulated sessions              | Token budget consumed by history          | Use `/compact` or start a new chat          |
| Mixing unrelated tasks                 | Cross-contamination between task contexts | Use `/clear` between different tasks        |
| Ignoring degradation signs             | Progressively worse output quality        | Recognize the signs and clear context       |

## Next Steps

* [Why RPI?](why-rpi.md): the psychology behind phase separation
* [RPI Overview](README.md): complete workflow guide
* [Using Tasks Together](using-together.md): phase transitions and handoffs

---

<!-- markdownlint-disable MD036 -->
_🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers._
<!-- markdownlint-enable MD036 -->
