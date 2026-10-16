---
description: "Source-grounded repository intake and candidate skill creation for the same supervised A/B workflow"
---

# Repository Intake And Candidate Creation

For an existing skill, inspect distinctive guidance and choose an ordinary task
where it could help. Do not impose skill extraction or a baseline probe first.

## Starting From A Repository

1. Establish the intended user task, relevant repository scope and whether the
   candidate is for work in this repository or transfer elsewhere. Pin the source
   commit. Inspect relevant entry points, implementations and tests with ordinary
   read/search tools; follow dependencies where needed, not a mandatory file list.
2. Identify connected practices that help perform that work. Trace each important
   instruction to source evidence and distinguish required behavior from an
   incidental implementation choice. Look for conditions, exceptions and failure
   paths, not just the successful example.
3. Explain what a capable agent might miss and why that matters to the user.
   Good code or a repeated pattern alone does not justify a skill. Prefer useful
   repository/domain knowledge over generic programming advice. If no candidate
   is defensible, explain why and stop without model trials. A baseline succeeding
   once does not establish redundancy; quality or effort may still differ.
4. Write one focused candidate folder containing `SKILL.md`, with YAML `name`
   and a discoverable `description`, followed by applicability, actionable steps
   and important pitfalls. Add references or assets only when needed. Explain
   what to do and why; do not turn a repository summary into instructions or copy
   large implementation sections. Keep source citations with the relevant
   guidance so it can be checked.
5. Verify referenced paths, APIs and examples against the pinned source and tests.
   Label inferred or untested guidance explicitly. Check licensing, attribution
   and publication permission; generalized wording can still disclose private
   knowledge. Do not include private code, data, credentials or identifying
   details in a public candidate or review package.
6. Propose a realistic evaluation task and the candidate's claimed benefit.
   Continue with [task discussion](../SKILL.md#discuss-the-task) using this
   candidate and the same native evaluation workflow as an existing skill.
   Put the source pin, rationale and scope in the evaluation notes, not a new
   extraction report or schema. The candidate remains experimental until tested.

### Examples Of Useful Extraction

- **Extension contract:** inspect an interface, a working extension and its tests.
  Explain required methods, registration and configuration steps, including when
  they are unnecessary; do not prescribe a folder layout solely because it exists.
- **Configuration flow:** trace a setting from parsing through validation to its
  consumer. Capture precedence and invalid-value behavior rather than listing
  configuration fields.
- **Resource lifecycle:** trace acquisition, normal completion, errors and early
  termination. Explain ownership and cleanup obligations, distinguishing
  observable guarantees from the particular scheduling or storage implementation.

Use only examples relevant to the intended work. There is no required taxonomy,
candidate count, exploration agent or pre-creation paid probe.

## Choosing An Evaluation Target

Before choosing a target:

- Pin the commit or bundled content hash.
- Inspect task/inputs for answer leakage, candidate terminology and hidden
  consumer requirements.
- Discuss baseline headroom and whether the checks distinguish useful from
  plausible weak results.
- Use execution for behavior, original sources for meaning, and pixels for
  visual usability.
- Explain uncertainty. Propose a separately budgeted probe only if it informs
  a real decision. Do not silently run it or alter checks after seeing results.

Describe scope plainly: reconstructing a familiar source task, a new task on the
same repository, or transfer to a different repository. Only the last tests
cross-repository transfer; one task still cannot establish general effectiveness.
Examples used for repairs are development, not held-out confirmation.
