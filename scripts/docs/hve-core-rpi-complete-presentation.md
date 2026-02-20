---
title: HVE-Core RPI Complete Presentation Script
description: Detailed 30-minute presentation script with slide-by-slide speaker notes, visual specifications, and format guidance
author: HVE Core Team
ms.date: 2026-02-19
ms.topic: reference
keywords:
  - hve-core
  - rpi
  - presentation
  - speaker-notes
estimated_reading_time: 25
---

## Format

- **Total duration:** 30 minutes (two 15-minute parts)
- **Audience:** Mixed — developers, TPMs/leads, platform engineers, executives
- **Tone:** Problem-first storytelling with layered depth
- **Slide count:** 16 slides (8 per part) + live demo in Part 2
- **Structure:** Part 1 establishes the "why" and "what"; Part 2 shows the "how" and "where to start"

---

## Part 1: Why RPI — The Problem and the Framework (15 minutes)

### Slide 1: Title Slide (30 seconds)

**Title:** HVE-Core and the RPI Framework
**Subtitle:** Turning AI from a Code Generator into a Research Partner

**Visual:** Dark background, HVE-Core logo, presenter name/date. Accent blue bar at bottom. Industry credibility strip: logos or text for AVEVA, BMW, Michelin, Hexagon, Kubota, Nvidia.

**Speaker notes:**

> Welcome. I'm [Name], [Title] in Microsoft's Industry Solutions Engineering. Over the next 30 minutes, I'll show you why the way most teams use AI coding assistants is fundamentally broken — and how a constraint-based framework called RPI fixes it. This isn't about throwing away your tools; it's about making them dramatically more effective.
>
> We'll cover this in two parts. Part 1: **why** RPI exists and what it is. Part 2: **how** it works in practice, including a live demo.
>
> HVE-Core has been proven at companies like AVEVA, BMW, Michelin, Hexagon, Kubota, and Nvidia. What I'll share today comes from real-world engineering, not theory.

---

### Slide 2: The Failure Mode You'll Recognize (2 minutes)

**Title:** The Failure Mode You'll Recognize

**Key points:**

- Centered block quote showing the Terraform failure scenario
- Pain point statistics as supporting evidence
- Red accent color for the "Reality" line

**Content:**

> **You:** "Build me a Terraform module for Azure IoT"
>
> **AI:** *immediately generates 2,000 lines of code*
>
> **Reality:** Missing dependencies, wrong variable names, outdated patterns, breaks existing infrastructure

**Supporting statistics:**

- Developers lose 15–20 hours/week to repetitive tasks, context-switching, and relearning
- 40% productivity lost from unstructured AI interactions and constant context switches
- Unstructured "vibe coding" with AI yields incorrect, bloated, or outdated code

**Visual:** Terminal-style monospace text on dark background. First two lines in white, the "Reality" line in red (`#D13438`). Stats appear as annotated callouts around the terminal. Optional: faded code waterfall behind the text.

**Speaker notes:**

> Raise your hand if this has happened to you — maybe not Terraform, maybe Python, maybe C#. The AI generates something that looks right. It compiles. It might even pass some tests. Then you deploy and discover it used patterns from three years ago, missed your naming conventions, and broke two downstream services.
>
> This isn't an edge case. This is the default behavior. And the pain goes deeper: teams lose 15 to 20 hours per developer per week just figuring things out or doing boilerplate work. Context-switching and lack of AI guidance costs about 40% of productivity. These aren't just inconveniences — they're engineering bottlenecks.

---

### Slide 3: Why It Happens (1.5 minutes)

**Title:** AI Writes First and Thinks Never

**Key points:**

- Root cause: AI cannot distinguish investigating from implementing
- When you ask for code, it optimizes for generating plausible code, not verified code
- "Plausible and correct aren't the same thing"

**Visual:** Two-column split. Left: magnifying glass icon with "Investigate?" Right: keyboard icon with "Implement!" — with a large equals sign between them, crossed out in red. Message: AI treats these as the same operation.

**Speaker notes:**

> Here's the root cause. When you say "build this," the AI has one optimization target: generate something that *looks like* correct code. It has no incentive to check whether `azurerm_iothub` still exists as a resource type, or whether your team wraps everything in modules. It writes first and thinks never.
>
> The key realization: **plausible and correct aren't the same thing.** The AI is optimizing for plausibility, not correctness. It pattern-matches from training data rather than investigating your actual codebase. That gap between plausible and correct is where most rework and frustration lives.

---

### Slide 4: The Counterintuitive Insight (1.5 minutes)

**Title:** The Constraint Changes the Goal

**Key points:**

- Central quote: "The solution isn't teaching AI to be smarter. It's preventing AI from doing certain things at certain times."
- When AI knows it cannot implement, it stops generating plausible code and starts generating verified knowledge
- The constraint changes the optimization target

**Visual:** Large centered quote in white on dark background with blue accent bar on left. Below: a before/after transformation arrow — "Optimizing for plausible code" (red, `#D13438`) → "Optimizing for verified truth" (green, `#107C10`).

**Speaker notes:**

> This is the paradigm shift that drives everything else you'll see today. The fix isn't better models or more training data. It's constraints.
>
> When you tell the AI "you will never write code in this phase," something remarkable happens. It stops trying to generate code and starts doing what you actually need: reading your codebase, finding existing patterns, citing specific files and line numbers. It becomes a research partner instead of a code generator.
>
> The constraint doesn't limit the AI — it redirects it. That's the core insight behind HVE-Core. "RPI treats AI as a research partner first, code generator second."

---

### Slide 5: What Is HVE-Core? (2 minutes)

**Title:** What Is HVE-Core?

**Key points:**

- Elevator pitch: enterprise-ready prompt engineering framework for GitHub Copilot
- Component summary in colored cards
- Four-tier artifact model
- Industry adoption

**Content:**

> **HVE-Core** is an enterprise-ready prompt engineering framework for GitHub Copilot that uses constraint-based AI workflows to turn AI from a code generator into a research partner.

| Component    | Count | Purpose                                                        |
|--------------|-------|----------------------------------------------------------------|
| Agents       | 22    | Specialized AI assistants for 9 functional domains             |
| Prompts      | 27    | Workflow entry points for common tasks                         |
| Instructions | 24    | Technology-specific coding standards (auto-applied by file pattern) |
| Skills       | 1     | Executable utility packages with cross-platform scripts        |
| Collections  | 10    | Role-based artifact filtering for 8 extension packages         |

**Four-tier artifact model:** User Request → Prompt → Agent → Instructions + Skills

**Visual:** Top half — elevator pitch as subtitle text. Bottom half — 5 colored cards in a row showing component counts (blue for agents, green for prompts, orange for instructions, purple for skills, teal for collections). Below cards: delegation flow arrow.

**Speaker notes:**

> HVE-Core is an enterprise-ready prompt engineering framework for GitHub Copilot. It provides 22 specialized agents, 27 reusable prompts, and 24 instruction sets — all validated by JSON schemas and a 12-job CI pipeline.
>
> Think of it as infrastructure for AI-assisted engineering. Prompts capture your intent, hand off to agents that orchestrate work, and agents follow instructions and invoke skills. Each layer has a single job in this delegation chain.
>
> Collections filter everything by role — a TPM sees different tools than a developer. A security engineer doesn't need data science agents. You install only what you need.
>
> Industry leaders like AVEVA, BMW, Michelin, Hexagon, Kubota, and Nvidia have used HVE-Core to accelerate their projects, proving its value in real-world enterprise scenarios.

---

### Slide 6: The RPI Pipeline (2.5 minutes)

**Title:** Research → Plan → Implement → Review

**Key points:**

- Four-phase type transformation pipeline
- Each phase converts one form of understanding into the next
- Skipping a phase means operating on the wrong type
- `/clear` between every phase

**Content:**

```text
Uncertainty → Knowledge → Strategy → Working Code → Validated Code
```

**Visual:** Horizontal pipeline with 4 large rounded rectangles connected by arrows:

- **Research** (blue, `#0078D4`) — "Uncertainty → Knowledge"
- **Plan** (green, `#107C10`) — "Knowledge → Strategy"
- **Implement** (orange, `#FF8C00`) — "Strategy → Working Code"
- **Review** (purple, `#8864D8`) — "Working Code → Validated Code"

Between each box: a `/clear` marker in a red circle to show context reset.

Below: the canonical ASCII workflow diagram:

```text
┌─────────────────┐   Handoff    ┌─────────────────┐   Handoff    ┌─────────────────┐   Handoff    ┌─────────────────┐
│ Task Researcher │ ──────────→ │  Task Planner   │ ──────────→ │ Task Implementor│ ──────────→ │  Task Reviewer  │
│                 │  📋 Create   │                 │  ⚡ Implement  │                 │  ✅ Review   │                 │
│ Uncertainty     │    Plan      │ Knowledge       │              │ Strategy        │              │ Working Code    │
│     ↓           │              │     ↓           │              │     ↓           │              │     ↓           │
│ Knowledge       │              │ Strategy        │              │ Working Code    │              │ Validated Code  │
└─────────────────┘              └─────────────────┘              └─────────────────┘              └─────────────────┘
        ↓                                ↓                                ↓                                ↓
   research.md                   plan.md + details.md           code + changes.md              review.md + findings
        ↑                                ↑
        └────────────────────────────────┴──────────────── 🔬 Research More / 📋 Revise Plan ────────────────────────┘
```

**Speaker notes:**

> This is the RPI pipeline. Four phases, four type transformations. Research converts uncertainty into knowledge. Planning converts knowledge into strategy. Implementation converts strategy into working code. Review converts working code into validated code.
>
> Notice the outputs match the inputs of the next phase. Research produces knowledge that planning consumes. Planning produces strategy that implementation follows. This is why the ordering matters — if you skip research, your plan is based on assumptions, not verified knowledge. If you skip planning, your implementation makes ad hoc decisions.
>
> See the `/clear` markers between phases? That's not optional — it's architectural. When you clear context between phases, you prevent mode contamination. Research findings live in files, not chat history. Each agent reads the canonical artifacts, not stale conversation.
>
> And RPI is cyclical, not linear. Review can route back to Research, Plan, or Implement via handoff buttons. The reviewer might find a research gap or a scope change that needs replanning.
>
> Using this structure, teams have seen task completion up to 88% faster than unstructured prompting. The "code comes last, after the hard work of understanding is complete."

---

### Slide 7: What Each Phase Does (and Cannot Do) (2.5 minutes)

**Title:** What Each Phase Does (and Cannot Do)

**Key points:**

- 4 vertical cards, one per phase, each showing: Purpose, Core Constraint, Key Output, Invocation
- Emphasis on the constraints column

**Visual:** Four vertical cards arranged horizontally, each with the phase color as a top accent bar:

| | Research (Blue) | Plan (Green) | Implement (Orange) | Review (Purple) |
|---|---|---|---|---|
| **Purpose** | Verify patterns exist | Sequence and dependencies | Execute the strategy | Validate against specs |
| **Constraint** | Cannot implement | Cannot implement | Follows plan only | Cannot modify code |
| **Output** | `research.md` | `plan.md` + `details.md` | Working code + `changes.md` | `review.md` |
| **Invoke** | `/task-research` | `/task-plan` | `/task-implement` | `/task-review` |

**Traceability chain:** Plan → Details (Lines X–Y) → Research (Lines A–B)

**Speaker notes:**

> Let me zoom into each phase. The most important row is the constraints.
>
> **The Researcher** cannot implement. That single constraint transforms its behavior — instead of inventing patterns, it searches for existing ones. It cites specific files and line numbers. It questions its own assumptions. Output: a research document with evidence.
>
> **The Planner** also cannot implement. It focuses entirely on sequencing, dependencies, and success criteria. It validates that research exists before it starts — mandatory first step. The plan becomes a contract between you and the AI.
>
> **The Implementor** follows the plan. No creative decisions that break existing patterns. It reads the plan checkbox by checkbox and implements each step. Stop controls let you pause after each phase or each task for verification.
>
> **The Reviewer** cannot modify code. It validates against the documented specifications, not assumptions. Findings use three severity levels — Critical, Major, Minor. If something fails, it routes back to the appropriate phase with handoff buttons.
>
> *For developers in the room:* These constraints are enforced by the agent definitions, not by willpower. You literally can't make the researcher write code.
>
> **Best practices:** Keep implementation to roughly three files per cycle. If the plan is larger, split into multiple RPI cycles. Start a fresh session for implementation for best results. Run tests after each implementation step.

---

### Slide 8: Traditional AI Coding vs. RPI (2 minutes)

**Title:** Traditional AI Coding vs. RPI

**Key points:**

- Side-by-side comparison table (5 rows)
- The /clear rule as structural architecture, not convenience
- Paradigm shift quote

**Visual:** Top section — two-column comparison table with red tint on left, green tint on right:

| Aspect | Traditional AI Coding | RPI Approach |
|--------|----------------------|--------------|
| **Pattern matching** | Invents plausible patterns | Uses verified existing patterns |
| **Traceability** | "The AI wrote it this way" | "Research cites lines 47-52" |
| **Knowledge transfer** | Tribal knowledge in your head | Research documents anyone can follow |
| **Rework** | Frequent — assumptions discovered wrong after the fact | Rare — assumptions verified before implementation |
| **Validation** | Hope it works or manual testing | Validated against specifications with evidence |

Bottom section — paradigm shift quote:

> Stop asking AI: "Write this code."
> Start asking: "Help me research, plan, then implement with evidence."

**Speaker notes:**

> Here's the before and after. On the left, traditional AI coding — the AI invents patterns, you can't trace decisions, knowledge lives in someone's head, and rework is frequent. "Hope it works" is your validation strategy.
>
> On the right, RPI — verified patterns, traceable decisions, transferable knowledge, and pre-verified assumptions. Validation is against specifications with actual evidence.
>
> *For TPMs and leads:* The traceability row is your strongest argument. Instead of "the AI wrote it that way," you get "the research document cites lines 47 through 52 of the existing service." When someone asks "why did we do it this way?" — there's a document with the answer.
>
> *For executives:* The knowledge transfer row matters most. When someone leaves the team, their research documents stay. New team members can read how past decisions were made. The institutional memory compounds over time.
>
> The paradigm shift is simple: stop asking AI to write code. Start asking it to help you research, plan, then implement with evidence. Structured phases kill the AI rework loop.

---

<!-- markdownlint-disable-next-line MD036 -->
**(End of Part 1 — approximately 15 minutes)**

---

## Part 2: HVE-Core in Practice (15 minutes)

### Slide 9: Six Specialized Chat Modes (1.5 minutes)

**Title:** Your Toolkit: Six Specialized Chat Modes

**Key points:**

- 4 RPI modes form the core cycle
- 2 complementary modes: Prompt Builder (meta-level artifact authoring) and PR Review (8-dimension quality gate)
- Each mode has a single constraint that defines its behavior

**Visual:** Six cards arranged in two groups.

**Group 1 (connected with arrows):** RPI Cycle

- **Task Researcher** — `/task-research` — "Cannot implement"
- **Task Planner** — `/task-plan` — "Cannot implement"
- **Task Implementor** — `/task-implement` — "Follows plan only"
- **Task Reviewer** — `/task-review` — "Cannot modify code"

**Group 2 (below):** Complementary Modes

- **Prompt Builder** — `/prompt-build` — "Orchestrates subagents, never reads prompt files directly"
- **PR Review** — Agent picker — "Never modifies code, 8-dimension quality check"

**Visual enhancement:** Copilot Chat mode picker screenshot next to the cards.

**Speaker notes:**

> Here are your six modes. The top four are the RPI cycle you just learned about — they're the phases mapped to specialized AI agents.
>
> Two additional modes serve specialized functions. **Prompt Builder** creates the artifacts that configure the RPI agents — instructions, prompts, agent definitions. It's meta-level tooling with a sandbox for safe testing. **PR Review** is an 8-dimension quality gate covering functional correctness, design, idioms, reusability, performance, reliability, security, and documentation.
>
> Where Task Reviewer validates your implementation against the *internal* plan and research specs, PR Review validates the *external-facing* PR against coding conventions and engineering standards. They're complementary: Reviewer is spec-scoped, PR Review is branch-scoped.
>
> *For developers:* You'll live in the top four modes 90% of the time. The invocation is just typing the slash command in Copilot Chat. Each agent also shows up in the mode picker dropdown.
>
> *Advanced option:* There's also an `rpi-agent` that orchestrates all four phases in a single session — great for quick, familiar tasks. If complexity emerges, you escalate to strict RPI. No upfront commitment required.

---

### Slide 10: Live Demo: RPI in Action (5 minutes)

**Title:** Let's See It in Action

**Demo intro (30 seconds):**

**Visual:** Terminal/VS Code screenshot with text overlay: "Live Demo: RPI Workflow — Research and Plan"

**Speaker notes (intro):**

> Now let me show you what this looks like in practice. I'm going to run through the first two phases of an RPI workflow live — Research and Plan. Watch for three things: (1) how the researcher finds existing patterns instead of inventing code, (2) how it cites specific files and line numbers, and (3) how the plan references the research artifacts.

**Demo script (4.5 minutes):**

1. **Open VS Code** with HVE-Core extension installed (30s)
   - Show the Copilot Chat panel with mode picker visible
   - Point out the six custom modes in the dropdown

2. **Run Task Researcher** (2 min)
   - Type `/task-research` with a focused topic
   - Let the researcher run — narrate:
     - "Notice it's searching the codebase, not generating code"
     - "It found the configuration and cites the exact file and line number"
     - "The output is a research document with evidence — not code"
   - Show the generated `research.md` file briefly

3. **Demonstrate /clear** (15s)
   - Type `/clear` to reset context
   - "Clean slate — the planner reads the research file, not chat history"

4. **Run Task Planner** (2 min)
   - Type `/task-plan` with the research file open
   - Let it generate the plan — narrate:
     - "It validates the research exists before planning — mandatory"
     - "Each step references specific lines in the details file"
     - "Phases are organized for sequential or parallel execution"
   - Show the generated `plan.instructions.md` and `details.md` briefly

5. **Wrap up** (15s)
   - "From here, an implementor would follow this plan step by step"
   - "The reviewer would validate against both the plan and the research"
   - "Each phase produces artifacts that bridge to the next — not chat history"

**Fallback plan:** If the live demo fails, switch to pre-recorded screenshots or a 5-minute screencast backup.

---

### Slide 11: Expanding RPI — Discovery and Design Thinking (1.5 minutes)

**Title:** Beyond RPI: Discovery and Design Thinking

**Key points:**

- D-RPI: optional Discovery phase before Research for ambiguous problems
- Alignment with Design Thinking stages
- RPI is cyclical — Review iterates back to earlier phases
- Context pre-seeding: keeping Discovery Q&A primes subsequent Research

**Visual:** Extended pipeline showing Discovery phase (gray, dashed border) before the four solid RPI phases:

```text
[Discovery] ··→ Research → Plan → Implement → Review
 (optional)        ↑                              │
                   └──── iteration loops ──────────┘
```

**Design Thinking alignment:**

| D-RPI Phase | Design Thinking Stage |
|-------------|----------------------|
| Discovery   | Empathize / Define   |
| Research    | Ideate (evidence-constrained) |
| Plan        | Prototype (on paper) |
| Implement   | Build / Test         |
| Review      | Validate / Feedback  |

**Speaker notes:**

> RPI adapts to different situations. For complex or ambiguous projects where requirements are unclear, you can add a Discovery phase before Research — we call this D-RPI.
>
> Discovery is essentially a brainstorming session with the AI in Ask Mode: "Who is the audience? What do they care about? What do they already know?" It mirrors the Empathize and Define stages of Design Thinking. Context from Discovery pre-seeds the Research phase, so the AI already understands the high-level intent.
>
> This alignment isn't a coincidence. RPI maps naturally to Design Thinking — Research parallels Ideation, Plan parallels Prototyping, Implement parallels Building, Review parallels Testing with feedback loops.
>
> And speaking of loops — RPI is cyclical, not linear. The Review phase can route back to Research if it finds knowledge gaps, back to Plan if scope changed, or back to Implement for fixes. The handoff buttons in Task Reviewer make this explicit.
>
> *Note:* D-RPI and Design Thinking integration are forward-looking extensions. The core four-phase RPI is the production workflow today.

---

### Slide 12: Real Results with HVE-Core (1.5 minutes)

**Title:** Real Results with HVE-Core

**Key points:**

- Concrete case study metrics
- Quality improvements
- Developer experience gains

**Content:**

| Metric | Result |
|--------|--------|
| Secure cloud deployments | **50% faster** (global telecom adopting AI-driven IaC) |
| Architecture docs and security plans | **90% faster** generation (days → hours) |
| Prototype delivery | **2 days vs. 8 weeks** (internal hackathon using RPI + Copilot) |
| Code quality | AI-powered PR reviews catch subtle bugs and security issues pre-merge |
| Developer experience | Less rework, less context-switching → higher satisfaction and innovation time |

**Visual:** Five metric cards with bold numbers and brief descriptions. Use green accent for positive metrics. Optional: before/after comparison bars.

**Speaker notes:**

> These aren't hypothetical — real teams have seen dramatic improvements with HVE-Core.
>
> A global telecom rolled out an HVE approach in their cloud deployment process and cut deployment times by 50%. Another team saw architecture documents and security plans go from taking several days to just a few hours — a 90% reduction.
>
> At an internal hackathon, a team delivered a working prototype in only 2 days using RPI and Copilot — something that traditionally would have taken 6 to 8 weeks.
>
> Quality improved too. The AI-driven PR Review agent helped developers catch subtle bugs and security issues before code was merged — things like a missing null-check that could've caused a production error. This early detection prevents expensive rework down the road.
>
> And developers are happier. By eliminating tedious tasks and reducing context-switching, HVE-Core frees engineers to focus on creative problem-solving. Teams report significantly less frustration and higher morale.

---

### Slide 13: Eight Roles, One Framework (1.5 minutes)

**Title:** Eight Roles, One Framework

**Key points:**

- 8 distinct engineering roles served by role-specific collections
- Each role has a different workflow pattern
- Collections filter agents and prompts by job function

**Visual:** 8 role cards in a 2×4 grid or role-collection-agent Sankey-style diagram:

| Role | Collection | Primary Workflow |
|------|-----------|------------------|
| **Developer** | `hve-core` | RPI Pipeline: Research → Plan → Implement → Review |
| **TPM / Lead** | `project-planning`, `ado` | Requirements → PRD → ADO Work Items |
| **Platform Engineer** | `coding-standards` | Artifact authoring → Sandbox testing → Distribution |
| **OSS Contributor** | `github` | Discovery → Triage → Sprint Planning → Execution |
| **Security Engineer** | `security-planning` | Blueprint-driven threat modeling and security plans |
| **Data Scientist** | `data-science` | Data Spec → Jupyter Notebook → Streamlit Dashboard → Tests |
| **Project Planner / PM** | `project-planning` | PRD / BRD / ADR building and stakeholder collaboration |
| **UX / DT Practitioner** | `design-thinking` | 9-method Design Thinking coaching with persistence |

**Speaker notes:**

> HVE-Core isn't just for developers. Eight distinct roles, each with a dedicated collection that filters the right tools for their job.
>
> *For developers:* You already know your workflow — it's the RPI pipeline. The agents handle boilerplate, suggest improvements, and ensure consistency across coding standards and commit messages.
>
> *For TPMs and leads:* Your workflow is requirements discovery → PRD authoring → ADO work item hierarchy creation. The product-manager-advisor agent helps discover requirements, the prd-builder creates the document, and ado-prd-to-wit converts it into a development backlog. You produce the plan; developers execute with RPI.
>
> *For OSS contributors and new team members:* HVE-Core acts as a self-service mentor. Pick a "good first issue," run Task Researcher to understand the codebase, use Task Planner to outline your approach. The AI keeps you on track and teaches project conventions in real time. Lower barrier to entry, higher quality contributions.
>
> *For PMs and non-coding roles:* Use Researcher to gather data for status reports, Planner to structure narratives, Prompt Builder to formulate user stories. Cross-role collaboration improves because everyone shares a common language and workflow.
>
> Notice that roles don't share workflows — a TPM's tooling is different from a developer's. Collections make that separation automatic.

---

### Slide 14: Built by HVE-Core, Validated by HVE-Core (1 minute)

**Title:** Built by HVE-Core, Validated by HVE-Core

**Key points:**

- Dogfooding: 5 examples of self-use
- Enterprise validation: 12 parallel CI/CD jobs
- Extension ecosystem: 8 packages

**Visual:** Split slide.

**Left half — Dogfooding (teal accent):**

1. GitHub Backlog Manager manages HVE-Core's own issues
2. Installer agent onboards contributors to HVE-Core's own environment
3. Community interaction templates define voice/tone for actual PR comments
4. Copilot Coding Agent environment mirrors devcontainer for consistent AI PR quality
5. Conventional commit format drives both releases AND triage label suggestions

**Right half — Validation Pipeline (orange accent):**

- **Linting (7 jobs):** spell-check, markdown, tables, YAML, frontmatter, links, link-check
- **Analysis (2 jobs):** PSScriptAnalyzer, Pester tests
- **Security (3 jobs):** dependency pinning, npm audit, CodeQL

**Below:** Schema validation: `*.instructions.md` / `*.prompt.md` / `*.agent.md` → JSON schemas

**Extension ecosystem:** 8 VS Code packages under `ise-hve-essentials` — full edition or domain-specific. Common base of 8 core agents + 5 core instructions across all packages.

**Speaker notes:**

> The strongest credibility signal: the team eats their own cooking. The same triage automation, community interaction templates, and coding standards that external users get are used to manage the HVE-Core repository itself. We use our own installer agent to onboard contributors. The Copilot Coding Agent environment — used for automated PRs — mirrors our devcontainer exactly.
>
> On quality: every PR runs through 12 parallel validation jobs — spell-checking, markdown linting, YAML validation, PSScriptAnalyzer, Pester tests, dependency pinning checks, npm audit, and CodeQL security scanning. Every AI artifact has typed frontmatter validated against JSON schemas. You can enforce structure across hundreds of prompt files.
>
> The extension ecosystem has eight VS Code packages. Install the full `hve-core` for everything, or pick domain-specific packages. All share a common base of RPI agents and core instructions.
>
> *For platform engineers:* The schema validation and maturity lifecycle (experimental → preview → stable → deprecated) are how you govern AI artifacts at scale.
>
> *For executives:* Zero to enterprise-grade in about four weeks. The 2.0 breaking change — adding the Review phase — demonstrates commitment to validated, evidence-based AI work.

---

### Slide 15: Getting Started and Learning Resources (1.5 minutes)

**Title:** Three Paths to Start + Learn More

**Key points:**

- Three primary installation methods with decision guidance
- Learning curve honesty and compounding value
- External learning resources and community

**Visual:** Three installation cards:

| Method | Time | Best For |
|--------|------|----------|
| **VS Code Extension** ⭐ | 10 seconds | Individuals, TPMs, immediate access |
| **Peer Clone** (`git clone`) | 2 minutes | Developers needing customization |
| **Codespaces** | 1 click | Contributors wanting zero-config |

**Learning curve section (orange/green split):**

> *Orange accent:* "Let's be honest: your first RPI workflow will feel slower."
>
> *Green accent:* "By your third feature, the workflow feels natural. Research documents accumulate into institutional memory. Patterns documented once get referenced forever."

**Resources:**

- **First Workflow Tutorial:** `docs/getting-started/first-workflow.md` — 15-minute guided RPI exercise
- **HVE-Learning Repository:** `microsoft/hve-learning` — self-paced modules on prompt engineering, RPI, backlog management
- **Customer Zero Katas:** `aka.ms/cz-repo-katas` — hands-on practice exercises for real-world scenarios
- **Documentation:** `aka.ms/hve-core` — installation steps, usage examples, FAQs
- **Community:** Bi-weekly HVE Community Syncs for live demos and Q&A. Internal channels: #Hypervelocity, #SeasonOfHVE
- **Contribute:** Look for "good first issue" tags on HVE-Core and accelerator repos (Edge AI, Robotics). Contributions to code, prompts, or docs are welcome

**Speaker notes:**

> Three paths to get started, based on your role. The VS Code Extension is the fastest — literally 10 seconds from the Marketplace. Search "HVE Core," install, and you have all six chat modes immediately. If you need to customize artifacts, clone the repo. For zero-config, use GitHub Codespaces — one click.
>
> I want to be honest with you. Your first RPI workflow will feel slower. You'll wonder why you're researching instead of just coding. But by your third feature, you'll know what questions to ask, what level of planning detail works for your codebase, and implementation becomes almost mechanical.
>
> The real value isn't the current task — it's what compounds. Research documents accumulate into institutional memory. New team members can read how past decisions were made. You're not just solving today's problem; you're building the knowledge base that accelerates tomorrow's.
>
> For learning, the first-workflow tutorial takes 15 minutes — it's what I just demoed but self-guided. HVE-Learning has full modules. Customer Zero Katas provide hands-on practice.
>
> And we'd love to have you contribute. Issues labeled "good first issue" are a great starting point. Use RPI to learn the repo and make your first PR — the agents will keep you on track.

---

### Slide 16: Key Takeaways and Q&A (1.5 minutes)

**Title:** Key Takeaways

**Key points:**

1. **Accelerate delivery and quality:** HVE-Core combines AI tools with structured practices — tasks up to 88% faster without sacrificing quality or security
2. **RPI is the game-changer:** Research → Plan → Implement → Review turns Copilot from a nifty helper into a reliable partner. Structured phases kill the AI rework loop
3. **Empower every role:** HVE-Core's approach isn't just for coders. PMs, TPMs, security engineers, data scientists, and OSS contributors each have dedicated workflows and collections
4. **Start your hypervelocity journey:** It only takes 10 seconds to install. Pick a small upcoming task, run it through RPI, and see the difference yourself

**Closing quote:**

> "The code comes last, after the hard work of understanding is complete."

**Call to action:**

- Install HVE-Core today → Try RPI on one task this week → Join the community to multiply impact

**Speaker notes:**

> To wrap up: Hypervelocity Engineering is about making your whole team dramatically faster and better.
>
> **First:** HVE-Core delivers real results. Some teams have seen nearly a tenfold speed-up on certain tasks, while also catching quality issues that could have slipped through before.
>
> **Second:** RPI is the heart of this approach. It might feel counterintuitive at first to slow down and do separate research and planning steps, but that structure is exactly what unlocks the speed later. By forcing ourselves — and the AI — to "think before coding," we avoid the painful cycle of writing code and then reworking it. Structured phases kill the AI rework loop.
>
> **Third:** HVE-Core empowers everyone, not just developers. PMs create PRDs. TPMs build backlog hierarchies. Security engineers generate threat models. Data scientists produce dashboards. Everyone benefits from constraint-based AI.
>
> **Our call to action:** Try HVE-Core on one task this week. The setup is trivial — 10 seconds. Start with something manageable, experience RPI in practice, and measure the results. Then join the community, ask questions, share your successes and challenges. Hypervelocity Engineering is a journey, and we're all still learning.
>
> "The code comes last, after the hard work of understanding is complete." Thank you for your time — let's go forth and build at hypervelocity. Questions?

---

## Timing Summary

| Part | Slide | Title | Duration |
|------|-------|-------|----------|
| **1** | 1 | Title | 0:30 |
| **1** | 2 | The Failure Mode You'll Recognize | 2:00 |
| **1** | 3 | AI Writes First and Thinks Never | 1:30 |
| **1** | 4 | The Constraint Changes the Goal | 1:30 |
| **1** | 5 | What Is HVE-Core? | 2:00 |
| **1** | 6 | The RPI Pipeline | 2:30 |
| **1** | 7 | What Each Phase Does (and Cannot Do) | 2:30 |
| **1** | 8 | Traditional AI Coding vs. RPI | 2:00 |
| | | **Part 1 Total** | **14:30** |
| **2** | 9 | Six Specialized Chat Modes | 1:30 |
| **2** | 10 | Live Demo: RPI in Action | 5:00 |
| **2** | 11 | Discovery and Design Thinking | 1:30 |
| **2** | 12 | Real Results with HVE-Core | 1:30 |
| **2** | 13 | Eight Roles, One Framework | 1:30 |
| **2** | 14 | Built by HVE-Core, Validated by HVE-Core | 1:00 |
| **2** | 15 | Getting Started and Learning Resources | 1:30 |
| **2** | 16 | Key Takeaways and Q&A | 1:30 |
| | | **Part 2 Total** | **15:00** |
| | | **Grand Total** | **29:30** |

*30-second buffer for slide transitions. Q&A absorbs remaining time. If demo runs long, compress slides 14–15.*

---

## Visual Asset Requirements

| Asset | Type | Slide |
|-------|------|-------|
| Terraform failure scenario | Styled text block | 2 |
| Pain point statistics | Annotated callouts | 2 |
| Investigation vs. Implementation split | Icon diagram | 3 |
| Optimization target transformation | Arrow diagram | 4 |
| Component count cards (5) | Colored cards | 5 |
| Delegation flow (User → Prompt → Agent → Instructions) | Arrow chain | 5 |
| RPI pipeline with type labels and `/clear` markers | Pillow-rendered flow diagram | 6 |
| Canonical ASCII workflow diagram | Text diagram or rendered image | 6 |
| Phase attribute cards (4) | Colored vertical cards | 7 |
| Quality comparison table | Two-column tinted table | 8 |
| Paradigm shift quote | Styled text block | 8 |
| Chat mode cards (6) in two groups | Two-group card layout | 9 |
| Copilot Chat mode picker | Screenshot or mockup | 9, 10 |
| Research output file | Screenshot | 10 |
| Plan output file | Screenshot | 10 |
| D-RPI extended pipeline | Dashed-border flow diagram | 11 |
| DT alignment table | Styled table | 11 |
| Case study metric cards (5) | Colored stat cards | 12 |
| Role-collection mapping | 8-role grid or Sankey diagram | 13 |
| Dogfooding bullets + CI pipeline | Split layout | 14 |
| Extension table (8 rows) | Highlighted table | 14 |
| Installation path cards (3) | Colored cards | 15 |
| Learning curve split | Orange/green two-column | 15 |
| Key takeaway bullets + quote | Styled list | 16 |

---

## Demo Fallback Plan

If the live demo fails:

1. **Pre-recorded screenshots:** Capture the workflow in advance and present as annotated screenshots on slide 10
2. **Terminal output paste:** Show pre-captured terminal output in a styled text block
3. **Video recording:** Record a 5-minute screencast as a backup MP4 embedded in the PPTX

Prepare all three fallback assets before the presentation.

---

## Appendix: Key Quotable Phrases (from official documentation)

These phrases are sourced directly from the HVE-Core RPI documentation and available for use in slides, banners, or speaker notes:

1. > "Uncertainty → Knowledge → Strategy → Working Code → Validated Code"
2. > "AI writes first and thinks never."
3. > "The solution isn't teaching AI to be smarter. It's preventing AI from doing certain things at certain times."
4. > "When AI knows it cannot implement, it stops optimizing for 'plausible code' and starts optimizing for 'verified truth.' The constraint changes the goal."
5. > "Stop asking AI: 'Write this code.' Start asking: 'Help me research, plan, then implement with evidence.'"
6. > "RPI treats AI as a research partner first, code generator second."
7. > "The code comes last, after the hard work of understanding is complete."
8. > "If you need to understand something before implementing, use RPI."
9. > "Let's be honest: your first RPI workflow will feel slower. By your third feature, the workflow feels natural."
10. > "Research documents accumulate into institutional memory."

---

## Appendix: Content Source Attribution

| Source | Primary Slides | Contributing Slides |
|--------|---------------|---------------------|
| Prior research outline | 2, 3, 4, 6, 8, 14 | 1, 5, 7, 9, 10, 15, 16 |
| Current presentation | 11, 12 | 1, 2, 5, 7, 13, 15, 16 |
| Both (merged) | 1, 5, 7, 9, 10, 13, 15, 16 | — |
| Gap analysis corrections | — | 6, 7, 9, 11, 14, 15 |

### Key Corrections Applied (from gap analysis)

| Correction | Severity | Change |
|------------|----------|--------|
| Four-phase replaces three-phase | Critical | Review is a full first-class phase, not an afterthought |
| Task Reviewer distinguished from PR Review | Major | Separate agents with different validation scopes |
| "Constraint changes the goal" elevated | Major | Dedicated slide (4) for core insight |
| Iteration loops added | Major | RPI shown as cyclical, not linear |
| Installation updated | Major | VS Code Extension as primary (10 seconds), not clone+config |
| `/task-*` invocation syntax | Minor | Replaces old `@agent` convention |
| D-RPI labeled forward-looking | Minor | Clearly distinguished from core four-phase RPI |
