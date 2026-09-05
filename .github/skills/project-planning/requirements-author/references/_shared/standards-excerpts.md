---
description: 'Cite-only registry of third-party standards and community frameworks referenced from the brd-author skill bundle - publisher, edition, year, URL, and a one-sentence original summary per entry; no verbatim text is redistributed'
---

# BRD Author — Cite-Only Standards Excerpts

This registry is the single place the `brd-author` skill bundle points at when it needs to cite a third-party standard or community framework. Every entry follows the same shape: standard name, edition/version, year, publisher, canonical URL, and a one-sentence original Microsoft summary of why the BRD Builder references the source. No prose, tables, definitions, or numbered lists are copied from the cited sources — those are accessed by the reader through the URL.

The registry mirrors the cite-only posture established by the ADR Planner standards anchor and the existing `requirements-definition` and `prioritization-schemes` skill registries: paraphrased summaries are CC-BY 4.0 Microsoft content; the upstream prose remains the property of its rights holders.

## How to use this file

* Cite an entry from a BRD authoring artifact (SKILL.md, template, instruction, agent prompt) by linking to the anchor below, for example [ISO/IEC/IEEE 29148:2018](#isoiecieee-291482018).
* Never copy the upstream definition, clause, or table into the BRD or into any HVE-Core artifact. Cite the standard name and clause number only.
* When a new standard becomes relevant to BRD authoring, add it here first, then reference the new anchor from the artifact that needs it.
* When a standard is superseded (for example, ISO/IEC 25010:2011 → ISO/IEC 25010:2023), update the existing entry in place and note the prior edition in the summary so cross-references still resolve.

## Requirements engineering core

### ISO/IEC/IEEE 29148:2018

* **Publisher** — ISO / IEC / IEEE (joint standard).
* **Edition / year** — Second edition, 2018-11.
* **URL** — [https://www.iso.org/standard/72089.html](https://www.iso.org/standard/72089.html)
* **Why the BRD Builder cites it** — Source standard for the nine individual-requirement quality characteristics (necessary, appropriate, unambiguous, complete, singular, feasible, verifiable, correct, conforming) used by the `requirements-definition` rubric and for the requirements-engineering process vocabulary used in the canonical BRD template.

### IIBA BABOK Guide v3

* **Publisher** — International Institute of Business Analysis (IIBA).
* **Edition / year** — Version 3.0, 2015.
* **URL** — [https://www.iiba.org/standards-and-resources/babok/](https://www.iiba.org/standards-and-resources/babok/)
* **Why the BRD Builder cites it** — Industry reference for the Business / Stakeholder / Solution {Functional, Non-Functional} / Transition requirement classification scheme that the canonical template paraphrases.

### PMI Business Analysis for Practitioners

* **Publisher** — Project Management Institute (PMI).
* **Edition / year** — Second edition, 2024.
* **URL** — [https://www.pmi.org/standards/business-analysis](https://www.pmi.org/standards/business-analysis)
* **Why the BRD Builder cites it** — Reference text for Define-phase elicitation, stakeholder analysis, and traceability practices that the BRD Builder paraphrases in its Discover and Define guidance.

### Karl Wiegers — Software Requirements

* **Publisher** — Microsoft Press (Karl Wiegers and Joy Beatty).
* **Edition / year** — Third edition, 2013.
* **URL** — [https://www.processimpact.com/books.shtml](https://www.processimpact.com/books.shtml)
* **Why the BRD Builder cites it** — Widely cited industry reference for requirement elicitation, classification, and ambiguity heuristics. Used as an external pointer for users who want depth beyond the BRD Builder's in-bundle vocabulary; never paraphrased.

### Volere Requirements Specification Template

* **Publisher** — Atlantic Systems Guild (James and Suzanne Robertson).
* **Edition / year** — Edition 18, 2022.
* **URL** — [https://www.volere.org/templates/volere-requirements-specification-template/](https://www.volere.org/templates/volere-requirements-specification-template/)
* **Why the BRD Builder cites it** — Industry-known requirements specification template offered to readers who want a comparative reference. The HVE-Core canonical BRD template is not derived from Volere; the Volere license is in-organization-use-only and its prose is never redistributed.

## Product quality and testability

### ISO/IEC 25010:2023

* **Publisher** — ISO / IEC.
* **Edition / year** — Second edition, 2023-11 (supersedes ISO/IEC 25010:2011).
* **URL** — [https://www.iso.org/standard/78176.html](https://www.iso.org/standard/78176.html)
* **Why the BRD Builder cites it** — Source standard for the product-quality model whose category names anchor the NFR section of the canonical BRD template and the `requirements-definition` NFR presence rubric.

### ISTQB Glossary of Testing Terms

* **Publisher** — International Software Testing Qualifications Board (ISTQB).
* **Edition / year** — Version 4.5, 2024.
* **URL** — [https://glossary.istqb.org/](https://glossary.istqb.org/)
* **Why the BRD Builder cites it** — Source vocabulary for the testability heuristics in the `requirements-definition` skill. The BRD Builder cites it by entry name only and never copies definitions.

## Prioritization, goal setting, and story quality

### SMART criteria (Doran 1981)

* **Publisher** — *Management Review*, AMA Forum, November 1981.
* **Edition / year** — Original article: George T. Doran, "There's a S.M.A.R.T. way to write management's goals and objectives".
* **URL** — [https://web.archive.org/web/20250908010801/https://community.mis.temple.edu/mis0855002fall2015/files/2015/10/S.M.A.R.T-Way-Management-Review.pdf](https://web.archive.org/web/20250908010801/https://community.mis.temple.edu/mis0855002fall2015/files/2015/10/S.M.A.R.T-Way-Management-Review.pdf)
* **Why the BRD Builder cites it** — Origin of the SMART acronym applied by the `requirements-definition` SMART rubric and by the Business Goals section of the canonical BRD template.

### MoSCoW prioritization

* **Publisher** — DSDM Consortium (now the Agile Business Consortium).
* **Edition / year** — Originated in the Dynamic Systems Development Method, mid-1990s; current treatment in the DSDM Handbook (2014, with periodic updates).
* **URL** — [https://www.agilebusiness.org/dsdm-project-framework/moscow-prioritisation.html](https://www.agilebusiness.org/dsdm-project-framework/moscow-prioritisation.html)
* **Why the BRD Builder cites it** — Origin of the Must / Should / Could / Won't prioritization labels paraphrased in the `prioritization-schemes` skill and used in BRD business-goal and requirement priority fields.

### INVEST checklist (Bill Wake)

* **Publisher** — Bill Wake, [XP123.com](https://xp123.com/).
* **Edition / year** — Originated August 2003; refined in subsequent posts and books.
* **URL** — [https://xp123.com/articles/invest-in-good-stories-and-smart-tasks/](https://xp123.com/articles/invest-in-good-stories-and-smart-tasks/)
* **Why the BRD Builder cites it** — Reference checklist for evaluating user-story-style requirements (Independent, Negotiable, Valuable, Estimable, Small, Testable). Cited from the acceptance-criteria guidance in the canonical BRD template; the prose is never copied.

### Kano model (Kano et al. 1984)

* **Publisher** — *Journal of the Japanese Society for Quality Control*.
* **Edition / year** — Noriaki Kano, Nobuhiko Seraku, Fumio Takahashi, Shinichi Tsuji, 1984.
* **URL** — [https://en.wikipedia.org/wiki/Kano_model](https://en.wikipedia.org/wiki/Kano_model)
* **Why the BRD Builder cites it** — Industry framework for classifying requirements as basic, performance, or delighter. Cited as an optional lens during Define-phase prioritization conversations; not embedded in the rubric.

### RACI responsibility assignment

* **Publisher** — No canonical originating publication; widely documented in PMI, ITIL, and BA literature.
* **Edition / year** — In continuous use since the 1970s; current PMI treatment in the PMBOK Guide (Seventh edition, 2021).
* **URL** — [https://www.pmi.org/learning/library/raci-responsibility-assignment-matrix-tool-7868](https://www.pmi.org/learning/library/raci-responsibility-assignment-matrix-tool-7868)
* **Why the BRD Builder cites it** — Reference framework for the Stakeholders section of the canonical BRD template when a project chooses RACI-style responsibility encoding.

## Acceptance criteria and behavior specification

### Cucumber Gherkin syntax

* **Publisher** — Cucumber Ltd.
* **Edition / year** — Gherkin reference documentation, continuously maintained; current major version aligned with Cucumber 11.x (2024).
* **URL** — [https://cucumber.io/docs/gherkin/reference/](https://cucumber.io/docs/gherkin/reference/)
* **Why the BRD Builder cites it** — Source syntax for Given/When/Then acceptance-criteria formatting used as the default AC style in the canonical BRD template. Cucumber's reference grammar is MIT-licensed; the BRD Builder embeds short literal Given/When/Then placeholders with attribution rather than paraphrasing the grammar.

## Process and decision modeling notation

### OMG BPMN 2.0.2

* **Publisher** — Object Management Group (OMG).
* **Edition / year** — Version 2.0.2, 2014-01.
* **URL** — [https://www.omg.org/spec/BPMN/2.0.2/](https://www.omg.org/spec/BPMN/2.0.2/)
* **Why the BRD Builder cites it** — Reference notation for the Process Models section of the canonical BRD template when users opt into BPMN diagrams. The BRD Builder embeds only diagram fragment placeholders, never the BPMN specification text.

### OMG DMN 1.5

* **Publisher** — Object Management Group (OMG).
* **Edition / year** — Version 1.5, 2023-10.
* **URL** — [https://www.omg.org/spec/DMN/1.5/](https://www.omg.org/spec/DMN/1.5/)
* **Why the BRD Builder cites it** — Reference notation for decision tables and decision requirements diagrams when a BRD's Business Rules section uses DMN.

### OMG UML 2.5.1

* **Publisher** — Object Management Group (OMG).
* **Edition / year** — Version 2.5.1, 2017-12.
* **URL** — [https://www.omg.org/spec/UML/2.5.1/](https://www.omg.org/spec/UML/2.5.1/)
* **Why the BRD Builder cites it** — Reference notation for use-case diagrams and class-style structural diagrams when a BRD's Scope or Process Models section uses UML.

### C4 Model (Simon Brown)

* **Publisher** — Simon Brown / Structurizr.
* **Edition / year** — Continuously published; current model documented at the URL below.
* **URL** — [https://c4model.com/](https://c4model.com/)
* **Why the BRD Builder cites it** — Reference notation for system-context and container diagrams sometimes used in the Scope section of a BRD. The C4 site content is CC-BY 4.0; the BRD Builder still cites by name rather than embedding upstream prose so the registry remains attribution-free at the artifact level.

## Cite-only contamination guard

The following two community resources are widely referenced when discussing BRD authoring, but their content is published under copyleft licenses (CC BY-SA 4.0) and is therefore subject to strict cite-only handling in this repository. They appear here so authors know they exist and can compare independently, not to be paraphrased or embedded.

### arc42

* **Publisher** — Dr. Peter Hruschka, Dr. Gernot Starke, and contributors.
* **Edition / year** — Version 8, 2022 (template); ongoing.
* **URL** — [https://arc42.org/](https://arc42.org/)
* **Why the BRD Builder cites it** — Industry-known architecture-documentation template. Listed for awareness; the BRD Builder never paraphrases arc42 prose because of the CC-BY-SA license.

## License

This file is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Every entry above cites a third-party source by name, edition, year, publisher, and URL. The cited works remain the property of their respective rights holders and are not redistributed through this registry.


