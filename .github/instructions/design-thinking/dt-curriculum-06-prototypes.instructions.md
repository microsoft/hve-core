---
description: 'DT Curriculum Module 6: Low-Fidelity Prototypes — concepts, techniques, checks, and exercises'
applyTo: '**/.copilot-tracking/dt/**/curriculum-06*'
---

# DT Curriculum Module 6: Low-Fidelity Prototypes

Low-fidelity prototyping is the Solution Space exit point. It transforms validated concepts from Method 5 into physical or functional approximations that can be tested with real users in real environments.
The governing principle is that every prototype failure is a success — each eliminated approach clarifies requirements and saves development resources. This module teaches learners why rough materials, rapid iteration, and real-environment testing produce better design decisions than careful planning alone.

## Key Concepts

*The scrappy principle* — Deliberately rough materials (paper, cardboard, tape, simple wireframes) encourage honest feedback about core functionality rather than surface aesthetics. When a prototype looks finished, users hesitate to criticize it; when it looks rough, they focus on whether the idea works. Learners often equate prototype quality with seriousness, but polish at this stage wastes effort and suppresses the critical feedback that prototyping exists to generate.

*Instant failure as instant win* — Each failed prototype eliminates a poor approach before significant development investment. A cardboard mockup that reveals touchscreen contamination from greasy hands costs minutes to build and test; discovering this after building a touchscreen solution costs months. Learners commonly view prototype failures as setbacks rather than as the primary value of the prototyping process.

*Single-assumption testing* — Each prototype should test one specific assumption: "Can operators interact with this while wearing gloves?" or "Is this readable under production floor lighting?" Testing multiple assumptions per prototype makes it impossible to isolate which assumption failed. Learners tend to build comprehensive prototypes that test everything at once, producing ambiguous results.

*Real environment testing* — Prototypes must be tested in actual use conditions — actual noise levels, actual lighting, actual hand contamination, actual time pressure. Lab conditions systematically miss the constraints that determine real-world viability. Learners often test in convenient settings and are surprised when solutions fail in deployment.

## Techniques

*Simple material prototyping* uses paper, cardboard, printed screenshots, and physical props to simulate solution interactions. Tape a paper interface to a wall at the height an operator would use it, hand them a greasy glove, and observe. Good output is a clear pass-or-fail result on the tested assumption. The pitfall is spending too long on construction — if it takes more than 30 minutes to build, it is too complex for lo-fi testing.

*Competing prototype generation* creates 2-3 different physical approaches that address the same validated concept. Test all variants with the same users in the same conditions. Good output is a ranked comparison showing which approach best suits the actual environment. The pitfall is becoming attached to one approach and testing only that one.

*Systematic variation* changes one variable at a time across prototype iterations: size, placement, interaction method, information density. Each variation isolates the effect of that variable. Good output is a decision log showing which variations passed and failed with evidence. The pitfall is changing multiple variables between tests, making results uninterpretable.

## Comprehension Checks

1. A team built a working tablet app prototype for production floor testing. Why might this level of fidelity be counterproductive at the lo-fi stage?
2. In the manufacturing scenario, a paper prototype taped to equipment showed that QR codes are unreadable under production lighting. Is this a prototype failure or a prototype success? Explain.
3. A prototype tested simultaneously whether operators could read the display, interact with gloves on, and hear audio prompts in a noisy environment. All three failed. What should the team do differently in the next round?
4. Why must lo-fi testing happen in the actual production environment rather than a conference room?

## Practice Exercises

*Exercise: Single-assumption prototype design* — Design three separate lo-fi prototypes for the manufacturing scenario, each testing exactly one assumption: (a) whether operators can read text at arm's length in production lighting, (b) whether glove-wearing operators can interact with a specific input method, (c) whether audio feedback is audible at 85-90 dB. Describe the materials, setup, and pass-or-fail criteria for each.

*Exercise: Failure analysis* — A lo-fi prototype of a touchscreen kiosk was tested on the production floor. Results: operators could not use it with greasy gloves, the screen was unreadable under overhead lighting, and workers ignored it when machines were running because they could not leave their station. Identify the three separate assumptions that failed, and propose a next-round prototype that addresses the most critical failure first.

## Learner Level Adaptations

Beginners should focus on the scrappy principle and practice building prototypes from simple materials with clear pass-or-fail criteria.

Intermediate learners benefit from comparing competing prototypes and understanding how lo-fi findings connect forward to Method 7 technical feasibility testing and backward to Method 4 if all approaches within a theme fail.

Advanced learners should explore how organizational risk tolerance affects prototyping ambition, analyze when a stream of prototype failures signals a return to Method 3 for re-synthesis, and critique the trade-off between single-assumption purity and practical time constraints.
