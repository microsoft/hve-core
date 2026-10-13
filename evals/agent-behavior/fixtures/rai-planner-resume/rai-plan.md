---
title: Support Reply Assistant RAI Plan
description: Synthetic RAI plan fixture paused at the start of Phase 3 for resume evaluation
---

## System Definition

The support reply assistant drafts responses to customer support tickets. A large language model generates each draft from the ticket text and up to five prior tickets from the same customer. A support agent reviews and edits every draft before it is sent.

### AI Component Inventory

| Component       | Role                                        | Data inputs                         |
|-----------------|---------------------------------------------|-------------------------------------|
| Reply generator | Drafts the customer reply                   | Ticket text, prior ticket history   |
| Context fetcher | Retrieves prior tickets for the same person | Customer identifier, ticket archive |

### Risk Classification Screening

* Prohibited uses gate: passed.
* Activated indicators: `safety_reliability` and `rights_fairness_privacy`.
* Suggested depth tier: comprehensive. The user confirmed this tier at the Phase 2 gate.

## Stakeholder Impact

* Customers receive replies that may reference their account history.
* Support agents remain accountable for every sent reply.

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
