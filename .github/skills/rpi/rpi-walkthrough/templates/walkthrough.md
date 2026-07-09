<!-- markdownlint-disable-file -->
<!-- Session artifact for the rpi-walkthrough skill. AI-consumed; references use plain workspace-relative paths. -->

# Walkthrough: {{task_slug}}

- Date: {{YYYY-MM-DD}}
- Target: {{target_description}}
- Target type: {{code | feature | ui-ux | prompt-artifact | tracking-artifact | document}} (name all that apply)
- Detail level: {{brief | normal | deep}}
- Status: {{in-progress | complete}}

## Scope

{{One or two sentences naming exactly what is being walked through and what is out of scope.}}

## Evidence map

Captured from the deep subagent review before explanation. One row per planned segment.

| Segment | Reference (path and lines or section) | What it does | Why it is this way | Evidence         |
|---------|---------------------------------------|--------------|--------------------|------------------|
| 1       | {{path/to/file.ext:L10-L24}}          | {{behavior}} | {{rationale}}      | {{path or note}} |
| 2       | {{path/to/file.ext:L30}}              | {{behavior}} | {{rationale}}      | {{path or note}} |

## Segment plan

1. {{segment-1 title}}
2. {{segment-2 title}}
3. {{segment-3 title}}

## Working notes

Scratch space for the current session: open questions, partial findings from the deep review, and anything needed to resume after an interruption. Keep working notes here so the walkthrough artifact stays the single durable record.

- {{note}}

## Walkthrough log

Append one entry per segment as it is explained.

### Segment {{n}}: {{title}} ({{covered | revisited}})

- References: {{path/to/file.ext:L10-L24}}
- Summary: {{the explanation given to the user, condensed}}
- Reminder: each segment explanation should follow the human-voice writing rules in references/walkthrough.md.
- User feedback: {{more detail | continue | change request | none}}

## Requested changes

Captured during the walkthrough. Not applied to the codebase unless the user asked for an immediate change.

| # | Reference (path and lines) | Requested change | Reason | Evidence | Applied now? |
|---|----------------------------|------------------|--------|----------|--------------|
| 1 | {{path/to/file.ext:L42}} | {{what to change}} | {{why the user wants it}} | {{path or note}} | {{no | yes}} |

## Next step

- Recommended: {{/rpi-quick | /rpi-research, /rpi-plan, /rpi-implement, /rpi-review}}
- Seed: this walkthrough artifact and its Requested Changes section.
