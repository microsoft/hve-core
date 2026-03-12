# Remediation Checklist Format

Example format contract for LLM vulnerability remediation checklists.

<format id="LLM_REMEDIATION_CHECKLIST_V1" name="LLM Remediation Checklist" purpose="Structured checklist for tracking remediation of LLM vulnerabilities.">
| <VULN_ID> | <CONTROL> | <OWNER> | <DUE_DATE> | <STATUS> | <EVIDENCE> |
WHERE:
- <VULN_ID> is String matching pattern LLM[0-9]{2}.
- <CONTROL> is String describing the specific mitigation control to implement.
- <OWNER> is String identifying the responsible team or individual.
- <DUE_DATE> is ISO8601 date.
- <STATUS> is one of: NOT_STARTED, IN_PROGRESS, COMPLETED, DEFERRED.
- <EVIDENCE> is String referencing the artifact or proof of implementation.
</format>
