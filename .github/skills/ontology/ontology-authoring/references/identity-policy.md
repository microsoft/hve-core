---
title: Ontology identity policy
description: Stable namespace and term identity rules for ontology authoring
ms.date: 2026-09-01
ms.topic: reference
---

## Purpose

Semantic identity must remain stable after approval. Labels, descriptions, and
other presentation metadata may evolve, but approved identifiers do not change
silently.

## Base IRI approval

The operator supplies an absolute base IRI during Design. A named role owner
approves it before any term receives an approved IRI.

An acceptable base IRI:

* Uses an absolute `http` or `https` IRI
* Ends with `/` or `#` so term IRIs can be formed unambiguously
* Has an approval record tied to the current Design inputs
* Is not replaced while approved terms still depend on it

A draft, rejected, or stale namespace cannot produce an approved ontology.

## Term identity

Each term has a stable term ID and one approved absolute IRI. The term ID tracks
the concept through review; the IRI identifies it in RDF.

After approval:

* Label, comment, and alias changes preserve the IRI
* Case, spelling, and punctuation edits do not create a new IRI
* Regeneration from a label or source column is prohibited
* Two stable term IDs cannot share one current IRI
* One stable term ID cannot acquire a different current IRI silently

Deterministic validation compares the current identity index with the last
approved index. It rejects duplicate current IRIs and unapproved IRI changes.

## Aliases

Aliases improve discovery without creating additional semantic identities.
Every alias points to one stable term ID and preserves the term's approved IRI.
An alias cannot redirect one term ID to another.

## Deprecation and replacement

Removing an approved IRI is prohibited. A retired concept remains in the
ontology as deprecated.

A replacement requires:

* A separate approved term with its own stable IRI
* An explicit replacement relationship from the deprecated term
* A named approver, rationale, approval timestamp, and current input digests
* A decision record that explains whether meaning was narrowed, broadened, or
  otherwise changed

The old and replacement IRIs remain distinct. Replacement does not authorize
rewriting historical evidence.

## Collision and change checks

Generation stops when any of these conditions is present:

* The base IRI is not approved
* A term IRI is relative or outside the approved namespace
* Distinct stable term IDs share a current IRI
* A stable term ID changes IRI without an approved replacement transition
* A deprecated term names itself as its replacement
* A replacement target lacks approval
* An approved term disappears from the identity index

## Sources

The policy uses repository-original rules informed by the RDF 1.1 Concepts and
OWL 2 Overview specifications. The specifications remain authoritative for RDF
and OWL syntax and semantics.

* [RDF 1.1 Concepts and Abstract Syntax](https://www.w3.org/TR/rdf11-concepts/)
* [OWL 2 Web Ontology Language Overview](https://www.w3.org/TR/owl2-overview/)
