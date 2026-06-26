---
description: "Run functional, standards, and accessibility code reviews on the current branch in a single pass"
name: code-review-full
agent: Code Review Full (pre)
argument-hint: "[story=AIAA-123]"
---

# Code Review Full

* ${input:story}: (Optional) A work item reference (e.g. `AIAA-123`, `AB#456`). When provided, the standards review includes an Acceptance Criteria Coverage table. The full review also runs functional and accessibility review passes.

---

