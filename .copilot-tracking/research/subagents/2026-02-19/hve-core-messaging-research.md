<!-- markdownlint-disable-file -->

## Research Summary

**Question:** HVE-Core elevator pitch, problem statement, and value proposition for a mixed-audience presentation
**Status:** Complete
**Output File:** `.copilot-tracking/research/subagents/2026-02-19/hve-core-messaging-research.md`

### Key Findings

* Elevator pitch extracted from README.md L18 and docs/README.md L10
* Core problem statement sourced from docs/rpi/why-rpi.md L1-L14 and README.md L106-L112
* Paradigm shift framing sourced from docs/rpi/why-rpi.md L92-L96
* Failure mode example (Terraform warning box) sourced from docs/rpi/why-rpi.md L22-L30
* Version history milestones from CHANGELOG.md spanning v0.0.0 through v2.3.4

---

## Elevator Pitch

**Short form (1 sentence):**

> HVE Core is an enterprise-ready prompt engineering framework for GitHub Copilot that uses constraint-based AI workflows to turn AI from a code generator into a research partner.

**Extended form (2 sentences):**

> HVE Core is an enterprise-ready prompt engineering framework for GitHub Copilot providing 18 specialized agents, 18 reusable prompts, and 17+ instruction sets with JSON schema validation. Its RPI methodology separates complex engineering tasks into Research, Plan, and Implement phases where AI knows what it cannot do — changing optimization targets from "plausible code" to "verified truth."

---

## Core Problem Statement

### Why Enterprise Teams Need This

AI coding assistants excel at simple tasks but fail at complex, multi-file work. The root cause is that AI cannot distinguish between investigating and implementing. When asked for code, it writes code immediately without verifying patterns, conventions, or dependencies against the actual codebase.

**Key problem framing from source material:**

> "Ask for a function that reverses a string, and you'll get working code in seconds. Ask for a feature that touches twelve files across three services, and you'll get something that looks right, compiles cleanly, and breaks everything it touches."
> — README.md, docs/rpi/why-rpi.md

> "The problem isn't that AI is incapable. The problem is that we're asking it to do too many things at once."
> — docs/rpi/why-rpi.md

> "AI writes first and thinks never. Not because it's broken, but because that's the only mode it has when you give it unrestricted access to both research and implementation."
> — docs/rpi/why-rpi.md

---

## The Failure Mode (Terraform Warning Box)

This example from `docs/rpi/why-rpi.md` works well on slides as is:

> **The failure mode you'll recognize**
>
> You: "Build me a Terraform module for Azure IoT"
>
> AI: *immediately generates 2000 lines of code*
>
> Reality: Missing dependencies, wrong variable names, outdated patterns, breaks existing infrastructure

**Why it happens:** AI can't tell the difference between investigating and implementing. It doesn't stop to verify that variable naming matches existing modules. It doesn't check whether resources already exist. It doesn't ask whether the API is current or deprecated.

---

## The Paradigm Shift

**The framing from source material:**

> Stop asking AI: "Write this code."
>
> Start asking: "Help me research, plan, then implement with evidence."

> "RPI treats AI as a research partner first, code generator second. The code comes last, after the hard work of understanding is complete."
> — docs/rpi/why-rpi.md

**The counterintuitive insight:**

> "The solution isn't teaching AI to be smarter. It's preventing AI from doing certain things at certain times."
> — docs/rpi/why-rpi.md

**The constraint mechanism:**

> "When AI knows it cannot implement during research, it stops optimizing for 'plausible code' and starts optimizing for 'verified truth.' The constraint changes the goal."
> — docs/rpi/why-rpi.md, README.md

---

## Value Propositions (5 Bullets)

1. **Constraint-based design prevents AI runaway behavior** — Agents know their boundaries. Research agents can't write production code; implementation agents follow documented plans rather than inventing patterns.

2. **Research-first methodology eliminates the "looks right, breaks everything" failure mode** — The RPI workflow separates investigation from code generation. AI discovers existing conventions before writing a single line.

3. **Enterprise validation pipeline with JSON schema enforcement** — All AI artifacts (agents, prompts, instructions, skills) go through typed frontmatter validation, maturity lifecycle enforcement, and link checking via CI/CD.

4. **Scales from solo developers to large teams** — Seven installation methods (VS Code extension, CLI plugins, multi-root workspace, submodule, peer clone, git-ignored clone, mounted directory, Codespaces). Research documents accumulate into institutional memory.

5. **Measurable quality differences in traceability and rework** — Traditional: "The AI wrote it this way." RPI: "Research document cites lines 47-52." Assumptions verified before implementation rather than discovered after breakage.

---

## Notable Quotable Phrases (Slide-Ready)

| Quote | Source | Best Use |
|-------|--------|----------|
| "AI writes first and thinks never" | why-rpi.md | Problem statement slide |
| "The constraint changes the goal" | why-rpi.md, README.md | Core insight slide |
| "Plausible and correct aren't the same thing" | why-rpi.md | Problem framing |
| "Research partner first, code generator second" | why-rpi.md | Vision/paradigm shift slide |
| "Preventing AI from doing certain things at certain times" | why-rpi.md | Solution summary |
| "The code comes last, after the hard work of understanding is complete" | why-rpi.md | Methodology philosophy |
| "18 specialized agents, 18 reusable prompts, and 17+ instruction sets" | README.md | Scale/breadth slide |
| "Constraint-based AI workflows, validated artifacts, and structured methodologies" | README.md | Tagline |
| "Stops optimizing for plausible code and starts optimizing for verified truth" | why-rpi.md | Before/after transformation |
| "Verified truth" vs "plausible code" | why-rpi.md | Two-word contrast pair |

---

## Version History Highlights

| Version | Date | Milestone |
|---------|------|-----------|
| 0.0.0 | Initial | Release-please bootstrap |
| 1.0.0 | — | First stable release (implied; 1.1.0 changelog begins) |
| 1.1.0 | 2026-01-19 | Foundation: devcontainer, agents, RPI docs, VS Code extension, installer agent, security scanning, CodeQL, release management |
| 2.0.0 | 2026-01-28 | **BREAKING:** Task Reviewer added, RPI expanded to 4-phase workflow (R→P→I→Review). OpenSSF Scorecard, skills framework, Pester tests, artifact attestation |
| 2.1.0 | 2026-02-04 | CIHelpers module, copyright validation, Coding Agent environment setup |
| 2.2.0 | 2026-02-06 | Incident response prompt, security action consistency, copyright header CI |
| 2.3.0 | 2026-02-13 | GitHub backlog management pipeline, collection-based plugin distribution, Copilot CLI plugin generation |
| 2.3.4 | 2026-02-13 | Current release (bug fixes for packaging and releases) |

**Key narrative arc:** From zero to enterprise-grade in ~4 weeks. The 2.0 breaking change (adding Task Reviewer to make RPI a 4-phase workflow) shows the project's commitment to validated, evidence-based AI work.

---

## Quality Comparison Table (Slide-Ready)

From `docs/rpi/why-rpi.md`:

| Aspect | Traditional Approach | RPI Approach |
|--------|---------------------|-------------|
| Pattern matching | Invents plausible patterns | Uses verified existing patterns |
| Traceability | "The AI wrote it this way" | "Research document cites lines 47-52" |
| Knowledge transfer | Tribal knowledge in your head | Research documents anyone can follow |
| Rework | Frequent, after discovering assumptions were wrong | Rare, because assumptions are verified first |
| Validation | Hope it works or manual testing | Validated against specifications with evidence |

---

## Audience-Specific Angles

| Audience | Lead With | Supporting Evidence |
|----------|-----------|---------------------|
| **Developers** | The Terraform failure mode → constraint-based fix | 15-minute first-workflow tutorial, agent picker UX |
| **Engineering Leads/TPMs** | Traceability table, institutional memory, team scaling | Research documents as audit trail, seven install methods |
| **Platform Engineers** | JSON schema validation pipeline, CI/CD integration | `npm run lint:frontmatter`, maturity lifecycle |
| **Executives** | "Zero to enterprise-grade in 4 weeks," measurable rework reduction | OpenSSF badges, version velocity |

---

## Gaps Requiring Further Research

1. **Quantitative metrics** — No specific numbers on rework reduction, time savings, or adoption rates found in source material. Case studies or telemetry would strengthen the value proposition.
2. **Competitive positioning** — Source material does not compare HVE Core against other prompt engineering frameworks (Cursor rules, aider conventions, etc.). A comparison matrix would help mixed audiences.
3. **Customer/user testimonials** — No quotes from external users found. Third-party validation would strengthen the pitch for executive audiences.
4. **Adoption scale** — GitHub stars, downloads, or active team counts are not present in the docs. Marketplace install counts could fill this gap.
5. **Demo script** — The first-workflow tutorial is text-based. A live demo script or screen recording storyboard would complement slides.
