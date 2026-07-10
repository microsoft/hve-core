---
description: 'PRD user-story reference - the Connextra "As a / I want / so that" role-feature-benefit template described in original Microsoft prose with anti-patterns and cite-only attribution; complements INVEST and EARS for story authoring'
---

# Connextra User-Story Template

The Connextra template is the canonical role-feature-benefit sentence form for a user story. The PRD Builder uses it to express stories derived from functional requirements so each story names a user role, a desired capability, and the value that capability delivers. The structure, authoring rules, and examples below are original Microsoft prose; the template form is attributed in the cite-only reference.

## The template

```text
As a <role>,
I want <capability>,
so that <benefit>.
```

| Clause                | Purpose                                     | Authoring rule                                                                  |
|-----------------------|---------------------------------------------|---------------------------------------------------------------------------------|
| `As a <role>`         | Names the persona or actor who gains value. | Use a specific persona from the PRD personas table, not a generic "user".       |
| `I want <capability>` | States the desired behavior or outcome.     | Describe intent, not UI mechanics or implementation.                            |
| `so that <benefit>`   | Captures the value or motivation.           | Express an observable outcome that justifies the story; never omit this clause. |

## Authoring rules

* Bind `<role>` to a named persona so the story traces back to the PRD Users & Personas section.
* Keep `<capability>` solution-neutral: state what the role needs to accomplish, leaving the delivery team free to choose the implementation.
* Treat the `so that` clause as mandatory. A missing benefit signals a story that may fail the INVEST "Valuable" attribute.
* One story expresses one capability. Compound "and"/"or" capabilities are split into separate stories.
* Pair every story with acceptance criteria authored in [ears-acceptance.md](ears-acceptance.md) or the shared [given-when-then.md](../_shared/given-when-then.md) form.

## Anti-patterns

| Anti-pattern                                                  | Why it fails                                                        | Correction                             |
|---------------------------------------------------------------|---------------------------------------------------------------------|----------------------------------------|
| Generic role ("As a user")                                    | Loses traceability to a persona and obscures whose value is served. | Name the specific persona.             |
| Solution-baked capability ("I want a dropdown that…")         | Freezes implementation, violating INVEST "Negotiable".              | Restate as the underlying need.        |
| Missing or circular benefit ("so that I can use the feature") | Provides no value justification, violating INVEST "Valuable".       | State the real outcome the role gains. |
| Multiple capabilities in one story                            | Inflates scope, violating INVEST "Small".                           | Split into one story per capability.   |

## Relationship to other references

* For judging the resulting story's shape and schedulability, see [invest.md](invest.md).
* For acceptance-criteria authoring, see [ears-acceptance.md](ears-acceptance.md) and the shared [given-when-then.md](../_shared/given-when-then.md).
* For requirement-level identifiers and traceability, see the shared [id-schema.md](../_shared/id-schema.md) and [traceability-matrix.md](../_shared/traceability-matrix.md).

## Cite-only attribution

* **Origin** — The role-feature-benefit user-story template popularized by the Connextra team (London, ca. 2001) and widely documented in agile practice by Mike Cohn, *User Stories Applied* (2004).
* **Why the PRD Builder cites it** — Source of the "As a / I want / so that" story form. The clause rules, anti-patterns, and examples above are repository-original; no upstream prose is reproduced.

## License

This reference file is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The story-authoring guidance is HVE-Core IP and may be reused under the same license. The Connextra template form remains attributable to its originators; the cited sources are accessed by the reader and are never redistributed here.


