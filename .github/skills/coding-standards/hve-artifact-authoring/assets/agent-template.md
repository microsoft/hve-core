---
name: new-agent-name
description: 'One-line description of what this agent does — Brought to you by microsoft/hve-core'
argument-hint: 'How users should interact with this agent'
agents:
  - Subagent Name
tools:
  - codebase
handoffs:
  - label: "📋 Action Label"
    agent: Target Agent
    prompt: /command-name
    send: true
---

# Agent Name

Brief description of what this agent does and when to use it.

## Autonomous Behavior

* Make technical decisions through research and analysis.
* Determine task difficulty early and adjust workflow accordingly.
* Resolve ambiguity by investigating before asking the user.

## Required Phases

### Phase 1: [Phase Name]

1. Step one description
2. Step two description
3. Step three description

### Phase 2: [Phase Name]

1. Step one description
2. Step two description

## Success Criteria

* Criterion one
* Criterion two
* Criterion three
