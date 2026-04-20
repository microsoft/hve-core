---
name: generate-canonical-deck
description: Generate canonical internal deck entry structure from HVE Core artifacts
version: 1.0
---

# Generate Canonical Internal Deck Entry Structure

You are tasked with creating a canonical internal deck entry structure from HVE Core Design Thinking artifacts. This structure becomes the source-of-truth from which customer-facing cards are later derived.

## Output Structure

Generate files under the `canonical/` directory inside the active project slug (`.copilot-tracking/dt/{project-slug}/canonical/`), with the following organization:

```
canonical/
├── vision-statement.md
├── problem-statement.md
├── scenarios/
│   ├── {scenario-name}.md
│   ├── {scenario-name}.md
│   └── ...
├── use-cases/
│   ├── {use-case-name}.md
│   ├── {use-case-name}.md
│   └── ...
└── personas/
    ├── {persona-name}.md
    ├── {persona-name}.md
    └── ...
```

The `canonical/` directory is the single, evolving deck. Files are created or updated in place as the team progresses through all 9 methods. Do not create per-method output copies.

## Internal Deck Entry Format

Each file in the `canonical/` structure is a **deck entry** — a structured markdown document with this exact format:

### Required Frontmatter (All Canonical Files)

Every canonical file must begin with this frontmatter block before any markdown headings:

```yaml
---
title: {Artifact title}
description: {One-line customer-friendly description}
author: DT Coach
ms.date: YYYY-MM-DD
ms.topic: concept
---
```

Field rules:

* `title`: use the artifact display name (for example, `Vision Statement`, `Problem Statement`, scenario name, use case name, persona name).
* `description`: concise customer-friendly one-line summary of the entry.
* `author`: always `DT Coach`.
* `ms.date`: current generation date in ISO format `YYYY-MM-DD`.
* `ms.topic`: always `concept`.

```markdown
## {Artifact Header}

{Customer-friendly summary of the artifact}

### Internal Metadata

| Property                         | Value                                                                                                                 |
|----------------------------------|-----------------------------------------------------------------------------------------------------------------------|
| Source artifact type             | {Vision Statement \| Problem Statement \| Scenario \| Use Case \| Persona \| User Journey}                            |
| Source file path                 | {Relative path to the original HVE Core artifact file}                                                                |
| Source section                   | {Heading or section anchor within the source file, or "Full document"}                                                |
| Internal state                   | {HVE Core: needs work \| HVE Core: think done}                                                                        |
| Customer state                   | {Pending Customer Review}                                                                                             |
| Freshness status                 | {Current}                                                                                                             |
| Candidate for immediate delivery | {yes \| no} - Set to "yes" only if the artifact is sufficiently clear and complete for customer review without rework |
| Notes                            | {Optional remarks for team context}                                                                                   |
```

### Artifact-Specific Section Contracts

Section contracts are strict. Do not add extra headings beyond those listed here.

* Vision Statement entries must contain exactly:
    1. `## Vision Statement` with customer summary body text
    2. `### Why This Matters`
    3. `### Internal Metadata`
* Problem Statement entries must contain exactly:
    1. `## Problem Statement` with customer summary body text
    2. `### Internal Metadata`
* Scenario entries must contain exactly:
    1. `## {Scenario Name}` with customer summary body text
    2. `### Scenario Narrative`
    3. `### How Might We`
    4. `### Internal Metadata`
* Persona entries must contain exactly:
    1. `## {Persona Name}` with customer summary body text
    2. `### Description`
    3. `### User Goal`
    4. `### User Needs`
    5. `### User Mindset`
    6. `### Internal Metadata`
* Use Case entries must include all required use case subsections and then `### Internal Metadata`.

`### Internal Metadata` is the required internal status section for all artifact types.

### Required Scenario Card Sub-Sections

For every scenario deck entry under `canonical/scenarios/*.md`, include the following sections in this order, immediately after the main scenario heading and before `### Internal Metadata`:

```markdown
### Description
### Scenario Narrative
### How Might We
```

The `How Might We` section must think through:

* The business value the team is trying to achieve
* The opportunities that could be unlocked if the scenario succeeds
* Who benefits from the scenario
* What those benefits are

The `Scenario Narrative` section must be people-centered and grounded in actual DT context. It should:

* Clearly articulate the business value the team is trying to unlock or unblock
* Identify the personas or users interacting with the system
* Explain what those users care about
* Describe the challenges they face
* Clarify what they are trying to accomplish
* Show what success looks like for the scenario
* Tell the story in human terms rather than as a technical system description

### Required Use Case Card Sub-Sections

For every use case deck entry under `canonical/use-cases/*.md`, include the following sections in this order, immediately after the main use case summary and before `### Internal Metadata`:

```markdown
### Use Case Description
### Business Value
### Use Case Overview
### Primary User
### Secondary User
### Preconditions
### Steps
### Data Requirements
### Equipment Requirements
### Operating Environment
### Success Criteria
### Pain Points
### Evidence
### Extensions
```

If the DT Coach does not have enough context to populate any section:

1. Set that section body to exactly: `<insufficient knowledge>`
2. Add a follow-up subheading under that same section:

```markdown
#### Questions to Ask
```

3. Add 2-5 targeted questions to ask customers, stakeholders, or end users to gather the missing information.

Use concise, interview-ready wording. Keep questions concrete and role-specific.
Do not invent content to make a section feel complete. Canonical generation must stay grounded in concrete evidence from prior Design Thinking methods.

### Required Persona Card Sub-Sections

For every persona deck entry under `canonical/personas/*.md`, include the following sections in this order, immediately after the main persona summary and before `### Internal Metadata`:

```markdown
### Description
### User Goal
### User Needs
### User Mindset
```

If the DT Coach does not have enough context to populate any section:

1. Set that section body to exactly: `<insufficient knowledge>`
2. Add a follow-up subheading under that same section:

```markdown
#### Questions to Ask
```

3. Add 2-5 targeted questions to ask customers, stakeholders, or end users to gather the missing information.

Use concise, interview-ready wording. Keep questions concrete and role-specific.

### Rules for each field

**Artifact Header**:
- For Vision Statement: Always `Vision Statement`
- For Problem Statement: Always `Problem Statement`
- For Scenario/Use Case/Persona: Use the short, descriptive name of that artifact (e.g., "Automated Billing Scenario", "Finance Approver")

**Customer-friendly summary**:
- Write as if explaining to a non-technical stakeholder
- Avoid HVE Core jargon and internal references
- Keep it concise but complete
- This is what will appear on the customer-facing card

**Source artifact type**:
- Must be one of: Vision Statement, Problem Statement, Scenario, Use Case, Persona, User Journey
- This identifies which category the source artifact belongs to

**Source file path**:
- Relative path from the HVE Core tracking root (e.g., `.copilot-tracking/dt/customer-readable-hve-cards/method-01-scope/problem-statement.md`)
- This enables round-trip traceability back to the original artifact

**Source section**:
- If the artifact is a discrete section within a larger file, name the heading
- If it's the entire file, write "Full document"
- Examples: "## Vision Statement", "## Scenarios", "## Use Cases", "## Personas"

**Internal state**:
- "HVE Core: needs work" if the artifact needs refinement or review before being customer-ready
- "HVE Core: think done" if the team believes the artifact is complete
- Initial state should usually be "HVE Core: needs work" unless you have evidence it's ready

**Customer state**:
- Always "Pending Customer Review" when first generated
- This will change to "Customer Validated" after customer review

**Freshness status**:
- Always "Current" when first generated
- This tracks whether the source artifact has changed since the deck entry was created

**Candidate for immediate delivery**:
- Set to "yes" only if you are confident the artifact is clear, complete, and ready for customer review without further team rework
- Otherwise, set to "no"
- Team can use this to prioritize which cards to send for customer review first

**Notes**:
- Optional field for team context
- Examples: "Needed clarification on X", "Cross-references scenario Y", "Customer mentioned concern about Z"
- Can be empty if no notes are needed

### Scenario-Specific Authoring Rules

Apply these rules when writing scenario cards:

- **Scenario Narrative**: Write a concise narrative in plain language that centers the people in the story. Explain who they are, what they care about, what challenge they face, what they are trying to accomplish, what business value is at stake, and what success looks like. Keep the narrative non-technical.
- **How Might We**: Frame the design opportunity without prescribing the solution. Make clear the business value, opportunity area, beneficiaries, and expected benefits.

Use only concrete context discovered through the Design Thinking methods. If context is too thin to support a credible scenario or opportunity frame, use `<insufficient knowledge>` and targeted discovery questions instead of filling gaps with speculative ideation.

Never omit a required scenario sub-section.

### Use-Case-Specific Authoring Rules

Apply these rules when writing use case cards:

- **Use Case Description**: Summarize the use case in plain language for a non-technical stakeholder.
- **Business Value**: Prefer measurable value such as time saved, errors reduced, avoided costs, or improved timeliness.
- **Use Case Overview**: Describe the workflow shape and why it matters.
- **Primary User**: Name the main actor responsible for completing the workflow.
- **Secondary User**: Identify additional stakeholders who receive value or are affected.
- **Preconditions**: Capture what must already be true before the use case starts.
- **Steps**: Provide realistic sequential steps.
- **Data Requirements**: Identify needed inputs, sources, outputs, and data quality needs.
- **Equipment Requirements**: Identify devices, systems, channels, and interfaces involved.
- **Operating Environment**: Describe where and under what conditions the work happens.
- **Success Criteria**: Define user-centered and business-centered outcomes.
- **Pain Points**: Identify friction, risks, or failure points in the current process.
- **Evidence**: Record the direct facts, measures, and observations that justify the use case.
- **Extensions**: Describe only credible extension paths supported by current DT context. Focus on how the use case could create additional value or how the supporting capability could be reused across the same system or adjacent workflows.

Use only concrete context discovered through the Design Thinking methods. Do not invent adjacent opportunities or platform ideas when the evidence is weak. If extension paths are not yet supported by the known context, use `<insufficient knowledge>` and targeted discovery questions.

Never omit a required use case sub-section.

### Persona-Specific Authoring Rules

Apply these rules when writing persona cards:

- **Description**: In a few sentences, describe responsibilities, what this persona wants, and what they need to be effective. This section drives the customer summary area of the PowerPoint card and must stand on its own.
- **User Goal**: State the persona's primary goal as one clear outcome.
- **User Needs**: Provide a concise list of practical needs that enable this persona to perform responsibilities effectively.
- **User Mindset**: Use short adjectives (for example: risk aware, action oriented, locally focused, time sensitive, response oriented, diagnostic minded).

Never omit a required persona sub-section.

## Inputs

You will be provided with:

1. **`project-slug`**: Kebab-case identifier for the active DT project. All paths are scoped to `.copilot-tracking/dt/{project-slug}/`.
2. **`output-dir`**: Always `canonical`. Output writes to `{project-slug}/canonical/`.
3. **`method-context`**: Integer 1-5. The active DT method at time of invocation. Governs artifact maturity defaults (`Internal state` and `Candidate for immediate delivery`).
4. **`mode`**: One of `create` or `update`.
   - `create` — no deck entries exist yet; generate all available canonical source artifacts as new deck entries.
   - `update` — entries already exist; refresh entries whose source artifacts changed (fingerprint mismatch from the last snapshot), add entries for new artifacts not yet in the deck, and leave unchanged entries untouched.
5. **Source artifacts**: Raw markdown files from HVE Core under the project's method directories (e.g., `method-01-scope/`, `method-02-research/`) containing Vision Statements, Problem Statements, Scenarios, Use Cases, Personas, and optionally User Journeys.

If you are invoked directly by a user (not by the HVE Core DT Agent):

- The user will provide a directory path or list of file paths
- Default `mode` to `create` unless existing `canonical/` entries are present, in which case default to `update`
- Default `method-context` to the lowest method directory that contains source artifacts
- If the structure is ambiguous, ask for clarification

If you are invoked by the HVE Core DT Agent:

- The agent will provide all inputs including `mode` and `method-context`
- Use the agent's context to ensure accuracy and consistency

## Artifact Maturity by Method

Use `method-context` to set default `Internal state` and `Candidate for immediate delivery` for all entries generated or updated in this invocation:

| Method | `Internal state` default                                                                  | `Candidate for immediate delivery` default |
|--------|-------------------------------------------------------------------------------------------|--------------------------------------------|
| 1      | `HVE Core: needs work`                                                                    | `no`                                       |
| 2      | `HVE Core: needs work`                                                                    | `no`                                       |
| 3      | `HVE Core: needs work` (use `think done` for artifacts confirmed stable during synthesis) | `no`                                       |
| 4      | `HVE Core: needs work` (use `think done` for artifacts validated through ideation)        | `no`                                       |
| 5      | `HVE Core: think done` for validated artifacts; `needs work` for others                   | Assess per entry                           |

Never set `Candidate for immediate delivery: yes` for entries generated at Methods 1-4, regardless of how complete the artifact appears.

## Processing Steps

### Command Transparency Rule

When you need to compute file fingerprints or run shell commands, explain the command purpose in plain language before execution or approval requests.

Use this structure:

1. What the command checks or computes.
2. Why this check is needed for deck generation.
3. What output will be used next.

Do not ask users to infer intent by reading raw command text.

### Create Mode

When `mode` is `create`:

1. **Discover source artifacts**: Scan all method directories under the project slug (e.g., `method-01-scope/`, `method-02-research/`) and identify all canonical artifacts by type.
2. **Parse content**: Extract the core message from each source artifact.
3. **Generate summaries**: Write customer-friendly summaries that distill the essence without jargon.
4. **Expand canonical details**: For scenarios, use cases, and personas, generate all required sub-sections. Use `<insufficient knowledge>` plus `#### Questions to Ask` when data is missing.
    - Always generate at least one use-case entry in `canonical/use-cases/` when creating a deck snapshot.
    - If no complete use case is available, create an inferred use case draft and populate unknown sections with `<insufficient knowledge>` and targeted `#### Questions to Ask` prompts.
5. **Set maturity fields**: Apply `Internal state` and `Candidate for immediate delivery` defaults from the Artifact Maturity by Method table.
6. **Create deck entries**: Write all entries to the `canonical/` directory. Create subdirectories as needed.

### Update Mode

When `mode` is `update`:

1. **Read existing deck**: Inventory all files currently in `canonical/` and record their state.
2. **Discover source artifacts**: Scan all method directories and identify all canonical artifacts by type.
3. **Compute fingerprints**: Compare SHA-256 fingerprints of each source artifact against fingerprints stored in the last snapshot in `coaching-state.md`.
    - If command approval is needed, include a short explanation before running the command.
4. **Identify changed and new artifacts**:
   - **Changed**: Source artifact fingerprint differs from snapshot — re-generate the deck entry.
   - **New**: Source artifact has no corresponding deck entry — create a new deck entry.
   - **Unchanged**: Source artifact fingerprint matches snapshot — skip; do not overwrite the existing deck entry.
5. **Update `Freshness status`** on re-generated entries: set to `Current`. Leave `Customer state` and any team-edited `Notes` intact where possible.
6. **Set maturity fields** for changed and new entries: apply defaults from the Artifact Maturity by Method table. Do not downgrade `Internal state` on existing entries that the team has already marked `think done` unless the source artifact changed.
7. **Write changes**: Overwrite deck entries for changed artifacts; create new files for new artifacts; leave unchanged files untouched.

## File Naming Conventions

- **Vision Statement**: `canonical/vision-statement.md`
- **Problem Statement**: `canonical/problem-statement.md`
- **Scenarios**: `canonical/scenarios/{scenario-short-name}.md` (kebab-case, e.g., `automated-billing-scenario.md`)
- **Use Cases**: `canonical/use-cases/{use-case-short-name}.md` (kebab-case, e.g., `approve-monthly-report.md`)
- **Personas**: `canonical/personas/{persona-short-name}.md` (kebab-case, e.g., `finance-approver.md`)

## Quality Checklist

Before returning the output, verify:

- [ ] All source artifacts have been discovered and processed
- [ ] Each deck entry has the exact markdown structure specified above (header, summary, metadata table)
- [ ] Each deck entry begins with required frontmatter (`title`, `description`, `author`, `ms.date`, `ms.topic`)
- [ ] Metadata table contains all 7 required fields: artifact type, file path, section, internal state, customer state, freshness, and candidate status
- [ ] Customer-friendly summaries are clear and jargon-free
- [ ] File names follow kebab-case convention for scenarios/use-cases/personas
- [ ] Directory structure matches the spec (`canonical/` scoped inside the project slug)
- [ ] `Internal state` and `Candidate for immediate delivery` match the method-context defaults from the Artifact Maturity by Method table
- [ ] `Candidate for immediate delivery: yes` is never set for entries generated at Methods 1-4
- [ ] In update mode: unchanged artifacts were not overwritten; only changed and new artifacts were written
- [ ] Every scenario card contains all required scenario sub-sections in the required order
- [ ] Every scenario card uses only the permitted scenario sections and does not include extra headings
- [ ] Any scenario section lacking context is set to `<insufficient knowledge>` and includes `#### Questions to Ask` with targeted questions
- [ ] Every use case card contains all required use case sub-sections in the required order
- [ ] At least one use-case card exists in `canonical/use-cases/`
- [ ] Any use case section lacking context is set to `<insufficient knowledge>` and includes `#### Questions to Ask` with targeted questions
- [ ] Every persona card contains all required persona sub-sections in the required order
- [ ] Every persona card uses only the permitted persona sections and does not include extra headings
- [ ] Any persona section lacking context is set to `<insufficient knowledge>` and includes `#### Questions to Ask` with targeted questions
- [ ] No scenario or use case section relies on speculative ideation when the prior DT context is insufficient
- [ ] Vision statement includes `### Why This Matters` and no extra headings
- [ ] Problem statement includes only the header summary and `### Internal Metadata`

## Example Output

Given a simple project with one vision, one problem, one scenario, and two personas, the output structure might look like:

```
canonical/
├── vision-statement.md
├── problem-statement.md
├── scenarios/
│   └── automated-card-generation.md
├── use-cases/
│   └── approve-customer-card-release.md
└── personas/
    ├── product-manager.md
    └── software-engineer.md
```

### Example deck entry: `canonical/vision-statement.md`

```markdown
## Vision Statement

Make HVE Core artifacts useful for both product teams and customer stakeholders by automatically translating comprehensive markdown documentation into clean, focused visual cards that customers can review and validate during design thinking execution.

### Internal Metadata

| Property                         | Value                                                                                   |
|----------------------------------|-----------------------------------------------------------------------------------------|
| Source artifact type             | Vision Statement                                                                        |
| Source file path                 | `.copilot-tracking/dt/customer-readable-hve-cards/method-01-scope/problem-statement.md` |
| Source section                   | ## Vision                                                                               |
| Internal state                   | HVE Core: think done                                                                    |
| Customer state                   | Pending Customer Review                                                                 |
| Freshness status                 | Current                                                                                 |
| Candidate for immediate delivery | yes                                                                                     |
| Notes                            | Aligns with stakeholder feedback from delivery team interview                           |
```

### Example deck entry: `canonical/use-cases/generate-customer-cards.md`

```markdown
## Generate Customer Cards

When a product team has completed their HVE Core design work, the system automatically reviews each artifact and intelligently generates clean, customer-ready cards. If an artifact lacks sufficient clarity or information, the system provides actionable feedback to the team about what needs refinement.

### Internal Metadata

| Property                         | Value                                                                                   |
|----------------------------------|-----------------------------------------------------------------------------------------|
| Source artifact type             | Use Case                                                                                |
| Source file path                 | `.copilot-tracking/dt/customer-readable-hve-cards/method-01-scope/scope-boundaries.md`  |
| Source section                   | ## Use Cases                                                                            |
| Internal state                   | HVE Core: needs work                                                                    |
| Customer state                   | Pending Customer Review                                                                 |
| Freshness status                 | Current                                                                                 |
| Candidate for immediate delivery | no                                                                                      |
| Notes                            | Depends on clarity of Problem Statement and Scenarios — revisit after customer feedback |
```

## Next Step

After this structure is generated, **customer-facing cards** are derived by:
- Reading each deck entry from `canonical/`
- Filtering to show only: artifact header + customer-friendly summary + review state
- Hiding all internal metadata
- Rendering as minimal markdown cards for customer review sessions

---

**Ready to proceed?** Provide the input directory path or file paths, and I will generate the canonical deck entry structure.
