---
name: performance-slo-planner
description: "Performance, load, and reliability (SLO/SRE) planning for production readiness. Use when defining service level objectives, load characterization, capacity, latency budgets, stress/soak/spike test plans, false-positive baselines, and reliability targets. USE FOR: SLO/SLA definition, load testing plan, performance budget, capacity planning, reliability/SRE backlog, latency targets, error-budget policy. DO NOT USE FOR: executing load tests (use Azure Load Testing tooling), security threat modeling, RAI assessment, or privacy/compliance planning."
argument-hint: "[journeys=critical-user-flows] [traffic=assumptions]"
license: MIT
user-invocable: true
---

# Performance & SLO/SRE Planner

Turn vague "it should be fast and reliable" expectations into measurable **SLIs, SLOs, a load model, a test matrix, and a reliability backlog** for production readiness. Pairs with Azure Load Testing tooling for execution — this skill plans, it does not run the tests.

## When to Use

- Defining service level objectives and error budgets before launch.
- Characterizing load behavior (steady, peak, spike, soak) for a system with "no characterized load."
- Setting latency/throughput budgets and a false-positive/accuracy baseline.
- Producing a reliability/SRE backlog for a production-readiness harness.

## When Not to Use

- Running the load tests — hand the test matrix to the Azure Load Testing tools.
- Security, RAI, or privacy concerns — use the respective specialist skill.

## Inputs

Gather what exists; flag what is missing as an assumption to validate.

1. **Critical user journeys** — the flows that must stay fast (for example: incident ingest → display, dispatch action, alert acknowledge).
2. **Stated NFRs** — any latency/availability targets from a PRD (for example stratified SLAs like "Critical ≤ 60s, Standard ≤ 3min").
3. **Traffic assumptions** — expected and peak concurrency, request rates, and growth.
4. **Accuracy expectations** — false-positive tolerance where relevant (for example alerting).

## Procedure

1. **Identify SLIs.** For each critical journey pick measurable indicators: latency (p50/p95/p99), availability, error rate, and accuracy/false-positive rate where relevant.
2. **Set SLOs and error budgets.** For each SLI define a target, a measurement window, and the resulting error budget. Anchor to PRD NFRs when present; otherwise propose a target and mark it `[ASSUMPTION]` for tuning.
3. **Define the load model.** Specify steady-state, peak, spike, and soak profiles with concurrency/rate and duration for each.
4. **Build the test matrix.** Map each load profile to the journeys it exercises, the pass/fail SLO thresholds, and the environment.
5. **Plan capacity and degradation.** Note scaling assumptions, saturation points, and required graceful-degradation behavior (no silent fidelity drops).
6. **List observability hooks.** Name the metrics/traces needed to *measure* each SLI in production — an SLO you cannot measure is not real.
7. **Write the backlog** to `.copilot-tracking/performance-plans/<date>-performance-slo-plan.md` using the Output Format.

## Output Format

```markdown
# Performance & SLO Plan — <app>

## SLOs
| SLI         | Journey         | Target           | Window         | Error budget | Source             |
|-------------|-----------------|------------------|----------------|--------------|--------------------|
| p95 latency | dispatch action | ≤ 60s end-to-end | 28-day rolling | 1%           | NFR / [ASSUMPTION] |

## Load model
| Profile             | Concurrency / rate | Duration | Purpose  |
|---------------------|--------------------|----------|----------|
| Steady              | ...                | ...      | baseline |
| Peak / Spike / Soak | ...                | ...      | ...      |

## Test matrix
| Test | Profile | Journeys | Pass threshold | Env |
|------|---------|----------|----------------|-----|

## Observability hooks
- <metric/trace needed to measure each SLI>

## Backlog
1. <item> — priority, depends-on, SLO it protects
```

## Principles

- **Measurable or it's not an SLO.** Every target needs a defined SLI and a way to measure it in production.
- **Anchor to the PRD, mark the rest.** Use stated NFRs verbatim; flag proposed numbers `[ASSUMPTION]` for agency/environment tuning.
- **Plan, don't run.** Output a test matrix the Azure Load Testing tools can execute; do not execute here.
- **Degradation is a requirement.** Define what graceful degradation looks like, not just the happy path.
