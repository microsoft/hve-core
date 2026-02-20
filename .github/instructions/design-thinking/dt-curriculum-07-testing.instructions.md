---
description: 'DT Curriculum Module 7: High-Fidelity Prototypes — concepts, techniques, checks, and exercises'
applyTo: '**/.copilot-tracking/dt/**/curriculum-07*'
---

# DT Curriculum Module 7: High-Fidelity Prototypes

High-fidelity prototyping is the entry point to the Implementation Space. It bridges what users need (validated through Methods 1-6) and what can actually be built with available technology and resources. Where lo-fi prototypes tested whether an approach is desirable, hi-fi prototypes test whether it is technically feasible under real-world constraints. This module teaches learners how to validate implementation paths without committing to production-ready development.

## Key Concepts

*Technical feasibility validation* — Proving that constraint-compliant solutions can be implemented using available technology. An industrial-grade microphone that works at 85-90 dB validates the voice-interaction approach; a consumer microphone that fails under those conditions invalidates it before any software is written. Learners often conflate desirability (users want it) with feasibility (it can be built), skipping the validation step between them.

*Stripped-down functional focus* — Build prototypes that validate core technical capabilities without visual polish or production-ready architecture. A voice recognition prototype needs to prove it can parse commands in a noisy manufacturing environment; it does not need a login screen or error handling framework. Learners tend to scope hi-fi prototypes too broadly, trying to build a miniature production system instead of a technical proof of concept.

*Multiple implementation comparison* — Generate and test 2-3 different technical approaches to the same validated concept. Compare an industrial microphone array vs a bone-conduction headset vs a directional lapel mic — each addresses the noise constraint differently. Choosing an approach without comparison means the team cannot know whether a better option existed. Learners frequently commit to the first technically viable approach without exploring alternatives.

*Domain constraint categories* — Technical validation must cover hardware constraints (can the device survive the environment), integration complexity (can this connect to existing systems), interface optimization (can users interact effectively), and multi-modal system validation (do the combined components work together). Learners tend to validate components in isolation and discover integration failures during deployment.

## Techniques

*Hardware constraint discovery* tests physical devices in actual operating conditions. Place the microphone on the production floor during peak noise, test the display under actual lighting, verify the interface works with contaminated gloves. Good output is a compatibility matrix showing which hardware meets which constraints. The pitfall is testing in best-case conditions and extrapolating.

*Integration complexity validation* connects prototype components to existing systems — databases, sensors, authentication, network infrastructure. Good output is a working data path from user interaction through to relevant backend systems. The pitfall is building a standalone prototype that works perfectly but cannot be integrated into the existing technology landscape.

*Comparative implementation testing* runs two or more technical approaches through identical test scenarios and evaluates them on the same criteria: accuracy, latency, environmental robustness, user adoption likelihood. Good output is a scored comparison table with evidence for each rating. The pitfall is comparing approaches using different test conditions, making the comparison invalid.

## Comprehension Checks

1. A lo-fi prototype showed operators want voice-controlled guidance. Why is it insufficient to proceed directly to building a voice-controlled production system?
2. A team built one hi-fi prototype, demonstrated it works, and declared technical validation complete. What step did they skip, and what risk does this create?
3. The manufacturing scenario validated an industrial microphone for 85-90 dB environments. Why must the team also test integration with the plant's existing network and database systems?
4. What distinguishes hi-fi prototyping goals from lo-fi prototyping goals? Why can these not be combined into a single prototyping phase?

## Practice Exercises

*Exercise: Comparison matrix design* — For the manufacturing voice-interaction approach, design a comparison testing plan for three microphone options: industrial-grade array, bone-conduction headset, and directional lapel mic. Define the test criteria (noise rejection, command accuracy, comfort with PPE, cost, maintenance), the test conditions (production floor during peak operation), and the pass-or-fail threshold for each criterion.

*Exercise: Integration risk identification* — The manufacturing plant has legacy equipment monitoring systems, a shift scheduling database, and a paper-based maintenance logging process. Identify three integration risks for a voice-guided repair system and describe how each risk could be validated through hi-fi prototyping before full development begins.

## Learner Level Adaptations

Beginners should focus on the distinction between desirability validation (lo-fi) and feasibility validation (hi-fi) and understand why stripped-down functional prototypes outperform comprehensive builds.

Intermediate learners benefit from designing comparison testing plans and understanding how hi-fi findings may trigger returns to Method 4 (when no technically feasible approach exists for a solution theme) or Method 6 (when a simpler interaction model succeeds).

Advanced learners should explore how organizational procurement and IT governance policies constrain hi-fi prototyping options, analyze when a failed technical validation reveals a gap in the original problem framing from Method 3, and critique the trade-off between thorough comparison and time-to-market pressure.
