# LLM Vulnerability Catalog Constants

Example constants block for the LLM vulnerability catalog.

LLM_VULN_CATALOG: JSON<<
{
  "LLM01": {"title": "Prompt Injection", "category": "Input Integrity"},
  "LLM02": {"title": "Sensitive Information Disclosure", "category": "Data Protection"},
  "LLM03": {"title": "Supply Chain", "category": "Supply Chain"},
  "LLM04": {"title": "Data and Model Poisoning", "category": "Data Integrity"},
  "LLM05": {"title": "Improper Output Handling", "category": "Output Safety"},
  "LLM06": {"title": "Excessive Agency", "category": "Access Control"},
  "LLM07": {"title": "System Prompt Leakage", "category": "Configuration Security"},
  "LLM08": {"title": "Vector and Embedding Weaknesses", "category": "Data Integrity"},
  "LLM09": {"title": "Misinformation", "category": "Output Reliability"},
  "LLM10": {"title": "Unbounded Consumption", "category": "Resource Management"}
}
>>

LLM_SEVERITY_LEVELS: JSON<<
{
  "CRITICAL": "Immediate exploitation leads to full system compromise or data exfiltration.",
  "HIGH": "Exploitation requires minimal prerequisites and results in significant impact.",
  "MEDIUM": "Exploitation requires specific conditions but leads to meaningful security degradation.",
  "LOW": "Exploitation is difficult or impact is limited in scope."
}
>>
