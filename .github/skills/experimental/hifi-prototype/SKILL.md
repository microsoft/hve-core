---
name: hifi-prototype
description: 'Opinionated scaffold and iteration loop for local-only high-fidelity prototypes that treat every build as a measurable experiment - Brought to you by microsoft/hve-core'
license: MIT
compatibility: 'Requires a web browser. Optional: Python 3.11+ (Flask), Node.js 18+ (Express), or .NET 8+ (Minimal API)'
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-04-10"
---

# High-Fidelity Prototype Builder

## Overview

Builds local-only, experiment-framed, intentionally-rough functional prototypes
with telemetry and Markdown reporting. Every prototype is an experiment with a
hypothesis, success criteria, and a clear way to know if it failed.

Core design constraints:

* A hypothesis and success criteria are required before scaffolding begins.
* Telemetry is built in from the start so every session produces measurable data.
* Rough UI is enforced deliberately to keep stakeholder feedback on behavior, not aesthetics.
* Everything runs locally with no cloud accounts, no deployments, no wait.
* Simulated components are visibly labeled so prototypes are never confused with production.
* Prototypes are disposable. If the experiment concluded, archive or delete it.

## When to Use

- Validating whether a concept works functionally before investing in production
- Testing user workflows with real-ish data and measuring actual behavior
- Building a prototype that needs to run on your machine with no cloud accounts
- Creating something stakeholders can click through while you watch what they do
- Generating structured experiment documentation alongside the prototype

## When Not to Use

- You need a polished, production-ready application
- The work requires cloud infrastructure, multi-user auth, or scalability
- You're past the experiment phase and need production code
- You only need a static mockup or wireframe (use Figma or paper)
- You need to deploy this for unsupervised remote user testing

## Prerequisites

No installation is required for the default HTML/CSS/JS stack. Open `index.html` in any modern browser.

| Stack          | Runtime                                |
|----------------|----------------------------------------|
| HTML (default) | Any modern browser                     |
| Python         | Python 3.11+ with Flask                |
| Node.js        | Node.js 18+ with Express               |
| .NET           | .NET 8+ SDK                            |

Optional dependencies:

* OpenTelemetry SDK for backend telemetry (installed per-stack)
* An LLM provider (Ollama or remote API) only if simulation requires one

## Inputs

| Input              | Required | Description                                                                                            |
|--------------------|----------|--------------------------------------------------------------------------------------------------------|
| Hypothesis         | Yes      | What you believe to be true and want to validate                                                       |
| Success criteria   | Yes      | Measurable conditions that confirm or reject the hypothesis                                            |
| Stack preference   | No       | `html` (default), `python` (Flask), `node` (Express), or `dotnet` (minimal API)                        |
| Storage            | No       | `sqlite` (default) or `files` (JSON/Markdown flat files)                                               |
| Simulation needs   | No       | What parts of the system should be simulated rather than built                                          |
| LLM provider       | No       | Endpoint and model for simulation (e.g., `ollama/llama3`). Defaults to no LLM                          |
| Telemetry level    | No       | `basic` (page views, clicks, task timing) or `detailed` (basic + custom events, session replay)        |

## Architecture Principles

### Local-Only, Zero Cloud

Everything runs on the developer's machine. No cloud accounts, no deployments,
no API keys unless the user explicitly opts into an LLM provider for simulation.

### Intentionally Rough UI

Enforced through specific design constraints:

* System fonts only (`system-ui, sans-serif`). No custom fonts.
* Maximum 2 colors: one neutral (gray), one accent.
* Visible 1px dashed borders on major layout sections. No rounded corners beyond `4px`, no shadows, no gradients.
* Minimum `16px` body text, `44px` touch targets.
* A visible banner on every page: **"⚠ EXPERIMENT — not a real product. [Prototype Name] | Hypothesis: [one-liner]"**

This is a deliberate Design Thinking technique (Method 7) that prevents stakeholders from giving feedback on visual polish when the goal is behavior validation.

### Simulation Layers

Simulated components must be:

1. **Visibly labeled** in the UI with a `[SIMULATED]` badge.
2. **Documented** in the experiment card with assumptions.
3. **Swappable** via isolated modules in a `sim/` directory.

See [stack-reference.md](references/stack-reference.md#simulation-approaches) for simulation approaches by need.

### Telemetry from Day One

Telemetry is not optional. **Basic** telemetry (page views, clicks, task timing, errors, session UUID) is always included. **Detailed** telemetry (custom events, funnel tracking, rage-click detection, session recording) is opt-in.

See [stack-reference.md](references/stack-reference.md#telemetry-implementation) for implementation details per stack.

## Project Structure

```
{prototype-name}/
├── experiment-card.md          # Hypothesis, criteria, measurement plan
├── index.html                  # Entry point (or app.py / server.js / Program.cs)
├── style.css                   # Rough UI styles (pre-populated with constraints)
├── app.js                      # Frontend logic and telemetry
├── telemetry.js                # Telemetry capture module
├── sim/                        # Simulation layer
│   ├── fixtures/               # JSON/CSV mock data
│   └── stubs.js                # Stub functions for simulated services
├── data/                       # SQLite file or JSON/Markdown data files
│   └── prototype.db            # (or *.json files if file storage chosen)
├── telemetry/                  # Telemetry output
│   └── events.json             # Captured events (append-only)
├── reports/                    # Markdown experiment reports
│   └── session-{n}.md          # Per-session observation report
└── README.md                   # Setup, run instructions, and experiment context
```

## Workflow

Follow the six-step workflow to build and evaluate a prototype experiment.
Each step has a checkpoint that must pass before proceeding.

| Step | Name                       | Purpose                                                   |
|------|----------------------------|-----------------------------------------------------------|
| 1    | Write the Experiment Card  | Define hypothesis, success/failure criteria, measurements  |
| 2    | Scaffold the Prototype     | Generate project structure, styles, telemetry, sim stubs   |
| 3    | Build the Core Interaction | Implement the minimum UI that tests the hypothesis         |
| 4    | Add Secondary Views        | Add supporting views if needed (max 5 total)               |
| 5    | Run a Test Session         | Execute task script, capture telemetry, write session report|
| 6    | Generate Experiment Report | Aggregate data, evaluate criteria, declare verdict         |

See [workflow.md](references/workflow.md) for detailed step instructions and checkpoints.
See [templates.md](references/templates.md) for experiment card, session report, and summary templates.

## Validation

- [ ] `experiment-card.md` exists before any code was written
- [ ] Hypothesis is falsifiable (failure criteria are specific)
- [ ] Prototype runs locally with a single command (no cloud setup)
- [ ] Experiment banner is visible on every page
- [ ] All simulated components are labeled `[SIMULATED]`
- [ ] Telemetry captures events to a local file
- [ ] Rough UI constraints are applied (system fonts, 2 colors, dashed borders)
- [ ] No view exists that does not test the hypothesis
- [ ] Session reports are in Markdown with structured data
- [ ] Experiment summary evaluates each success criterion with evidence

## Troubleshooting

| Issue                                  | Cause                               | Solution                                                                                           |
|----------------------------------------|-------------------------------------|----------------------------------------------------------------------------------------------------|
| Code written before experiment card    | Skipped hypothesis definition       | Refuse to scaffold until the experiment card is complete                                           |
| UI looks polished                      | Design constraints not enforced     | Enforce rough constraints in `style.css`; remove any shadows, gradients, or custom fonts           |
| No telemetry data captured             | Telemetry module missing or unwired | Telemetry module is scaffolded in Step 2; verify events fire in Step 3                             |
| Feature creep beyond hypothesis        | Scope expanded past experiment card | If a feature does not appear in the experiment card, it does not get built                         |
| Simulated output mistaken for real     | Missing simulation labels           | Every simulated component gets a `[SIMULATED]` badge; the experiment card catalogs all simulations |
| Hypothesis not testable                | No failure criteria defined         | Ask "what would convince you this is wrong?"; if unanswerable, the hypothesis needs refinement     |
| Conclusions drawn from one session     | Insufficient session count          | Experiment card defines session count target; do not write the summary until it is reached          |
| Prototype kept past experiment         | Over-investment in disposable code  | Archive or delete prototypes when the experiment concludes                                          |

## References

| File                                                    | Covers                                                     |
|---------------------------------------------------------|------------------------------------------------------------|
| [workflow.md](references/workflow.md)                   | Six-step workflow with detailed instructions and checkpoints|
| [templates.md](references/templates.md)                 | Experiment card, session report, and summary templates       |
| [stack-reference.md](references/stack-reference.md)     | Per-stack setup, simulation approaches, telemetry details    |

> Brought to you by microsoft/hve-core

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
