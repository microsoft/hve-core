---
description: Formatting, tone, and language rules for engagement reports
applyTo: "**/.github/agents/engagement-reporting/**, **/.github/prompts/engagement-reporting/**, **/.github/skills/engagement-reporting/**"
---

# Style Guide

Rules for formatting, tone, and language in engagement reports.

## Voice and Tone

* Use **active voice** throughout
* State facts confidently; avoid unsupported hedging
* Write for the audience's level: tactical for engineers, outcome-focused for
  directors, strategic for VPs
* Describe engagement outcomes and decisions, not how the reporting agent found
  them

## Formatting

* Do not add trailing full stops to bullet fragments
* Use semicolons to separate related clauses within a bullet
* Bold module or component names when it improves scanning
* Include dates for all scheduled events

## Language

### Do Not Use

* "deep dive", "sync up", "circle back", "leverage", "robust", "seamless"
* "&" in prose; write "and"
* Em dashes for parenthetical explanation; use semicolons or separate sentences
* AI patterns such as "I'm happy to help", "Let me know if", and "Here's what
  I found"
* Research-process phrases such as "primary-source evidence", "available
  evidence", "the search returned", "the transcript was unavailable", or
  "requires verification"
* Source-channel narration such as "Teams chat identified", "meeting notes
  showed", or "an email confirmed" unless the channel itself is materially
  relevant to the audience

### Evidence Separation

Keep source references, coverage gaps, confidence assessments, retrieval
details, and verification notes in `.working/` and the agent handoff. In the
report:

* State the supported business outcome directly
* Convert unresolved facts into a blocker, ask, or next step
* Omit unsupported detail rather than explaining the retrieval limitation
* Do not add a Coverage Note, Evidence Note, Research Summary, or source list

### Progression

Each update must demonstrate forward movement. Never repeat the same status.

* Bad: "Continuing work on the API integration" (same as last week)
* Good: "API integration reached 95% completion; awaiting schema validation
  from the customer team"

### Future Events as Achievements

* Bad: "Demo for SteerCo on 3/25" (future event listed as achievement)
* Good: "SteerCo demo prepared and scheduled for 3/25" (frames the preparation
  work)

## Spelling Conventions

Preserve original spelling conventions from contributors. Do not normalize
British and American spelling across sections authored by different people.
