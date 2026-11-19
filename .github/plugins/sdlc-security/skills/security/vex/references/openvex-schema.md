---
title: OpenVEX JSON Schema Reference
description: Field definitions, types, and constraints for OpenVEX v0.2.0 documents
---

OpenVEX documents are serialized as JSON-LD. File encoding must be UTF-8. This reference covers
the v0.2.0 specification.

## Document struct

The top-level object containing metadata and a collection of VEX statements.

| Field          | Required | Type    | Description                                                                                                                                                                                                     |
|----------------|----------|---------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `@context`     | Yes      | string  | The URL linking to the OpenVEX context definition. Set to `https://openvex.dev/ns/v0.2.0`.                                                                                                                      |
| `@id`          | Yes      | string  | IRI identifying the document (for example, `https://github.com/microsoft/hve-core/security/vex/2026-05-14`).                                                                                                    |
| `author`       | Yes      | string  | Individual or organization that authored the document. Should be machine-readable (IRI, email etc.). Author must be an individual or an organization directly involved in the vulnerability assessment process. |
| `role`         | No       | string  | Role of the document author (for example, `Document Creator`).                                                                                                                                                  |
| `timestamp`    | Yes      | string  | ISO 8601 datetime when the document was issued.                                                                                                                                                                 |
| `last_updated` | No       | string  | ISO 8601 datetime of the last modification.                                                                                                                                                                     |
| `version`      | Yes      | integer | Document version. Increment on any content change including statement additions or modifications.                                                                                                               |
| `tooling`      | No       | string  | Description of tools or processes used to generate the document.                                                                                                                                                |
| `statements`   | Yes      | array   | Array of statement objects. Populated documents must contain at least one statement; foundation or bootstrap documents may ship an empty array until the first statement is added.                              |

## Statement struct

Each statement asserts the impact a vulnerability has on one or more products at a point in time.

| Field                        | Required    | Type    | Description                                                                                                                                           |
|------------------------------|-------------|---------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| `@id`                        | No          | string  | Optional IRI making the statement externally referenceable.                                                                                           |
| `version`                    | No          | integer | Statement version. Optional; when present, must be an integer greater than or equal to `1`.                                                           |
| `vulnerability`              | Yes         | object  | Vulnerability struct identifying the CVE or other defect. See Vulnerability struct below.                                                             |
| `timestamp`                  | No          | string  | ISO 8601 datetime when the statement was known to be true. Inherits from the document if omitted.                                                     |
| `last_updated`               | No          | string  | ISO 8601 datetime when the statement was last updated.                                                                                                |
| `products`                   | Yes         | array   | Array of product structs. Required on each statement.                                                                                                 |
| `status`                     | Yes         | string  | One of: `not_affected`, `affected`, `fixed`, `under_investigation`.                                                                                   |
| `supplier`                   | No          | string  | Supplier of the product or subcomponent.                                                                                                              |
| `status_notes`               | No          | string  | Free-form text describing how the status was determined. May reference other VEX information.                                                         |
| `justification`              | Conditional | string  | Required when `status` is `not_affected` (unless `impact_statement` is provided). See Justification codes.                                            |
| `impact_statement`           | Conditional | string  | Required when `status` is `not_affected` (unless `justification` is provided). Free-form explanation. Prefer `justification` for machine readability. |
| `action_statement`           | Conditional | string  | Required when `status` is `affected`. Describes remediation or mitigation actions.                                                                    |
| `action_statement_timestamp` | No          | string  | ISO 8601 datetime when the action statement was issued.                                                                                               |

## Vulnerability struct

| Field         | Required | Type   | Description                                                                       |
|---------------|----------|--------|-----------------------------------------------------------------------------------|
| `@id`         | No       | string | IRI for linking (for example, `https://nvd.nist.gov/vuln/detail/CVE-2026-XXXXX`). |
| `name`        | Yes      | string | Primary identifier (for example, `CVE-2026-XXXXX`).                               |
| `description` | No       | string | Free-form text describing the vulnerability.                                      |
| `aliases`     | No       | array  | List of alternative identifiers (GHSA IDs, distro tracker IDs).                   |

## Product struct (component)

Products and subcomponents share the same component structure. Use as many identifiers as possible
to help VEX processors match against SBOMs.

| Field           | Required | Type   | Description                                                                                    |
|-----------------|----------|--------|------------------------------------------------------------------------------------------------|
| `@id`           | No       | string | IRI identifying the component. Package URLs are valid IRIs and the recommended value.          |
| `identifiers`   | No       | object | Map of software identifiers. Keys: `purl`, `cpe23`, `cpe22`. Values: identifier strings.       |
| `hashes`        | No       | object | Map of cryptographic hashes. Keys: algorithm names per IANA registry (for example, `sha-256`). |
| `subcomponents` | No       | array  | (Product only) List of component structs for vulnerable subcomponents.                         |

## Justification codes

Valid values for the `justification` field when `status` is `not_affected`:

| Code                                                | When to use                                                          |
|-----------------------------------------------------|----------------------------------------------------------------------|
| `component_not_present`                             | The vulnerable component is not included in the product.             |
| `vulnerable_code_not_present`                       | The component is present but the vulnerable code is excluded.        |
| `vulnerable_code_not_in_execute_path`               | The vulnerable code exists but cannot be reached at runtime.         |
| `vulnerable_code_cannot_be_controlled_by_adversary` | The code is reachable but attacker-controlled input cannot reach it. |
| `inline_mitigations_already_exist`                  | Built-in protections prevent exploitation.                           |

## Inheritance flow

Statements can inherit `timestamp` from the parent document. A valid statement requires four data
points:

1. One or more products (required on each statement)
2. A status
3. A vulnerability
4. A timestamp (directly or inherited from the document)

When `timestamp` is defined at both document and statement level, the statement value takes
precedence. The `products` field has no document-level equivalent and must appear on each statement.

## Minimal document example

```json
{
  "@context": "https://openvex.dev/ns/v0.2.0",
  "@id": "https://github.com/microsoft/hve-core/security/vex/2026-05-14",
  "author": "Microsoft HVE Core Maintainers",
  "timestamp": "2026-05-14T00:00:00Z",
  "version": 1,
  "tooling": "hve-core SSSC Reviewer VEX assessment (AI-assisted drafting), human-reviewed and Sigstore-attested at release.",
  "statements": [
    {
      "vulnerability": { "name": "CVE-2026-XXXXX" },
      "products": [{ "@id": "pkg:npm/@microsoft/hve-core@3.10.0" }],
      "status": "under_investigation"
    }
  ]
}
```

## Statement examples

### not_affected with justification

```json
{
  "vulnerability": { "name": "CVE-2026-XXXXX" },
  "products": [{ "@id": "pkg:npm/@microsoft/hve-core@3.10.0" }],
  "status": "not_affected",
  "justification": "vulnerable_code_not_in_execute_path",
  "impact_statement": "The affected parsing function is never invoked by HVE Core."
}
```

### affected with action statement

```json
{
  "vulnerability": { "name": "CVE-2026-YYYYY" },
  "products": [{ "@id": "pkg:npm/@microsoft/hve-core@3.9.0" }],
  "status": "affected",
  "action_statement": "Upgrade to @microsoft/hve-core@3.10.0 which removes the vulnerable dependency."
}
```

### under_investigation

```json
{
  "vulnerability": { "name": "CVE-2026-ZZZZZ" },
  "products": [{ "@id": "pkg:npm/@microsoft/hve-core@3.10.0" }],
  "status": "under_investigation",
  "status_notes": "Reachability analysis in progress. Awaiting confirmation of runtime code path."
}
```

### fixed

```json
{
  "vulnerability": { "name": "CVE-2026-AAAAA" },
  "products": [{ "@id": "pkg:npm/@microsoft/hve-core@3.10.1" }],
  "status": "fixed",
  "status_notes": "Vulnerable dependency updated to patched version in release 3.10.1."
}
```
