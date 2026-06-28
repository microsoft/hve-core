---
name: onboarding-glossary
description: "Plain-language, on-demand definitions of hve-core onboarding vocabulary (agent, skill, slash command, subagent, Design Thinking, BRD/PRD, RPI, ADR, threat model, RAI, accessibility) for explaining terms to newcomers only when asked or when a beginner signal appears"
---

# Onboarding Glossary Skill

## Goal

Give the onboarding concierge plain-language one-liners it can weave into a sentence when a newcomer stalls on the vocabulary. Explain one term in context; never recite the whole list. Skip entirely for users who are already fluent.

This skill is repo-local: it describes hve-core's own vocabulary and is not distributed in any collection.

## When to use

* The user asks what a term means (for example "what's an agent?").
* A beginner signal appears and a term would otherwise go unexplained.

Offer the definition lightly ("Want me to quickly explain what an agent is?") rather than forcing it, and pull only the line that fits the moment.

## How you use the tools

* **Agent** — a specialized assistant you switch to in the chat box by typing `@` and its name (for example `@dt-coach`) and picking it from the list. Each agent is good at one kind of work.
* **Skill** — packaged know-how the assistant loads on its own to do a specific task well. You do not invoke skills directly; the assistant reaches for them when relevant.
* **Slash command / prompt** — a saved starting instruction you run by typing `/` and its name (for example `/onboarding`). You can re-run it anytime.
* **Subagent** — a helper an agent calls behind the scenes to do focused work and report back. You do not call these yourself.

## The workflow stages

* **Design Thinking** — a way to understand the real problem and the people affected before deciding what to build.
* **BRD / PRD** — written documents that capture the business need (BRD) and the product requirements (PRD).
* **RPI** — Research, Plan, Implement: the build loop that gathers evidence, makes a plan, then writes the code.
* **ADR** — Architecture Decision Record: a short note capturing an important technical decision and the reasoning behind it.

## The safety checks

* **Threat model / security review** — thinking through how something could be attacked or misused before it ships.
* **Responsible AI (RAI)** — checking an AI-facing feature for fairness, safety, privacy, and accountability.
* **Accessibility** — making sure a user-facing interface works for people with disabilities.

## Constraints

* Weave one relevant definition into a sentence; do not recite the whole list.
* Skip definitions entirely for users who are already fluent.
* Do not front-load vocabulary on someone who did not ask.

> Brought to you by microsoft/hve-core
