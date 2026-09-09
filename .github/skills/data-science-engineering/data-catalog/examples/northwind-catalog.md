---
catalog_version: DS_CATALOG_V1
engagement: northwind-modernization
generated_at: "2026-08-01T09:00:00Z"
last_enriched: "2026-08-02T14:30:00Z"
entities:
  - id: customer
    name: Customer Master
    description: Canonical customer account record
    source:
      system: crm
      location: connections/crm-readonly
      format: table
      access_confirmed: true
    tier: silver
    grain: One row per customer account
    volume:
      row_estimate: 120000
      period_covered: "2018-01-01/2026-07-31"
      update_frequency: daily
    profile_ref: outputs/data-profile-customer-2026-07-28.json
    classification:
      sensitivity: confidential
      contains_personal_data: true
      data_categories:
        - contact-data
      gdpr_article: "Art. 6(1)(b)"
      ccpa_section: null
      nist_pf_category: ID.IM-P
      nistir8062_objective: null
      owasp_privacy_id: null
      dpia_ref: docs/privacy/customer-data-plan.md
    lineage:
      derived_from: []
      transform_ref: src/customer/clean.py
    open_questions: []
  - id: sales-order-line
    name: Sales Order Line
    description: Individual line items recorded on sales orders
    source:
      system: erp
      location: lake/bronze/sales-order-line
      format: parquet
      access_confirmed: true
    tier: bronze
    grain: One row per order and line number
    volume:
      row_estimate: 9000000
      period_covered: "2020-01-01/2026-07-31"
      update_frequency: hourly
    profile_ref: outputs/data-profile-sales-order-line-2026-08-01.json
    classification:
      sensitivity: internal
      contains_personal_data: false
      data_categories: []
      gdpr_article: null
      ccpa_section: null
      nist_pf_category: null
      nistir8062_objective: null
      owasp_privacy_id: null
      dpia_ref: null
    lineage:
      derived_from:
        - customer
      transform_ref: null
    open_questions:
      - Confirm whether order lines can move between accounts
  - id: product
    name: Product Catalogue
    description: Sellable product definitions and their commercial attributes
    source:
      system: erp
      location: lake/silver/product
      format: parquet
      access_confirmed: true
    tier: silver
    grain: One row per product code
    volume:
      row_estimate: 4200
      period_covered: null
      update_frequency: daily
    profile_ref: null
    classification:
      sensitivity: internal
      contains_personal_data: false
      data_categories: []
      gdpr_article: null
      ccpa_section: null
      nist_pf_category: null
      nistir8062_objective: null
      owasp_privacy_id: null
      dpia_ref: null
    lineage:
      derived_from: []
      transform_ref: null
    open_questions: []
  - id: support-ticket
    name: Support Ticket
    description: Customer support requests raised through the service desk
    source:
      system: service-desk
      location: connections/service-desk-export
      format: jsonl
      access_confirmed: false
    tier: bronze
    grain: One row per support ticket
    volume:
      row_estimate: null
      period_covered: null
      update_frequency: unknown
    profile_ref: null
    classification:
      sensitivity: confidential
      contains_personal_data: true
      data_categories:
        - contact-data
      gdpr_article: "Art. 6(1)(f)"
      ccpa_section: null
      nist_pf_category: null
      nistir8062_objective: null
      owasp_privacy_id: null
      dpia_ref: null
    lineage:
      derived_from: []
      transform_ref: null
    open_questions:
      - Confirm the identifier that links tickets to customer accounts
relationships:
  - id: rel-customer-order-line
    from: customer
    to: sales-order-line
    cardinality: one-to-many
    from_minimum: one
    to_minimum: zero
    join_keys:
      from_field:
        - tenant_id
        - customer_id
      to_field:
        - tenant_id
        - customer_id
    confidence: confirmed
    basis: Confirmed by the CRM and ERP data owners
  - id: rel-product-order-line
    from: product
    to: sales-order-line
    cardinality: one-to-many
    from_minimum: one
    to_minimum: one
    join_keys:
      from_field: product_code
      to_field: product_code
    confidence: inferred
    basis: Every sampled order line resolves to exactly one product code
  - id: rel-customer-support-ticket
    from: customer
    to: support-ticket
    cardinality: one-to-many
    from_minimum: zero
    to_minimum: zero
    join_keys:
      from_field: customer_id
      to_field: account_ref
    confidence: assumed
    basis: Proposed during the discovery workshop; service-desk access is not yet granted
coverage:
  entities_catalogued: 4
  entities_access_confirmed: 3
  entities_classified: 4
  relationships_confirmed: 1
  relationships_inferred: 1
---

# Northwind modernization data catalog

## Overview and engagement context

This catalog records the confirmed customer, order-line, product, and support entities for modernization planning, along with the relationships that remain unconfirmed.

## Entity summary

| Entity            | Grain                             | Tier   | Sensitivity  | Access      |
|-------------------|-----------------------------------|--------|--------------|-------------|
| Customer Master   | One row per customer account      | Silver | Confidential | Confirmed   |
| Sales Order Line  | One row per order and line number | Bronze | Internal     | Confirmed   |
| Product Catalogue | One row per product code          | Silver | Internal     | Confirmed   |
| Support Ticket    | One row per support ticket        | Bronze | Confidential | Unconfirmed |

## Entity relationship diagram

The declared relationships are ready for catalog-driven ERD rendering. One relationship uses a composite key, two use scalar keys, and only one is confirmed.

| Relationship                  | Endpoints                    | Cardinality | Minimums               | Join keys                                                | Confidence |
|-------------------------------|------------------------------|-------------|------------------------|----------------------------------------------------------|------------|
| `rel-customer-order-line`     | customer to sales-order-line | one-to-many | from `one`, to `zero`  | `tenant_id`, `customer_id` to `tenant_id`, `customer_id` | confirmed  |
| `rel-product-order-line`      | product to sales-order-line  | one-to-many | from `one`, to `one`   | `product_code` to `product_code`                         | inferred   |
| `rel-customer-support-ticket` | customer to support-ticket   | one-to-many | from `zero`, to `zero` | `customer_id` to `account_ref`                           | assumed    |

## Entity details

### Customer Master

The CRM record is the canonical customer account source and points to a dated profile.

### Sales Order Line

The ERP extract uses tenant and customer identifiers as a composite relationship key.

### Product Catalogue

The curated product table supplies the product code that order lines reference. The pairing is supported by sampling rather than an owner confirmation.

### Support Ticket

The service-desk export is not yet accessible, so its link to customer accounts remains an assumption from the discovery workshop.

## Coverage summary

Four entities are catalogued and classified. Three have confirmed access. Of three declared relationships, one is confirmed, one is inferred, and one is assumed.

## Open questions and access gaps

* Confirm whether order lines can move between accounts
* Confirm the identifier that links tickets to customer accounts
* Obtain service-desk access so the support-ticket relationship can be evidenced

## Disclaimer

> [!CAUTION]
> **Disclaimer:** This agent is an assistive data-science and data-engineering coaching tool only. It does not validate customer data, execute production pipelines, establish model fitness, or replace data owners, privacy and Responsible AI reviewers, engineering review, or business decision authority. Catalogs, feasibility findings, analyses, experiments, tests, and operational recommendations generated with this tool may be incomplete or inaccurate and must be independently reviewed against approved data sources, stakeholder evidence, and organizational controls before use. Outputs from this tool do not constitute data approval, feasibility sign-off, model approval, privacy or Responsible AI approval, or production readiness.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
