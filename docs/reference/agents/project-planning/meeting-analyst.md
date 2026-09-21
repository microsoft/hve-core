---
title: Meeting Analyst
description: Meeting transcript analyzer that extracts product requirements for PRD creation via work-iq-mcp
sidebar_position: 5
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - project-planning
  - meeting-analyst
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                      |
|-------------|------------------------------------------------------------|
| Kind        | agent                                                      |
| Source      | `.github/agents/project-planning/meeting-analyst.agent.md` |
| Invocation  | Selected from the chat agent picker as `Meeting Analyst`   |
| Interactive | Yes                                                        |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Meeting transcript analyzer that extracts product requirements for PRD creation via work-iq-mcp
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use Meeting Analyst to extract requirements, decisions, and action items from Microsoft 365 meeting transcripts for a PRD handoff. It distinguishes participant authority and unvalidated suggestions. Use PRD Builder directly when the requirements are already available in an approved document.

## How to use it

1. Select `Meeting Analyst`, review the data-sensitivity notice, and identify the meetings and initiative using the available Microsoft 365 connection.
2. Confirm participant roles and decision authority before requirements extraction.
3. Review anonymized findings, conflicts, and statements marked as needing validation before handing them to PRD Builder.
4. After the handoff is complete, follow the retention guidance for local analysis and state files. Deletion requires your confirmation; raw transcripts and customer identifiers should not enter public artifacts.

## Example usage

Ask: "Analyze the two service-portal discovery meetings I identify. Separate confirmed decisions from suggestions, let me confirm participant authority, and prepare an anonymized PRD handoff."

Expect structured findings with evidence and validation status, not a verbatim transcript dump. Success means tentative or external-participant requests are not silently promoted into approved requirements.
