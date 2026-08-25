---
title: engagement-reporting
description: "Creates source-grounded internal or external engagement status reports. Use for weekly, monthly, QBR, or stakeholder updates."
sidebar_position: 1
author: Microsoft
ms.date: 2026-08-24
ms.topic: reference
keywords:
  - skill
  - engagement-reporting
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                  |
|-------------|----------------------------------------------------------------------------------------|
| Kind        | skill                                                                                  |
| Source      | `.github/skills/engagement-reporting/engagement-reporting`                             |
| Invocation  | Invoked directly as `/engagement-reporting`, or loaded on demand by referencing agents |
| Interactive | No                                                                                     |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Creates source-grounded internal or external engagement status reports. Use for weekly, monthly, QBR, or stakeholder updates.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill to create source-grounded weekly, monthly, quarterly, or
stakeholder engagement reports. It is suitable for M365-only reporting and can
also normalize optional Azure DevOps, GitHub, Jira, or GitLab board evidence.

Use the Engagement Report Generator when a user needs the complete interactive
coordination experience. Do not use this skill to publish reports or send
email.

## Set up the workspace

Copy the packaged configuration template to the root of the engagement
workspace:

```bash
cp .github/skills/engagement-reporting/engagement-reporting/assets/engagement.template.yaml \
  engagement.yaml
```

Edit `engagement.yaml` with the engagement identity, stakeholders, source
locations, and optional distribution settings. Add these local and potentially
sensitive paths to the workspace `.gitignore` before running a report:

```gitignore
engagement.yaml
.working/
reports/
transcripts/
```

The HVE Core installer installs the template with the skill but does not create
the workspace configuration or modify `.gitignore`.

## Example usage

```text
/engagement-reporting weekly August 17-21
```

With a valid `engagement.yaml`, the skill discovers configured sources,
normalizes evidence, enforces coverage and verification gates, drafts against
the selected template, applies review, and returns approved report artifacts.
Optional Outlook distribution creates a draft only after separate approval.
