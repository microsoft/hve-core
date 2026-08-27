---
title: Feasibility Study Interchange Profile standards crosswalk
description: Non-binding mappings to selected SpecIF, OSLC RM, PROV, and DCMI concepts
---

## Mapping posture

The profile is standards-aligned, not externally conformant. SpecIF is the closest structural reference, OSLC RM supplies selected relation meanings, PROV and DCMI supply provenance and revision vocabulary, and RFC 9562 supplies UUID syntax. The payload does not implement the full required model or service behavior of any source.

| Profile concept                                      | Nearest source concept                   | Mapping note                                                                 |
|------------------------------------------------------|------------------------------------------|------------------------------------------------------------------------------|
| Item concept and class                               | SpecIF Resource and ResourceClass        | Selective structural alignment; no SpecIF payload or schema claim            |
| Typed relation record                                | SpecIF Statement and StatementClass      | Profile adds confidence, rationale, provenance, and review state             |
| Independent narrative placement                      | SpecIF hierarchy node                    | Markdown anchor is presentation, not identity                                |
| Revision registry                                    | SpecIF revision and replacement lineage  | Local immutable registry and never-reuse rules are profile-owned             |
| `satisfies`, `implements`, `constrains`, `validates` | OSLC RM relation meanings                | Reused only where the profile meaning is exact                               |
| `depends-on`, split, merge, derivation               | Profile-owned relation meanings          | No external-conformance implication                                          |
| `revision_of`                                        | PROV `wasRevisionOf`; DCMI `isVersionOf` | Descriptive mapping; local validator enforces closure and acyclicity         |
| `derived-from`                                       | PROV `wasDerivedFrom`; DCMI `source`     | Records lineage without asserting truth or approval                          |
| `supersedes` and successor state                     | DCMI `replaces` and `isReplacedBy`       | Local tombstone policy supplies retention and completeness                   |
| `attributed_to`                                      | PROV attribution                         | Actor label remains local and need not be a PROV Agent resource              |
| Concept and revision UUID URNs                       | RFC 9562 UUID and UUID URN syntax        | UUID syntax does not replace application-level never-reuse governance        |
| Local schema                                         | JSON Schema Draft 2020-12                | Validates this profile only; SpecIF v1.1 uses a different schema and dialect |

## False-conformance boundaries

* A static Markdown file is not an OSLC RM service.
* A selective JSON-shaped projection is not a SpecIF v1.1 payload.
* UUID URN syntax does not establish a managed URN namespace.
* Using provenance terms does not make the study a PROV dataset.
* Using DCMI mappings does not make the study a DCMI application profile.
* The profile is not ReqIF XML and does not claim ReqIF interchange compatibility.

## Sources

* SpecIF, [Specification Integration Facility](https://specif.de/)
* OASIS, [OSLC Requirements Management 2.1](https://docs.oasis-open-projects.org/oslc-op/rm/v2.1/os/)
* W3C, [PROV-O](https://www.w3.org/TR/prov-o/) and [PROV-DM](https://www.w3.org/TR/prov-dm/)
* DCMI, [Metadata Terms](https://www.dublincore.org/specifications/dublin-core/dcmi-terms/)
* IETF, [RFC 9562 UUIDs](https://www.rfc-editor.org/rfc/rfc9562.html)
* JSON Schema, [Draft 2020-12](https://json-schema.org/draft/2020-12/)
