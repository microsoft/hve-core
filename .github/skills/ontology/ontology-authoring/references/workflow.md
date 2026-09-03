---
title: Ontology authoring workflow
description: Resumable coaching, approval, state, and deterministic execution contract for ontology authoring
ms.date: 2026-09-02
ms.topic: reference
---

## Outcome

The workflow produces an evidence-grounded, approved, and locally validated
ontology package. It preserves enough durable state to resume without treating
chat history as authority. Deployment remains outside this workflow.

## Invocation modes

Direct skill invocation and parent-agent invocation use the same phases, gates,
state transitions, and outputs.

In direct mode, the skill asks the operator questions and recommends the next
eligible action. In parent-coordinated mode, the parent carries the questions and
responses between the operator and this workflow, then consumes the returned
state summary. The parent cannot approve on the operator's behalf.

## Initialize or resume

Resolve one project slug and its validated project root before any write.

For a new project:

1. Create schema version `1.0.0` state in phase `research`.
2. Set each context field to pending, keep source inventory and evidence empty,
   and initialize Research, Design, and Implement gates as pending.
3. Set the Deploy handoff to deferred with target `033 Fabric Ontology Edge AI
   Agent`.
4. Persist state atomically, then report the context questions.

For an existing project:

1. Read and validate state before using any value from it.
2. Refuse traversal, symlink escape, an unknown schema version, malformed state,
   or a project identity mismatch.
3. Recompute or verify recorded input digests before trusting an approval.
4. Resume at the earliest pending, rejected, or stale gate. Do not skip ahead
   because later artifacts happen to exist.

State reads and writes are permitted before context confirmation. Source
inventory, file reads for evidence, parsing, extraction, and generation are not.

## Confirm business context

Infer provisional answers only from the current conversation and text the
operator deliberately pasted into it. Do not inspect a path to improve an
inference.

Present the five fields in one reviewable batch:

* Business activity being represented
* Purpose and expected value of the ontology
* Included domain scope and explicit exclusions
* Intended users and the decisions or tasks it supports
* Approved local source boundary

Mark inferred text as provisional. Ask focused follow-ups only for fields that
remain ambiguous, contradictory, or too broad to enforce. Then present the full
batch again and request explicit confirmation.

Confirmation is valid only when the operator affirmatively confirms all five
fields. Persist the confirmer attribution, timestamp, and current input digest.
An edit to any field returns context to pending and keeps source and evidence
operations denied until reconfirmed.

## Deterministic call boundary

Every deterministic capability validates its inputs and project path. Calls
must follow this order:

1. State initialize, read, validate, reduce, and atomic write
2. Context confirmation write
3. Safe source inventory
4. Supported adapter extraction into normalized evidence
5. Cross-record evidence integrity validation
6. Approved Design compilation into package artifacts
7. Syntax, SHACL conformance, semantic-policy, and applicable competency checks
8. Semantic diff and failure-closed finalization

Steps 3 through 8 are prohibited while context is pending. Steps 6 through 8
also require approved Research and Design gates. Finalization requires approved
Implement inputs and current reports.

When a required capability has not yet been implemented, stop at that call,
record it as unavailable, and preserve the next resumable action. Do not replace
the result with model-generated claims.

## State mutation rules

Validate every proposed state mutation against the Ontology Builder State Schema
before atomically replacing the prior file.

Each material record carries stable identity, timestamp, attribution, and source
or input-digest provenance. Record operator statements, model suggestions,
decisions, unresolved candidates, approvals, artifacts, and reports in their
separate state collections.

When an approved gate input changes:

1. Mark that gate stale with the changed input and reason.
2. Mark every downstream approval and gate stale.
3. Set downstream invalidation state before regenerating any artifact.
4. Resume at the earliest stale gate.

Byte-equivalent evidence and report-only regeneration do not invalidate a gate.
They may update report timestamps and checksums when semantic inputs remain
unchanged.

## Research phase

Research starts only after confirmed context.

1. Inventory the approved source boundary and report every skipped or unsupported
   item with its reason.
2. Normalize supported evidence without making semantic assertions.
3. Review provenance, limitations, extraction status, and confidence with the
   operator.
4. Coach the operator to identify vocabulary, relationships, questions,
   ambiguities, disagreements, rights concerns, and evidence gaps.
5. Produce a Research design brief that separates evidence, operator decisions,
   and unresolved model candidates.
6. Present the brief and its input digests for explicit approval.

An approval advances state to `design`. Rejection records rationale and keeps the
Research gate rejected. Changed evidence makes the approval stale.

## Design phase

Design translates the approved brief into an implementable ontology
specification without generating approved RDF.

1. Define competency questions and measurable expected outcomes where evidence
   supports them.
2. Select and approve an absolute base IRI.
3. Define classes, properties, labels, aliases, mappings, constraints, examples,
   and stable term IDs with provenance.
4. Apply the identity policy and conservative semantic profile.
5. Keep uncertain alignments, inferred relationships, and unsupported terms in
   candidates rather than the approved specification.
6. Record alternatives, disagreements, decisions, rights, and limitations.
7. Present the ontology specification, semantic policy, and input digests for
   explicit approval.

An approval advances state to `implement`. Rejection retains Design for revision.
A change to the approved brief, namespace, or specification makes Design and all
downstream state stale.

## Implement phase

Implement compiles approved Design state. It does not add concepts or settle
unresolved decisions.

1. Generate `ontology.ttl` as semantic authority and `shapes.ttl` as constraint
   authority.
2. Generate mappings and any approved, non-authoritative sampled instances.
3. Preserve candidates outside approved graphs.
4. Run syntax, SHACL conformance, semantic-policy, and applicable competency
   checks against supplied local content with inference and network access
   disabled.
5. Build provenance, rights, decision, approval, and no-deployment records.
6. Compare the resulting graph and evidence records with the approved baseline.
7. Assemble the complete package manifest and verify every required or applicable
   role, authority label, checksum, and approval digest.
8. Present the semantic diff, reports, limitations, and package for explicit
   Implement approval.

Any failed or missing prerequisite blocks finalization. Approval advances state
to `deploy-handoff`; rejection retains Implement for revision. A changed Design
input makes generated artifacts and the Implement gate stale.

## Deferred Deploy handoff

Deploy is not executed. After current Implement approval:

1. Set `deployHandoff.status` to `ready`.
2. Retain target `033 Fabric Ontology Edge AI Agent`.
3. Emit package location, digest, approvals, validation summary, unresolved
   limitations, and no-deployment attestation.
4. Stop without invoking the target or claiming operational readiness beyond the
   validated local package.

## Coaching behavior

Ask small batches of questions tied to the current gate. Explain material
trade-offs, distinguish source evidence from interpretation, and make
disagreement visible. Prefer concrete examples from confirmed evidence, but do
not reopen source files when normalized evidence is sufficient.

The operator owns business meaning and every approval. The skill may propose,
compare, challenge, and summarize. It cannot silently resolve ambiguity,
manufacture expected answers, or infer acceptance from continued conversation.

## Stop responses

When stopped, return:

* Project and current phase
* Context status and missing confirmation fields
* Research, Design, Implement, and Deploy handoff statuses
* Last successful deterministic capability
* Missing, failed, rejected, or stale prerequisite
* Artifacts and reports currently valid
* Unresolved decisions and candidates
* Exact next eligible action

Never describe a coaching draft as a deterministic result or a pending gate as
approved.

## Completion response

Completion requires current Implement approval, a complete manifest, passing or
explicitly not-applicable reports, a package digest, and a no-deployment
attestation. Return the package and report locations, semantic change summary,
approval identities and timestamps, known limitations, and the ready deferred
handoff. State plainly that deployment did not occur.
