---
description: "Required writing style conventions for voice, tone, and language in all markdown content"
applyTo: '**/*.md'
maturity: stable
---

# Writing Style Instructions

These instructions define writing style, voice, and tone conventions for markdown content. Apply these conventions to maintain consistency and authenticity across documentation.

## Voice and Tone

Writing voice adapts to context while maintaining professionalism:

* Maintain a clear, professional voice while adjusting formality to suit context
* Write with authority while remaining accessible (expert without condescension)
* Adapt tone and structure to match purpose and audience
* Preserve clarity regardless of complexity

### Formal Contexts

Use these conventions for strategic documents, architecture decisions, and official communications:

* Write in an authoritative yet accessible style
* Use structured sections with precise vocabulary
* Employ inclusive pronouns ("we", "our") to speak for the team
* Maintain professionalism while remaining approachable

### Instructional Contexts

Use these conventions for guides, tutorials, how-tos, and developer-facing content:

* Adopt a warmer, more direct tone
* Address the reader as "you" to create engagement
* Use first-person reflections ("I") when sharing rationale or experience
* Keep guidance actionable and concrete

## Language and Vocabulary

Vocabulary choices affect clarity and reader engagement:

* Use rich, varied vocabulary to avoid repetitive word choices within close proximity
* Choose precise terms over vague alternatives; prefer specificity
* Match vocabulary complexity to the audience without sacrificing accuracy
* Avoid jargon unless the audience expects it; define terms when introducing them

## Sentence Structure

Sentence variety improves readability:

* Vary sentence length deliberately
* Use longer, more complex sentences for narrative explanations and context-setting
* Use shorter, punchy sentences for step-by-step instructions and emphasis
* Maintain clarity regardless of sentence complexity
* Avoid run-on sentences; break complex ideas into digestible parts
* Use parallel structure in lists and comparisons

## Patterns to Avoid

Avoid these common patterns that reduce clarity and create clutter.

### Em Dashes

Do not use em dashes (—) for parenthetical statements, explanations, or dramatic pauses. Use these alternatives instead:

| Instead of Em Dash | Use This | Example |
| ------------------ | -------- | ------- |
| Parenthetical aside | Commas | "The system, when enabled, logs all events." |
| Explanation | Colons | "One option remains: refactor the module." |
| Emphasis | Periods | Create a new sentence when emphasizing a point. |
| Supplementary info | Parentheses | Use for truly supplementary information. |

### Bolded-Prefix List Items

Do not format lists with bolded terms followed by descriptions.

```markdown
<!-- Avoid this pattern -->
* **Configuration**: Set up the environment variables
* **Deployment**: Push to production

<!-- Use this pattern instead -->
* Set up environment variables for configuration
* Push to production for deployment
```

Use plain lists, proper headings, or description lists instead.

### Hedging and Filler

Remove these phrases that add no value:

* "It's worth noting that..." (delete, state directly)
* "It should be mentioned..." (delete, state directly)
* "simply", "easily", "just" (delete)
* "robust", "powerful", "seamless" (use specific descriptions)

### Self-Referential Writing

Avoid meta-commentary about the document itself. Start with the content directly instead of phrases like "This document explains..." or "This page will show you..."

## Structural Patterns

Organize content to help readers find and understand information:

* Use structured sections with clear headings to organize content logically
* Lead with context before diving into details
* Group related information together
* Provide transitions between major sections when helpful

## Callouts and Alerts

Use GitHub-flavored markdown alerts for important callouts. Each alert type serves a specific purpose:

| Alert | Purpose |
| ----- | ------- |
| `[!NOTE]` | Useful information users should know when skimming |
| `[!TIP]` | Helpful advice for doing things better or more easily |
| `[!IMPORTANT]` | Key information users need to achieve their goal |
| `[!WARNING]` | Urgent info needing immediate attention to avoid problems |
| `[!CAUTION]` | Advises about risks or negative outcomes of certain actions |

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

## Pronoun Usage

Match pronouns to context and purpose:

| Context | Preferred Pronouns | Example |
| ------- | ------------------ | ------- |
| Team/organizational voice | "we", "our" | "We recommend using..." |
| Instructional/tutorial | "you", "your" | "You can configure..." |
| Personal insight/rationale | "I" | "I prefer this approach because..." |
| Neutral/technical | Impersonal constructions | "This configuration enables..." |

## Clarity Principles

Clarity takes priority while balancing brevity:

* Prioritize clarity over brevity, but aim for both when possible
* Ensure complex ideas remain understandable through structure and word choice
* Use examples to illustrate abstract concepts
* Front-load important information; do not bury the lede

## Adaptability

Adaptability is the hallmark of effective writing style. Shift register based on content purpose:

| Formality Level | Use For | Characteristics |
| --------------- | ------- | --------------- |
| High | Strategic plans, executive summaries, architecture decisions | Structured, precise, authoritative |
| Medium | Technical documentation, READMEs, contributing guides | Clear, professional, balanced |
| Lower | Internal notes, casual updates, quick references | Direct, concise, conversational |

Regardless of formality level, maintain professionalism and precision.
