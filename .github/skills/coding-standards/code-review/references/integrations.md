---
description: 'Conditional business alignment, security-plan correlation, and specialist routing for Code Review.'
---

# Conditional review integrations

Load the relevant section only when its input exists. These comparisons use
the captured review surface and the owning capability's criteria; they do not
start another review lane or widen source-write authority.

## Business alignment

Use supplied BRD, PRD, or ADR context after resolving it. Discover additional
context from PR/linked-issue text, changed files in the folder containing
`.adr-config.yml`, and changed files whose base-revision frontmatter has
`brd_id` or `prd_id`. For genuinely new sources use current frontmatter.
Run one bounded search of the folder containing `.adr-config.yml` and the
repository's files with `brd_id` or `prd_id` frontmatter for changed paths and
component names; prefer matching ADR `affected_components`. Record search locations,
terms, citation, source identity, and provenance.

Accept only repository-contained paths that identify a business source.
Resolve ADR IDs to their numbered file and BRD/PRD IDs to matching frontmatter.
Unresolved or outside paths remain unresolved. Confirm discovered sources with
the human before using them. Host-managed runs use only explicitly supplied
sources and never silently adopt discovered ones.

Read the `rpi-review` skill's bundled `references/business-alignment.md` for its
Shared core, Business alignment, Product alignment, and Decision alignment
sections. Do not run its RPI-only workflow. That reference owns the evidence
rule, severity rubric, alerts, source-update routing, and note format.

### Baseline and supersession

Resolve supersession at the base revision, following every listed successor
until current. Keep the original citation and path. A successor or link added by
the PR is a proposed source update; it cannot redirect the comparison.
Unresolved successors remain gaps, and the original source still receives its
stale-source assessment.

Compare modified sources against the base-revision text. For an unreadable base:

* Use removed lines for each recoverable pre-change passage, recording baseline
  `diff`, including deleted sources.
* Added-only passages are proposed updates with baseline `unavailable`; edited
  current text cannot clear drift.
* Read current metadata or passages only when captured evidence proves they
  were unchanged, recording baseline `head`.
* Cap owner awareness at developer-confirmed for fallback passages.

A genuinely new source is compared at head; a new ADR is proposed for stake and
its drift is developer-confirmed. If a necessary source, delivered behavior,
or differing element is missing, record unassessed `possible-drift` with a reason,
no severity, and no finding ID. Never turn that gap into a rated defect.

### Synthesis and owner decisions

Compare before final synthesis. Add supported drift and the rubric's stale-source
or source-gap alerts through the core's parent `assess` operation under the
relevant existing work item, then verify/decide them like other findings.
Use captured changed-behavior anchors and cite the source/requirement in
`criterion`; do not fabricate source positions. Assessed findings affect the
same severity-to-verdict calculation.

Store `context.businessAlignment` with source ID/type/path, status, owners or
deciders, baseline, original citation, and per-result kind, requirement IDs,
stake, awareness, outcome change, finding ID, evidence, and unresolved sources.
Keep stakeholder notes separate in `context.stakeholderNotes`.

An in-PR source edit or a developer-controlled approval claim is
developer-confirmed. Record a claimed owner acknowledgment as unverified.
Only a human reviewer can confirm the owner's acknowledgment; record who
confirmed it and when, then re-rate using the shared rubric through the parent's
finding decision. Do this before the final compact summary and posting decision.
Host-managed automation never grants owner-acknowledged status.

For actual drift, recommend the System Architecture Reviewer and the owning
BRD/PRD revision or superseding-ADR workflow. Do not edit the source. Offer a
local copy-ready stakeholder note for retained Critical/High drift, writing it
only when accepted. A declined note does not close the finding. Host-managed
runs record the offer as a follow-up. Neither notes nor owner claims become
posted comments or automatic outbound actions.

## Security Plan Drift

Use an explicit baseline reference or a discovered candidate from the change,
PR context, or a co-located plan with a security signal. Confirm discovered
baselines; never select among them by recency. Defer correlation until the
security perspective has completed and the parent has accepted its findings.

Activate `security-planning` for its drift capability. Read its drift input
contract and the confirmed baseline state, then the plan named by that state.
Map accepted findings to Form C, retaining identity, producer, severity,
location, evidence, status, and uncertainty. Store the result under
`context.securityPlanDrift` and apply the owning skill's disclaimer and
exclusions.

Diff-scoped findings cannot establish validated controls or prove plan items
obsolete from absence. Preserve insufficient-evidence results and incomplete
baseline fields. If the capability, baseline, or required location is missing,
disclose the limitation and leave the rest of the review intact. An executed
correlation is not also a specialist referral.

## Other specialists

Privacy, performance, supply chain, and responsible AI have added reviewers that
run inside the review, as the `code-review` skill's Scope and depth section
describes; suggest those first. Each names a deeper follow-up for a full audit
beyond the captured change.

For other concerns, or for that deeper audit, recommend specialist work only
when changed-surface signals support it and the runtime exposes a relevant
capability. Name the concern, evidence, capability, and reason for a separate
follow-up; avoid a fixed catalog. Missing capabilities remain explicit.
Production telemetry criteria come from `telemetry-foundations`. No referral
grants permission for installs, broader audits, or source edits.
