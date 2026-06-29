---
description: 'PRD EARS acceptance-criteria reference - the five Easy Approach to Requirements Syntax sentence patterns (ubiquitous, event-driven, state-driven, unwanted-behavior, optional-feature) described in original Microsoft prose with generic non-product-specific examples and cite-only attribution to Mavin et al.'
---

# EARS Acceptance Criteria

This document describes the Easy Approach to Requirements Syntax (EARS) the PRD Builder emits when authoring requirement and acceptance statements. The five sentence patterns, authoring rules, and examples below are original Microsoft prose. EARS is attributed to its authors in the cite-only reference; no upstream paper text is reproduced.

## When to apply

Apply this reference during the PRD Build phase when:

* Writing functional requirement statements that must read unambiguously.
* Authoring acceptance criteria where a Given/When/Then triplet is heavier than needed.
* Tightening vague requirements ("the system should be fast") into testable sentences.

EARS and Given/When/Then are complementary: EARS shapes the requirement sentence; [given-when-then.md](../_shared/given-when-then.md) shapes the behavioral acceptance triplet. Either may anchor an acceptance criterion.

## The five EARS patterns (original prose)

Each pattern fixes the clause order so the trigger condition and the system response are unambiguous. The keyword `the system` stands in for the named solution or component.

### 1. Ubiquitous

An always-on requirement with no trigger condition.

> The system shall `<system response>`.

Use for invariants that hold at all times.

### 2. Event-driven

A response triggered by a discrete event.

> When `<trigger event>`, the system shall `<system response>`.

Use when a specific stimulus must produce a specific response.

### 3. State-driven

A response that holds while a condition is true.

> While `<system state>`, the system shall `<system response>`.

Use for behavior bound to a continuous mode or state.

### 4. Unwanted-behavior

A response to an error, fault, or disallowed input.

> If `<unwanted condition>`, then the system shall `<system response>`.

Use to specify how the system handles faults, invalid input, or policy violations.

### 5. Optional-feature

A response present only when a feature or configuration is enabled.

> Where `<feature is included>`, the system shall `<system response>`.

Use for behavior that depends on an optional capability, license tier, or deployment configuration.

Complex requirements may nest a precondition before the keyword — for example, `While <state>, when <event>, the system shall <response>` — but each statement still names exactly one response.

## Authoring rules

1. **One response per statement.** A sentence with two independent responses is split into two requirements.
2. **Pick the narrowest pattern.** Prefer event-driven or state-driven over ubiquitous when a trigger exists; ubiquitous is for true invariants only.
3. **Name the actor or trigger concretely.** Replace "when needed" or "as appropriate" with the actual event or state.
4. **No unquantified adjectives.** Replace `fast`, `secure`, `scalable` with a measurable threshold or move the target to a non-functional requirement.
5. **Observable responses only.** The response names a state, output, or artifact a user or downstream system can observe; internal implementation is out of scope.

## Generic examples (original Microsoft content)

These examples are intentionally non-product-specific and reusable across PRD drafts.

```text
Ubiquitous:      The system shall record every configuration change with an actor identifier and a timestamp.
Event-driven:    When a user submits the sign-in form with valid credentials, the system shall establish an authenticated session.
State-driven:    While a background sync is in progress, the system shall display a sync-status indicator.
Unwanted:        If an uploaded file exceeds the configured size limit, then the system shall reject the upload and report the limit.
Optional:        Where single sign-on is enabled, the system shall redirect unauthenticated users to the configured identity provider.
```

## Cite-only attribution

* **Source** — Alistair Mavin, Philip Wilkinson, Adrian Harwood, Mark Novak, "Easy Approach to Requirements Syntax (EARS)", 17th IEEE International Requirements Engineering Conference (RE'09), 2009.
* **URL** — [https://alistairmavin.com/ears/](https://alistairmavin.com/ears/)
* **Why the PRD Builder cites it** — Origin of the EARS sentence patterns. The pattern names and clause order are used under attribution; the descriptive prose, rules, and examples above are original Microsoft content and reproduce no text from the EARS paper.

## License

This reference file is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). EARS originates with Mavin et al.; the keyword names and clause order are used by name only, and the upstream paper is accessed by the reader through the cited URL.


