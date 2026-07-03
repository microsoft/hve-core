---
name: vex
description: OpenVEX v0.2.0 specification reference plus VEX management playbooks - Brought to you by microsoft/hve-core.
license: Apache-2.0 AND CC-BY-4.0
user-invocable: false
metadata:
  authors: "OpenVEX Community; microsoft/hve-core"
  spec_version: "1.0"
  framework_revision: "1.0.0"
  last_updated: "2026-07-01"
  content_based_on: "https://github.com/openvex/spec/blob/main/OPENVEX-SPEC.md"
---

# VEX skill

This skill is the entrypoint for VEX operations in hve-core. It combines the OpenVEX v0.2.0
specification reference with reusable management playbooks for implementing, reviewing, and
validating VEX documents. The normative reference material below remains the authoritative
source for schema, status logic, and public-source guidance.

## VEX management playbooks

Detection, drafting, and attestation are workflow-owned automation. This skill supplies the
reusable procedures, mutation rules, and review criteria. The `CVE Analyzer` subagent performs the per-CVE exploitability analysis that feeds those workflows.

### Implement VEX in a target project

Use this playbook when standing up VEX in a target project. Scaffold the VEX document under
security/vex, wire the vex-detect and vex-draft workflows, reference the PR-body scaffold in
[assets/pr-body-scaffold.yml](assets/pr-body-scaffold.yml), connect the release attestation step
for provenance and OpenVEX-over-SBOM attestation, and set CODEOWNERS on the VEX document.
Use [references/vex-status-logic.md](references/vex-status-logic.md) and the
`vex-standards.instructions.md` instructions for the detailed rules.

### Review and validate VEX

Use this playbook when reviewing drafted VEX statements. Assess the status determination against
the evidence and confidence bands, honor the document mutation and forbidden-transition contract,
and validate the release attestation output. Attestation generation is owned by the release
workflow, not by the reviewer. The forthcoming tested gate module and tests will live in this
skill so the workflow and interactive entry points can share the same rules.

## VEX statuses

| Status                | Meaning                                                                                                    |
|-----------------------|------------------------------------------------------------------------------------------------------------|
| `not_affected`        | The vulnerability is not exploitable in this product. Requires a `justification` or `impact_statement`.    |
| `affected`            | The vulnerability is exploitable. Requires an `action_statement` describing remediation.                   |
| `fixed`               | The vulnerability was present but has been remediated in this product version.                             |
| `under_investigation` | The author is evaluating whether the vulnerability affects this product. Safe default for uncertain cases. |

### Justification codes for `not_affected`

When a statement uses `not_affected` status, it must include a machine-readable justification:

| Code                                                | Meaning                                                            |
|-----------------------------------------------------|--------------------------------------------------------------------|
| `component_not_present`                             | The vulnerable component is not included in the product.           |
| `vulnerable_code_not_present`                       | The component is present but the vulnerable code is not included.  |
| `vulnerable_code_not_in_execute_path`               | The vulnerable code is present but cannot be reached at runtime.   |
| `vulnerable_code_cannot_be_controlled_by_adversary` | The code is reachable but an attacker cannot influence the inputs. |
| `inline_mitigations_already_exist`                  | Existing controls prevent exploitation of the vulnerability.       |

### Product identifiers

Products use [Package URL (PURL)](https://github.com/package-url/purl-spec) format
(for example, `pkg:npm/@microsoft/hve-core@3.10.0`).

## Normative references

1. [OpenVEX JSON Schema Reference](references/openvex-schema.md): field definitions, required
   versus optional fields, and example documents.
2. [VEX Status Logic](references/vex-status-logic.md): status determination decision tree,
   evidence requirements per status, and forbidden transitions.
3. [CVE Data Sources](references/cve-data-sources.md): OSV.dev, NVD, and GitHub Advisory Database
   API references with licensing posture.

## Skill layout

* `SKILL.md`: this file (skill entrypoint).
* `references/`: normative reference documents.
  * `openvex-schema.md`: JSON schema reference with field definitions and examples.
  * `vex-status-logic.md`: status determination decision tree and forbidden transitions.
  * `cve-data-sources.md`: CVE data source API references and licensing.

## Attribution and licensing

The OpenVEX specification reference content in this skill is derived from the OpenVEX Community
specification and remains attributed to the OpenVEX Community. The reusable VEX management
playbooks and the surrounding guidance in this skill are hve-core-authored content. The skill
frontmatter uses a mixed-attribution metadata set so the upstream specification reference and the
hve-core playbooks are clearly distinguished.

### Third-Party Attribution

| Attribute     | Value                                                                                                                                                            |
|---------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Specification | OpenVEX Specification v0.2.0                                                                                                                                     |
| Copyright     | © OpenVEX Contributors                                                                                                                                           |
| License       | [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0)                                                                                                |
| Source        | <https://github.com/openvex/spec/blob/main/OPENVEX-SPEC.md>                                                                                                      |
| Modifications | Specification restructured into agent-consumable reference documents with added status determination logic, evidence requirements, and CVE data source guidance. |
