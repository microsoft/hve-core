---
title: Security Planning TM7 generation and feedback tools
description: Current generator, validator, feedback, schemas, and references shipped with the Security Planning skill
ms.date: 2026-08-05
ms.topic: reference
---

# Security Planning TM7 Generation

This package contains the current TM7 generation, validation, and native feedback assets for the Security Planning skill.

## Contents

### Scripts

* `scripts/generate_tm7.py`: deterministic TM7 generation entry point with optional overlay replay
* `scripts/validate_tm7_with_tmt.py`: native Microsoft Threat Modeling Tool harness entry point for probe, calibration-smoke, validate, compare-generation-state, upgrade-template, and feedback-loop modes
* `scripts/tm7_visual_feedback.py`: feedback-domain module for overlay validation, geometry metrics, ranking, and convergence
* `scripts/tm7_threat_contract.py`: hardened XML parsing policy and the shared threat-contract types
* `scripts/generate_tb7.py`: deterministic `.tb7` template generation
* `scripts/populate_tm7_threats.py`: post-generation threat population with an expected-count guard
* `scripts/generate_markdown.py`: synchronized markdown twin of a generated model

### Assets

* `assets/template-profiles/`: bundled template-profile metadata used by the generator, with `sdl_core_generic.yaml` as the shipped profile
* `assets/templates/default-kb.xml`: embeddable DataContract KnowledgeBase spliced into generated models
* `assets/templates/default.tb7`: bundled XmlSerializer template, not spliced into `.tm7` directly
* `assets/schemas/tm7-layout-overlay.schema.json`: versioned overlay schema for deterministic replay
* `assets/schemas/tm7-visual-feedback-manifest.schema.json`: evidence-manifest schema for native feedback runs

### References

* `references/00-index.md`: navigation catalog and consolidated attribution
* `references/tm7-generation.md`: public TM7 contract, CLI surface, mode-flag behavior, feedback-loop documentation, and operator runbook
* `references/operational-buckets.md`, `references/stride-model.md`, `references/standards-cross-reference.md`, `references/nist-control-families.md`, `references/data-classification.md`, `references/threat-model-review.md`, `references/backlog-formats.md`: planning references loaded on demand

### Other

* `SKILL.md`: skill entry point and workflow contract
* `SECURITY.md`: skill-level STRIDE model for local generation, TMT automation, UI Automation, screenshots, and evidence handling
* `templates/threat-model-spec-example.yaml`: worked input-spec example
* `tests/`: focused regression coverage for generation, validation, and feedback-loop behavior, plus `tests/fuzz_harness.py` for the fuzz entry point
* `pyproject.toml` and `uv.lock`: pinned Python dependency contract, including the optional `windows` group required by the native harness

## Notes

The template-profile bundle is intentionally vendor-neutral and uses the verified generic stencil TypeIds from the current implementation.

The native feedback loop is opt-in and remains local to Windows with the pinned TMT 7.3.51110.1 requirement. It writes redacted evidence bundles under the requested evidence directory, creates root-level `manifest.json`, `status.json`, `action.log`, and the `screenshots/`, `uia/`, `exports/`, `summaries/`, and `logs/` folders, writes iteration bundles under `iterations/00-baseline` and `iterations/01` through `iterations/03` as needed, and keeps overlay output in `approval_state: pending`.

A run stops with a stable reason such as `automated-ready-pending-human`, `repeated-defect-no-improvement`, `max-iterations`, `evidence-incomplete`, `semantic-regression`, `candidate-generation-failed`, `overlay-validation-failed`, `tmt-unavailable`, `skipped`, `version-mismatch`, `automation-timeout`, `unexpected-modal`, or `harness-error`.

## Exit codes

The generator and the harness share a stable exit-code contract. `status.json` records the same value the process returns.

| Code  | Meaning                                                                             |
|-------|-------------------------------------------------------------------------------------|
| `0`   | Success, or a local run that skipped because TMT was absent without `--require-tmt` |
| `1`   | Validation failure, including semantic regression against the baseline model        |
| `2`   | Input or harness error, including a rejected spec, overlay, or evidence path        |
| `3`   | TMT was not found, was untrusted, or the host is not Windows                        |
| `4`   | The installed TMT is not the pinned version                                         |
| `5`   | UI Automation exceeded `--timeout-seconds`                                          |
| `6`   | An unexpected modal dialog blocked automation                                       |
| `7`   | Required per-surface feedback evidence was missing                                  |
| `8`   | The feedback loop stopped without converging                                        |
| `130` | The operator interrupted the run                                                    |

See [references/tm7-generation.md](references/tm7-generation.md) for the full CLI surface of both scripts, the `--mode` behavior of the generator and the harness, and the operator runbook.

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
