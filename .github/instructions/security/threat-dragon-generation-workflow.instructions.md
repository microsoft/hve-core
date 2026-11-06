---
description: "Human-in-the-loop contract for OWASP Threat Dragon threat-model generation"
applyTo: '.github/agents/security/security-planner.agent.md, .github/agents/security/security-reviewer.agent.md'
---

# Threat Dragon Generation Workflow

This file owns the human-in-the-loop contract that every agent invoking OWASP Threat Dragon model generation must follow. It defines confirmation behavior only; entry points, flags, and output mechanics belong to the security-planning skill.

## Authorship confirmation

When the user requests a Threat Dragon threat-model draft, refresh, or update, the agent may run the `generate_threat_dragon.py` generator to produce the Threat Dragon JSON model from the threat-model spec. That permission covers generation and validation only.

Before treating any generated output as authored or final, the agent must present the input spec and the generated result to the user, say: "I have prepared the proposed specification and generated output below for your review. Please confirm explicitly before I treat it as authored or final.", and then wait for that confirmation.

Until confirmation arrives, the generated model is unconfirmed. The agent does not record it as a phase artifact, does not advance a phase gate on it, and does not hand it off to backlog, review, or another agent. A missing, ambiguous, or declined response leaves it unconfirmed; the agent reports the model as awaiting confirmation rather than inferring approval from silence.

The agent keeps the human in the loop for the spec and the generated model, and it does not author decisions on the user's behalf.

## Spec changes for Threat Dragon

When Threat Dragon needs a security fact the spec lacks, such as an owner, an out-of-scope component, or a two-way flow, the agent proposes the optional spec field to the user rather than inventing the value. An unknown fact stays absent from the spec. The same spec continues to drive TM7 generation, so the agent does not fork a Threat Dragon-only copy of it.
