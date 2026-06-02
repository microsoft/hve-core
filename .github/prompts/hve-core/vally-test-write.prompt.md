---
description: "Authors Vally conformance test stimuli for an existing prompt, instructions, agent, or skill artifact - Brought to you by microsoft/hve-core"
agent: Prompt Builder
argument-hint: "[files=...] [kind=auto] [mode=from-artifact]"
---

# Vally Test Write

## Inputs

* (Optional) files - ${input:files}: Target artifact file(s) to author conformance test stimuli for. Defaults to the current open file or attached file(s).
* (Optional) kind - ${input:kind:auto}: Artifact kind (`prompt`, `instructions`, `agent`, or `skill`). Defaults to `auto` for detection from the artifact path and frontmatter.

## What this prompt does

Dispatches the `Vally Test Author` subagent in `from-artifact` mode for each resolved file. The subagent drafts a conformance stimulus YAML block per documented behavior the artifact already claims and appends each block to the routed Vally eval file per `.github/skills/hve-core/vally-tests/references/eval-suite-routing.md`.

The subagent runs a Safety Self-Check before any write using the seven-category refusal taxonomy at `.github/skills/hve-core/vally-tests/references/refusal-taxonomy.md` (jailbreak, prompt-injection, harmful-elicitation, tos-violation, coc-violation, model-refusal-elicitation, pii-extraction). A matched category triggers the canonical refusal block and skips the write for that stimulus.

## Required Protocol

1. Resolve `files` from the `files=` argument when supplied, otherwise from the current open file or attached file(s) in the conversation.
2. For each resolved file, dispatch the `Vally Test Author` subagent with `mode=from-artifact`, `files=<resolved>`, and `kind=<resolved or auto>`.
3. Surface the subagent's Handoff Format output for each dispatch: target eval file path, stimuli appended count, duplicates skipped, refusals triggered, and JSON report path.
