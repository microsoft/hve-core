---
description: "Required writing style conventions for voice, tone, and language in all markdown content"
applyTo: '**/*.md'
maturity: stable
---

# Writing Style Instructions

These instructions define the writing style, voice, and tone for all markdown content. Apply these conventions to maintain consistency and authenticity across documentation.

## Voice and Tone

<!-- <important-voice-principles> -->
* Maintain a **clear, professional voice** while adjusting formality to suit context
* Be **authoritative yet accessible**—expert without being condescending
* Adapt tone and structure to match purpose and audience
* Preserve clarity regardless of complexity
<!-- </important-voice-principles> -->

### Formal contexts

Use these conventions for strategic documents, architecture decisions, and official communications:

* Write in an authoritative yet accessible style
* Use structured sections with precise vocabulary
* Employ inclusive pronouns (e.g., "we", "our") to speak for the team
* Maintain professionalism while remaining approachable

### Instructional and direct contexts

Use these conventions for guides, tutorials, how-tos, and developer-facing content:

* Adopt a **warmer, more direct** tone
* Address the reader as "you" to create engagement
* Use first-person reflections ("I") when sharing rationale or experience
* Keep guidance actionable and concrete

## Language and Vocabulary

<!-- <conventions-language> -->
* Use **rich, varied vocabulary**—avoid repetitive word choices within close proximity
* Choose precise terms over vague alternatives; prefer specificity
* Match vocabulary complexity to the audience without sacrificing accuracy
* Avoid jargon unless the audience expects it; define terms when introducing them
<!-- </conventions-language> -->

## Sentence Structure

<!-- <conventions-sentences> -->
* Vary sentence length deliberately:
  * Use **longer, more complex sentences** for narrative explanations and context-setting
  * Use **shorter, punchy sentences** for step-by-step instructions and emphasis
* Maintain clarity regardless of sentence complexity
* Avoid run-on sentences; break complex ideas into digestible parts
* Use parallel structure in lists and comparisons
<!-- </conventions-sentences> -->

## Patterns to Avoid

<!-- <important-anti-patterns> -->
Avoid these common patterns that reduce clarity and create clutter:

### Em dashes

Do not use em dashes (—) for parenthetical statements, explanations, or dramatic pauses. Instead:

* Use **commas** for parenthetical asides: "The system, when enabled, logs all events."
* Use **colons** for explanations: "One option remains: refactor the module."
* Use **periods** to create new sentences when emphasizing a point
* Use **parentheses** for truly supplementary information

### Bolded-prefix list items

Do not format lists with bolded terms followed by descriptions:

```markdown
<!-- ❌ Avoid -->
- **Configuration**: Set up the environment variables
- **Deployment**: Push to production

<!-- ✅ Prefer -->
- Set up environment variables for configuration
- Push to production for deployment
```

Use plain lists, proper headings, or description lists instead.

### Hedging and filler

Remove these phrases that add no value:

* "It's worth noting that..." → (delete, state directly)
* "It should be mentioned..." → (delete, state directly)
* "simply", "easily", "just" → (delete)
* "robust", "powerful", "seamless" → (use specific descriptions)

### Self-referential writing

Avoid meta-commentary about the document itself:

* ❌ "This document explains how to..."
* ❌ "This page will show you..."
* ✅ Start with the content directly
<!-- </important-anti-patterns> -->

## Structural Patterns

* Use **structured sections** with clear headings to organize content logically
* Lead with context before diving into details
* Group related information together
* Provide transitions between major sections when helpful

## Callouts and Alerts

Use GitHub-flavored markdown alerts for important callouts. Each alert type serves a specific purpose:

| Alert | Purpose |
|-------|---------|
| `[!NOTE]` | Useful information users should know when skimming |
| `[!TIP]` | Helpful advice for doing things better or more easily |
| `[!IMPORTANT]` | Key information users need to achieve their goal |
| `[!WARNING]` | Urgent info needing immediate attention to avoid problems |
| `[!CAUTION]` | Advises about risks or negative outcomes of certain actions |

<!-- <example-alerts> -->
```markdown
> [!NOTE]
> Useful information that users should know, even when skimming content.

> [!TIP]
> Helpful advice for doing things better or more easily.

> [!IMPORTANT]
> Key information users need to know to achieve their goal.

> [!WARNING]
> Urgent info that needs immediate user attention to avoid problems.

> [!CAUTION]
> Advises about risks or negative outcomes of certain actions.
```
<!-- </example-alerts> -->

## Pronoun Usage

Match pronouns to context and purpose:

| Context                     | Preferred Pronouns       | Example                              |
| --------------------------- | ------------------------ | ------------------------------------ |
| Team/organizational voice   | "we", "our"              | "We recommend using..."              |
| Instructional/tutorial      | "you", "your"            | "You can configure..."               |
| Personal insight/rationale  | "I"                      | "I prefer this approach because..."  |
| Neutral/technical           | Impersonal constructions | "This configuration enables..."      |

## Clarity Principles

<!-- <important-clarity> -->
* Prioritize **clarity over brevity**—but aim for both when possible
* Ensure complex ideas remain understandable through structure and word choice
* Use examples to illustrate abstract concepts
* Front-load important information; don't bury the lede
<!-- </important-clarity> -->

## Adaptability

The hallmark of this style is **adaptability**. Shift register appropriately:

* **High formality**: Strategic plans, executive summaries, architecture decisions
* **Medium formality**: Technical documentation, READMEs, contributing guides
* **Lower formality**: Internal notes, casual updates, quick references

Regardless of formality level, maintain professionalism and precision.
