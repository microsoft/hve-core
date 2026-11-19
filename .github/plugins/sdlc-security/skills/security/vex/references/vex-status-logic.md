---
title: VEX Status Logic
description: Status determination decision tree, evidence requirements, and forbidden transitions for OpenVEX triage
---

Decision tree and evidence requirements for determining the correct VEX status when triaging a CVE
against a codebase.

## Status determination decision tree

Follow this tree top-to-bottom for each CVE. Stop at the first matching terminal node.

```text
Is the vulnerable component present in the dependency tree?
├─ No  → not_affected (component_not_present)
└─ Yes
   └─ Is the vulnerable code included in the installed artifact?
      ├─ No  → not_affected (vulnerable_code_not_present)
      └─ Yes
         └─ Can the vulnerable code be reached at runtime?
            ├─ Unknown → under_investigation
            ├─ No      → not_affected (vulnerable_code_not_in_execute_path)
            └─ Yes
               └─ Can an attacker control the inputs to the vulnerable code?
                  ├─ Unknown → under_investigation
                  ├─ No      → not_affected (vulnerable_code_cannot_be_controlled_by_adversary)
                  └─ Yes
                     └─ Do built-in mitigations fully prevent exploitation?
                        ├─ Unknown → under_investigation
                        ├─ Yes     → not_affected (inline_mitigations_already_exist)
                        └─ No
                           └─ Has the vulnerability been remediated in this version?
                              ├─ Yes → fixed
                              └─ No  → affected
```

## Evidence requirements per status

Each status requires specific evidence to support the determination.

### not_affected

| Justification code                                  | Required evidence                                                                            |
|-----------------------------------------------------|----------------------------------------------------------------------------------------------|
| `component_not_present`                             | Dependency tree output showing the component is absent.                                      |
| `vulnerable_code_not_present`                       | Build configuration or tree-shaking evidence showing vulnerable code is excluded.            |
| `vulnerable_code_not_in_execute_path`               | Code citation (file and line range) showing no call path reaches the vulnerable function.    |
| `vulnerable_code_cannot_be_controlled_by_adversary` | Analysis showing attacker-controlled input cannot reach the vulnerable code path.            |
| `inline_mitigations_already_exist`                  | Reference to specific mitigation controls with explanation of how they prevent exploitation. |

### affected

* Reachable execution path or runtime invocation evidence demonstrating the vulnerable code is
  exercised in production use.
* An `action_statement` describing recommended remediation or mitigation.

### fixed

* Version reference identifying the release where the fix was applied.
* Dependency update reference or patch citation.

### under_investigation

* No evidence required. This is the safe default when reachability or exploitability cannot be
  determined.
* Should include `status_notes` describing what is being investigated and expected timeline.

## Forbidden transitions

The following transitions are forbidden. An agent must never produce these determinations.

| From state            | To state       | Why forbidden                                                               |
|-----------------------|----------------|-----------------------------------------------------------------------------|
| Unknown reachability  | `not_affected` | Cannot assert non-exploitability without evidence that code is unreachable. |
| Unknown reachability  | `affected`     | Cannot assert exploitability without evidence that code is reachable.       |
| No analysis performed | `not_affected` | Absence of evidence is not evidence of absence.                             |
| No analysis performed | `affected`     | Vulnerability presence alone does not confirm exploitability.               |

**Default rule**: when reachability or exploitability is uncertain, the only valid status is
`under_investigation`.

## Confidence-routing rules

The agent classifies each finding into a confidence band that determines what it is allowed to
draft.

| Band              | Criteria                                                                                                         | Allowed agent action                                                                            | Required human action                                        |
|-------------------|------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------|--------------------------------------------------------------|
| High not_affected | Vulnerable symbol provably unreachable (no import path, dead code, or guarded by mitigation)                     | Draft `not_affected` with justification code and code citations                                 | Approve PR (skim evidence)                                   |
| High affected     | Vulnerable symbol on a reachable execution path                                                                  | Draft `affected` with link to remediation issue                                                 | Approve PR and triage remediation                            |
| Medium            | Symbol reachable in some configurations but ambiguous (feature flags, optional code paths, runtime conditionals) | Draft `under_investigation` with structured questions for human reviewer                        | Decide final status, edit PR                                 |
| Low               | Cannot determine reachability (closed-source dep, dynamic dispatch, native code)                                 | Draft `under_investigation` only. Forbidden from drafting `not_affected`.                       | Manual analysis, may transition to `fixed` or `not_affected` |
| Vendor-disputed   | OSV/NVD shows dispute or CVSS < 4.0 with no known exploit                                                        | Draft `under_investigation` with `status_notes` recording the dispute source and CVSS rationale | Review dispute evidence, decide final status                 |

## Status lifecycle

VEX statuses evolve over time as investigation progresses. Typical progressions:

* `under_investigation` → `not_affected` (analysis confirms code is unreachable)
* `under_investigation` → `affected` (analysis confirms exploitability)
* `affected` → `fixed` (patched version released)
* `under_investigation` → `fixed` (dependency updated before analysis completed)

Each status change produces a new VEX statement with an updated timestamp. Previous statements
remain valid for their point in time; the latest statement takes precedence.
