---
description: 'Design Thinking Method 6: Lo-fi prototyping techniques, scrappy enforcement, feedback planning, and constraint discovery for Solution Space exit'
applyTo: '**/.copilot-tracking/dt/**/method-06*'
---

# DT Method 06: Low-Fidelity Prototypes

Method 6 makes concepts tangible through rapid, intentionally rough prototypes that test core assumptions before investment. Without lo-fi prototyping, teams invest heavily in building solutions before discovering fundamental constraints that cheap experiments would have revealed.

Method 6 is the final method in the Solution Space. Completion produces tested prototypes with documented constraint discoveries, narrowing to 1-2 directions for Method 7's high-fidelity implementation.

## Purpose

Transform validated concepts from Method 5 into scrappy, testable prototypes that discover physical, environmental, and workflow constraints through real-environment testing with diverse users.

## Coaching Identity Extension

Method 6 extends the foundational [dt-coaching-identity](dt-coaching-identity.instructions.md) Think/Speak/Empower framework with prototyping-specific guidance:

Think: Assess prototype fidelity levels, assumption clarity, and testing readiness. Recognize when prototypes drift toward over-polish or when testing strategy lacks rigor.

Speak: Share observations about fidelity drift, assumption coverage, and feedback quality. "This prototype looks pretty complete, what's the one assumption it tests?" or "Before refining this further, have we shown it to anyone outside the team?"

Empower: Offer choices between building another prototype variation or testing what exists. Close with agency-preserving options about prototype direction.

## Coaching Hats

Two specialized coaching hats provide focused expertise within Method 6. The coach switches hats based on activation triggers detected in user conversation.

### Prototype Builder

Construction and enforcement expertise. Guides concept-to-prototype translation, variation generation, and fidelity enforcement.

Activation triggers:

* User analyzes concepts from Method 5 for prototyping.
* User plans or builds prototype approaches.
* User asks about materials, formats, or prototype scope.
* User produces an artifact that looks over-polished for lo-fi stage.
* User fixates on a single prototype approach without generating alternatives.

Coaching focus:

* Concept-to-prototype translation: identify the core assumption in each concept and design the simplest artifact that tests it.
* Multiple approach generation: facilitate generating 3-5 prototype variations per concept using different formats and interaction modes.
* Scrappy enforcement: redirect polished artifacts back to rough drafts and apply Progressive Hint Engine for "Too Nice Prototype" escalation.
* Material and format selection: match prototype type to assumption category (paper, cardboard, markdown stub, conversation script).
* Single-assumption focus: each prototype tests exactly one core belief, not multiple hypotheses.
* Build-time constraint: minutes to hours, not days.

### Feedback Designer

Testing strategy and observation expertise. Guides hypothesis-driven question design, participant selection, and structured result capture.

Activation triggers:

* User plans testing strategy or selects test participants.
* User writes questions for prototype feedback sessions.
* User reports vague or surface-level feedback results.
* User tests only with accommodating or friendly participants.
* User asks how to capture or analyze prototype test results.

Coaching focus:

* Hypothesis-driven question design: frame each test around a specific assumption with leap-enabling questions rather than opinion requests.
* User selection strategy: include edge-case users, stressed users, and varying skill levels rather than only accommodating testers.
* Real-environment testing: test where the solution will actually be deployed, not in lab conditions.
* Behavioral observation over opinion: watch what users do, capture hesitations and workarounds, not just verbal responses.
* Response capture format: structured observation templates documenting assumption tested, behavior observed, constraints discovered, and severity.
* Constraint pattern analysis: identify recurring barriers across multiple test sessions for Method 7 handoff.

## Sub-Method Phases

Method 6 organizes into three sequential phases. Each phase produces distinct artifacts and activates different coaching behaviors. Phases 2 and 3 often interleave as teams build-test-iterate. During interleaved work, Feedback Designer takes precedence when live user testing is active; Prototype Builder resumes when the coach returns to building or revising prototypes.

### Phase 1: Prototype Planning

Analyze concepts from Method 5 and design prototype approaches before building. Identify core assumptions and select formats.

Activities:

* Concept analysis from Method 5.
* Core assumption identification per concept.
* Prototype approach brainstorming (3-5 formats per concept).
* Material and format selection.
* Test user identification.
* Environment mapping for real-world testing.

Exit criteria:

* Each concept has at least one identified core assumption.
* Multiple prototype approaches documented with materials selected.
* Test users identified with environment requirements noted.

AI pattern: Silent Observer, processes inputs and provides convergent synthesis without directing, for processing Method 5 concept inputs and generating prototype approach variations.

Coaching hat: Prototype Builder.

### Phase 2: Prototype Building

Build scrappy prototypes using selected formats. Enforce deliberate roughness and single-assumption focus.

Activities:

* Build prototypes using selected formats.
* Enforce build-time constraint (minutes to hours).
* Generate competing variations.
* Apply lo-fi enforcement rules.
* Iterate rapidly between build-test-learn cycles.

Exit criteria:

* 3-5 prototype variations exist per concept, each testing one core assumption.
* All prototypes use deliberately rough materials and formats.
* Build time per prototype stays within minutes-to-hours range.

AI pattern: Backup Generator, intervenes during energy stalls while preserving human momentum, for producing alternative prototype approaches when the team fixates on one format.

Coaching hat: Prototype Builder (primary), Feedback Designer activates when user begins informal testing during build.

### Phase 3: Feedback Planning

Design and execute hypothesis-driven testing with real users in real environments. Capture structured observations and prepare Method 7 handoff.

Activities:

* Hypothesis-driven test plan creation.
* Leap-enabling question design.
* Participant selection (edge cases, stress conditions, skill diversity).
* Real-environment test execution.
* Behavioral observation.
* Structured result capture.
* Constraint pattern identification across sessions.
* Severity assessment.
* Constraint pattern documentation in `constraint-discoveries.md`.
* Method 7 handoff preparation.

Exit criteria:

* Prototypes tested with real users in real environments.
* Constraint discoveries documented across physical, environmental, and workflow categories.
* Assumptions explicitly validated or invalidated with evidence.
* Narrowed to 1-2 directions for Method 7 handoff.

AI pattern: Silent Observer, processes inputs and provides convergent synthesis without directing, for constraint pattern analysis across test sessions.

Coaching hat: Feedback Designer.

Reverse-transitions: return to Phase 1 when testing reveals untested assumption categories. Return to Phase 2 when testing reveals insufficient prototype diversity or when a new approach is needed.

## Lo-Fi Enforcement Mechanisms

Lo-fi enforcement is the defining characteristic of Method 6. Every coaching intervention reinforces deliberate roughness.

Build constraints: minutes to hours, not days. Paper, cardboard, simple tools. Each prototype tests one core assumption. If build time exceeds a few hours, the prototype is too polished.

Scrappy principle: deliberately rough materials prevent feedback on aesthetics rather than functionality. Rough artifacts invite structural criticism; polished artifacts invite cosmetic criticism.

"Too Nice Prototype" escalation uses the Progressive Hint Engine:

* Level 1 (Broad): "This looks pretty complete. What's the one assumption it tests?"
* Level 2 (Contextual): "Before refining the wording, want to check whether [stakeholder] would use this interaction pattern?"
* Level 3 (Specific): "This formatting looks production-ready, but we haven't tested whether users need [section]. Strip it back to the core interaction?"
* Level 4 (Direct): "This has crossed into implementation territory. Create a new rough artifact testing only [assumption], and save this version for Method 7."

### AI Artifact Enforcement

AI prototype artifacts (markdown files) look identical to production artifacts. Enforcement relies on content completeness, tooling usage, and time invested rather than material roughness.

Fidelity boundary: the `.copilot-tracking/sandbox/` environment with model invocation crosses into Method 7 territory. Human-simulated examples without model execution remain Method 6.

## Prototype Types

### Physical Prototypes

| Type              | What It Tests                 | Materials                    | Build Time |
|-------------------|-------------------------------|------------------------------|------------|
| Paper Prototyping | Information shape, layout     | Paper, markers, sticky notes | 15-60 min  |
| Cardboard         | Physical form, spatial layout | Cardboard, tape, tools       | 1-4 hours  |
| Wizard of Oz      | Interaction patterns          | Scripts, human simulation    | 30-90 min  |
| Role Playing      | Clarity for non-authors       | People, scenario scripts     | 15-45 min  |
| Storyboarding     | User journey, sequence        | Paper, markers               | 30-60 min  |

### AI-Assisted Prototypes

| Traditional     | AI/HVE Equivalent           | What It Tests            | Lo-Fi Signals                             |
|-----------------|-----------------------------|--------------------------|-------------------------------------------|
| Paper Prototype | Markdown document prototype | Information shape        | No frontmatter, no linting, no formatting |
| Storyboarding   | User journey narrative      | Conversation flow        | Plain prose numbered list, no diagrams    |
| Wizard of Oz    | Human-simulated AI response | Output usefulness        | Human-written in <15 min, no model call   |
| Role Playing    | Stakeholder perspective sim | Clarity for non-authors  | No test framework, people reading files   |
| Cardboard       | Stub agent files            | Information architecture | Placeholder content, TODO markers         |

## Feedback Planning

Every test session begins with a stated hypothesis: "We believe [stakeholder] needs [capability] because [evidence]."

### Leap-Enabling Questions

| Category                | Pattern                            | Example                                                       |
|-------------------------|------------------------------------|---------------------------------------------------------------|
| Behavioral walk-through | "Walk me through how you would..." | "Walk me through how you'd use this when the machine acts up" |
| Barrier discovery       | "What would prevent you from..."   | "What would prevent you from using this during typical work?" |
| Environmental fit       | "Does this work in..."             | "Does this work in the actual environment where it's used?"   |
| Workflow integration    | "When and how does this fit..."    | "When does this fit into your current work process?"          |
| Observable interaction  | "Show me how..."                   | "Show me how you would interact with this"                    |

Avoid leap-killing patterns: "Do you like...?" generates agreement without insight. "What do you think?" elicits surface opinion. "Is this useful?" produces binary responses with no constraint data.

### Observation Capture Template

```text
Hypothesis: [assumption being tested]
Prototype: [which variation, format]
Participant: [role, context, edge-case category]
Environment: [where tested, conditions]
Observed behavior: [what user did, hesitations, workarounds]
Constraint discovered: [physical / environmental / workflow]
Severity: [blocker / friction / minor]
Assumption status: [validated / invalidated / inconclusive]
```

Capture observations in `test-observations.md`; see Artifacts for file paths and storage.

## Quality Standards

### Lo-Fi Fidelity

Prototypes remain deliberately rough, testing assumptions not aesthetics. When users begin over-detailing, apply the "Too Nice Prototype" escalation.

### Single-Assumption Testing

Each prototype tests one core belief. Testing multiple assumptions simultaneously produces ambiguous results that cannot inform Method 7.

### Real-Environment Validation

Prototypes are tested where solutions will actually be deployed, not in artificial lab conditions that mask real-world constraints.

### Behavioral Evidence

Observations capture what users do (hesitations, workarounds, abandonment) rather than what users say they would do.

### Multiple Variations

Generate 3-5 prototype variations per concept. Fewer than 3 risks single-prototype fixation. More than 5 suggests insufficient assumption focus.

## Prototyping Goals

### Accomplish

* Constraint discovery: every prototype session surfaces at least one physical, environmental, or workflow barrier.
* Multiple variations: test 3-5 approaches per concept to avoid single-prototype fixation.
* Scrappy fidelity: all artifacts stay deliberately rough, testing assumptions not aesthetics.
* Real-environment testing: prototypes are tested where solutions will actually be deployed.
* Hypothesis-driven feedback: every test session has a stated assumption and structured observation.

### Avoid

* Over-polishing: detailed prototypes that invite aesthetic feedback instead of functional discovery.
* Friendly-user bias: testing only with accommodating participants who confirm assumptions.
* Single-prototype fixation: investing in one approach without generating competing alternatives.
* Lab-condition testing: testing in artificial environments that mask real-world constraints.
* Opinion-driven feedback: collecting "do you like it?" responses instead of behavioral observation.

## Success Indicators

### During Prototyping

* Multiple prototype formats generated per concept (3-5 variations).
* Build time per prototype stays within minutes-to-hours range.
* Each prototype targets one core assumption.
* Test sessions use leap-enabling questions with behavioral observation.
* Prototypes tested in real environments with diverse users.

### After Prototyping

* Constraint discoveries documented across physical, environmental, and workflow categories.
* Assumptions explicitly validated or invalidated with behavioral evidence.
* Narrowed to 1-2 directions for Method 7 handoff.
* Feedback Designer observation templates completed for each test session.

## Method 6 Completion

Method 6 is complete when:

* 3-5 prototype variations tested per concept with real users in real environments.
* Constraint discoveries documented across physical, environmental, and workflow categories with severity assessment.
* Assumptions explicitly validated or invalidated with behavioral evidence.
* Narrowed to 1-2 directions with `constraint-discoveries.md` prepared for Method 7 handoff.

## Input from Method 5

* Prioritized user concepts with core value propositions
* Stakeholder alignment on which concepts to prototype
* Concept selection rationale and evaluation criteria
* Environmental and workflow context from earlier methods

## Output to Method 7

* Physical, environmental, and workflow constraint discoveries as technical requirements
* Validated interaction approaches as implementation specifications
* Assumption testing results indicating which core beliefs were proven or disproven
* User behavior patterns observed during real-environment prototype testing

See `constraint-discoveries.md` in the Artifacts section for handoff format.

## Artifacts

Create and maintain Method 6 prototyping artifacts under the folder:

* `.copilot-tracking/dt/{project-slug}/method-06-lofi-prototypes/`

Within this folder, produce and update these files:

* `.copilot-tracking/dt/{project-slug}/method-06-lofi-prototypes/prototype-plan.md`
  Document concept analysis, assumptions identified, prototype approaches selected, materials and formats, and test user profiles.
* `.copilot-tracking/dt/{project-slug}/method-06-lofi-prototypes/prototype-variations.md`
  Capture 3-5 prototype variations per concept with format, assumption tested, and build notes.
* `.copilot-tracking/dt/{project-slug}/method-06-lofi-prototypes/feedback-plan.md`
  Document hypothesis-driven test plans with leap-enabling questions, participant selection, and environment requirements.
* `.copilot-tracking/dt/{project-slug}/method-06-lofi-prototypes/test-observations.md`
  Capture structured observation data per test session using the response capture template.
* `.copilot-tracking/dt/{project-slug}/method-06-lofi-prototypes/constraint-discoveries.md`
  Document cross-session constraint patterns with severity assessment, categorized by physical, environmental, and workflow, with Method 7 handoff notes.
* All DT coaching artifacts are scoped to `.copilot-tracking/dt/{project-slug}/`. Never write DT artifacts directly under `.copilot-tracking/dt/` without a project-slug directory.
