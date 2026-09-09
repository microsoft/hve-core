---
title: evaluation-design provenance and licensing posture
description: Source map, licensing determination, and currency posture for external evaluator vocabulary referenced by this skill
---

## Package licensing

This package declares `CC-BY-4.0`. All prose, the interview structure, the distribution defaults, the dataset contract, the review protocol, and the document skeletons are repository-original HVE Core content.

No upstream text, table, schema, or example is reproduced in this package. Because no upstream expression is redistributed, the package remains solely CC BY 4.0 and requires no `THIRD-PARTY-NOTICES` entry.

## Source map

| Referenced material                                                                              | Source                                                                                                                                           | Posture                                                                                                                     |
|--------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------|
| Agent evaluator names and their broad grouping into outcome, step, and response-quality concerns | Microsoft Foundry agent evaluators documentation, <https://learn.microsoft.com/azure/ai-foundry/concepts/evaluation-evaluators/agent-evaluators> | Cite-only. Names are used as factual identifiers. Definitions are paraphrased into repository guidance; none are reproduced |
| Managed low-code agent evaluation surface                                                        | Microsoft Copilot Studio agent evaluation documentation                                                                                          | Cite-only. Referenced by capability, not by reproduced text                                                                 |

Retrieved 2026-08-05.

## Licensing determination

The referenced vendor documentation is published under the Microsoft Terms of Use rather than an open content license. It is therefore treated as cite-only under the repository licensing posture: link to the official page, paraphrase where explanation is needed, and reproduce nothing.

Evaluator names themselves are preserved as written because identifiers are facts rather than licensed prose. This is the same treatment the repository applies to standards clause numbers and control identifiers.

## Currency posture

The external evaluator catalog is versioned and changes between platform releases. At the retrieval date above, several evaluators were marked preview, some carried constrained support depending on which tools an agent uses, and the response-quality evaluators had been reorganized under a combined grader.

Two consequences follow, and both are deliberate design choices in this skill:

* This package does not freeze an evaluator list into a lookup table. A frozen list silently decays and then misinforms, which is precisely the failure mode observed in the material this skill replaces.
* [metric-selection-and-tooling.md](metric-selection-and-tooling.md) instructs the reader to confirm current evaluator names and availability against the authoritative source and to record the date checked.

The upstream page carries a notice that it was authored with AI assistance. Treat it as the authoritative statement of what the platform currently offers, not as an independent specification.
