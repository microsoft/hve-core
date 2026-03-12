<format id="WEB_REMEDIATION_CHECKLIST_V1" name="Web Remediation Checklist" purpose="Actionable remediation plan for addressing identified web application vulnerabilities.">
## Remediation Plan — <VULN_ID>

**Generated:** <TIMESTAMP>
**Target Application:** <APP_NAME>

### Immediate Actions (0-24 hours)

| # | Action | Owner | Status | Deadline |
|---|---|---|---|---|
| <ACTION_NUM> | <ACTION_DESCRIPTION> | <OWNER> | <ACTION_STATUS> | <DEADLINE> |

### Short-Term Controls (1-7 days)

| # | Control | Owner | Status | Deadline |
|---|---|---|---|---|
| <CONTROL_NUM> | <CONTROL_DESCRIPTION> | <OWNER> | <ACTION_STATUS> | <DEADLINE> |

### Long-Term Improvements (7-30 days)

| # | Improvement | Owner | Status | Deadline |
|---|---|---|---|---|
| <IMPROVE_NUM> | <IMPROVE_DESCRIPTION> | <OWNER> | <ACTION_STATUS> | <DEADLINE> |

### Verification Criteria

* <VERIFICATION_ITEM>

WHERE:

* <VULN_ID> is String; OWASP Web Application Security identifier (e.g., "A01:2025").
* <TIMESTAMP> is ISO8601; when the plan was generated.
* <APP_NAME> is String; target application or system name.
* <ACTION_NUM> is Integer; sequential action number.
* <ACTION_DESCRIPTION> is String; specific remediation action.
* <OWNER> is String; responsible individual or team.
* <ACTION_STATUS> is one of: PENDING, IN_PROGRESS, COMPLETED, BLOCKED.
* <DEADLINE> is ISO8601; target completion date.
* <CONTROL_NUM> is Integer; sequential control number.
* <CONTROL_DESCRIPTION> is String; defensive control to implement.
* <IMPROVE_NUM> is Integer; sequential improvement number.
* <IMPROVE_DESCRIPTION> is String; long-term security improvement.
* <VERIFICATION_ITEM> is String; criterion to confirm remediation effectiveness.
</format>
