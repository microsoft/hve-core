---
title: Ontology semantic profile
description: Conservative RDF, RDFS, OWL, and SHACL profile for release-one ontology packages
ms.date: 2026-09-01
ms.topic: reference
---

## Authority model

`ontology.ttl` is the sole semantic authority. `shapes.ttl` contains validation
constraints. Evidence, mappings, examples, reports, and sampled instances do
not add authoritative ontology assertions.

The runtime validates supplied local content without fetching remote resources.

## Permitted ontology constructs

Release one permits these declaration and documentation constructs:

* `rdf:type`
* `rdf:Property`
* `rdfs:Class`
* `rdfs:subClassOf`
* `rdfs:subPropertyOf`
* `rdfs:domain`
* `rdfs:range`
* `rdfs:label`
* `rdfs:comment`
* `owl:Class`
* `owl:ObjectProperty`
* `owl:DatatypeProperty`
* `owl:AnnotationProperty`
* `owl:deprecated`

Literal ranges use explicit XML Schema datatypes. Language-bearing labels and
comments use valid language tags where applicable.

## Constraint ownership

SHACL owns closed-world validation rules, including required values, cardinality,
allowed values, string patterns, numeric bounds, node kinds, classes, datatypes,
and cross-property conditions supported by the release-one validator.

The ontology does not reinterpret SHACL constraints as OWL axioms. A passing
SHACL report establishes conformance to the selected constraints, not logical
completeness.

## Prohibited ontology features

Release one rejects:

* `owl:imports`
* `owl:sameAs`
* `owl:equivalentClass` and `owl:equivalentProperty`
* Property chains, keys, restrictions, and class-expression constructors
* Disjointness, complements, unions, and intersections
* Rule languages, JavaScript constraints, and SHACL rules
* Remote contexts, remote graphs, and service endpoints
* Automatic vocabulary alignment

Candidates for equivalence or alignment remain provenance-bearing unresolved
records until a future profile explicitly supports them.

## Processing mode

Inference is disabled. Validation and comparison operate on asserted triples.
No parser, validator, query, or serializer may dereference an IRI, process an
import, contact a SPARQL service, or read an unapproved secondary file.

SPARQL competency checks are optional and run only against the supplied local
graph when an approved expected outcome exists. They do not mutate the graph.

## Serialization and comparison

Turtle byte order is not authoritative. Semantic comparison parses local graphs
and compares RDF statements. Blank-node handling must be deterministic or use a
canonical comparison strategy before a package can claim zero semantic change.

## Sources

The profile is repository-original guidance informed by the following W3C
specifications. It paraphrases their concepts and does not reproduce normative
text.

* [RDF 1.1 Concepts and Abstract Syntax](https://www.w3.org/TR/rdf11-concepts/)
* [RDF Schema 1.1](https://www.w3.org/TR/rdf-schema/)
* [OWL 2 Web Ontology Language Overview](https://www.w3.org/TR/owl2-overview/)
* [Shapes Constraint Language](https://www.w3.org/TR/shacl/)
