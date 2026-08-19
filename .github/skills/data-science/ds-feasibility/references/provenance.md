---
title: ds-feasibility provenance and licensing posture
description: Source mapping, independent authorship, licensing, and non-conformance statement for the feasibility profile
---

## Independent profile

The Feasibility Study Interchange Profile is repository-original content under CC BY 4.0. Its schema, field names, lifecycle policy, constrained-YAML rules, validator, fixtures, and producer workflow were authored independently for this repository.

No upstream schema, sample payload, table, or substantial prose is vendored. External concepts are paraphrased and mapped at the level needed to explain interoperability intent.

## Source posture

| Source                                                                                   | Use                                                       | License and treatment                                                                  |
|------------------------------------------------------------------------------------------|-----------------------------------------------------------|----------------------------------------------------------------------------------------|
| [SpecIF](https://specif.de/)                                                             | Structural alignment for resources, statements, revisions | Public specification cited and paraphrased; no copied schema or conformance claim      |
| [OSLC RM 2.1](https://docs.oasis-open-projects.org/oslc-op/rm/v2.1/os/)                  | Selected exact relation meanings                          | OASIS specification cited and paraphrased; no static-file or service conformance claim |
| [W3C PROV](https://www.w3.org/TR/prov-o/)                                                | Provenance, derivation, revision, attribution             | W3C concepts cited and paraphrased; no PROV conformance claim                          |
| [DCMI Metadata Terms](https://www.dublincore.org/specifications/dublin-core/dcmi-terms/) | Source, version, and replacement mappings                 | Terms cited and paraphrased; no DCMI conformance claim                                 |
| [RFC 9562](https://www.rfc-editor.org/rfc/rfc9562.html)                                  | UUID and UUID URN syntax                                  | IETF standard cited for identifier syntax                                              |
| [JSON Schema 2020-12](https://json-schema.org/draft/2020-12/)                            | Local structural validation dialect                       | Public specification cited; local schema is independently authored                     |
| [YAML 1.2.2](https://yaml.org/spec/1.2.2/)                                               | Source syntax bounded to JSON-compatible values           | Public specification cited; no YAML text reproduced                                    |

ReqIF is retained only as a possible future generated export target. JSON-LD and managed URN namespaces are deferred until a concrete consumer requires them.

