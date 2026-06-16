---
title: Feed Two Birds With One Scone
description: Contribute to HVE Core while learning HVE Core, by using HVE Core on HVE Core itself.
sidebar_position: 2
author: Microsoft
ms.date: 2026-06-14
ms.topic: concept
keywords:
  - contributing
  - sssc-planner
  - task-researcher
  - dogfooding
  - announcements
estimated_reading_time: 5
---

## The kinder version of an old idiom

There's an older expression about birds and stones. It works, but it's grim. The newer version, "feed two birds with one scone," lands softer and points at the same thing: you can get two outcomes from one action.

Here's the version worth making the case for: you can learn HVE Core, and you can contribute to HVE Core, by pointing HVE Core at HVE Core.

That last sentence is intentionally recursive. Stay with me.

## The two birds

When you pick up HVE Core, two needs usually show up at the same time.

* You want to understand how the agents, prompts, instructions, and skills actually behave on real work.
* You want to give back: file an issue, sharpen a prompt, suggest a missing instruction, anything that helps the next person.

Most people treat those as separate efforts. Learn first, contribute later, maybe never. The shortcut is to collapse them into one motion: use HVE Core on the HVE Core repo itself. Every honest run produces both a finished artifact for you and a list of "this could be better" signals for the project.

## A worked example: dogfooding the SSSC Planner

The Secure Software Supply Chain (SSSC) Planner is a good place to try this. Supply chain work is exactly the kind of cross-cutting analysis that exposes documentation gaps, prompt drift, and missing references the moment you run it on a real codebase.

Here's a short loop you can do in one sitting.

### 1. Start with Task Researcher

Open the chat agent picker in VS Code and select Task Researcher by name. It's not a slash command and not an @ handle; you switch to it from the picker like you would any other custom agent.

Ask it something like:

> Research the current state of HVE Core's supply chain posture so we can hand off to the SSSC Planner. Look at workflows, signing, dependency pinning, and existing supply chain docs.

Task Researcher does the reading for you and produces a single research document under `.copilot-tracking/research/`. You'll get an evidence-backed picture of what already exists, what looks unfinished, and where the SSSC Planner should focus first.

### 2. Hand off to the SSSC Planner

Switch agents in the picker, this time to SSSC Planner. The agent runs a six-phase conversation:

1. Capture (scope, repository context, conformance targets)
2. Assessment against the combined capabilities inventory
3. Standards mapping against OpenSSF Scorecard, SLSA, Sigstore, the OpenSSF Best Practices Badge, and SBOM minimum elements
4. Gap analysis with adoption categories and effort sizing
5. Backlog generation with priority derivation
6. Handoff to the next planner or to your work-tracking system

The research document from step 1 makes the capture phase faster. The planner has context to work with instead of asking you to recite the repo from memory.

### 3. Walk the phases honestly

Treat each phase like a real review. When the planner asks about Sigstore maturity, answer the way the repo actually looks today, not the way you'd like it to look. When it asks about SLSA build levels, check the workflow files before you guess.

Two useful side effects happen here:

* You learn the standards the planner is built on, because you're being asked to reason in their terms.
* You start noticing places where the planner's questions could be sharper, or where its references could point to a clearer source.

Both of those are gold.

### 4. Review the resulting backlog

Phase 5 emits a backlog in both ADO and GitHub-friendly formats. Phase 6 hands it off. Before you accept the output, read it with fresh eyes:

* Are the items scoped tightly enough to act on?
* Do the priorities match how you'd rank them?
* Is anything obviously missing for HVE Core specifically?

If a backlog item makes you go "huh, that's a real hole," congratulations: you found bird two. That finding is a contribution waiting to happen.

## Close the loop, one of two ways

Now decide how loud you want to be.

### The quiet path: consult a maintainer

Open an issue on the repo, drop a note in a Discussion, or tag a core writer on a PR thread. Share the artifact, share the gap, and ask for a quick read. Most maintainers would rather hear "your tool surfaced this gap" than find it themselves later.

### The bold path: start a group chat

Find the people who care about the topic. For SSSC work, that's the supply chain crowd. For something Responsible AI-shaped, that's the RAI Planner folks. For threat modeling, that's the Security Planner crew.

Start a thread. Drop the planner output. Invite three people who'd have opinions. The fastest improvements to HVE Core tend to come from short, focused conversations between people who all ran the same agent on different repos that week.

## Why both birds eat

The dogfooding loop works because it produces useful output on both sides at once.

* Your repo ends up with a real plan, a real backlog, or a real review you wouldn't have written by hand.
* HVE Core ends up sharper, because a contributor noticed something only a real run can surface: a confusing prompt, an outdated reference, a missing skill, a question that should have been asked one phase earlier.

Neither bird is hypothetical. You get a finished artifact. Your findings make HVE Core a better toolchain. Same scone.

## Try it this week

Pick one planner. Run it on a repo you already care about. Bring back one finding, however small.

Some easy starting points:

* SSSC Planner for supply chain posture
* Security Planner for threat modeling against the operational buckets
* RAI Planner for responsible AI review
* Accessibility Planner for inclusive design review

When you find something, share it. Issue, Discussion, group chat, your call. The bar is honest feedback, not polished prose.

That's the whole bet: every honest run feeds both birds. Bring a scone.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
