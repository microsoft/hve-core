---
title: ADR Standards Excerpts
description: Curated external standards excerpts and citations supporting the adr-author skill, with license attribution
author: microsoft/hve-core
ms.date: 2026-05-02
ms.topic: reference
keywords:
  - adr
  - architecture-decision-record
  - madr
  - standards
  - project-planning
---

# ADR Standards Excerpts

Curated excerpts and citations supporting the `adr-author` skill. This file gathers external standards the skill relies on, with license attribution and change indication where required. The verbatim MADR template is not duplicated here; see `../templates/madr-v4.md`.

## MADR v4.0.0

Markdown Any Decision Records (MADR) is a lean ADR template optimized for collaboration in Markdown. Version 4.0.0 defines the canonical frontmatter (status, date, decision-makers, consulted, informed) and the section structure (Context and Problem Statement, Decision Drivers, Considered Options, Decision Outcome, Consequences, Confirmation, Pros and Cons, More Information) that the `adr-author` skill produces in `full` entry mode. The template is released under CC0-1.0 Universal Public Domain Dedication and may be reproduced byte-identical without modification.

- Upstream: <https://github.com/adr/madr> (tag `4.0.0`, file `template/adr-template.md`).
- License: CC0-1.0.
- Verbatim template: `../templates/madr-v4.md` (this reference file does not duplicate it).

## Y-Statement

The Y-Statement is a six-slot single-sentence decision capture formula authored by Olaf Zimmermann and Uwe Zdun. It condenses an architectural decision into: use case, concern, chosen option, rejected alternatives, target quality, and accepted downside. The `adr-author` skill uses the Y-Statement as the primary output of `capture` entry mode for low-stakes or reversible decisions where a full MADR long-form would be over-investment.

- Citation: Olaf Zimmermann and Uwe Zdun, "Y-Statements: A Light Template for Architectural Decision Capturing", published via the Architectural Decision Records community materials (ozimmer.ch / SATURN tutorials, 2018-onward).
- Purpose in `capture` mode: produce a single durable sentence that records the decision and its tradeoff without demanding an options analysis.

## Azure Well-Architected Framework — Architecture Decisions

Microsoft's Azure Well-Architected Framework guidance on architecture decisions emphasizes recording decisions as first-class artifacts, tying each decision to the workload's quality-pillar tradeoffs (reliability, security, cost optimization, operational excellence, performance efficiency), and treating ADRs as living documents that are revisited when drivers change. The `adr-author` skill aligns its ASR trigger taxonomy with these pillars and uses the WAF guidance to frame the Decide-phase tradeoff conversation.

- Source: Microsoft Learn — Azure Well-Architected Framework, "Architecture decision records" guidance.
- License: CC-BY 4.0.
- Attribution: paraphrased and condensed by microsoft/hve-core; original text not reproduced verbatim.

## microsoft/code-with-engineering-playbook — Decision Log

The Microsoft code-with-engineering-playbook documents the team practice of maintaining a per-project decision log (a directory of ADRs) co-located with code, written in plain Markdown, reviewed via pull request, and never deleted. Superseded decisions remain in history with their successor linked, providing a durable record of why the architecture is what it is. The `adr-author` skill's lineage rules (supersedes / superseded-by, immutable history) operationalize this guidance.

- Source: <https://github.com/microsoft/code-with-engineering-playbook>, "Design / Design Reviews / Decision Log" pages.
- License: CC-BY 4.0.
- Attribution: paraphrased and condensed by microsoft/hve-core; original text not reproduced verbatim.

## Cite-Only — Do Not Quote Verbatim

The following sources inform the practice but MUST NOT be embedded verbatim in skill outputs or templates. Reference them by citation only.

- Michael Nygard, "Documenting Architecture Decisions" (2011) — the foundational ADR essay that established the Context / Decision / Status / Consequences shape later refined by MADR.
- IEEE 42010:2022 — "Software, systems and enterprise — Architecture description". Standardizes architecture description elements including architecture decisions and their rationale.
- arc42 §9 — "Architecture Decisions" section of the arc42 documentation template, providing a lightweight rationale-capture pattern complementary to MADR.
- joelparkerhenderson/architecture-decision-record — community catalog of ADR templates and examples. Licensed under CC-BY-SA; embedding text would impose share-alike obligations on hve-core and is therefore prohibited. Cite by URL only.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
