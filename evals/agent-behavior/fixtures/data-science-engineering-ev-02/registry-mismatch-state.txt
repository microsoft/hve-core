# Synthetic session state with registry mismatch

```yaml
schema_version: data-workstream-session-v1
project:
  name: Synthetic demand project
  slug: synthetic-demand
  created_at: "2026-09-01T09:00:00Z"
  customer_output_root: docs/data
current:
  job: null
  class: null
  phase: null
  disclaimerShownAt: "2026-09-01T09:00:00Z"
jobs:
  catalog: {class: continuous, status: active, artifact: docs/data/catalog.md, last_enriched_at: "2026-09-02T09:00:00Z"}
  model-diagram: {class: episodic, status: never, invocations: []}
  problem-framing: {class: episodic, status: never, invocations: []}
  feasibility: {class: bounded, status: never, phase: null, phase_gates: {}, artifact: null}
  pipeline: {class: episodic, status: never, invocations: []}
  analysis: {class: episodic, status: never, invocations: []}
  experiment: {class: episodic, status: never, invocations: []}
  testing: {class: episodic, status: never, invocations: []}
  observability: {class: episodic, status: never, invocations: []}
  legacy-job: {class: episodic, status: never, invocations: []}
job_log: []
session_log: []
artifacts: []
cross_agent_refs: []
```
