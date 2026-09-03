---
description: Human-readable review projection of the validated package manifest
---

# Package Manifest Review: {{project_name}}

The validated JSON package manifest remains authoritative. Regenerate this view
after any package membership or checksum change.

## Package

* Schema version: {{schema_version}}
* Project slug: {{project_slug}}
* Generated at: {{ISO_8601_timestamp}}
* Base IRI: {{absolute_base_iri}}
* Package digest: {{sha256}}

## Capabilities

* Sampled instances applicable: {{true_or_false}}
* Competency checks applicable: {{true_or_false}}

## Artifacts

| Role             | Path                        | Media type     | SHA-256    | Authority     |
|------------------|-----------------------------|----------------|------------|---------------|
| {{package_role}} | {{workspace_relative_path}} | {{media_type}} | {{sha256}} | {{authority}} |

## Attestations

* Candidates excluded from approved graphs: {{true}}
* Deployment occurred: {{false}}
* Missing required or applicable roles: {{none_or_roles}}