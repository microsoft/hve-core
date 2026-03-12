# Agentic Vulnerability Catalog Constants

Example constants block for the agentic vulnerability catalog.

AGENTIC_VULN_CATALOG: JSON<<
{
  "ASI01": {"title": "Agent Goal Hijack", "category": "Goal Integrity"},
  "ASI02": {"title": "Tool Misuse and Exploitation", "category": "Tool Security"},
  "ASI03": {"title": "Identity and Privilege Abuse", "category": "Access Control"},
  "ASI04": {"title": "Agentic Supply Chain Vulnerabilities", "category": "Supply Chain"},
  "ASI05": {"title": "Unexpected Code Execution", "category": "Execution Safety"},
  "ASI06": {"title": "Memory and Context Poisoning", "category": "Data Integrity"},
  "ASI07": {"title": "Insecure Inter-Agent Communication", "category": "Communication Security"},
  "ASI08": {"title": "Cascading Failures", "category": "Resilience"},
  "ASI09": {"title": "Human-Agent Trust Exploitation", "category": "Human Factors"},
  "ASI10": {"title": "Rogue Agents", "category": "Behavioral Integrity"}
}
>>

AGENTIC_SEVERITY_LEVELS: JSON<<
{
  "CRITICAL": "Immediate exploitation leads to full system compromise or data exfiltration.",
  "HIGH": "Exploitation requires minimal prerequisites and results in significant impact.",
  "MEDIUM": "Exploitation requires specific conditions but leads to meaningful security degradation.",
  "LOW": "Exploitation is difficult or impact is limited in scope."
}
>>
