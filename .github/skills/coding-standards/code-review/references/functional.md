---
description: 'Functional review reference for Code Review covering contribution bar, bugs and side effects, refactored control flow, missed APIs/SDKs, missed abstractions, and unneeded edge-case checks.'
---

# Functional review

## Goal

Ensure changed code meets the contribution bar of the codebase, preserves behavioral invariants, reuses existing APIs and abstractions, and keeps control paths clean without unneeded defensive clutter. Follow [review-contract.md](review-contract.md) and tag findings with vector `functional`.

## What to inspect

Read the assigned areas, files, and captured hunks, then trace caller and callee context according to the assigned depth (`basic`, `standard`, or `comprehensive`):

* Contribution bar and requirements: compare delivered behavior against codebase requirements, module contracts, and supplied acceptance criteria. Record each assigned acceptance criterion in `observations` as `Implemented`, `Partial`, `Not found`, or `Not assessed` with evidence and gaps (missing story definitions stay `Not assessed`).
* Unintended behaviors, side effects, and regressions: trace success paths, failure paths, boundary inputs, state mutations, async/concurrency interleavings, resource ownership, persistence, and backward compatibility. Preserve removed-line (`old`) anchors when a deletion causes a regression.
* Cleaned-up and refactored code paths: flag tangled compensating branches, duplicated local plumbing, or multi-step workarounds where reading backward from the required outcome reveals a direct, linear control path.
* Missed APIs, built-ins, or SDKs: check surrounding modules and approved dependencies for existing runtime built-ins, SDK methods, or codebase helpers that solve the problem directly instead of custom hand-rolled logic.
* Missed abstractions to reuse or extend: identify existing interfaces, base types, validators, or shared modules in the codebase that the change bypassed or duplicated, while rejecting speculative new wrappers where plain functions and data are clearer.
* Extra or leftover edge-case checks: flag redundant internal null/type guards, impossible defensive branches, swallowed errors, or scaffolding left behind from earlier iterations that cannot occur under established internal invariants. Never recommend removing genuine trust-boundary checks (external input validation, path containment, authentication, authorization, secret redaction, or untrusted-content handling).
* Test evidence: check whether tests verify real behavior and failure modes rather than restating implementation details; distinguish test presence from verified execution.

## Boundaries

* Do not read non-functional references (`security.md`, `specialist.md`, `accessibility.md`, `integrations.md`) or activate non-functional skills during functional review.
* Report a finding only when captured hunks and surrounding codebase evidence establish a concrete defect, regression, missed reuse, or maintainability hazard. Check counter-evidence first.
* Record pre-existing unrelated issues as factual `observations` rather than verdict-bearing findings.
* Leave PR deliverable metadata anchors (`side: "metadata"`) to `readiness`.

## Completion

Write a validated result via `node scripts/review.mjs result` covering every assigned file and hunk (or a reasoned `notApplicable` string). Stop as `blocked` when missing contracts or unreadable evidence prevent completing the check, naming the smallest required input.
