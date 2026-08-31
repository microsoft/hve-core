---
description: 'Cite-only pointer to MoSCoW prioritization - names the four-bucket technique (Must / Should / Could / Won''t-this-time) and its DSDM origin, links to the upstream publisher, and does not redistribute upstream prose'
---

# MoSCoW Prioritization - Cite-Only Pointer

This document is a cite-only pointer. It names the MoSCoW prioritization technique and the four-bucket structure the BRD Builder workflow references, links to the upstream publisher, and does not redistribute upstream prose.

## What MoSCoW Is

MoSCoW is a four-bucket prioritization technique authored by Dai Clegg in the 1990s and adopted as a core technique of the Dynamic Systems Development Method (DSDM), now maintained by the Agile Business Consortium. The acronym names the four buckets: Must-have, Should-have, Could-have, and Won't-have-this-time. The "o"s are filler letters to make the acronym pronounceable.

The technique is applied against a defined time-box (typically a release, increment, or fixed delivery window). Items are categorized relative to that time-box, not absolutely. "Won't-have-this-time" explicitly defers an item to a later time-box rather than rejecting it permanently.

The BRD Builder references MoSCoW by name as its default prioritization scheme. Stakeholders see the four bucket names in the prioritization section of the BRD; the BRD Builder does not redistribute DSDM's full technique description, examples, or governance prose.

## Why Cite-Only

The MoSCoW acronym, the four-bucket structure, and the technique name are widely used industry terminology that the BRD Builder can reference by name. DSDM's full technique description and governance guidance are published by the Agile Business Consortium on their site under their own terms and are not redistributed here.

The BRD Builder's posture is:

* Reference MoSCoW by name when the BRD prioritization section is being authored or assessed.
* Use the four bucket names (Must / Should / Could / Won't-this-time) in BRD templates without quoting DSDM's bucket-definition prose.
* Link to the upstream DSDM page when a stakeholder wants the canonical technique description.

## Upstream Source

[https://www.agilebusiness.org/dsdm-project-framework/moscow-prioririsation.html](https://www.agilebusiness.org/dsdm-project-framework/moscow-prioririsation.html) (accessed 2026-05-25) - the DSDM Agile Project Framework page describing the MoSCoW prioritization technique, maintained by the Agile Business Consortium.

## How the BRD Builder Uses MoSCoW

The BRD Builder applies MoSCoW under the following operating rules, which are original Microsoft synthesis informed by the scheme selector in [prioritization-schemes.md](prioritization-schemes.md):

* Every BRD prioritization section that declares MoSCoW must also declare the time-box the categorization applies to (release, increment, or fixed delivery window).
* "Must" is reserved for requirements without which the time-box's deliverable has no usable value; the assessor flags Must-inflation when more than approximately 60% of items land in this bucket.
* "Won't-this-time" must record the next forum or time-box at which the item is reconsidered, so deferred items do not silently disappear.
* When stakeholders are unsure between Must and Should, the default is Should; promoting to Must requires recorded justification.

## License

This pointer file is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The MoSCoW technique and DSDM framework are the property of the Agile Business Consortium and the original authors and are subject to their own terms at the upstream source.


