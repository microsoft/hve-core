---
description: Human-readable source inventory with adapter status and limitations
---

# Source Inventory: {{project_name}}

Render this projection from state `sourceInventory`. Do not inventory or inspect
sources while context is pending.

| Source ID     | Kind                    | Display path     | Status                                      | Adapter             | SHA-256                      | Reason                       | Limitations             |
|---------------|-------------------------|------------------|---------------------------------------------|---------------------|------------------------------|------------------------------|-------------------------|
| {{source_id}} | {{file_or_pasted_text}} | {{display_path}} | {{supported_unsupported_skipped_or_failed}} | {{adapter_or_null}} | {{sha256_or_not_applicable}} | {{reason_or_not_applicable}} | {{limitations_or_none}} |

## Inventory Summary

* Confirmed source boundary: {{source_boundary}}
* Inventory generated at: {{ISO_8601_timestamp}}
* Supported count: {{count}}
* Unsupported, skipped, or failed count: {{count}}
* Normalized evidence artifacts: {{artifact_ids_and_paths_or_none}}
