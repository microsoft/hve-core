---
description: "Initiate security planning from PRD/BRD artifacts using the Security Planner agent in from-prd mode"
agent: security-planner
---

# Security Plan from PRD/BRD

Activate the Security Planner in **from-prd mode** to bootstrap a security plan from existing product definition artifacts.

## Inputs

* ${input:project-slug}: (Optional) Project slug for the security plan directory. When omitted, derive from the discovered PRD/BRD project name.

## Requirements

### PRD/BRD Discovery

Scan these directories as the primary discovery path:

* `.copilot-tracking/prd-sessions/` for product requirements documents
* `.copilot-tracking/brd-sessions/` for business requirements documents

If the primary paths yield no matches, perform a secondary scan of `.copilot-tracking/` for files whose names match `prd-*.md`, `*-prd.md`, `brd-*.md`, `*-brd.md`, or `product-definition*.md`. Exclude generic matches like `requirements.txt` or files outside product-scoping contexts.

Present all discovery results to the user for confirmation before proceeding. Example results:

```text
Found 3 candidates:
  ✅ .copilot-tracking/prd-sessions/contoso-api/prd-final.md
  ✅ .copilot-tracking/brd-sessions/contoso-api/brd-v2.md
  ❌ .copilot-tracking/plans/npm-requirements.md (false positive, discard)
```

If zero artifacts are found after both scans: inform the user that no PRD/BRD artifacts were discovered, offer to switch to capture mode using the `/security-capture` prompt, or ask the user to provide a file path manually. Do not proceed to scope extraction without at least one confirmed artifact.

### Scope Extraction

From confirmed artifacts, extract:

* Project name and description
* Technology stack and frameworks
* Deployment targets (cloud provider, regions, environments)
* Data classification and sensitivity levels
* Compliance requirements mentioned in the artifacts
* Stakeholder roles identified

If the project name cannot be derived from the discovered artifacts and `${input:project-slug}` is empty, prompt the user for a project slug before proceeding to state initialization.

### State Initialization

Create the project directory at `.copilot-tracking/security-plans/{project-slug}/` and initialize `state.json` with:

* `entryMode` set to `"from-prd"`
* `currentPhase` set to `1`
* Pre-populated fields from extracted PRD/BRD data (project slug, technology inventory, deployment targets, compliance requirements)

### Phase 1 Entry

Present the extracted scope to the user as a checklist using ❓ (pending) and ✅ (confirmed) markers. Ask 3-5 clarifying questions targeting:

* Gaps in the extracted information
* Security-specific concerns not covered in the PRD/BRD
* Data handling and privacy requirements
* Integration points and external dependencies
