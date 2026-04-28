---
title: "{{productName}} - Product Requirements Document"
description: "Product requirements for {{briefDescription}}"
sidebar_position: 3
author: "{{authorName}}"
ms.date: 2026-04-22
ms.topic: reference
---

<!-- markdownlint-disable-file -->
<!-- markdown-table-prettify-ignore-start -->

Version \{\{version\}\} | Status \{\{status\}\} | Owner \{\{docOwner\}\} | Team \{\{owningTeam\}\} | Target \{\{targetRelease\}\} | Lifecycle \{\{lifecycleStage\}\}

## Progress Tracker

| Phase             | Done                            | Gaps                        | Updated                        |
|-------------------|---------------------------------|-----------------------------|--------------------------------|
| Context           | \{\{phaseContextComplete\}\}    | \{\{phaseContextGaps\}\}    | \{\{phaseContextUpdated\}\}    |
| Problem & Users   | \{\{phaseProblemComplete\}\}    | \{\{phaseProblemGaps\}\}    | \{\{phaseProblemUpdated\}\}    |
| Scope             | \{\{phaseScopeComplete\}\}      | \{\{phaseScopeGaps\}\}      | \{\{phaseScopeUpdated\}\}      |
| Requirements      | \{\{phaseReqsComplete\}\}       | \{\{phaseReqsGaps\}\}       | \{\{phaseReqsUpdated\}\}       |
| Metrics & Risks   | \{\{phaseMetricsComplete\}\}    | \{\{phaseMetricsGaps\}\}    | \{\{phaseMetricsUpdated\}\}    |
| Operationalization| \{\{phaseOpsComplete\}\}        | \{\{phaseOpsGaps\}\}        | \{\{phaseOpsUpdated\}\}        |
| Finalization      | \{\{phaseFinalComplete\}\}      | \{\{phaseFinalGaps\}\}      | \{\{phaseFinalUpdated\}\}      |

Unresolved Critical Questions: \{\{unresolvedCriticalQuestionsCount\}\} | TBDs: \{\{tbdCount\}\}

## 1. Executive Summary

### Context

\{\{executiveContext\}\}

### Core Opportunity

\{\{coreOpportunity\}\}

### Goals

| Goal ID | Statement | Type | Baseline | Target | Timeframe | Priority |
|---------|-----------|------|----------|--------|-----------|----------|
\{\{goalsTable\}\}

### Objectives (Optional)

| Objective | Key Result | Priority | Owner |
|-----------|------------|----------|-------|
\{\{objectivesTable\}\}

## 2. Problem Definition

### Current Situation

\{\{currentSituation\}\}

### Problem Statement

\{\{problemStatement\}\}

### Root Causes

* \{\{rootCause1\}\}
* \{\{rootCause2\}\}

### Impact of Inaction

\{\{impactOfInaction\}\}

## 3. Users & Personas

| Persona | Goals | Pain Points | Impact |
|---------|-------|-------------|--------|
\{\{personasTable\}\}

### Journeys (Optional)

\{\{userJourneysSummary\}\}

## 4. Scope

### In Scope

* \{\{inScopeItem1\}\}

### Out of Scope (justify if empty)

* \{\{outOfScopeItem1\}\}

### Assumptions

* \{\{assumption1\}\}

### Constraints

* \{\{constraint1\}\}

## 5. Product Overview

### Value Proposition

\{\{valueProposition\}\}

### Differentiators (Optional)

* \{\{differentiator1\}\}

### UX / UI (Conditional)

\{\{uxConsiderations\}\} | UX Status: \{\{uxStatus\}\}

## 6. Functional Requirements

| FR ID | Title | Description | Goals | Personas | Priority | Acceptance | Notes |
|-------|-------|-------------|-------|----------|----------|------------|-------|
\{\{functionalRequirementsTable\}\}

### Feature Hierarchy (Optional)

```plain
\{\{featureHierarchySkeleton\}\}
```

## 7. Non-Functional Requirements

| NFR ID | Category | Requirement | Metric/Target | Priority | Validation | Notes |
|--------|----------|-------------|---------------|----------|------------|-------|
\{\{nfrTable\}\}

Categories: Performance, Reliability, Scalability, Security, Privacy, Accessibility, Observability, Maintainability, Localization (if), Compliance (if).

## 8. Data & Analytics (Conditional)

### Inputs

\{\{dataInputs\}\}

### Outputs / Events

\{\{dataOutputs\}\}

### Instrumentation Plan

| Event | Trigger | Payload | Purpose | Owner |
|-------|---------|---------|---------|-------|
\{\{instrumentationTable\}\}

### Metrics & Success Criteria

| Metric | Type | Baseline | Target | Window | Source |
|--------|------|----------|--------|--------|--------|
\{\{metricsTable\}\}

## 9. Dependencies

| Dependency | Type | Criticality | Owner | Risk | Mitigation |
|------------|------|-------------|-------|------|------------|
\{\{dependenciesTable\}\}

## 10. Risks & Mitigations

| Risk ID | Description | Severity | Likelihood | Mitigation | Owner | Status |
|---------|-------------|----------|------------|------------|-------|--------|
\{\{risksTable\}\}

## 11. Privacy, Security & Compliance

### Data Classification

\{\{dataClassification\}\}

### PII Handling

\{\{piiHandling\}\}

### Threat Considerations

\{\{threatSummary\}\}

### Regulatory / Compliance (Conditional)

| Regulation | Applicability | Action | Owner | Status |
|------------|---------------|--------|-------|--------|
\{\{complianceTable\}\}

## 12. Operational Considerations

| Aspect            | Requirement                  | Notes |
|-------------------|------------------------------|-------|
| Deployment        | \{\{deploymentNotes\}\}      |       |
| Rollback          | \{\{rollbackPlan\}\}         |       |
| Monitoring        | \{\{monitoringPlan\}\}       |       |
| Alerting          | \{\{alertingPlan\}\}         |       |
| Support           | \{\{supportModel\}\}         |       |
| Capacity Planning | \{\{capacityPlanning\}\}     |       |

## 13. Rollout & Launch Plan

### Phases / Milestones

| Phase | Date | Gate Criteria | Owner |
|-------|------|---------------|-------|
\{\{phasesTable\}\}

### Feature Flags (Conditional)

| Flag | Purpose | Default | Sunset Criteria |
|------|---------|---------|-----------------|
\{\{featureFlagsTable\}\}

### Communication Plan (Optional)

\{\{communicationPlan\}\}

## 14. Open Questions

| Q ID | Question | Owner | Deadline | Status |
|------|----------|-------|----------|--------|
\{\{openQuestionsTable\}\}

## 15. Changelog

| Version | Date | Author | Summary | Type |
|---------|------|--------|---------|------|
\{\{changelogTable\}\}

## 16. References & Provenance

| Ref ID | Type | Source | Summary | Conflict Resolution |
|--------|------|--------|---------|---------------------|
\{\{referenceCatalogTable\}\}

### Citation Usage

\{\{citationUsageNotes\}\}

## 17. Appendices (Optional)

### Glossary

| Term | Definition |
|------|------------|
\{\{glossaryTable\}\}

### Additional Notes

\{\{additionalNotes\}\}

Generated \{\{generationTimestamp\}\} by \{\{generatorName\}\} (mode: \{\{generationMode\}\})

<!-- markdown-table-prettify-ignore-end -->

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
