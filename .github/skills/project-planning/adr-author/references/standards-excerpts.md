---
title: ADR Standards Excerpts
description: Curated external standards excerpts and citations supporting the adr-author skill, with license attribution
author: microsoft/hve-core
ms.date: 2026-08-23
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

Markdown Any Decision Records (MADR) is a lean ADR template optimized for collaboration in Markdown. Version 4.0.0 defines the canonical frontmatter (status, date, decision-makers, consulted, informed) and the section structure (Context and Problem Statement, Decision Drivers, Considered Options, Decision Outcome, Consequences, Confirmation, Pros and Cons, More Information) that the `adr-author` skill produces when `state.outputTemplate` is `madr-v4`. The template is released under CC0-1.0 Universal Public Domain Dedication and may be reproduced byte-identical without modification.

- Upstream: <https://github.com/adr/madr> (tag `4.0.0`, file `template/adr-template.md`).
- License: CC0-1.0.
- Verbatim template: `../templates/madr-v4.md` (this reference file does not duplicate it).

## Y-Statement

The Y-Statement is a six-slot single-sentence decision capture formula authored by Olaf Zimmermann and Uwe Zdun. It captures the use case, concern, chosen option, rejected alternatives, target quality, and accepted downside in HVE's own wording. The `adr-author` skill produces one when `state.outputTemplate` is `y-statement`, regardless of entry mode.

- Citation: [Olaf Zimmermann, "Y-Statements"](https://medium.com/olzzio/y-statements-10eb07b5a177), based on work with Uwe Zdun.
- Purpose: produce a single durable sentence that records a low-stakes or reversible decision and its tradeoff without requiring MADR long-form output.

## Azure Well-Architected Framework: Architecture Decisions

Microsoft's Azure Well-Architected Framework guidance treats ADRs as an append-only log. Records capture context, alternatives, rationale, tradeoffs, status, and consequences; changed decisions supersede rather than rewrite accepted records.

- Source: [Microsoft Learn, "Maintain an architecture decision record (ADR)"](https://learn.microsoft.com/azure/well-architected/architect-role/architecture-decision-record).
- License: CC-BY 4.0.
- Attribution: paraphrased and condensed by microsoft/hve-core; original text not reproduced verbatim.

## microsoft/code-with-engineering-playbook: Decision Log

The Microsoft code-with-engineering-playbook recommends storing ADRs in version control and reviewing proposed records through pull requests. It also defines ADR statuses and links superseded records to their replacements.

- Source: [Microsoft code-with-engineering-playbook, "Design Decision Log"](https://microsoft.github.io/code-with-engineering-playbook/design/design-reviews/decision-log/).
- License: CC-BY 4.0.
- Attribution: paraphrased and condensed by microsoft/hve-core; original text not reproduced verbatim.

## Cite-Only Sources

The ADR standards contract treats the following sources as citation-only. Do not embed their text in skill outputs or templates.

- [Michael Nygard, "Documenting Architecture Decisions" (2011)](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions), the foundational ADR essay that established the Context / Decision / Status / Consequences shape later refined by MADR.
- ISO/IEC/IEEE 42010:2022, "Software, systems and enterprise — Architecture description". ISO catalog: <https://www.iso.org/standard/74393.html>. Cite only; do not quote.
- [arc42 section 9, "Architecture Decisions"](https://docs.arc42.org/section-9/), a lightweight rationale-capture pattern complementary to MADR.
- [architecture-decision-record/architecture-decision-record](https://github.com/architecture-decision-record/architecture-decision-record), a community catalog of ADR templates and examples. Cite rather than reproduce its collected content.