---
title: Feasibility profile invalid fixture inventory
description: Mutation inventory for negative validation cases owned by the feasibility profile test suite
---

## Fixture basis

Each negative fixture starts from [valid-study.md](valid-study.md). The test suite applies one mutation at a time and proves that validation fails for the named reason.

| Fixture name         | Mutation                                                               |
|----------------------|------------------------------------------------------------------------|
| Unsupported version  | Set `profile_version` to `2.0.0`                                       |
| Duplicate ID         | Reuse one conceptual `item_id` for another item                        |
| Malformed UUID       | Replace an item ID with a non-URN string                               |
| Broken relation      | Point a relation to an unknown conceptual item                         |
| Cyclic revision      | Point the first revision to its descendant                             |
| Incomplete tombstone | Mark an item `superseded` without effective time, reason, or successor |
| Prohibited YAML      | Add an anchor and alias to the authoritative YAML block                |
| Orphaned anchor      | Remove one item narrative heading                                      |

The mutation inventory is durable documentation. Executable fixtures are produced in memory from the valid artifact so schema additions do not require eight copied studies to be synchronized manually.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
