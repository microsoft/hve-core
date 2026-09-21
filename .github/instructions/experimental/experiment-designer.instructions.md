---
description: "MVE tracking-artifact conventions for session directories, artifact names, and file hygiene; routes MVE methodology to the experiment-design skill"
applyTo: '**/.copilot-tracking/mve/**'
---

# Experiment Designer: MVE Tracking Conventions

These conventions apply automatically when working with Minimum Viable Experimentation session artifacts. They govern where MVE artifacts live, what they are called, and how the files are formatted.

MVE domain knowledge lives in `experiment-design`, the general experiment-design skill for MVE definitions, experiment types, vetting criteria, red flags, hypothesis construction, experiment practices, result evaluation, project hypotheses, and backlog-bridge templates.

## Session directory

Each session uses one tracking directory:

```text
.copilot-tracking/mve/{{YYYY-MM-DD}}/{{experiment-name}}/
```

`{{experiment-name}}` is a short kebab-case identifier derived from the problem statement.

## Artifact names and placement

Write session artifacts to that directory using these names, so a later reader or agent can locate them without inspecting content:

| File                   | Holds                                                                                   |
|------------------------|-----------------------------------------------------------------------------------------|
| `context.md`           | Problem statement, customer and stakeholder context, business case, and experiment type |
| `hypotheses.md`        | Testable hypotheses with priority ranking and rationale                                 |
| `vetting.md`           | Vetting results and red flag assessment                                                 |
| `experiment-design.md` | Approach, scope, timeline, resources, success criteria                                  |
| `mve-plan.md`          | Consolidated MVE plan                                                                   |
| `backlog-brief.md`     | Optional requirements bridge for backlog manager consumption                            |

`context.md` records an experiment type naming the domain the experiment sits in, or `undetermined` when the classification is not yet supported. Downstream conditional skill loading reads this field, so it is recorded explicitly rather than inferred from the problem statement.

## File hygiene

* Use Markdown for all session artifacts.
* Include `<!-- markdownlint-disable-file -->` at the top of every Markdown file created under `.copilot-tracking/`.
* Update artifacts progressively as the session proceeds rather than writing them once at the end.
