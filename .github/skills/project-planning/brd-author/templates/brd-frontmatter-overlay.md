---
description: "BRD Frontmatter Overlay — Schema Definition - Brought to you by microsoft/hve-core"
---

# BRD Frontmatter Overlay Schema

This document defines all YAML frontmatter fields for BRD documents in the HVE-Core BRD Builder.

## Required Fields

### `brd_id`

**Type**: String
**Format**: Namespace + Version + Sequential ID
**Example**: `BRD-2026-Q1-001`
**Description**: Unique identifier for this BRD. Should follow organizational naming convention. Used in supersession chains and cross-references.

### `title`

**Type**: String
**Example**: "Customer Portal Redesign — Requirements"
**Description**: Human-readable title of the BRD.

### `status`

**Type**: Enum
**Valid Values**: `draft`, `in-review`, `approved`, `superseded`
**Default**: `draft`
**Description**: Current lifecycle stage:

- `draft`: Authoring in progress (Discover→Define phase)
- `in-review`: Ready for stakeholder review (Define phase end)
- `approved`: Approved and active (Govern phase)
- `superseded`: Replaced by a newer BRD; see `lineage.superseded_by`

### `version`

**Type**: String
**Format**: Semantic versioning (Major.Minor.Patch)
**Example**: `1.0.0`
**Description**: Version of this BRD revision.

### `owners`

**Type**: Array of Strings
**Example**: `["alice@example.com", "bob@example.com"]`
**Description**: Primary owners/authors of this BRD. Used for approval routing.

### `reviewers`

**Type**: Array of Strings
**Example**: `["technical-lead@example.com", "qa-lead@example.com"]`
**Description**: Designated reviewers for Define→Govern gate assessment.

### `created_date`

**Type**: ISO 8601 Date String
**Format**: `YYYY-MM-DD`
**Example**: `2026-05-08`
**Description**: Date BRD was initially created.

### `last_updated`

**Type**: ISO 8601 Date String
**Format**: `YYYY-MM-DD`
**Example**: `2026-05-15`
**Description**: Most recent modification date.

## Conditional/Optional Fields

### `business_goal_ids`

**Type**: Array of Strings
**Example**: `["BG-001", "BG-002"]`
**Description**: IDs of business goals this BRD addresses. Populated at Define phase.

### `business_goal_smart_status`

**Type**: Enum
**Valid Values**: `pass`, `fail`, `deferred`
**Default**: `deferred`
**Description**: SMART rubric evaluation result (from `requirements-definition` skill). Populated by `brd-standard-assessor` subagent at Define→Govern gate:

- `pass`: All SMART criteria (Specific, Measurable, Achievable, Relevant, Time-bound) met
- `fail`: One or more SMART criteria unmet; must resolve before Govern approval
- `deferred`: Assessment deferred to post-publish iteration

### `diagram_format`

**Type**: Enum
**Valid Values**: `ascii`, `mermaid`, `figma`, `none`
**Default**: `mermaid`
**Description**: Diagram format used in Process Models section (DD-10). Snapshots user preference at publish time:

- `ascii`: Plain-text ASCII diagram (from `diagram-ascii.md`)
- `mermaid`: Mermaid flowchart diagram (from `diagram-mermaid.md`)
- `figma`: Figma low-fidelity prototype (from `diagram-figma.md`)
- `none`: No diagram section included

### `lineage`

**Type**: Object
**Structure**:

```yaml
lineage:
  supersedes: ["BRD-2026-Q1-001"]        # Array of BRD IDs this document replaces
  superseded_by: []                       # Array of BRD IDs that replace this document
  last_brd_id: "BRD-2026-Q1-001"          # Previous BRD ID in chain (for audit trail)
```

**Description**: Bidirectional links for BRD supersession (DD-13 Pattern). When a new BRD supersedes an older one:

- New BRD: `lineage.supersedes: ["BRD-2026-Q1-001"]`
- Old BRD (updated retroactively): `lineage.superseded_by: ["BRD-2026-Q1-002"]`
- Both: Historical BRD files remain on disk with supersession metadata for auditability.

### `requirement_id_prefixes`

**Type**: Object
**Structure**:

```yaml
requirement_id_prefixes:
  fr: "FR"        # Functional Requirement prefix (default)
  ac: "AC"        # Acceptance Criteria prefix (default)
  nfr: "NFR"      # Non-Functional Requirement prefix (default)
  br: "BR"        # Business Rule prefix (default)
```

**Default**: `{ fr: "FR", ac: "AC", nfr: "NFR", br: "BR" }`
**Description**: Snapshot of ID prefix strings active when this BRD was authored. Allows downstream consumers (PRD, ADR) to see actual prefix strings rather than re-deriving from `.brd-config.yml`. Four-tier namespace separation (FR/AC/NFR/BR) is NOT overridable; only prefix strings per namespace.

### `license`

**Type**: String
**Example**: `CC-BY 4.0 (Microsoft HVE-Core)`
**Description**: License for original BRD content.

---

## Field Validation Rules

| Field                        | Required | Mutable | Validator                                      |
|------------------------------|----------|---------|------------------------------------------------|
| `brd_id`                     | Yes      | No      | Non-empty string                               |
| `title`                      | Yes      | Yes     | Non-empty string                               |
| `status`                     | Yes      | Yes     | One of: draft, in-review, approved, superseded |
| `version`                    | Yes      | Yes     | Semantic versioning (x.y.z)                    |
| `owners`                     | Yes      | Yes     | Non-empty array of strings                     |
| `reviewers`                  | Yes      | Yes     | Non-empty array of strings                     |
| `created_date`               | Yes      | No      | ISO 8601 date (YYYY-MM-DD)                     |
| `last_updated`               | Yes      | Yes     | ISO 8601 date (YYYY-MM-DD)                     |
| `business_goal_ids`          | No       | Yes     | Array of strings (can be empty)                |
| `business_goal_smart_status` | No       | Yes     | One of: pass, fail, deferred                   |
| `diagram_format`             | No       | Yes     | One of: ascii, mermaid, figma, none            |
| `lineage`                    | No       | Yes     | Object with optional arrays                    |
| `requirement_id_prefixes`    | No       | Yes     | Object with four string fields                 |
| `license`                    | No       | No      | Non-empty string                               |

---

## Example Frontmatter (Complete)

```yaml
---
brd_id: "BRD-2026-Q1-015"
title: "Customer Portal Redesign — Requirements"
status: "in-review"
version: "1.0.0"
owners: ["alice@hve.com", "bob@hve.com"]
reviewers: ["qa-lead@hve.com", "technical-lead@hve.com"]
created_date: "2026-05-08"
last_updated: "2026-05-15"
business_goal_ids: ["BG-001", "BG-002"]
business_goal_smart_status: "pass"
diagram_format: "mermaid"
lineage:
  supersedes: ["BRD-2026-Q1-001"]
  superseded_by: []
  last_brd_id: "BRD-2026-Q1-001"
requirement_id_prefixes:
  fr: "FR"
  ac: "AC"
  nfr: "NFR"
  br: "BR"
license: "CC-BY 4.0 (Microsoft HVE-Core)"
---
```

---

> Brought to you by microsoft/hve-core

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
