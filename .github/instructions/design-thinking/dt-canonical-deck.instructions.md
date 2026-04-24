---
description: "Opt-in canonical deck and customer-card workflow for DT coaching"
applyTo: "**/.copilot-tracking/dt/**"
---

# DT Canonical Deck Instructions

Use this workflow only when the team explicitly opts in to canonical deck support.

## Scope

Canonical deck workflow covers two related outputs:

1. Canonical markdown artifacts under `.copilot-tracking/dt/{project-slug}/canonical/`.
2. Optional customer-card PowerPoint output under `.copilot-tracking/dt/{project-slug}/render/`.

Treat canonical deck and PowerPoint generation as optional and skippable at each offer point.

## Single Source of Truth

Keep canonical-deck rules in this file only.

Do not duplicate transition gates or non-waivable checks in:

- Method instructions (for example Method 1 or sequencing)
- DT Coach agent behavior text
- Other prompt files

## Activation Rule

The coach must explicitly ask the user once per DT project whether to enable canonical deck and customer-card workflow.

Use a direct yes-or-no checkpoint prompt during Session Initialization, before any method-specific coaching begins:

> Would you like to enable the canonical deck and customer-card workflow for this DT project?

This checkpoint is required once per DT project and is not skippable by the coach. The user can still decline the workflow.

After that prompt, the canonical-deck workflow is active only when either condition is true:

1. The user asks for canonical deck or customer cards.
2. The user accepts a canonical deck offer in the active DT session.

If neither condition is true, continue normal DT coaching with no canonical-deck enforcement.

## Offer Points (Optional)

When workflow is active, offer canonical deck snapshot creation or refresh at these method exits:

1. End of Method 1
2. End of Method 2
3. End of Method 3
4. End of Method 5

Checkpoint phrasing expectation:

- Between Method 1 and Method 2, ask whether to create or update the canonical deck and customer card artifacts.
- Between Method 2 and Method 3, ask whether to create or update the canonical deck and customer card artifacts.
- At the end of Method 5, ask whether to create or update the canonical deck and customer card artifacts.

Each offer must be optional and skippable. Declining an offer must not block method transition.

## Mandatory Post-Snapshot Customer-Card Checkpoint

After any canonical deck create or refresh, the coach must ask this yes-or-no question in the same turn:

> Would you like to generate the customer-card PowerPoint now?

This checkpoint is required whenever canonical artifacts were created or updated at Method 1, Method 2, Method 3, or Method 5 offer points.

Do not end canonical snapshot workflow without asking this question.

Record the offer timestamp and user response in coaching state.

### Customer-Card Re-Offer Rules

If the user declines the customer-card PowerPoint offer:

- **Do not re-offer at Method 2, 3, or 4 snapshots** — The user's decline is final until the end of Method 5.
- **Re-offer at the end of Method 5** — Before transitioning from Method 5 to Method 6, ask the customer-card question one final time: *"We're finishing up Method 5. Before we move to prototyping, would you like to generate the customer-card PowerPoint now?"*
- **If declined again at Method 5, do not re-offer** — Respect the user's decision and continue to implementation methods without further customer-card prompts.

Record all offers and responses in coaching state for audit and session recovery.

## Offer Language

Use concise coaching language. Example:

> We can snapshot the canonical deck now so your current artifacts are easier to track and share. Want to do that now or skip for later?

If the team declines, continue without additional commentary.

## Validation Checklist (When Workflow Is Active)

Before generating or refreshing canonical deck content, run this checklist:

1. Confirm project scope path exists: `.copilot-tracking/dt/{project-slug}/`.
2. Resolve canonical directory as `.copilot-tracking/dt/{project-slug}/canonical/`.
3. Confirm canonical source artifacts available from DT method outputs.
4. Detect create vs refresh mode:
   - `create`: no canonical entries exist yet
   - `refresh`: canonical entries already exist
5. If refreshing, compute artifact fingerprints and update only changed or new entries.
6. Record snapshot metadata in coaching state for the current method checkpoint when generated.
7. Ask the mandatory post-snapshot customer-card checkpoint question.
8. Record the offer timestamp and user response in coaching state.
9. If requested, proceed to customer-card PowerPoint build branch.

## Canonical Artifact Model

Canonical deck entries are maintained in place under:

```text
.copilot-tracking/dt/{project-slug}/canonical/
├── vision-statement.md
├── problem-statement.md
├── scenarios/
├── use-cases/
└── personas/
```

Use existing Design Thinking evidence and avoid speculative content.

### Required Vision Statement Sections

Every vision-statement entry must include:

1. Title from frontmatter `title`, or first heading if no frontmatter title exists
2. `## Vision Statement` — Concise articulation of what the team wants to achieve or create, written as a goal statement from the team's perspective
3. `### Why This Matters` — Business value, strategic importance, and stakeholder impact of the vision. Explain what problems this vision solves and what opportunities it enables

If information is missing, use `<insufficient knowledge>` and add `#### Questions to Ask` with 2-5 targeted questions.

### Required Problem Statement Sections

Every problem-statement entry must include:

1. Title from frontmatter `title`, or first heading if no frontmatter title exists
2. `## Problem Statement` — Exactly one sentence using this required generator framework:

   `The [root cause] is producing an [undesirable effort] for [who it impacts]. How might we do [opportunity] so that we can provide [benefits]?`

   Framework enforcement requirements:
   - Replace all bracketed placeholders with concise, evidence-grounded content from available DT artifacts
   - Do not leave bracketed placeholders in final canonical output
   - Keep each replacement brief and specific; avoid generic filler
   - Preserve the sentence structure and punctuation pattern of the framework
   - If any required component is unknown, use `<insufficient knowledge>` in that component position

If information is missing, use `<insufficient knowledge>` and add `#### Questions to Ask` with 2-5 targeted questions.

### Required Scenario Sections

Every scenario entry must include:

1. `### Description` — Short customer-facing overview of the scenario (2-3 sentences). Set the context: who is involved, what is happening, and why it matters
2. `### Scenario Narrative` — People-centered story grounded in actual research. Clearly articulate business value being unlocked, describe the stakeholders/users and what they care about, explain their challenges and what they are trying to accomplish, and show what success looks like
3. `### How Might We` — Opportunity framing that captures what the team could explore. Address the business value, stakeholders, potential solutions space, and what unlocking this scenario would enable

If information is missing, use `<insufficient knowledge>` and add `#### Questions to Ask` with 2-5 targeted questions.

### Required Use Case Sections

Every use case entry must include all required subsections in this exact order:

1. `### Use Case Description` — Short narrative describing what the use case is about (1-2 sentences)
2. `### Use Case Overview` — Detailed explanation of the use case including context, actors, and what they are trying to accomplish
3. `### Business Value` — What value is delivered by this use case? Who benefits (user, organization, customer)? What outcomes or metrics matter?
4. `### Primary User` — Who is the main actor in this use case? Describe their role, goals, and constraints
5. `### Secondary User` — Who else interacts with or is affected by this use case?
6. `### Preconditions` — What must be true before this use case can start? What state or data must exist?
7. `### Steps` — Numbered sequence of actions the user takes and the system's responses. Be precise about the interaction flow
8. `### Data Requirements` — What information or data is needed for this use case to work? What data is created or modified?
9. `### Equipment Requirements` — What tools, devices, or systems does the user need to accomplish this use case?
10. `### Operating Environment` — Where and when does this use case happen? What are the environmental constraints (noise, lighting, accessibility, connectivity)?
11. `### Success Criteria` — How do we know when this use case succeeds? What are the measurable outcomes or user satisfaction signals?
12. `### Pain Points` — What challenges, frustrations, or inefficiencies exist in the current execution of this use case?
13. `### Extensions` — What variations or alternative paths exist? When would they be used?
14. `### Evidence` — What research, data, or user quotes support this use case? Reference the source DT method artifacts

If information is missing, use `<insufficient knowledge>` and add `#### Questions to Ask` with 2-5 targeted questions.

### Required Persona Sections

Every persona entry must include:

1. `### Description` — Who is this person? Include demographic context (role, organization type, experience level), what they do, and why they matter to the project
2. `### User Goal` — What is this person trying to accomplish? What is their primary objective or desired outcome?
3. `### User Needs` — What do they need to achieve their goal? Distinguish between explicit needs (what they ask for) and latent needs (what they actually need to succeed)
4. `### User Mindset` — How do they think about their work? What are their mental models, priorities, frustrations, and decision-making patterns? What assumptions do they hold?

If information is missing, use `<insufficient knowledge>` and add `#### Questions to Ask` with 2-5 targeted questions.

## Customer Card PowerPoint Branch

When the team requests PowerPoint output, accepts a build offer, or accepts the mandatory post-snapshot checkpoint:

1. Generate `content.yaml` slide artifacts from canonical markdown using the customer-card-render skill.

2. Determine the active shell runtime and follow the appropriate build path.

### PowerShell Runtime Path

When the active runtime is a PowerShell terminal:

1. Invoke `Invoke-PptxPipeline.ps1` directly (do not prefix with `pwsh`; the script runs in the current session).
2. If `Invoke-PptxPipeline.ps1` fails specifically because of an outdated PowerShell version (for example, `#requires` version mismatch):
   - Ask the user for explicit approval to upgrade PowerShell.
   - If the user approves: upgrade PowerShell, verify the version, then retry the script.
   - If the user declines: stop and inform the user that the PowerPoint cannot be generated due to an incompatible PowerShell version.

### Bash Runtime Path

When the active runtime is a bash terminal (Git Bash, WSL, or similar):

**Never attempt to run the PowerShell script (`Invoke-PptxPipeline.ps1`) in a bash terminal. Use the bash script (`invoke-pptx-pipeline.sh`) instead.**

1. Verify you are in a bash terminal by observing a prompt containing `MINGW64`, `bash`, `/bin/bash`, or a Unix-style path like `~/git/`.
2. Before sending the build command, send `invoke-pptx-pipeline.sh --help` to the bash terminal via `send_to_terminal` and read the output with `get_terminal_output` to confirm the exact flag names. Do not infer bash flags from PowerShell parameter names — they differ.
3. Send the build command to the bash terminal using `send_to_terminal` with the confirmed flags.
4. Poll for completion by calling `get_terminal_output` on the same `terminalId` until the bash prompt reappears or output is stable.
5. If no bash terminal is found, stop and inform the user: "I can't generate the PowerPoint in bash because no bash terminal is available. Please open a Git Bash or WSL terminal in VS Code and try again."

### General Requirements

- Always require explicit user approval before any PowerShell upgrade action.
- Do not silently fall back between runtime paths. The shell environment you are running in determines the path: PowerShell terminal → PowerShell script; bash terminal → bash script.

### Mandatory Runtime Compliance Contract

The procedure defined above in **Customer Card PowerPoint Branch** is the single runtime protocol and must be executed exactly as written.

Enforcement:

1. The shell environment you are in determines which script path to use: PowerShell terminal uses `Invoke-PptxPipeline.ps1`; bash terminal uses `invoke-pptx-pipeline.sh`.
2. Do not run `invoke-pptx-pipeline.sh` in a PowerShell terminal under any circumstances.
3. Always require explicit user approval before upgrading PowerShell.
4. If the user declines a PowerShell upgrade, stop immediately and inform the user that the PowerPoint cannot be generated due to the incompatible version.

Any deviation from the defined paths is non-compliant with this workflow.

Do not restate pipeline internals here. Use these sources:

- `.github/skills/experimental/customer-card-render/README.md`
- `.github/skills/experimental/powerpoint/SKILL.md`

## Method 5 Auto-Generate

If the team completes Method 5 and canonical workflow is active, ask whether to create or update canonical deck and customer card artifacts. If accepted, generate a final canonical deck refresh and then offer customer-card build.

## Coaching State Expectations

When canonical workflow is active, maintain canonical state fields in coaching state for:

- Snapshot status and timestamp for offered checkpoints
- Entry counts and candidate counts when generated
- Fingerprints for staleness detection
- Last offered and last generated customer-card snapshot keys

If the team does not opt in, these fields are optional and should not gate progress.
