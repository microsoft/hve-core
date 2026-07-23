---
name: mcsb
description: Microsoft Cloud Security Benchmark (MCSB v2) control-domain taxonomy and NIST 800-53 / CIS Controls crosswalk for planning and reviewing Azure cloud resources.
license: MIT
user-invocable: false
metadata:
  authors: "Microsoft"
  spec_version: "1.0"
  framework_revision: "MCSB v2 (preview)"
  last_updated: "2026-07-21"
  content_based_on: "https://learn.microsoft.com/en-us/security/benchmark/azure/overview"
---

# Microsoft Cloud Security Benchmark — Skill Entry

This `SKILL.md` is the entrypoint for the Microsoft Cloud Security Benchmark (MCSB) skill.

The skill encodes the durable, structurally stable layer of MCSB — the control-domain taxonomy and a domain-grain crosswalk to NIST SP 800-53 and CIS Controls — so the Security Planner and Security Reviewer can map and assess Azure cloud resources against a consistent control vocabulary.

The skill deliberately does not embed the volatile layer of MCSB (per-Azure-service security baselines, per-service control IDs, Azure Policy mappings, and Defender for Cloud assessment specifics). That content changes on Microsoft's release cadence and is retrieved at runtime through the Researcher Subagent per [references/lookup-playbook.md](references/lookup-playbook.md).
## Version and stability

This skill targets **MCSB v2**, which Microsoft marks as preview and which supersedes MCSB v1. Content is version-pinned and retrieval-dated (2026-07-21). MCSB v2 replaces v1's Governance and Strategy (`GS`) domain with an Artificial Intelligence Security (`AI`) domain, and maps to NIST SP 800-53 Rev. 5 and CIS Controls v8.1 (v1 mapped to Rev. 4 and CIS v8). Re-verify the taxonomy and mappings against the official source before relying on them for a compliance decision.

## Normative references

1. [00 Control Index](references/00-control-index.md)
2. [01 Network Security](references/01-network-security.md)
3. [02 Identity Management](references/02-identity-management.md)
4. [03 Privileged Access](references/03-privileged-access.md)
5. [04 Data Protection](references/04-data-protection.md)
6. [05 Asset Management](references/05-asset-management.md)
7. [06 Logging and Threat Detection](references/06-logging-threat-detection.md)
8. [07 Incident Response](references/07-incident-response.md)
9. [08 Posture and Vulnerability Management](references/08-posture-vulnerability-management.md)
10. [09 Endpoint Security](references/09-endpoint-security.md)
11. [10 Backup and Recovery](references/10-backup-recovery.md)
12. [11 DevOps Security](references/11-devops-security.md)
13. [12 Artificial Intelligence Security](references/12-ai-security.md)
14. [Lookup Playbook](references/lookup-playbook.md) — delegation guardrail for volatile per-service lookups.

## Skill layout

* `SKILL.md` — this file (skill entrypoint).
* `references/` — the MCSB durable reference documents.
  * `00-control-index.md` — control-domain catalog, consolidated crosswalk, and attribution.
  * `01` through `12` — one document per MCSB v2 control domain with assessment checklists.
  * `lookup-playbook.md` — delegation guardrail for volatile per-service content.

## Attribution

Reference content in this skill is original prose that paraphrases publicly documented MCSB structure. Microsoft Cloud Security Benchmark documentation on Microsoft Learn is governed by the Microsoft Learn Terms of Use, not a Creative Commons license; this skill therefore paraphrases rather than reproduces upstream text and cites the canonical source in each reference file. See [references/00-control-index.md](references/00-control-index.md) for the consolidated attribution.
