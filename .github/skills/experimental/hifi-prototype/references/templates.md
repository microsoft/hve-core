# Experiment Templates

Templates for experiment cards, session reports, and experiment summaries used
by the hifi-prototype skill.

## Experiment Card Template

Every prototype starts with an experiment card. No card, no code.

```markdown
# Experiment Card: {Prototype Name}

## Status

🔬 Active | 📊 Collecting Data | ✅ Concluded | ❌ Invalidated

## Hypothesis

{One clear statement of what you believe to be true.}

## Success Criteria

| Metric | Target | How Measured |
|--------|--------|-------------|
| {metric} | {target} | {telemetry event or observation} |

## Failure Criteria

What evidence would REJECT the hypothesis? Be specific:

- {condition that disproves the hypothesis}

## What Is Simulated

| Component | Real or Simulated | Assumptions |
|-----------|-------------------|-------------|
| {component} | {Real / Simulated} | {what the simulation assumes} |

## Measurement Plan

- Telemetry level: {basic / detailed}
- Session count target: {how many sessions before analysis}
- Key events to track: {list specific telemetry events}

## Risks and Limitations

- {known risk or limitation of the experiment design}

## Dates

- Started: {date}
- Target conclusion: {date}
```

## Session Report Template

Generate a session report in `reports/session-{n}.md` after each test session.

```markdown
# Session {n} Report

**Date**: {date}
**Participant**: {role or persona — no PII}
**Duration**: {minutes}

## Task Completion

| Task | Completed | Time | Errors | Notes |
|------|-----------|------|--------|-------|
| {task} | Yes/No | {time} | {count} | {observation} |

## Telemetry Summary

- Events captured: {count}
- Key events: {summary of notable telemetry}

## Observations

- {what the user did, not what they said}
- {confusion points, workarounds, unexpected behavior}

## Quotes

- "{anything the user said that reveals intent or frustration}"

## Preliminary Signal

Does this session support or weaken the hypothesis?
{brief assessment — not a conclusion from one session}
```

## Experiment Summary Template

After the target number of sessions, produce a summary in `reports/experiment-summary.md`.

```markdown
# Experiment Summary: {Prototype Name}

## Hypothesis

{restated from experiment card}

## Verdict

✅ Supported | ⚠️ Weakened | ❌ Invalidated

## Evidence

| Criterion | Target | Actual | Verdict |
|-----------|--------|--------|---------|
| {metric} | {target} | {measured} | ✅/⚠️/❌ |

## Telemetry Findings

- {aggregated telemetry insights}

## What We Learned

- {insight — valuable regardless of hypothesis outcome}

## What Surprised Us

- {unexpected behavior or finding}

## Recommended Next Step

{iterate / pivot / proceed} — {rationale}

## Artifacts

- Experiment card: `experiment-card.md`
- Session reports: `reports/session-*.md`
- Telemetry data: `telemetry/events.json`
- Prototype source: `{entry point}`
```
