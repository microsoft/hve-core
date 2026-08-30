---
title: Proposal Response Builder Extension Contract
description: Shared activation, session-state, rejected-operation, and reporting rules for a parent builder agent that invokes this skill.
---

## Scope

This reference is for a parent requirements-builder agent, such as BRD Builder or PRD Builder, that invokes `proposal-response` as an extension. It owns the rules those agents share. Each agent keeps only its own activation statement, domain binding, and operation bindings.

Direct invocation of the skill does not need this reference.

## Activation

Activate the skill only when the user explicitly asks for proposal, RFI, RFP, questionnaire, tender, bid-response, or reusable response-evidence work.

Continue from the supplied proposal-response artifact path when the user names one, or let the skill create its canonical tracking artifact. Pass approved source artifact paths, such as an existing BRD or PRD the user names, to the skill rather than transcribing their contents into chat.

The extension does not change the canonical requirements document, lifecycle gates, quality-report authority, approval process, or release authority. It grants no authority the skill does not already have.

## Session State

After the skill content is available, append the agent's own extension entry to `state.extensionsLoaded` once.

Record an artifact path only when the skill returns `RESPONSE_EVIDENCE_POINTER_V1`. Create `state.proposalResponseArtifacts` if it is absent, append that pointer's `artifact_path` once, and pass that path to later operations instead of copying `RESPONSE_EVIDENCE_V1` into chat or state.

Treat missing extension arrays as empty, preserve unknown state fields, and do not use the extension record for `phaseSkillsLoaded` deduplication. Each value appears exactly once in each array.

## Rejected Operations

When the skill returns `RESPONSE_EVIDENCE_ERROR_V1`, the operation was rejected and no artifact was written. Leave `state.proposalResponseArtifacts` unchanged, do not create it, and never append that payload's `artifact_path`. Report the payload's `validation_error` and `clearing_action` to the user.

## Reporting

Report the operation with the compact pointer or error payload the skill returns. The skill owns that response contract; do not restate it, reorder it, or inline the full evidence payload.

Report the agent's own `extensionsLoaded` and `proposalResponseArtifacts` values alongside the skill's payload, each value listed exactly once. These arrays belong to the agent's session state, not to the skill's contract.

When the skill returns `RESPONSE_EVIDENCE_POINTER_V1`, close the extension turn
by naming the operation its `next_operation` reports, so the user knows the
remaining step without re-reading the payload. A rejected turn has no next
operation; close it with the error payload's `validation_error` and
`clearing_action`.
