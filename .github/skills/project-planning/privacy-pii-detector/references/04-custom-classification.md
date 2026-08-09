---
title: Custom Classification
description: Project-level configuration for custom PII types, tier overrides, suppressions, and data catalog integration
---

# Custom Classification

This reference defines the `.pii-config.yml` schema that projects place in their repository root to customize PII detection. The configuration allows teams to bring their own data classification without modifying the skill's core taxonomy.

## Configuration file location

The detector looks for `.pii-config.yml` at the repository root. If absent, the skill uses its built-in taxonomy and industry overlays without customization.

```
my-project/
├── .pii-config.yml          ← project-level customization
├── src/
├── ...
```

## Schema

```yaml
# .pii-config.yml
version: "1.0"

# Industry context (activates the matching overlay)
industry: "telco"  # Options: telco, healthcare, financial, or omit for core-only

# Custom PII types specific to this organization
custom_types:
  - id: "PII-C001"
    name: "Employee Badge ID"
    description: "Internal badge number used for physical access"
    tier: "T1"
    detection_patterns:
      - "*badgeId*"
      - "*badge_number*"
      - "*accessCardId*"
    required_controls:
      - "encryption_at_rest"
      - "access_control"
      - "retention_policy"

  - id: "PII-C002"
    name: "Vehicle Registration"
    description: "Customer vehicle registration plate number"
    tier: "T1"
    detection_patterns:
      - "*registration*"
      - "*plateNumber*"
      - "*vehicleReg*"
    format_patterns:
      - "[A-Z]{1,3}\\d{1,4}[A-Z]{0,3}"  # AU format
    required_controls:
      - "encryption_at_rest"
      - "output_masking"

# Override sensitivity tiers for built-in types
tier_overrides:
  - pii_type: "PII-002"       # Email
    new_tier: "T2"            # Upgrade from T1 to T2
    justification: "Our org handles whistleblower emails requiring enhanced protection"

  - pii_type: "PII-006"       # IP address
    new_tier: "T2"
    justification: "Regulatory requirement to treat IP as sensitive in our jurisdiction"

# Additional controls beyond tier defaults
additional_controls:
  - pii_type: "PII-002"       # Email
    controls:
      - "audit_logging"       # Add audit logging requirement for email
      - "purpose_binding"

  - pii_type: "PII-023"       # Payment card
    controls:
      - "tokenization"        # Require tokenization (beyond default encryption)

# Suppress false positives
suppressions:
  - pattern: "address"
    context: "memory_address"
    reason: "Our 'address' fields in kernel module refer to memory addresses, not postal"
    files:
      - "src/kernel/**"
      - "src/drivers/**"

  - pattern: "phone"
    context: "phone_type_enum"
    reason: "PhoneType enum values (MOBILE, LANDLINE) are not PII"
    files:
      - "src/models/enums.py"

  - pattern: "patient*"
    context: "test_fixtures"
    reason: "Test fixtures use synthetic patient data clearly marked as non-production"
    files:
      - "tests/**"
      - "fixtures/**"

# Data catalog integration (import existing classification)
catalog_import:
  # Microsoft Purview
  purview:
    enabled: false
    # When enabled, the detector merges Purview sensitivity labels with its taxonomy
    # Requires: PURVIEW_TENANT_ID and PURVIEW_CLIENT_ID environment variables
    label_mapping:
      "Highly Confidential": "T3"
      "Confidential": "T2"
      "General": "T1"

  # Custom CSV/JSON import
  file_import:
    enabled: false
    path: "docs/data-classification.csv"
    # CSV must have columns: field_name, pii_type, tier, description
    # Imported entries are treated as custom_types

# Retention schedule overrides (per data category)
retention_overrides:
  - pii_type: "PII-002"       # Email
    retention_days: 730       # 2 years (org policy)
    justification: "Contractual requirement for 2-year email retention"

  - pii_type: "PII-106"       # CDR (telco)
    retention_days: 730       # 2 years (Australian metadata retention)
    justification: "Telecommunications (Interception and Access) Act 1979 s 187AA"
```

## Schema field reference

### `version`

Required. Schema version. Currently `"1.0"`.

### `industry`

Optional. Activates the matching industry overlay. Values: `telco`, `healthcare`, `financial`. Omit to use only core taxonomy + custom types.

### `custom_types`

Optional. Array of organization-specific PII types not in the core taxonomy.

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Unique ID in format `PII-C<NNN>` (C prefix = custom) |
| `name` | Yes | Human-readable name |
| `description` | Yes | What this data type is |
| `tier` | Yes | Sensitivity tier: `T1`, `T2`, or `T3` |
| `detection_patterns` | Yes | Glob patterns for field/variable names (case-insensitive) |
| `format_patterns` | No | Regex patterns for format validation detection |
| `required_controls` | Yes | Controls from the control matrix that must be present |

### `tier_overrides`

Optional. Override the default sensitivity tier for a built-in PII type.

| Field | Required | Description |
|-------|----------|-------------|
| `pii_type` | Yes | PII taxonomy ID to override (e.g., `PII-002`) |
| `new_tier` | Yes | New tier assignment: `T1`, `T2`, or `T3` |
| `justification` | Yes | Why this override exists (documented for audit) |

### `additional_controls`

Optional. Add controls beyond the tier default for specific PII types.

| Field | Required | Description |
|-------|----------|-------------|
| `pii_type` | Yes | PII taxonomy ID |
| `controls` | Yes | Array of additional control names from the control matrix |

### `suppressions`

Optional. Suppress known false positive detections.

| Field | Required | Description |
|-------|----------|-------------|
| `pattern` | Yes | The detection pattern to suppress |
| `context` | Yes | Why it's a false positive (e.g., `memory_address`, `test_fixtures`) |
| `reason` | Yes | Human-readable justification |
| `files` | No | Glob patterns limiting suppression scope. If omitted, applies globally |

### `catalog_import`

Optional. Import classification from external data catalogs.

#### `purview`

| Field | Required | Description |
|-------|----------|-------------|
| `enabled` | Yes | Whether to import from Microsoft Purview |
| `label_mapping` | Yes (if enabled) | Maps Purview sensitivity labels to PII tiers |

#### `file_import`

| Field | Required | Description |
|-------|----------|-------------|
| `enabled` | Yes | Whether to import from a local file |
| `path` | Yes (if enabled) | Relative path to CSV or JSON classification file |

### `retention_overrides`

Optional. Override retention expectations for specific PII types.

| Field | Required | Description |
|-------|----------|-------------|
| `pii_type` | Yes | PII taxonomy ID |
| `retention_days` | Yes | Maximum retention in days |
| `justification` | Yes | Why this retention period (regulatory reference or org policy) |

## Resolution order

When the detector classifies a field, it resolves in this order:

1. **Suppressions** — if the field matches a suppression, skip it.
2. **Custom types** — check project-defined types first.
3. **Tier overrides** — apply org-specific tier changes to built-in types.
4. **Industry overlay** — apply industry-specific types if configured.
5. **Core taxonomy** — fall back to the built-in classification.

## Control resolution

For each detected PII type, required controls are determined by:

1. Base controls from `02-control-expectations.md` for the effective tier.
2. Plus any `additional_controls` from the config.
3. Industry overlay controls (if applicable).

## Example: Telco company with custom classification

```yaml
version: "1.0"
industry: "telco"

custom_types:
  - id: "PII-C001"
    name: "Network Slice ID"
    description: "5G network slice identifier linked to subscriber"
    tier: "T2"
    detection_patterns:
      - "*sliceId*"
      - "*networkSlice*"
      - "*nssai*"
    required_controls:
      - "encryption_at_rest"
      - "access_control"
      - "audit_logging"

tier_overrides:
  - pii_type: "PII-104"       # MAC address
    new_tier: "T2"
    justification: "Persistent device tracking via MAC requires enhanced controls per our DPO guidance"

suppressions:
  - pattern: "address"
    context: "network_address"
    reason: "Network address fields in routing tables are infrastructure, not postal addresses"
    files:
      - "src/routing/**"
      - "src/network/**"

retention_overrides:
  - pii_type: "PII-106"       # CDR
    retention_days: 730
    justification: "Australian Telecommunications (Interception and Access) Act metadata retention"
```

## Validation

The skill validates `.pii-config.yml` at the start of Phase 1 (Industry context). Invalid configurations produce a finding:

```yaml
finding:
  id: "PII-GAP-CONFIG-001"
  severity: "LOW"
  title: "Invalid .pii-config.yml: <specific error>"
  remediation: "Fix the configuration error; detection proceeds with defaults"
```

The detector does not halt on invalid config — it falls back to defaults and reports the config issue as a LOW finding.

---

Configuration schema is original content (CC BY 4.0). The `.pii-config.yml` pattern follows the convention established by `.adr-config.yml` in the ADR Creator skill.
