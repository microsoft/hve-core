---
description: "Synthetic current-state security review report fixture for sample-service"
---

# Security Review Report 001

## Confirmed findings

| Finding ID   | Verdict | Severity | Location             | Finding                            |
|--------------|---------|----------|----------------------|------------------------------------|
| WEB-INPUT    | PASS    | N/A      | `src/api/gateway.ts` | Request validation is present.     |
| AUTHZ-OBJECT | FAIL    | HIGH     | `src/auth/policy.ts` | Object authorization remains open. |

This report is current-state evidence for drift comparison against the sample-service security plan.

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
