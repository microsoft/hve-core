---
title: Backlog Draft
description: Initial backlog hierarchy for the relationship manager workshop scenario
sidebar_position: 5
author: Microsoft
ms.date: 2026-08-16
ms.topic: reference
keywords:
  - backlog
  - workshop
  - FSI
  - relationship manager
estimated_reading_time: 5
---

## First MVP Backlog Draft

This draft refines the workshop requirements into a more implementation-ready backlog for the first MVP. It stays lightweight, but it is structured enough for backlog refinement, sequencing, and early implementation planning.

### Epic

* EPIC-01 Prepare the relationship manager for customer conversations with a trusted account view

### Features

* FEAT-01 Unified account context view
* FEAT-02 Evidence-backed priority signals and next-best actions
* FEAT-03 Reviewable follow-up and action capture

### Stories and Tasks

#### FEAT-01 Unified account context view

* STORY-01 As a relationship manager, I can open an account view that consolidates customer, account, and activity context so I can prepare quickly.
  * TASK-01 Identify approved data sources for the workshop scenario.
  * TASK-02 Create a simple account summary view that surfaces key customer and account facts.
  * TASK-03 Display recent interactions, transactions, and internal notes in one place.
  * TASK-04 Define the initial layout for the first-slice experience and its core information hierarchy.

#### FEAT-02 Evidence-backed priority signals and next-best actions

* STORY-02 As a relationship manager, I can see which accounts need attention now and why.
  * TASK-05 Define the initial priority rules for risk and growth signals.
  * TASK-06 Surface urgency, risk indicators, and growth opportunities with supporting evidence.
  * TASK-07 Label recommendations as high confidence, low confidence, or uncertain when data is incomplete.

* STORY-03 As a relationship manager, I can review suggested next-best actions with clear rationale before acting.
  * TASK-08 Create a recommendation panel for the next-best action.
  * TASK-09 Show the evidence and reasoning behind each recommendation.
  * TASK-10 Add a review path for approve, defer, or escalate decisions.

#### FEAT-03 Reviewable follow-up and action capture

* STORY-04 As a relationship manager, I can record the chosen action and keep follow-up work aligned.
  * TASK-11 Create a simple action capture flow for selected follow-up steps.
  * TASK-12 Record the action outcome and completion status for review.
  * TASK-13 Ensure the workflow fails safely when the system cannot produce a trustworthy recommendation.

### Suggested Priority for the First MVP

* P0: Unified account context view
* P0: Evidence-backed recommendations with clear rationale
* P1: Reviewable follow-up and action capture

### Publication Readiness Notes

* Capture early packaging and discoverability requirements for Microsoft Marketplace and Microsoft 365 Copilot Agent Store.
* Document the minimum user experience and support expectations needed for review readiness, including clear value, trust, and explainability.
* Keep the first MVP focused on a clearly scoped scenario so it remains easy to review and publish later.

### GitHub Issue Status

* A planning-ready backlog hierarchy has been prepared for the first slice.
* The backlog is ready to be translated into GitHub Issues once a GitHub-capable execution context is available.

### Notes for Backlog Refinement

* Keep the first slice focused on one primary scenario: preparing for a customer conversation.
* Treat evidence, trust, and human review as core requirements rather than optional enhancements.
* Use this draft as the starting point for a more detailed implementation backlog once the team confirms scope and data availability.
