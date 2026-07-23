---
title: Demo Video Script Template
description: Reusable template for HVE Core demo video scripts with section structure, visual cue format, and timing guidance
---

## How to Use This Template

This template provides both the structural reference for authoring a demo video script and a fillable scaffold. Copy this file to the prototype directory as `demo-video-script.md`, then replace the `{{placeholder}}` text with content derived from the customer persona brief, DT artifacts, experiment card, and prototype screens.

### Script Structure

| Section | Duration | Content |
|---|---|---|
| Video Details | — | Metadata table: title, subtitle, target duration, audience, tone |
| Cold Open | 0:30 | Show the running prototype; narrate the persona's pain in their own words |
| Section 1: The Problem | 1:30 | Walk through the persona brief on screen; highlight frustrations and the specific scenario |
| Section 2: Design Thinking Coach | 2:30 | Show the DT artifacts directory; narrate key method outputs and coaching state |
| Section 3: The Experiment Card | 1:00 | Open the experiment card; narrate hypothesis, success criteria, and failure criteria |
| Section 4+: Prototype Demo | 4:00 | Screen-by-screen narration of the prototype; one section per major screen |
| What You Just Saw | 1:30 | Recap the five HVE Core capabilities demonstrated |
| Where to Start | 4:00 | Three entry points with live demo prompts for Task Researcher, RPI Agent, and DT Coach |
| Closing | 0:30 | Summary statement and call to action |
| Production Notes | — | Recording setup table: tool, browser, theme, font size, resolution, pre-recording steps |

### Section Authoring Rules

* Visual cues appear in `**[VISUAL: description]**` format before the narrator text they accompany.
* Narrator text uses blockquote format (`>`) for spoken words.
* Demo prompts (text the presenter types on screen) appear in a dedicated code block labeled with the prompt context.
* Each prototype demo section covers one screen of the prototype. Name the section after the screen (for example, "Order Queue Demo" or "Dashboard Demo").
* Timing annotations appear in parentheses in each section heading (for example, `## COLD OPEN (0:00 - 0:30)`).
* The "Where to Start" section includes three subsections, one per agent, each with a typed prompt and narration of the agent's response.
* Production Notes table includes at minimum: screen recording tool, browser, VS Code theme, font size, resolution, and any pre-recording reset steps (for example, clearing localStorage).

### Content Derivation

| Script Section | Source Artifact |
|---|---|
| Cold Open scene | Prototype `index.html` primary screen |
| The Problem narration | Customer persona brief: frustrations, problem scenario, constraints |
| DT Coach walkthrough | `.copilot-tracking/dt/{slug}/` artifact directory and coaching-state.md |
| Experiment Card | `experiment-card.md` hypothesis and criteria |
| Prototype Demo screens | Each `.html` file in the scaffold, walked through in workflow order |
| What You Just Saw | Integration with HVE Core Tools table from the demo-setup skill |
| Where to Start | Standard three-agent intro: Task Researcher, RPI Agent, DT Coach |

---

## Video Details

| Field            | Value                                                                          |
|------------------|--------------------------------------------------------------------------------|
| Title            | {{title — action-oriented statement about the demo outcome}}                   |
| Subtitle         | HVE Core Design Thinking + Prototyping Workflow                                |
| Target duration  | 14-16 minutes                                                                  |
| Audience         | {{audience — who will watch this recording}}                                   |
| Tone             | Conversational, confident, practitioner-to-practitioner                        |

---

## COLD OPEN (0:00 - 0:30)

**[VISUAL: Browser showing the prototype primary screen with key UI elements visible]**

> {{Vivid description of the persona's daily pain in their own words. Show the running prototype as the backdrop. End with a hook: "We built this in under an hour using two HVE Core tools. Let me show you how."}}

---

## SECTION 1: THE PROBLEM (0:30 - 2:00)

**[VISUAL: VS Code, open to `customer-persona-brief.md`, scrolling through the Organization and Persona Profile sections]**

> {{Introduce the persona: name, role, organization, scale. Ground the viewer in who this person is and what their day looks like.}}

**[VISUAL: Highlight the "Frustrations" section of the persona brief]**

> {{Walk through the top 3 frustrations. Be specific with numbers, names, and workflow details.}}

**[VISUAL: Highlight the "Problem Scenario" section]**

> {{Narrate one concrete instance of the problem occurring. Include the cascading consequences.}}

**[VISUAL: Cut to the problem statement in `method-03-problem-statement.md`]**

> {{State the problem statement as synthesized by the DT Coach. Frame it as a question: "Can [proposed solution] change that?"}}

---

## SECTION 2: DESIGN THINKING COACH (2:00 - 4:30)

**[VISUAL: VS Code file explorer showing the `.copilot-tracking/dt/{slug}/` directory with all method artifacts visible]**

> {{Introduce the DT Coach: "Before writing any code, we ran a Design Thinking coaching session." Mention methods 1-6 and structured artifacts.}}

**[VISUAL: Open `method-01-stakeholder-map.md`]**

> {{Method 1 highlight: Who are the stakeholders? What insight emerged from mapping them?}}

**[VISUAL: Open `coaching-state.md`, highlight the transition log]**

> {{Coaching state persistence: session recovery, method tracking, artifact lineage. "If I close VS Code and come back tomorrow, the DT Coach picks up exactly where we left off."}}

**[VISUAL: Open `method-03-theme-clusters.md`]**

> {{Method 3 highlight: What themes emerged from synthesis? List 2-3 key themes with evidence.}}

**[VISUAL: Open `method-05-concept-cards.md`, show the D/F/V summary table]**

> {{Method 5 highlight: Desirability, feasibility, viability assessment. What was the verdict?}}

**[VISUAL: Brief pause on the full `.copilot-tracking/dt/{slug}/` file tree]**

> {{Summary: "Six methods. Ten artifacts. A validated problem, a testable hypothesis, and a clear concept. All before a single line of prototype code."}}

---

## SECTION 3: THE EXPERIMENT CARD (4:30 - 5:30)

**[VISUAL: Open `experiment-card.md` in VS Code]**

> {{Introduce the experiment card concept: "This is not a requirements doc. It is a hypothesis with explicit success and failure criteria."}}

**[VISUAL: Highlight the hypothesis]**

> {{Read the hypothesis verbatim or paraphrase closely.}}

**[VISUAL: Highlight the success criteria table]**

> {{Walk through 2-3 key success criteria that are observable and measurable.}}

**[VISUAL: Highlight the failure criteria]**

> {{Explain what would prove the hypothesis wrong. "A good experiment is falsifiable."}}

---

## SECTION 4: PROTOTYPE DEMO — PRIMARY SCREEN (5:30 - 7:30)

**[VISUAL: Browser, `index.html` — primary screen visible]**

> {{Describe the persona's new workflow. Narrate what each UI element means and how it maps to the problem statement.}}

**[VISUAL: Interact with the primary screen — click buttons, hover elements, show state changes]**

> {{Walk through 2-3 key interactions. Show the happy path first, then edge cases with lower confidence or flagged items.}}

**[VISUAL: Point out the experiment banner and [SIMULATED] badges]**

> {{Acknowledge the prototype constraints: "The simulated badge reminds us this is a prototype. The real architecture would [describe production approach]. But the prototype proved the workflow works before we invest."}}

---

## SECTION 5: PROTOTYPE DEMO — SECONDARY SCREEN (7:30 - 9:30)

**[VISUAL: Browser, secondary screen (e.g., review, pipeline, closeout)]**

> {{Describe the second key screen. What does it show? How does the persona use it?}}

**[VISUAL: Walk through the interaction flow on this screen]**

> {{Narrate the specific interactions: approvals, overrides, confirmations. Show how the persona completes their core task.}}

**[VISUAL: Show completion state or confirmation]**

> {{Describe the endpoint: "The task is complete. The [action] is confirmed."}}

---

## SECTION 6: WHAT YOU JUST SAW (9:30 - 11:00)

> Let me recap what we covered.

> First, the DT Coach agent. It guided us through six Design Thinking methods with a simulated customer persona. Every method produced a structured artifact. Those artifacts are reusable. They are the institutional memory of the design process.

> Second, coaching state management. The session is persistent. You can close VS Code, come back next week, and the coach picks up where you left off. Method progress, artifact lineage, transition rationale: all tracked.

> Third, the experiment card. Every prototype starts with a hypothesis written before any code. Success criteria you can observe. Failure criteria that tell you when to pivot. This is not a feature backlog. It is a falsifiable experiment.

> Fourth, the prototype skill. It generated the scaffold in minutes. Intentionally rough UI so stakeholders react to the workflow, not the colors. Simulated badges on every mock component so nobody confuses this with a product.

> And fifth, telemetry from day one. Page views, clicks, task timing, session IDs. When you run this prototype with real users, you get measurement data automatically.

> The whole thing runs by opening a single HTML file. No servers, no cloud accounts, no API keys.

---

## SECTION 7: WHERE TO START (11:00 - 15:00)

**[VISUAL: VS Code command palette or agent selector showing the three agents]**

> So you have seen the workflow end to end. The natural question is: where do I start? HVE Core gives you three entry points depending on where you are in your work.

### Task Researcher Demo (11:00 - 12:30)

**[VISUAL: VS Code with the Task Researcher agent active]**

> If you are joining an existing project or picking up unfamiliar code, start with the **Task Researcher**. Point it at a codebase and it maps the architecture, identifies patterns, surfaces dependencies, and answers your questions grounded in what is actually there.

**[DEMO: Ask the Task Researcher]**

Prompt to type:

> "I just opened this repo for the first time. Give me a technical overview — what does this project do, what's the tech stack, how is it organized, and where should I start if I want to add a new {{domain feature}}?"

**[VISUAL: Watch the Task Researcher read files, scan directories, and synthesize a structured overview.]**

> {{Narrate what the researcher does and the quality of its grounded output.}}

### RPI Agent Demo (12:30 - 14:00)

**[VISUAL: VS Code with rpi-agent active]**

> When you are ready to build, reach for the **RPI Agent**. RPI stands for Research, Plan, Implement. It breaks your task into phases: the researcher gathers context, the planner writes a step-by-step implementation plan, and the implementor executes each phase.

**[DEMO: Ask the RPI Agent]**

Prompt to type:

> "Add a telemetry dashboard page (telemetry-dashboard.html) that reads captured events from localStorage and visualizes: {{2-3 metrics relevant to the prototype's experiment card}}."

**[VISUAL: Watch the RPI agent research, plan, and implement. Show the finished dashboard.]**

> {{Narrate the three phases and the final result.}}

### DT Coach Recap (14:00 - 14:30)

**[VISUAL: VS Code with DT Coach agent active]**

> And if you are starting from scratch, that is where the **DT Coach** comes in. It walks you through Design Thinking methods to make sure you are solving the right problem before you build anything.

> One more thing. In this demo we used a generated persona brief to simulate the customer conversations. But in real engagements, you feed it real context. Drop a meeting transcript into the `context/` folder and the coach grounds its coaching in what was actually said.

### Connecting the Three (14:30 - 15:00)

**[VISUAL: Simple diagram or text overlay showing the three agents]**

> Three starting points. Exploring existing code? Task Researcher. Building the next feature? RPI Agent. Validating a new idea from scratch? DT Coach. They work independently, but they also connect. The DT Coach's experiment card feeds the RPI Agent's planning. The Task Researcher grounds both of them in what is actually in the codebase.

---

## CLOSING (15:00 - 15:30)

**[VISUAL: VS Code showing the full `.copilot-tracking/dt/{slug}/` directory alongside the prototype files]**

> {{Summarize the journey: persona to prototype. Name the key tools. Invite the viewer to try with their own scenario.}}

> Thanks for watching.

---

## Production Notes

| Item                 | Detail                                                                    |
|----------------------|---------------------------------------------------------------------------|
| Screen recording tool | OBS or VS Code screen recorder extension                                 |
| Browser              | Chrome with DevTools closed, zoom at 100%                                |
| VS Code theme        | Default dark or light — keep it familiar                                 |
| Font size            | VS Code editor font 14px minimum for readability                         |
| Resolution           | 1920x1080 or 2560x1440                                                   |
| localStorage         | Run `localStorage.clear()` in DevTools before each take                  |
| Pauses               | Leave 1-2 second pauses at section transitions for editing               |
| B-roll opportunities | File explorer navigation, coaching state YAML scrolling, status bar updates |


---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
