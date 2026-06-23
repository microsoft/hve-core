---
title: Coverage method
description: Discovery and gap-analysis method for documentation audit mode.
---

# Coverage method

Use this method for audit-mode discovery and gap analysis.

## Discovery phases

1. Scope the files to the requested documentation targets.
2. Review the current repository structure and identify likely documentation gaps.
3. Compare the documentation to existing implementation surfaces, commands, and workflows.
4. Highlight factual discrepancies, missing coverage, and obvious omissions.
5. Recommend precise follow-up actions rather than broad editorial rewrites.

## What to capture

- Missing or outdated documentation for a command, script, workflow, or directory.
- Documentation that mentions paths, options, or outputs that no longer exist.
- Sections that should be updated because the implementation changed.
- Anything that would confuse a new contributor or user.

## Output expectations

The audit output should be actionable and bounded. Each finding should include the
location, the observed issue, and the recommended fix.
