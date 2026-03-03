---
title: Root Cause Analysis (RCA) Template
description: Structured post-incident documentation template for root cause analysis
sidebar_position: 3
author: Microsoft
ms.date: 2026-02-04
---

This template provides a structured format for post-incident documentation, inspired by industry best practices including [Google's SRE Postmortem Culture](https://sre.google/sre-book/postmortem-culture/) and [Example Postmortem](https://sre.google/sre-book/example-postmortem/).

## Template

```markdown
# Incident Report: {Title}

## Summary

- **Incident ID**: INC-YYYY-MMDD-NNN
- **Date**: {Date}
- **Duration**: {Start} to {End} ({total time})
- **Severity**: {1-4}
- **Services Affected**: {list}
- **Incident Commander**: {Name}

## Executive Summary

{2-3 sentence summary of what happened, impact, and resolution}

## Timeline

All times in UTC.

| Time  | Event                         |
|-------|-------------------------------|
| HH:MM | {First symptom detected}      |
| HH:MM | {Incident declared}           |
| HH:MM | {Key investigation milestone} |
| HH:MM | {Mitigation applied}          |
| HH:MM | {Service restored}            |
| HH:MM | {Incident resolved}           |

## Impact

- **Users affected**: {count or percentage}
- **Transactions impacted**: {count}
- **Revenue impact**: {if applicable}
- **SLA impact**: {if applicable}
- **Data loss**: {Yes/No, details if applicable}

## Root Cause

{Detailed technical explanation of what caused the incident. Be specific and factual.}

## Contributing Factors

- {Factor 1: e.g., Missing monitoring for specific failure mode}
- {Factor 2: e.g., Documentation gap in runbooks}
- {Factor 3: e.g., Insufficient testing coverage}

## Trigger

{What specific event triggered the incident? Deployment, configuration change, traffic spike, external dependency failure, etc.}

## Resolution

{What was done to resolve the incident? Include specific commands, rollbacks, or configuration changes.}

## Detection

- **How was the incident detected?** {Monitoring alert / Customer report / Manual discovery}
- **Time to detect (TTD)**: {minutes from incident start to detection}
- **Could detection be improved?** {Yes/No, how}

## Response

- **Time to engage (TTE)**: {minutes from detection to first responder}
- **Time to mitigate (TTM)**: {minutes from engagement to mitigation}
- **Time to resolve (TTR)**: {minutes from incident start to full resolution}

## Five Whys Analysis

1. **Why** did the service fail?
   → {Answer}

2. **Why** did that happen?
   → {Answer}

3. **Why** was that the case?
   → {Answer}

4. **Why** wasn't this prevented?
   → {Answer}

5. **Why** wasn't this detected earlier?
   → {Answer}

## Action Items

| ID | Priority | Action                                | Owner  | Due Date | Status |
|----|----------|---------------------------------------|--------|----------|--------|
| 1  | P1       | {Immediate fix to prevent recurrence} | {Name} | {Date}   | Open   |
| 2  | P2       | {Improve monitoring/alerting}         | {Name} | {Date}   | Open   |
| 3  | P2       | {Update documentation/runbooks}       | {Name} | {Date}   | Open   |
| 4  | P3       | {Long-term systemic improvement}      | {Name} | {Date}   | Open   |

## Lessons Learned

### What went well

- {e.g., Quick detection due to recent monitoring improvements}
- {e.g., Effective communication during incident}

### What went poorly

- {e.g., Runbook was outdated}
- {e.g., Escalation path unclear}

### Where we got lucky

- {e.g., Incident occurred during low-traffic period}
- {e.g., Expert happened to be available}

## Supporting Information

- **Related incidents**: {links to similar past incidents}
- **Monitoring dashboards**: {links}
- **Relevant logs/queries**: {links or references}
- **Slack/Teams thread**: {link to incident channel}
```

## Usage Guidelines

1. **Start the document immediately** when an incident is declared
2. **Update continuously** during the incident - don't rely on memory afterward
3. **Be blameless** - focus on systems and processes, not individuals
4. **Be thorough** - future responders will thank you
5. **Track action items** - incidents without follow-through will repeat

## References

* [Google SRE Book: Postmortem Culture](https://sre.google/sre-book/postmortem-culture/)
* [Google SRE Book: Example Postmortem](https://sre.google/sre-book/example-postmortem/)
* [Atlassian Incident Management](https://www.atlassian.com/incident-management/postmortem)

---

🤖 *Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
