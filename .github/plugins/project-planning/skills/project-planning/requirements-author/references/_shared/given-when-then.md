---
description: 'Canonical Given/When/Then (Gherkin) acceptance-criteria pattern used by the BRD Builder workflow, with generic non-product-specific examples and BSD-3 attribution to the Cucumber project'
---

# Given/When/Then - Gherkin Pattern

This document describes the Given/When/Then acceptance-criteria pattern the BRD Builder emits by default. The pattern is part of the Gherkin language published by the Cucumber project. This file uses the keyword names and the canonical clause order under [BSD 3-Clause](https://opensource.org/licenses/BSD-3-Clause) attribution; no Cucumber documentation prose is reproduced.

## Attribution

The Gherkin language and the Given/When/Then keyword vocabulary originate with the [Cucumber project](https://github.com/cucumber/gherkin) (accessed 2026-05-25), distributed under the BSD 3-Clause license. Use of the keywords in this document is limited to the canonical clause names and clause order, and is original Microsoft content describing how the BRD Builder applies the pattern.

## Clause Structure

A Given/When/Then acceptance criterion has three required clauses and two optional connectors:

| Clause  | Required | Purpose                                                                        |
|---------|----------|--------------------------------------------------------------------------------|
| `Given` | Yes      | Establishes the precondition or context that must hold before the behavior.    |
| `When`  | Yes      | Names the event, action, or input that triggers the behavior under test.       |
| `Then`  | Yes      | States the observable outcome the solution must produce.                       |
| `And`   | No       | Chains an additional clause of the same kind as the immediately preceding one. |
| `But`   | No       | Chains a contrasting outcome (typically inside `Then`).                        |

Each criterion expresses exactly one behavior. Multi-behavior criteria are split into separate triplets before they are recorded in a BRD.

## Authoring Rules

The BRD Builder applies these rules when authoring a Given/When/Then criterion:

1. **One behavior per triplet.** A criterion with two independent `When` clauses is split into two criteria.
2. **Externally observable outcomes.** The `Then` clause names a state, response, or artifact the user or another system can observe. Internal log messages and implementation details are out of scope.
3. **No quantifiers without thresholds.** Replace `quickly`, `most`, `usually` with measurable thresholds or remove them.
4. **Stable subject across clauses.** The subject of the `When` clause is the actor; the subject of the `Then` clause is the system under test or a downstream observer.
5. **No solution-internal references.** Avoid naming internal modules, table names, or API routes. Acceptance criteria describe what, not how.

The full atomicity checklist is recorded in [atomicity-checklist.md](atomicity-checklist.md).

## Generic Examples

The examples below illustrate the pattern using common domains. They are intentionally non-product-specific and reusable across BRD drafts. They are original Microsoft content.

### Example 1 - User login

```gherkin
Given a registered account with a valid email and password
When the user submits the sign-in form with the correct credentials
Then the user is signed in and redirected to the home view
```

### Example 2 - Search with no results

```gherkin
Given the user is on the search view
When the user submits a query that matches no records
Then the search view displays an empty-state message identifying the query that returned no results
```

### Example 3 - E-commerce checkout, declined payment

```gherkin
Given the user has a cart with at least one item and a valid shipping address
When the user submits checkout with a payment method that the payment processor declines
Then the order is not created
And the user is shown a checkout error that names the declined payment method
And the cart contents are preserved
```

### Example 4 - Threshold criterion attached to a non-functional requirement

```gherkin
Given the service is running its production configuration under nominal load
When 100 requests per second are sustained for 10 minutes
Then the p95 response latency stays at or below 200 ms
```

## Anti-Patterns

The patterns below are rejected by the assessor and rewritten before they are recorded.

* **Compound When.** `When the user signs in and uploads a file` - split into two criteria.
* **Compound Then with independent failure modes.** `Then the user is signed in and the welcome email is sent` - split when the two outcomes can fail independently.
* **Internal-only Then.** `Then a row is inserted into the sessions table` - rewrite to describe the externally observable outcome.
* **Unmeasured quantifier.** `Then the page loads quickly` - rewrite with a measurable threshold.
* **Solution naming in Given.** `Given the AuthGateway service is healthy` - rewrite without the implementation detail unless the requirement is explicitly about that component.

## License

This pointer file is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The Gherkin language and the Given/When/Then keyword vocabulary are the property of the Cucumber project and are subject to the [BSD 3-Clause](https://opensource.org/licenses/BSD-3-Clause) license at the upstream source.

## Citations

* Cucumber project - Gherkin language and parser. [https://github.com/cucumber/gherkin](https://github.com/cucumber/gherkin) (accessed 2026-05-25).


