---
description: Security model and AI STRIDE overlay usage guidance for Phase 4 of the RAI Planner
---

# Security Model Reference

Use this reference during Phase 4 when you build the RAI security model and prepare the Measure-phase threat addendum.

## Phase 4 overlay usage

Apply the AI STRIDE overlay as an extension of the existing security-model analysis rather than as a substitute for it. Start from the shared overlay in [AI STRIDE Overlay](../../../rai/rai-standards/references/ai-stride-overlay.md) and use it to surface AI-specific trust boundaries, lifecycle risks, and human-review considerations that are easy to miss in standard software threat modeling.

* Review each AI component across training, inference, monitoring, and feedback paths.
* Treat model lifecycle assets as first-class control surfaces, including data provenance, features, checkpoints, and retraining flows.
* Record whether a concern should remain as an RAI-managed finding or be linked into the Security Planner's bucketed analysis through the dual threat-ID convention.
* Keep the overlay usage tied to the Measure-phase artifacts: the threat addendum, control-surface catalog, and evidence register.

## Control Surface Catalog

Create or update a control surface catalog for the system under review. Capture each surface with its ownership boundary, current controls, evidence, and open gaps.

* Training data stores
* Model artifacts and checkpoints
* Inference endpoints and serving layers
* Feature pipelines and data preparation
* Feedback loops and retraining paths
* Human review queues and escalation paths
* Monitoring dashboards and telemetry pipelines
* Orchestration layers and agentic control flows

## RAI Threat Addendum

When you draft the RAI threat addendum, use the dual threat-ID convention and merge the findings into the Security Planner's bucketed analysis without losing either the RAI-managed or cross-referenced identity.

* Use `T-RAI-###` for RAI-managed threat IDs.
* Use `T-{BUCKET}-AI-###` for cross-references that connect to the Security Planner's bucketed analysis.
* Preserve both IDs in the merged output so the RAI analysis and the security plan stay traceable.
* Capture the affected control surface, trust boundary, concern level, and proposed mitigation for each threat entry.
