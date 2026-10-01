---
title: Threat Models
description: Machine-readable threat-model specs for HVE Core and the generators that consume them
sidebar_position: 1
author: Microsoft
ms.date: 2026-08-08
ms.topic: reference
keywords:
  - threat model
  - security planning
  - tm7
---

## Overview

> [!WARNING]
> `hve-core-comprehensive.yaml` carries a `DRAFT` marker and has **not** been through human security review. Treat that spec, and every `.tm7` or markdown artifact generated from it, as unreviewed until a qualified human reviewer removes the marker from the spec itself. Do not cite it as an authored threat model.

Machine-readable threat-model specs consumed by the `security-planning` skill generators. Each spec is the versioned source; the `.tm7` and markdown outputs are build artifacts and are not committed.

## Specs

| Spec                                                       | Scope                                                                                                                             | Review status             |
|------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------|---------------------------|
| [hve-core-comprehensive.yaml](hve-core-comprehensive.yaml) | Repository contents, CI/CD pipeline, developer workstation, dependency supply chain, dev container, and executable skill runtimes | DRAFT, not human-reviewed |

## Relationship to the prose model

[Security model](../../security/security-model) is the narrative STRIDE model and remains the source of truth for threat content. Per-skill `SECURITY.md` files cover individual skill runtimes. A spec in this directory encodes that same analysis in the schema the generators accept.

## Regenerating outputs

Generate a `.tm7` from a spec:

```bash
uv run --project .github/skills/project-planning/security-planning \
  python .github/skills/project-planning/security-planning/scripts/generate_tm7.py \
  docs/planning/threat-models/hve-core-comprehensive.yaml \
  -o <output>.tm7
```

Generate the synchronized markdown twin from the same spec:

```bash
uv run --project .github/skills/project-planning/security-planning \
  python .github/skills/project-planning/security-planning/scripts/generate_markdown.py \
  docs/planning/threat-models/hve-core-comprehensive.yaml \
  -o <output>.md
```

Both commands read the same spec and use the same deterministic threat derivation, so regenerate them together to keep the pair consistent. Generating a large spec takes a while because layout packing runs per surface.

Outputs are deterministic for a given spec and generator version, so they are regenerated on demand rather than stored. Validating a generated model against the native Threat Modeling Tool requires Windows and a pinned TMT version; see the skill's [README](https://github.com/microsoft/hve-core/blob/main/.github/skills/project-planning/security-planning/README.md) and the [operator runbook](https://github.com/microsoft/hve-core/blob/main/.github/skills/project-planning/security-planning/references/tm7-generation.md).

## Reading a generated model

### Threat state mapping

The Microsoft Threat Modeling Tool recognizes a fixed six-value state vocabulary. The spec uses a richer set of terms that carry the reason for a state, and the generator translates each one on the way out. A reviewer reading a generated `.tm7` sees the right-hand column.

| Spec state                               | Renders in TMT as    | What it means                                                          |
|------------------------------------------|----------------------|------------------------------------------------------------------------|
| `Mitigated`                              | `Mitigated`          | An enforced control addresses the threat                               |
| `Mitigated by Design`                    | `Mitigated`          | The architecture removes the failure mode                              |
| `Mitigated with Documentation`           | `Mitigated`          | No enforced control; guidance or a documented risk transfer covers it  |
| `Mitigated (Copilot Controls)`           | `Mitigated`          | A real control exists but is owned and operated by GitHub or Microsoft |
| `Partially Mitigated`                    | `NeedsMitigation`    | A control addresses part of the threat                                 |
| `Partially Mitigated with Documentation` | `NeedsMitigation`    | Partial control plus documented residual acceptance                    |
| `Open`                                   | `NeedsInvestigation` | No control applied                                                     |
| `Accepted with Documentation`            | `NotApplicable`      | The risk is real, owned here, and deliberately carried                 |
| `Accepted (Outside Control)`             | `NotApplicable`      | The risk is real but sits inside a third party's system                |

The last two rows are the ones to read carefully. **TMT has no "accepted" state**, so a consciously accepted risk renders as `NotApplicable`, which reads as a denial that the risk applies. It does apply. Every threat in that group carries an explicit `ACCEPTED RISK` note in its own description text so the distinction survives into the model.

Priority is derived from the prose model's post-mitigation residual risk, elevated to `High` when a threat is also `Open`. A small `High` tier therefore reflects effective controls rather than a softened assessment.

### Deliberate spec exclusions

The prose model documents fourteen Responsible AI entries. Five are encoded in the spec. The other nine, plus `AI-10`, are deliberately absent:

| Excluded entry                                                   | Reason                                                                                                                                                                                                                                                                                                                                 |
|------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| RAI-2, RAI-5, RAI-6, RAI-7, RAI-8, RAI-9, RAI-10, RAI-11, RAI-12 | Their assets are organizational or societal conditions such as developer autonomy, user agency, organizational trust, skill development, and compute resources. None names a trust boundary or an adversary acting on a modeled connector, so assigning a component and a data flow would fabricate traceability rather than record it |
| AI-10                                                            | An explicit not-applicable placeholder recording that HVE Core neither hosts nor distributes models. Encoding a documented non-applicability as a threat would misrepresent it                                                                                                                                                         |

All fourteen remain in the [Responsible AI Threats](../../security/security-model#responsible-ai-threats) section of the prose model, which is authoritative for them. `RAI-1` in the generated model carries a pointer to this section so the boundary is visible to a reviewer working from the `.tm7` alone.

Note for future encoding: `RAI-12`'s prose status is plain `Accepted`, which is not a member of the generator's state vocabulary. It would need to become `Accepted with Documentation` before that entry could be encoded.

## Review status

A spec carrying a `DRAFT` marker at the top of its file has not been through human security review. `hve-core-comprehensive.yaml` currently carries that marker. Treat both the spec and anything generated from it as unreviewed until the marker is removed by a qualified human reviewer.

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
