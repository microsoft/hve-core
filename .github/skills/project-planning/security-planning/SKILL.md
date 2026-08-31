---
name: security-planning
description: Security planning reference set for operational buckets, STRIDE analysis, standards mapping, NIST control families, backlog scaffolding, and deterministic TM7 (.tm7) plus markdown dual-output generation.
license: MIT
compatibility: 'Generation requires Python 3.11+ and uv. The native TM7 feedback loop additionally requires Windows with an interactive desktop session and the pinned Microsoft Threat Modeling Tool 7.3.51110.1.'
user-invocable: true
---

# Security Planning

This skill packages the durable security-planning reference material used by the Security Planner: operational bucket guidance, STRIDE analysis patterns, standards cross-references, NIST control-family references, and security-specific backlog formats.

## When to use

Use this skill when you need to:

* Classify application components into the operational security buckets used during planning.
* Evaluate threats with STRIDE-based analysis, including AI-specific extensions when `raiEnabled` is true.
* Map bucket findings to standards references and control families without re-embedding long standard tables.
* Derive security-specific backlog priorities and RAI work item categories for Phase 5 handoff.
* Generate a dual-output TM7 model plus markdown report from a YAML/JSON threat-model spec for human-reviewed audit workflows.

### TM7 generation workflow

When the user asks for a TM7 threat model, the runtime can generate a `.tm7` file and a matching markdown report from the same spec. The generator supports the `pre-populated-comprehensive` and `diagram-only-defer-to-tmt` modes and can update an existing model with `--update`. Use the `generate_tm7.py` and `generate_markdown.py` entry points with `--template` to select a profile.

The `.tm7` output mirrors the Microsoft Threat Modeling Tool's real `SerializableModelData` DataContract and deserializes cleanly under the tool's own `DataContractSerializer`. Fidelity is validated against the tool's own assemblies by `scripts/Deserialize-Tm7.ps1`, which the pytest suite runs when the tool is installed and skips cleanly otherwise. See [references/tm7-generation.md](references/tm7-generation.md) for the verified contract.

### Native TM7 visual feedback workflow

The skill also supports an opt-in, Windows-local feedback loop for the native Microsoft Threat Modeling Tool UI. The feature is off by default. The generator and standard validator keep their existing portable behavior when the feedback flags are absent. Native feedback is enabled only when `validate_tm7_with_tmt.py` is run with `--feedback-loop`, `--spec`, and `--overlay-output`; optional `--overlay-input`, `--max-iterations`, and `--require-feedback-evidence` refine the execution contract.

The workflow requires Microsoft Threat Modeling Tool 7.3.51110.1, a Windows desktop session, and UI Automation access. The loop is bounded to a baseline run plus at most three refinement iterations, and defaults to a baseline plus one. A single run holds the mouse and keyboard continuously across the baseline and every refinement iteration; control returns only at the release notice. Replaying a corrected overlay is a new run and a new takeover. Exit codes, stop reasons, and the discovery-failure rules are defined in the generation reference.

The harness controls TMT windows and may open, close, and reopen the app for save/reopen validation. It emits a start notice before automation begins, progress updates for the baseline and each refinement candidate, and a release notice when the loop completes or aborts so the operator knows when control is returned. These are notices only; the harness does not block on operator acknowledgment. The agent-facing lockout and release obligations that surround a run are owned by `tm7-generation-workflow.instructions.md`.

The loop records one evidence bundle per run under the requested evidence directory, with per-iteration screenshots, UI Automation snapshots, summaries, and candidate models. A run that captured at least one surface and either passed the automated gates or stopped for layout exhaustion also emits `agent-review-request.json` at the bundle root. The overlay payload remains in `approval_state: pending`, and no runtime path or flag auto-promotes it to `approved` or rewrites the canonical baseline.

Scoring keeps deterministic geometry gates separate from advisory screenshot heuristics. Screenshot heuristics are not a semantic approval signal.

A Windows-native example uses the skill's locked Windows dependency group:

```bash
uv run --project .github/skills/project-planning/security-planning --group windows \
  python scripts/validate_tm7_with_tmt.py model.tm7 \
  --evidence-dir ./artifacts/feedback \
  --feedback-loop \
  --spec ./specs/model.yaml \
  --overlay-output ./artifacts/feedback/overlay.json \
  --max-iterations 3 \
  --require-feedback-evidence
```

The overlay contract is versioned and deterministic. It carries layout intent in named rule collections and is invalidated unless its full fingerprint block matches, so a stale overlay is rejected rather than replayed onto a changed model.

See [references/tm7-generation.md](references/tm7-generation.md) for the full CLI surface, exit codes, stop reasons, geometry thresholds, the evidence-bundle layout, the overlay fingerprint contract, and the operator runbook covering prerequisites, abort, recovery, and rollback.

### Agent-assisted visual review

Some layout defects never reach a metric. TM7 persists no connector label geometry and UI Automation exposes no label element, so label collisions, unreadable label text, and visual crowding are invisible to the deterministic gates. An agent that reads the rendered screenshots can see them and author corrections into the overlay the harness publishes.

This review is a default step of every feedback-loop run, not an opt-in extra. A run that captured at least one surface and either passed the automated gates or stopped for layout exhaustion emits `agent-review-request.json` at the evidence root, carrying per surface the screenshot and UI Automation paths, the node and zone rectangles, the connector handle points, and the predicted label rectangles in model coordinates, plus the coordinate-translation constants and the port convention. The agent reviews from that payload rather than hand-parsing UI Automation trees. `automated-ready-pending-human` means the automated gates passed and the result awaits review; it is not an approval. The remedy remains documented rather than proven: it has not yet been demonstrated end to end on a real defect.

On the success path the published overlay addresses every captured surface, so a correction can be authored for any of them. When the run found no automated correction, that overlay is the seed shape, carrying an `overlay-seed-` identifier and empty rule collections. A layout-exhaustion stop publishes the same seed shape; a correctness or environment stop publishes nothing at all.

See [references/tm7-generation.md](references/tm7-generation.md) for the protocol, the request payload, the accepted rule fields, the coordinate translation, and the constraints that bound an agent-authored overlay.

> [!CAUTION]
> **Disclaimer:** This agent is an assistive tool only. It does not provide legal, regulatory, or compliance advice and does not replace professional security review boards, penetration testing teams, compliance auditors, legal counsel, or other qualified human reviewers. The output consists of suggested actions and considerations to support a user's own internal security review and decision-making. All security plans, threat models, security models, and mitigation recommendations generated by this tool must be independently reviewed and validated by appropriate security and compliance reviewers before use. Outputs from this tool do not constitute security approval, compliance certification, or regulatory sign-off.

The human-in-the-loop contract governing authorship confirmation, native feedback-loop operator safety, and layout overlay promotion is owned by `tm7-generation-workflow.instructions.md`. This skill owns the mechanics only.

## Skill layout

Load the reference file that matches the phase or topic you need.

| Reference                                                                          | Topic                                                                                                                                                               |
|------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| [references/00-index.md](references/00-index.md)                                   | Navigation catalog and consolidated attribution                                                                                                                     |
| [references/operational-buckets.md](references/operational-buckets.md)             | Operational bucket definitions, GS overlay, and classification guidance                                                                                             |
| [references/stride-model.md](references/stride-model.md)                           | STRIDE methodology, AI extensions, risk matrix, and data-flow analysis                                                                                              |
| [references/standards-cross-reference.md](references/standards-cross-reference.md) | Bucket-to-standards mapping table and component mapping output format                                                                                               |
| [references/nist-control-families.md](references/nist-control-families.md)         | NIST 800-53 priority tiers and NIST AI RMF subcategory mappings                                                                                                     |
| [references/backlog-formats.md](references/backlog-formats.md)                     | Security-specific prioritization and RAI work item categories                                                                                                       |
| [references/data-classification.md](references/data-classification.md)             | Public-safe data-classification taxonomy, tiers/categories/retention, and schema mapping                                                                            |
| [references/threat-model-review.md](references/threat-model-review.md)             | Threat-model completeness checklist, PASS/INCOMPLETE verdict, and gap list                                                                                          |
| [references/tm7-generation.md](references/tm7-generation.md)                       | TM7 input schema, dual-output generation contract, profile mapping, emission contract, native feedback loop, overlay and fingerprint contract, and operator runbook |

Bundled executable and data resources:

| Resource                                                  | Use                                                                |
|-----------------------------------------------------------|--------------------------------------------------------------------|
| `scripts/generate_tm7.py`                                 | Run to build a `.tm7` from a threat-model spec                     |
| `scripts/generate_markdown.py`                            | Run to render the same spec as a markdown report                   |
| `scripts/generate_tb7.py`                                 | Run to emit a template file                                        |
| `scripts/validate_tm7_with_tmt.py`                        | Run for native Windows TMT validation and the opt-in feedback loop |
| `scripts/Deserialize-Tm7.ps1`                             | Run to check round-trip fidelity against the tool's own assemblies |
| `assets/schemas/tm7-layout-overlay.schema.json`           | Read as the layout overlay schema                                  |
| `assets/schemas/tm7-agent-review-request.schema.json`     | Read as the agent visual-review request schema                     |
| `assets/schemas/tm7-visual-feedback-manifest.schema.json` | Read as the evidence manifest schema                               |
| `templates/threat-model-spec-example.yaml`                | Copy as the starting point for a new spec                          |

The skill ships public defaults for the taxonomy and the completeness checklist. Organization-specific internal details such as internal data-type taxonomies, internal auth service names, and internal review-gate steps are supplied through a private config overlay referenced by state.overlayConfigPath and are never embedded in the public skill.

## Attribution

The durable reference content in this skill is organized by reference file and summarized in [references/00-index.md](references/00-index.md). See that index for the consolidated attribution and delegation notes.
