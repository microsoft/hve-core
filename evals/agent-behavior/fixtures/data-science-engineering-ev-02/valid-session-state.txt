# Synthetic session state

```yaml
schema_version: data-workstream-session-v1
project:
  name: Synthetic demand project
  slug: synthetic-demand
  created_at: "2026-09-01T09:00:00Z"
  customer_output_root: docs/data
current:
  job: catalog
  class: continuous
  phase: null
  disclaimerShownAt: "2026-09-01T09:00:00Z"
jobs:
  catalog: {class: continuous, status: active, artifact: docs/data/catalog.md, last_enriched_at: "2026-09-02T09:00:00Z"}
  model-diagram: {class: episodic, status: never, invocations: []}
  problem-framing: {class: episodic, status: never, invocations: []}
  feasibility: {class: bounded, status: paused, phase: 2, phase_gates: {}, artifact: docs/data/study.md}
  pipeline: {class: episodic, status: never, invocations: []}
  analysis: {class: episodic, status: never, invocations: []}
  evaluation: {class: episodic, status: never, invocations: []}
  experiment: {class: episodic, status: never, invocations: []}
  testing: {class: episodic, status: never, invocations: []}
  observability: {class: episodic, status: never, invocations: []}
job_log: []
session_log: []
artifacts:
  - docs/data/catalog.md
cross_agent_refs: []
```
