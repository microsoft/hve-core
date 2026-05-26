---
name: demo-setup
description: 'Repeatable HVE Core demo setup that simulates DT Coach sessions with a customer persona and scaffolds a hi-fi prototype - Brought to you by microsoft/hve-core'
user-invocable: true
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-05-22"
---

# Demo Setup

## Overview

Creates demo-ready prototypes by guiding you through a simulated Design Thinking Coach session with a customer persona, then scaffolding a hi-fi prototype. The skill generates a customer persona brief with realistic conversation seeds, accelerates through DT Methods 1 through 6 with simulated customer dialogue, and hands off to the hifi-prototype skill for Method 7 scaffolding. The result is a complete, runnable demo with a presenter's walkthrough guide and a video script for recording.

Primary audience: new users learning HVE Core tools.

Core design constraints:

* Every demo starts with a customer persona brief that drives the simulated conversation.
* DT Coach interactions use accelerated pacing (2 to 3 exchanges per method) for demo efficiency.
* The hifi-prototype skill handles all scaffold generation and experiment framing.
* Presenter's guide included so demos are repeatable without memorizing the flow.
* Demo video script generated for recording a polished walkthrough video.

## Prerequisites

* DT Coach agent accessible (provided by the HVE Core extension)
* hifi-prototype skill accessible (workspace `.github/skills/hifi-prototype/`)
* `.copilot-tracking/` directory exists at the workspace root

## Quick Start

Run a demo with custom inputs:

1. Invoke `/demo-setup` with `customer={name}`, `industry={vertical}`, and optionally `persona` and `problem`.
2. The DT Coach walks through Methods 1 through 6 with a generated persona and conversation seeds.
3. At Method 7 the hifi-prototype skill scaffolds a runnable prototype.
4. Open `index.html` in a browser and follow the presenter's guide in `README.md`.

## When to Use

- Setting up a demo for a customer, partner, or internal team to showcase HVE Core tooling
- Onboarding new users who need to see the DT Coach and prototype workflow end to end
- Preparing a conference talk, workshop, or training session that walks through the tools
- Creating a reference demo that others can replicate independently

## When Not to Use

- Running a real Design Thinking engagement with actual stakeholders (use the DT Coach directly)
- Building a production prototype without the demo scaffolding and walkthrough
- Creating a static slide deck or documentation (use the canonical deck or PowerPoint skill)
- The audience already knows the tools and needs advanced workflow guidance

## Inputs

| Input | Required | Description |
|---|---|---|
| `customer` | Yes | Customer name or organization for the demo scenario |
| `industry` | Yes | Industry vertical (field service, government, healthcare, manufacturing, energy) |
| `persona` | No | End-user persona name and role. Generated from customer and industry context when omitted |
| `problem` | No | Brief problem statement. Inferred from industry patterns when omitted |
| `accelerated` | No | Whether to use accelerated DT method pacing for demo purposes. Defaults to `true` |

## Customer Persona Brief Template

The skill generates a customer persona brief before starting the DT Coach session. This brief drives all simulated customer interactions through Methods 1 through 6.

Save location: `.copilot-tracking/dt/{project-slug}/context/customer-persona-brief.md`

### Organization Profile

| Field | Description |
|---|---|
| Name | Organization name |
| Industry | Industry vertical and sub-sector |
| Size | Employee count and scale indicators |
| Context | Business context, market position, and relevant operational details |

### Persona Profile

| Field | Description |
|---|---|
| Name | Full name of the persona |
| Role | Job title and department |
| Daily work | Typical workday activities and responsibilities |
| Frustrations | Top 3 to 5 pain points in current workflow |
| Goals | What success looks like for this person |

### Problem Scenario

| Field | Description |
|---|---|
| Specific situation | Concrete instance of the problem occurring |
| Constraints | Budget, timeline, regulatory, or technical limitations |
| Stakeholders affected | Who else feels the impact of this problem |
| Existing workarounds | How the persona currently copes with the problem |

### Conversation Seeds

Conversation seeds provide realistic customer responses that the DT Coach uses during simulated interactions. Each seed matches the coaching focus of its method.

| Method | Seed Focus | Example Response Pattern |
|---|---|---|
| M1 Scope | What the customer says about their problem initially | Describes the pain point in their own words, mentions what prompted the conversation |
| M2 Research | Daily workflow description and pain points | Walks through a typical day, highlights where things break down |
| M3 Synthesis | Reactions to synthesized themes | Confirms or challenges pattern accuracy, adds nuance from their experience |
| M4 Brainstorming | What excites and concerns them about ideas | Responds to feasibility, flags organizational constraints, identifies quick wins |
| M5 Concepts | Feedback on visual concepts | Reacts to desirability, viability, and feasibility of proposed solutions |
| M6 Lo-Fi | Reactions to paper prototypes | Points out usability friction, suggests workflow changes, identifies missing steps |

### Domain Vocabulary

Industry-specific terms the persona would naturally use in conversation. Include 10 to 15 terms with brief definitions for context.

## Workflow

Follow the six-step workflow to set up a complete HVE Core demo. Each step builds on the previous one.

| Step | Name | Purpose |
|---|---|---|
| 1 | Define Customer Scenario | Generate the customer context and persona brief from user inputs |
| 2 | Initialize DT Coach Session | Create project structure and start the coaching session |
| 3 | Guided DT Methods 1-6 | Accelerated coaching with simulated customer conversations |
| 4 | Prototype Scaffold | Transition to Method 7 and generate the runnable prototype |
| 5 | Demo Walkthrough Guide | Generate the presenter's guide and finalize the demo |
| 6 | Demo Video Script | Generate a narrated video script for recording the demo |

### Step 1: Define Customer Scenario

Accept customer context from user inputs and generate the persona brief.

1. Generate a Customer Persona Brief from the `customer`, `industry`, `persona`, and `problem` inputs.
2. Fill all sections of the Customer Persona Brief Template, including conversation seeds tailored to the industry and problem.
3. Derive the project slug from the customer name: strip all characters except letters, digits, and spaces, collapse consecutive spaces, then lowercase and replace spaces with hyphens (for example, `Contoso Manufacturing` becomes `contoso-manufacturing`, `O'Brien & Co.` becomes `obrien-co`). If the resulting slug is empty, prompt the user for a valid customer name.
4. Save the brief to `.copilot-tracking/dt/{project-slug}/context/customer-persona-brief.md` using the project slug derived above.

Checkpoint: persona brief exists with all sections populated.

### Step 2: Initialize DT Coach Session

Create the project structure and start the DT Coach session with demo context.

1. Use the project slug derived in Step 1.
2. Initialize `coaching-state.md` with `initial_classification` set to `frozen` and add a `session_mode: demo` field under the `project` block to signal accelerated pacing.
3. Include at minimum these fields: `project.slug`, `project.name`, `project.initial_classification: frozen`, `project.session_mode: demo`, `current.method: 1`, `current.space: problem`, `current.phase: session-init`.
4. The DT Coach loads the customer persona brief as simulated customer context.
5. Begin Method 1 with the DT Coach greeting and session initialization.

Checkpoint: coaching-state.md exists with demo `initial_classification` and Method 1 active.

### Step 3: Guided DT Methods 1-6 (Accelerated Demo Mode)

The DT Coach guides through each method with simulated customer conversations drawn from the persona brief.

1. At each method, the persona brief's conversation seeds provide realistic customer responses.
2. In accelerated mode, each method completes in 2 to 3 exchanges (one user turn plus one coach response per exchange), compared to 10 or more in full coaching.
3. Key artifacts are generated at each method exit:
   - M1: stakeholder map and scope summary
   - M2: research notes and interview synthesis
   - M3: theme clusters and problem statement
   - M4: prioritized idea list
   - M5: concept cards with desirability/feasibility/viability assessment
   - M6: lo-fi prototype sketches and usability notes
4. At each method transition, highlight which HVE Core tool or feature is being demonstrated:
   - M1 to M2: coaching state persistence and session recovery
   - M2 to M3: artifact lineage across methods
   - M3 to M4: problem-to-solution space transition
   - M4 to M5: concept cards with D/F/V evaluation
   - M5 to M6: canonical deck snapshot (optional)
   - M6 to M7: hifi-prototype skill handoff

Checkpoint: Methods 1 through 6 have generated artifacts in the coaching state.

### Step 4: Prototype Scaffold (Method 7)

Transition to Method 7 and invoke the hifi-prototype skill for scaffold generation.

1. Invoke the hifi-prototype skill with the inputs from the Hifi-Prototype Input Mapping table below.
2. Populate the experiment card from DT session artifacts (hypothesis from M3 themes, success criteria from M5 concepts).
3. Generate the scaffold using demo template patterns from existing examples.
4. Fixture data derived from the persona brief and domain vocabulary.
5. Name the fixture file after the primary domain noun in plural form (for example, `machines.js`, `vehicles.js`, `patients.js`).
6. Include experiment banner on every page with hypothesis text.
7. Apply `[SIMULATED]` badges to all mock components.
8. Pre-wire telemetry for page views, clicks, and task timing.

#### Hifi-Prototype Input Mapping

| hifi-prototype Input | Source DT Artifact | Derivation |
|---|---|---|
| Hypothesis | M3 problem statement | Reframe as a testable prediction about user behavior |
| Success criteria | M5 concept D/F/V assessment | Convert desirability, feasibility, and viability ratings into measurable conditions |
| Stack preference | Always `html` | Default zero-install stack for demos |
| Simulation needs | M2 constraint catalog and M6 usability notes | List components that cannot be built live and require fixtures |
| Telemetry level | Always `basic` | Page views, clicks, and task timing for demo purposes |
| Storage | Always `files` | Zero-dependency demo default; avoids database setup |
| LLM provider | Always `none` | Demos use fixture data, not live LLM calls |

Checkpoint: prototype runs locally by opening `index.html` in a browser.

### Step 5: Demo Walkthrough Guide

Generate a presenter's guide in the prototype README with everything needed to deliver the demo.

1. Step-by-step demo narrative from DT Coach session through prototype walkthrough.
2. Key talking points at each stage of the demo.
3. Which HVE Core features are showcased at each step:
   - DT Coach agent and coaching state management
   - Customer persona brief and conversation simulation
   - Experiment cards and hypothesis-driven development
   - hifi-prototype skill and scaffold generation
   - Telemetry instrumentation
4. Common audience questions and suggested responses.
5. Timing guidance (approximate duration per section).

Checkpoint: README contains a complete presenter's walkthrough guide.

### Step 6: Demo Video Script

Generate a `demo-video-script.md` in the prototype directory with a complete narrated video script for recording the demo.

1. Follow the structure in `references/demo-video-script-template.md` for the script layout.
2. Populate the Cold Open with a vivid scene showing the prototype in action and stating the persona's core pain point.
3. Write Section 1 (The Problem) using the customer persona brief: organization profile, frustrations, and the specific problem scenario.
4. Write Section 2 (Design Thinking Coach) walking through the DT artifacts generated in Step 3, highlighting coaching state persistence and artifact lineage.
5. Write Section 3 (The Experiment Card) narrating the hypothesis, success criteria, and failure criteria from the experiment card.
6. Write prototype demo sections (Sections 4 and 5) with screen-by-screen narration of the prototype workflow. Include visual cues in brackets describing what appears on screen and what the presenter clicks.
7. Write Section 6 (What You Just Saw) recapping the HVE Core tools demonstrated and their value.
8. Write Section 7 (Where to Start) introducing the three entry points: Task Researcher, RPI Agent, and DT Coach. Include a brief live demo prompt for each.
9. Write a Closing section and Production Notes table with recording setup details.
10. Target duration is 14 to 16 minutes. Distribute time across sections proportionally, with prototype demo sections receiving the most time.

Checkpoint: `demo-video-script.md` exists with all sections populated and timing annotations.

## Demo Scaffold Template

Every demo scaffold follows a fixed structure. The hifi-prototype skill generates this layout with demo-specific content.

```text
{project-slug}/
├── experiment-card.md
├── README.md
├── demo-video-script.md
├── index.html
├── style.css
├── app.js
├── telemetry.js
└── sim/fixtures/{domain-data}.js
```

### Fixed Elements (same across all demos)

| Element | Details |
|---|---|
| Experiment banner | Visible on every page with hypothesis text |
| CSS reset | System fonts, 2-color palette, dashed borders, 44px touch targets |
| Rough UI constraints | No shadows, gradients, or custom fonts |
| Telemetry skeleton | Page views, clicks, task timing, session UUID |
| `[SIMULATED]` badges | Applied to every mock component |
| Experiment card | Hypothesis, success criteria, failure criteria, simulation inventory |
| Demo video script | Narrated walkthrough with visual cues, timing, and production notes |

### Variable Elements (customized per demo)

| Element | Varies By |
|---|---|
| Accent color | Industry or customer brand association |
| Layout | Screen count and workflow shape (1 to 5 screens max) |
| Fixture schema | Domain-specific data structure in `sim/fixtures/` |
| Domain terms | Industry vocabulary in labels, headings, and fixture data |
| Hypothesis text | Derived from DT session Method 3 themes |
| Success criteria | Derived from DT session Method 5 concepts |

## Integration with HVE Core Tools

Each step of the demo workflow showcases specific HVE Core tools and features.

| Tool / Feature | Where Showcased | Demo Talking Point |
|---|---|---|
| DT Coach agent | Methods 1-6 coaching | AI-guided Design Thinking with structured method progression |
| Customer persona brief | Step 1 scenario setup | Simulated customer conversations grounded in realistic personas |
| Coaching state management | Session persistence across methods | Session recovery, method tracking, and artifact lineage |
| hifi-prototype skill | Method 7 scaffold generation | Experiment-framed prototypes with hypothesis-driven development |
| Experiment cards | Prototype setup | Every prototype starts with a falsifiable hypothesis |
| Telemetry instrumentation | Prototype scaffold | Measurement built in from day one, not added later |
| Canonical deck (optional) | Method 1, 3, and 5 snapshots | Visual summaries at scope, synthesis, and concept milestones |

## Validation

- [ ] Customer persona brief exists and all sections are populated
- [ ] DT coaching state initialized with `initial_classification: frozen` and `session_mode: demo`
- [ ] Methods 1 through 6 have generated artifacts
- [ ] Experiment card has a falsifiable hypothesis and measurable success criteria
- [ ] Prototype scaffold runs locally by opening `index.html`
- [ ] Telemetry captures page views, clicks, and task timing
- [ ] README contains a complete presenter's walkthrough guide
- [ ] Demo video script exists with all sections, visual cues, and timing annotations
- [ ] All simulated components display `[SIMULATED]` badges
- [ ] Experiment banner visible on every prototype page

## Troubleshooting

| Issue | Cause | Solution |
|---|---|---|
| Persona brief feels generic | Insufficient industry context provided | Add specific domain vocabulary and 3 to 5 concrete workflow details to the inputs |
| DT Coach exits accelerated mode | Coaching state missing `session_mode: demo` | Verify coaching-state.md has `session_mode: demo` under the project block in Step 2 |
| Prototype scaffold missing telemetry | hifi-prototype skill not invoked correctly | Ensure the experiment card is complete before triggering Method 7 transition |
| Audience confuses demo with real product | Missing simulation labels | Every mock component requires a visible `[SIMULATED]` badge; check the validation list |
| Demo takes too long to present | Full coaching mode active | Set `accelerated` input to `true` (default) for 2 to 3 exchanges per method |
| Fixture data does not match domain | Conversation seeds missing domain vocabulary | Update the Domain Vocabulary section of the persona brief before starting the session |
| Demo video script too long | Too many prototype screens narrated | Limit prototype demo to 2 to 3 key screens; reference additional screens briefly without full narration |
| Video script feels disconnected from prototype | Script written before scaffold finalized | Generate the video script after Step 5 completes so all prototype screens and the README are available as source material |

## Demo Video Script Template

The demo video script follows a fixed section structure with narrator text (blockquoted) and visual stage directions (bracketed). See `references/demo-video-script-template.md` for the full template, section-by-section script structure, authoring rules, and content derivation guidance. Copy that file to the prototype directory as `demo-video-script.md` in Step 6 and fill in the placeholders.

> Brought to you by microsoft/hve-core

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
