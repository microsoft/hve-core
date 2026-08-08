---
title: Data Classification and Retention Guidance
description: Public-safe taxonomy hints for asset classification, sensitivity, and retention metadata in threat-model specs.
ms.date: 2026-08-05
ms.topic: reference
---

# Data Classification and Retention Guidance

This reference captures a public-safe, vendor-neutral vocabulary for optional
classification hints used by threat-model specifications. It is intentionally
lightweight and policy-driven so teams can adapt it to their own review process
without relying on internal taxonomies or proprietary labels.

## Public-safe guidance

Use these hints as annotations rather than enforcement rules. The goal is to make
threat models understandable to reviewers across organizations while preserving a
pluggable policy layer for local implementation details.

## Sensitivity hints

Use `assets[].sensitivity` and other policy fields to indicate the broad
handling tier of the data. Suggested values are:

- `public` — information intended for broad release or non-sensitive use
- `internal` — information suitable for internal operations and trusted teams
- `restricted` — sensitive information that requires stronger handling controls

These values should be treated as a coarse overlay. When a team has a more
formal policy, they can replace or extend the labels with their own values while
keeping the same schema shape.

### Optional richer tier ladder

Teams that want a finer scheme can adopt a four-tier ladder aligned to public
Microsoft Purview default sensitivity labels. The tiers map cleanly onto the
coarse `sensitivity` values above:

| Tier | Purview default label | Coarse `sensitivity` |
|------|-----------------------|----------------------|
| T0   | Personal / Public     | `public`             |
| T1   | General               | `internal`           |
| T2   | Confidential          | `restricted`         |
| T3   | Highly Confidential   | `restricted`         |

The `sensitivity` field accepts any string label, so a team can record either the
coarse value or the richer tier/label; the generator carries whichever value is
present into the threat notes and properties for reviewers.

## Category hints

Use `assets[].category` to describe the role of the asset in the system. The
examples below are intentionally public and vendor-neutral:

- `Content` — user or business content that moves through the system
- `Identifiable PII` — data that directly identifies a natural person
- `Pseudonymous` — pseudonymous identifiers that do not directly identify a person
- `Organizational` — data that identifies an organization rather than a person
- `Account/Financial` — billing, payment, licensing, or purchase data
- `Operational` — service configuration, telemetry, or run-state data
- `Credentials` — secrets, tokens, keys, or account material
- `Special-category` — biometric, health, precise-location, or children's data
- `Public personal` — personal data the subject has made public

## Retention hints

Use `data_flows[].retention` to describe the expected lifecycle of the data in a
flow. Suggested values include:

- `transient` — short-lived data that should not persist beyond an interaction
- `90 days` — a short-term retention window for routine operational records
- `1 year` — a longer-term retention window for business records
- `until-closure` — retain until a defined business or legal closure event

## Public Microsoft anchors

The vocabulary above is intentionally aligned to public Microsoft guidance without
copying internal taxonomies. In particular:

- Microsoft Purview default sensitivity labels use a public ladder such as
  Personal, Public, General, Confidential, and Highly Confidential.
- Public Microsoft material also uses broad categories such as Customer Data,
  EUII, EUPI, OII, and System or Organizational data.

A team can map its local labels onto the generic hints above while preserving a
review-friendly, public-safe schema.

Sources:

* Microsoft Purview sensitivity labels: <https://learn.microsoft.com/purview/sensitivity-labels>
* Microsoft data classification categories (Customer Data, EUII, EUPI, OII): <https://learn.microsoft.com/compliance/assurance/assurance-data-classification>

## Private overlay for internal taxonomies

Keep organization-specific classification schemes out of this public reference.
When a deployment needs internal data-type names, retention policies, or label
mappings, supply them through a private config overlay referenced by
`state.overlayConfigPath` (an out-of-repo file), so no internal taxonomy is ever
embedded here.

## Usage notes

- Keep labels generic and reviewable so the threat model can be reused across
  organizations.
- Treat classification values as annotations rather than enforcement rules.
- When the generator emits a TM7 or markdown report, it carries these hints into
  the threat notes and properties where they remain visible to reviewers.

## Review guidance

When reviewing a completed model, confirm that:

- asset labels are consistent with the stated system purpose,
- retention hints are plausible for the described flow,
- any custom policy values are documented in the spec instead of being hard-coded
  in the generator.
