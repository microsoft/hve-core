---
title: ds-catalog provenance and standards posture
description: Source selection, licensing, and non-conformance boundaries for the native data catalog contract
---

## Native contract decision

The contract is independently authored for engagement discovery. No surveyed publication, contract, or lineage format can represent declared inter-entity cardinality together with evidence confidence, access-confirmation state, and engagement coverage. Binding to one would discard or side-channel the facts that keep uncertain discovery work honest.

## Standards use

Each entry names the upstream source, how this package uses it, and the posture that keeps the use non-binding.

* [W3C DCAT 3](https://www.w3.org/TR/vocab-dcat-3/) supplies the non-binding catalog and relationship crosswalk. W3C concepts are paraphrased with official links and no RDF or conformance claim is made.
* [W3C PROV-O](https://www.w3.org/TR/prov-o/) supplies the crosswalk for derivation and generation. Concepts are paraphrased with official links and no PROV conformance claim is made.
* [DCMI Metadata Terms](https://www.dublincore.org/specifications/dublin-core/dcmi-terms/) supplies crosswalk term identifiers for title, description, and coverage. Term identifiers are cited as facts and no DCMI conformance claim is made.
* [Frictionless Table Schema v2](https://datapackage.org/standard/table-schema/) is evidence that paired arrays are an established representation of composite keys. Only the structural concept is used; no schema is vendored and no conformance claim is made.
* [`privacy-standards`](../../../project-planning/privacy-standards/SKILL.md) supplies the binding citation-field names for privacy mappings. It is the repository authority, and this package does not reproduce its standards content.
* Microsoft Fabric ontology and [Datasheets for Datasets](https://arxiv.org/abs/1803.09010) inform product and interview framing only. Neither creates a schema field or a conformance obligation.

Croissant is not used as a contract because it is ML-dataset scoped and its specification is CC BY-ND 4.0. OpenLineage is not used because it models runtime events. Open Data Contract Standard is not used because it represents producer-consumer commitments rather than uncertain discovery assertions.

## License

Every file in this package is repository-original content licensed CC BY 4.0. The package declares `CC-BY-4.0` and nothing else.

External specifications are cited by name, official URL, and term identifier. Standard names and term identifiers are facts rather than licensed prose, the crosswalk explanations and the paired-array join-key contract are independently authored, and no upstream schema, example, table, figure, or substantial excerpt is reproduced.

The cited sources carry their own terms: W3C DCAT 3 and PROV-O are published under the W3C Document License, DCMI Metadata Terms under CC BY 4.0, and Frictionless Table Schema under the Unlicense. Those terms govern the upstream documents, not this package. Introducing copied or adapted upstream expression would require a compound license declaration and a matching `THIRD-PARTY-NOTICES` entry, so paraphrase remains the required posture.
