// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

// Test helper: a small synthetic RPI session shaped like the RPI templates, including the
// deviations real artifacts show (nested labeled fields, flat plan updates, ID ranges,
// pipes in fences and diagram labels). Kept in code rather than .md files so repository
// Markdown checks do not treat fixtures as documentation.
import fs from 'node:fs/promises';
import path from 'node:path';

import { assembleSession } from '../../lib/source/assemble.mjs';
import { parseChanges, parseCritique, parsePlan, parseResearch, parseReview, parseState } from '../../lib/source/parse.mjs';

const DAY = '2026-01-15';
const T = '.copilot-tracking';

export const ROOT_TASK = 'trail-maps';
export const CHILD_TASK = 'trail-maps-fixes';
export const STALE_TASK = 'old-task';

export const SESSION_KEY = `${DAY}/${ROOT_TASK}`;
export const STALE_SESSION_KEY = `2026-01-10/${STALE_TASK}`;

export const PATHS = {
    rootState: `${T}/rpi-sessions/${SESSION_KEY}/${ROOT_TASK}-state.json`,
    childState: `${T}/rpi-sessions/${SESSION_KEY}/${CHILD_TASK}-state.json`,
    staleState: `${T}/rpi-sessions/${STALE_SESSION_KEY}/${STALE_TASK}-state.json`,
    research: `${T}/research/${DAY}/${ROOT_TASK}-research.md`,
    plan: `${T}/plans/${DAY}/${ROOT_TASK}-plan.md`,
    critique: `${T}/reviews/plans/${DAY}/${ROOT_TASK}-plan-critique.md`,
    changes: `${T}/changes/${DAY}/${ROOT_TASK}-changes.md`,
    review: `${T}/reviews/logs/${DAY}/${ROOT_TASK}-review.md`,
    childPlan: `${T}/plans/${DAY}/${CHILD_TASK}-plan.md`,
    childChanges: `${T}/changes/${DAY}/${CHILD_TASK}-changes.md`,
};

const json = (value) => `${JSON.stringify(value, null, 2)}\n`;

export const ROOT_STATE = {
    task_id: ROOT_TASK,
    task_slug: ROOT_TASK,
    session_name: 'Offline trail maps',
    parent_task: null,
    child_tasks: [{ task_id: CHILD_TASK, task_slug: CHILD_TASK, state_path: PATHS.childState }],
    mode: 'automatic',
    active_phase: 'Follow-up',
    status: 'completed',
    session_status: 'running',
    artifact_paths: { research: PATHS.research, plan: PATHS.plan, critique: PATHS.critique, changes: PATHS.changes, review: PATHS.review },
    confirmed_decisions: [
        { decision: 'Automatic session scope', status: 'current', evidence: 'User request: offline trail maps.' },
        { decision: 'Review step', status: 'run', evidence: 'First task default' },
        { decision: 'Research disposition', status: 'executed', evidence: 'Research artifact' },
    ],
    blockers: [],
    next_action: { phase: 'Follow-up', action: `Child task ${CHILD_TASK} is running; reassess when it completes` },
    prioritized_follow_ups: [
        { rank: 1, task: `Fix review findings RV-001 and RV-002 (assigned to child ${CHILD_TASK})`, rationale: 'Required in-scope: both findings break FR-002', evidence: 'Review RD-003, RD-004' },
        { rank: 2, task: 'Cache map tiles for a second region', rationale: 'Optional; users asked for it once', evidence: 'Research R2' },
    ],
};

export const CHILD_STATE = {
    task_id: CHILD_TASK,
    task_slug: CHILD_TASK,
    session_name: 'Offline trail maps',
    parent_task: { task_id: ROOT_TASK, task_slug: ROOT_TASK, state_path: PATHS.rootState },
    child_tasks: [],
    mode: 'automatic',
    active_phase: 'Follow-up',
    status: 'completed',
    session_status: 'stopped',
    artifact_paths: { research: PATHS.review, plan: PATHS.childPlan, critique: null, changes: PATHS.childChanges, review: null },
    confirmed_decisions: [
        { decision: 'Research disposition', status: 'reused', evidence: 'The review record' },
        { decision: 'Review step', status: 'skip', evidence: 'Child-loop default' },
        { decision: 'Plan readiness', status: 'ready', evidence: 'Plan' },
    ],
    blockers: [],
    next_action: { phase: 'Follow-up', action: 'None required' },
    prioritized_follow_ups: [],
};

export const STALE_STATE = {
    task_id: STALE_TASK,
    task_slug: STALE_TASK,
    parent_task: null,
    mode: 'manual',
    active_phase: 'Plan',
    status: 'active',
    session_status: 'running',
    artifact_paths: { research: null, plan: null, critique: null, changes: null, review: null },
    confirmed_decisions: [],
    blockers: [{ id: 'B1', summary: 'Waiting on the map vendor', resolution: null }],
    next_action: { phase: 'Plan', action: 'Draft the plan' },
    follow_ups: [{ item: 'Ask the vendor about tile licensing', owner: 'user' }],
};

export const RESEARCH = `<!-- markdownlint-disable-file -->
# Task Research: Offline trail maps

| Field              | Value                    |
|--------------------|--------------------------|
| Date               | ${DAY}                   |
| Researcher / agent | rpi-research (RPI Agent) |
| Output mode        | convergence              |

## Executive Summary

* Bottom line: Store map tiles in IndexedDB and download one region at a time.
* Why this matters: Hikers lose the map when the signal drops.
* Research status: Complete.
* Confidence and uncertainty: High for storage; medium for tile licensing.

## What You May Not Know

* Tile licenses limit offline caching to 30 days.

## Findings

### Tiles fit in IndexedDB for one region

A region of 2,000 tiles takes about 40 MB, well within quota.

* Questions: Q1
* Evidence state: Evidence-backed finding
* Evidence: C1 to C3, W1
* Confidence and limits: High; measured on two devices.

| Region | Tiles | Size |
|--------|-------|------|
| Park   | 2,000 | 40 MB |

### Licenses allow 30 days of offline use

The vendor terms allow caching for 30 days.

* Questions: Q2
* Evidence state: Partially supported claim
* Evidence: W2
* Confidence and limits: Medium; the terms page is ambiguous.

## Recommendation and Alternatives

* Recommendation or decision state: Download by region into IndexedDB.
* Rationale: Fits the quota (C1).

| Option | Benefits | Costs and risks | Evidence | Disposition |
|--------|----------|-----------------|----------|-------------|
| IndexedDB by region | Fits quota | Needs a download step | C1, W1 | selected |
| Cache API | Simple | No metadata | C2 | rejected as primary; kept for icons |

## Scope and Questions

* Goal: Offline maps for one region.

| ID | Question | Source | Status |
|----|----------|--------|--------|
| Q1 | Where should tiles live offline? | Inferred | answered |
| Q2 | How long may tiles be cached? | Inferred | answered; renewal is a runtime check |
| Q3 | Can two regions share tiles? | Inferred | open |

## Decisions and Feedback

| Group | Decision or feedback item | Status | Owner | Rationale or input needed | Evidence | Impact of answer |
|-------|---------------------------|--------|-------|---------------------------|----------|------------------|
| D1 | Store tiles in IndexedDB by region | confirmed | agent | Fits the quota | C1 | Defines storage |
| D2 | Which region ships first? | input requested | user | Pick the park or the coast | W1 | Changes P01 |

## Risks and Open Questions

| Priority | Type | Risk, question, or research item | Impact | Smallest action or evidence needed | Owner |
|----------|------|----------------------------------|--------|------------------------------------|-------|
| H | risk | Quota eviction on full devices | Lost tiles | Call \`navigator.storage.persist()\` | downstream |
| M | further research | A second region | Scope | Ask users | deferred |

## Planning Readiness and Next Step

| Field | Record |
|-------|--------|
| Research disposition | executed |
| Planning Readiness | Ready: questions answered except Q3, which does not block |

## Research Record

### Evidence Log

| ID | Claim or finding | Source or location | Retrieved and version | Tool | Confidence | Notes |
|----|------------------|--------------------|-----------------------|------|------------|-------|
| C1 | Quota allows 40 MB per region | src/storage/quota.ts (estimate) | not applicable | read | High | |
| C2 | The \`Cache\` API has no **metadata** | src/sw/cache.ts | not applicable | read | Medium | |
| C3 | Tiles are 20 KB each | src/map/tiles.ts | not applicable | read | High | |
| W1 | IndexedDB quotas | [Storage quotas](https://developer.mozilla.org/docs/Web/API/Storage_API/Storage_quotas_and_eviction_criteria) | ${DAY} | external_research | High | |
| W2 | Tile terms | Vendor terms page, https://example.com/terms/tiles; checked twice | ${DAY} | external_research | Medium | |
`;

export const PLAN = `<!-- markdownlint-disable-file -->
# RPI Plan: Offline trail maps

## Task Metadata

* Task ID: ${ROOT_TASK}
* Task slug: ${ROOT_TASK}
* Plan date: ${DAY}

## Executive Summary

* Bottom line: Download a region's tiles into IndexedDB and draw from them offline.
  * Phase one stores tiles; phase two renders them.
* Planning result: Complete and Ready.

### What You May Not Know

* Tiles expire after 30 days.

## Phase Checklist

### Before

\`\`\`mermaid
%%{init: {"themeVariables": {"fontFamily": "Arial, Helvetica, sans-serif"}}}%%
flowchart LR
    map["Map view"]
    net["Tile server"]
    map -->|fetches| net
\`\`\`

### After

\`\`\`mermaid
flowchart LR
    map["Map view"]
    net["Tile server"]
    store["Added: tile store"]
    map -->|reads| store
    store -->|downloads| net
    classDef new stroke-dasharray: 5 5
    class store new
\`\`\`

The map reads tiles from a local store.

<!-- rpi:phase id=P01 -->
### [x] P01: Store tiles

Goals:
* Tiles for one region are stored on the device.

Dependencies:
* None

\`\`\`mermaid
flowchart LR
    store["Added: tile store"]
    net["Tile server"]
    store -->|downloads| net
\`\`\`

Highlighted work: \`store\`.

<!-- rpi:task id=P01-T01 -->
#### [x] P01-T01: Save tiles by region

Goals:
* A region downloads into IndexedDB.

Requirements:
* FR-001, NFR-001
* A partial download resumes:
  * from the last saved tile
  * without duplicates

Details:
* Use one object store per region.

  \`\`\`text
  region -> tiles | metadata
  \`\`\`

References:
* [src/storage/quota.ts](../../../src/storage/quota.ts): quota checks.

Dependencies:
* None

<!-- rpi:phase id=P02 -->
### [ ] P02: Draw offline

Goals:
* The map draws stored tiles without a network.

Dependencies:
* P01

<!-- rpi:task id=P02-T01 -->
#### [x] P02-T01: Read tiles from the store

Goals:
* The map asks the store first.

Requirements:
* FR-002

Details:
* Fall back to the network when online.

References:
* None

Dependencies:
* P01-T01

<!-- rpi:task id=P02-T02 -->
#### [ ] P02-T02: Show download progress

Goals:
* The user sees how much of a region is saved.

Requirements:
* FR-003, NFR-001

Details:
* Announce progress politely.

References:
* None

Dependencies:
* P01-T01

## User Decisions and Requirements

### Confirmed User Direction

* Offline maps for one region first.

### Planning Decisions and Feedback

| Group | Decision or feedback item | Status | Owner | Rationale or input needed | Evidence | Planning impact |
|-------|---------------------------|--------|-------|---------------------------|----------|-----------------|
| D1 | Adopt research decisions D1 and D2 | confirmed | agent | Evidence-backed | Research D1 | P01 |
| D2 | Progress announcements every 10 percent | confirmed | agent | Avoids noise | W1 | P02-T02 |

## Planning Readiness and Next Step

| Field | Record |
|-------|--------|
| Planning execution and readiness | Complete and Ready |
| Latest critique | Revise, resolved |

## Functional Requirements

* FR-001: A region downloads and resumes.
* FR-002: The map draws stored tiles offline.
* FR-003: Download progress is visible and announced.

## Non-Functional Requirements

* NFR-001: Accessibility meets WCAG 2.2 AA.
  * Objective threshold or evaluation condition: no axe violations.
  * Operating condition or verification approach, if needed: keyboard walk.

## Risks and Open Questions

| Priority | Type | Risk, question, or planning item | Affected work | Impact | Smallest action or evidence needed | Owner |
|----------|------|----------------------------------|---------------|--------|------------------------------------|-------|
| M | risk | Quota eviction | P01-T01 | Lost tiles | Persistent storage | implementer |

## Critique Disposition

* Critique setting and provenance: standard; first-task default
* Critique status: Complete
* Latest critique and verdict: Revise (2 findings, both resolved)

| Critique run and finding | Disposition | Action owner | Exact resolving evidence | Decision route | Plan response or residual risk |
|--------------------------|-------------|--------------|--------------------------|----------------|--------------------------------|
| PC-001 | resolved | planning parent | P01-T01 Requirements | planner | Added resume |
| PC-002 | accepted with risk | planning parent | Risk table | planner | Eviction stays a risk |

## Follow-Up Items

* Cache a second region. Owner: user.

## Handoff

* Authoritative implementation handoff: Planning Readiness and Next Step
`;

export const CRITIQUE = `<!-- markdownlint-disable-file -->
# RPI Plan Critique: Offline trail maps

## Metadata

* Task ID: ${ROOT_TASK}
* Critique depth: standard
* Critique execution: Complete

## Verdict

* Verdict: Revise
* Rationale: Resume is missing.

## Findings

<!-- rpi:critique id=PC-001 -->
### PC-001 [High]: Downloads cannot resume

* Related IDs: P01-T01, FR-001
* Evidence: The plan restarts a failed download.
* Concern: Hikers on weak signal never finish.
* Impact: FR-001 fails.
* Smallest useful change: Resume from the last tile.
* Action owner: planning parent
* Exact resolving evidence: P01-T01 Requirements
* Decision route: planner

<!-- rpi:critique id=PC-002 -->
### PC-002 [Low]: Eviction is not discussed

* Related IDs: P01, Risks
* Evidence: No risk row.
* Concern: Tiles vanish.
* Impact: Confusion offline.
* Smallest useful change: Add a risk row.
* Action owner: planning parent
* Exact resolving evidence: Risk table
* Decision route: planner
`;

export const CHANGES = `<!-- markdownlint-disable-file -->
# RPI Changes: Offline trail maps

## Metadata

* Task ID: ${ROOT_TASK}
* Implementation date: ${DAY}

## Execution Status

* Status: Complete
* Declared invocation scope: full plan
* Completed scope markers: P01, P01-T01, P02-T01
* All remaining active-plan markers: P02-T02
* Status basis: tests

## Execution Summary

Tiles download and draw offline; progress is still pending.

## Completed Work

### Regions download into the tile store and resume

* Related phase or task: P01-T01
* Files:
  * [src/storage/tiles.ts](../../../src/storage/tiles.ts)
  * [src/storage/quota.ts](../../../src/storage/quota.ts)
* Behavior or functionality changed:
  * A region downloads into IndexedDB.
  * A failed download resumes from the last tile.
* Validation:
  * \`npm test -- tiles\` passed.

### The map reads stored tiles first

* Related phase or task: P02-T01 (RV-002)
* Files:
  * [src/map/source.ts](../../../src/map/source.ts)
* Behavior or functionality changed: The map asks the store before the network.
* Validation: Manual airplane-mode check.

## Implementation-Time Plan Updates

* Tile size: tiles are 20 KB, not 15 KB, so a region is 40 MB.
* P02-T01 (descriptive): reads fall back to the network only when online.

## Business Alignment

* None

## Validation Record

| Check | Scope | Status | Evidence or reason |
|-------|-------|--------|--------------------|
| npm test -- tiles | P01-T01 | Passed | 12 tests |
| Airplane-mode check | P02-T01 | Passed with notes | Slow first draw |
| Device lab | P02 | Unavailable | Lab offline |

## Blockers

* None

## Remaining Work

* P02-T02

## Follow-Up Items

* Cache a second region; Owner: user
`;

export const REVIEW = `<!-- markdownlint-disable-file -->
# Review: Offline trail maps

## Executive Summary

* Assessment: Tiles work offline, with two defects.
* Why this matters: Hikers can lose a download.
* Review execution: Complete
* Assessed outcome: Defects found
* Validation coverage: Unit tests and a manual check.
* Confidence and limitations: High.

## What You May Not Know

* The device lab was offline.

## Findings and Proposed Routes

<!-- rpi:review id=RV-001 -->
### RV-001 [High]: A full disk leaves a half region

* Related scope: P01-T01; FR-001
* Expected behavior: A full disk stops the download and says so.
* Observed behavior and evidence:
  * The download stops silently.
  * src/storage/tiles.ts ignores \`QuotaExceededError\`.
* Impact: The map shows holes.
* Resolution condition: The user sees why the download stopped.
* Proposed destination: rpi-implement
* Smallest useful next action: Catch the error.

<!-- rpi:review id=RV-002 -->
### RV-002 [Medium]: The first offline draw is slow

* Related scope: P02-T01; CH-002
* Expected behavior: The first draw takes under a second.
* Observed behavior and evidence: It takes three seconds.
* Impact: The map looks broken.
* Resolution condition: Under one second on the test device.
* Proposed destination: rpi-implement
* Smallest useful next action: Index tiles by zoom.

## Parent Decision Record

<!-- Decisions live here. Append events; never rewrite the evidence body above to fit a decision. -->

### Current Disposition

* Based on events: RD-001 to RD-005
* Review execution: Complete
* Final outcome: Defects found

### Decision History

| Event | Subject | Decision source | Status or value | Proposed destination | Final destination | Owner | More information needed | Smallest next action | Rationale |
|-------|---------|-----------------|-----------------|----------------------|-------------------|-------|-------------------------|----------------------|-----------|
| RD-001 | Review execution | agent | Complete | none | none | review parent | none | Record outcome | All requirements assessed |
| RD-002 | Outcome | agent | Defects found | none | none | review parent | none | Return | Two defects |
| RD-003 | RV-001 | agent | accepted | rpi-implement | rpi-implement | child loop | none | Catch the error | Breaks FR-001 |
| RD-004 | RV-002 | agent | accepted | rpi-implement | rpi-implement | child loop | none | Index tiles | Breaks FR-002 |
| RD-005 | RV-001 to RV-002 | agent | resolved | none | none | RPI Agent | none | None | Child ${CHILD_TASK} fixed both |

## Validation Evidence

| Command | Scope | Status | Summary |
|---------|-------|--------|---------|
| npm test | All | Passed | 31 tests |
| Device lab | Offline | Skipped | Lab offline |

## Risks, Blockers, and Residual Work

* Blockers: none
* Residual work: a second region

## Review Record

### Critique and Follow-Up Assessment

| Follow-up item | Why outside immediate scope | Owner or next action | Assessment and route |
|----------------|-----------------------------|----------------------|----------------------|
| Second region | Not requested yet | user | optional |
`;

export const CHILD_PLAN = `<!-- markdownlint-disable-file -->
# RPI Plan: Offline trail maps review fixes

## Task Metadata

* Task ID: ${CHILD_TASK}
* Parent task: ${ROOT_TASK}

## Executive Summary

* Bottom line: Fix RV-001 and RV-002.

## Phase Checklist

<!-- rpi:phase id=P01 -->
### [x] P01: Fix the review findings

Goals:
* Both findings are resolved.

Dependencies:
* None

<!-- rpi:task id=P01-T01 -->
#### [x] P01-T01: Report a full disk

Goals:
* The user sees why a download stopped.

Requirements:
* FR-001

Details:
* Catch \`QuotaExceededError\`.

References:
* None

Dependencies:
* None

## User Decisions and Requirements

### Planning Decisions and Feedback

| Group | Decision or feedback item | Status | Owner | Rationale or input needed | Evidence | Planning impact |
|-------|---------------------------|--------|-------|---------------------------|----------|-----------------|
| D1 | Show the error in the download panel | confirmed | agent | Visible where the user looks | RV-001 | P01-T01 |

## Planning Readiness and Next Step

| Field | Record |
|-------|--------|
| Planning execution and readiness | Complete and Ready |

## Functional Requirements

* FR-001: The RV-001 resolution condition holds.
`;

export const CHILD_CHANGES = `<!-- markdownlint-disable-file -->
# RPI Changes: Offline trail maps review fixes

## Execution Status

* Status: Complete

## Completed Work

### A full disk is reported in the download panel

* Related phase or task: P01-T01 (RV-001)
* Files:
  * [src/storage/tiles.ts](../../../src/storage/tiles.ts)
* Behavior or functionality changed:
  * \`QuotaExceededError\` stops the download.
  * The panel says the device is full.
* Validation: \`npm test -- tiles\` passed.

## Implementation-Time Plan Updates

None yet.

## Validation Record

| Check | Scope | Status | Evidence or reason |
|-------|-------|--------|--------------------|
| npm test -- tiles | P01-T01 | Passed | 13 tests |

## Blockers

* None
`;

/** Every fixture file by workspace-relative path. */
export const FILES = {
    [PATHS.rootState]: json(ROOT_STATE),
    [PATHS.childState]: json(CHILD_STATE),
    [PATHS.staleState]: json(STALE_STATE),
    [PATHS.research]: RESEARCH,
    [PATHS.plan]: PLAN,
    [PATHS.critique]: CRITIQUE,
    [PATHS.changes]: CHANGES,
    [PATHS.review]: REVIEW,
    [PATHS.childPlan]: CHILD_PLAN,
    [PATHS.childChanges]: CHILD_CHANGES,
};

/** Workspace source files the fixture research cites as code evidence. */
export const SOURCE_FILES = {
    'src/storage/quota.ts': ['// Storage quota checks for offline regions.', 'export const REGION_LIMIT_MB = 40;', '', 'export async function estimate() {', '    return navigator.storage.estimate();', '}', ''].join('\n'),
    'src/sw/cache.ts': ['// The service worker cache keeps responses without metadata.', 'export const CACHE_NAME = \'tiles-v1\';', ''].join('\n'),
    'src/map/tiles.ts': ['// Map tiles are about 20 KB each.', 'export const TILE_BYTES = 20 * 1024;', ''].join('\n'),
};

/**
 * Writes the fixture session and the source files its research cites under `root`, and
 * dates the stale state file a few days back, so the newest running session is the trail
 * maps one.
 *
 * @param {string} root
 */
export async function writeFixtureWorkspace(root) {
    for (const [relative, content] of Object.entries({ ...FILES, ...SOURCE_FILES })) {
        const target = path.join(root, relative);
        await fs.mkdir(path.dirname(target), { recursive: true });
        await fs.writeFile(target, content);
    }
    const old = new Date(Date.now() - 5 * 24 * 3600 * 1000);
    await fs.utimes(path.join(root, PATHS.staleState), old, old);
    return root;
}

/** Clock the assembled fixture documents use. */
export const FIXTURE_NOW = '2026-01-15T12:00:00.000Z';

/** The root task assembled from every fixture artifact, with a child loop in its lineage. */
export const rootSession = () => assembleSession({
    id: 'rpi-trail-maps',
    state: parseState(ROOT_STATE),
    artifacts: { research: parseResearch(RESEARCH), plan: parsePlan(PLAN), critique: parseCritique(CRITIQUE), changes: parseChanges(CHANGES), review: parseReview(REVIEW) },
    statePath: PATHS.rootState,
    files: { plan: { path: PATHS.plan, mtimeMs: Date.parse('2026-01-15T10:00:00Z') } },
    tree: {
        key: SESSION_KEY,
        date: DAY,
        name: 'Offline trail maps',
        tasks: [
            { id: ROOT_TASK, title: 'Offline trail maps', status: 'completed', depth: 0, statePath: PATHS.rootState, parent: null, shown: true, continues: null },
            { id: CHILD_TASK, title: 'Offline trail maps review fixes', status: 'completed', depth: 1, statePath: PATHS.childState, parent: PATHS.rootState, shown: false, continues: null },
        ],
    },
    git: { repository: 'contoso/trails', branch: 'feat/offline' },
    root: '/work/trails',
    now: FIXTURE_NOW,
});

/** The child loop: reused research, its own plan and changes, and Review skipped. */
export const childSession = () => assembleSession({
    id: 'rpi-trail-maps-fixes',
    state: parseState(CHILD_STATE),
    artifacts: { plan: parsePlan(CHILD_PLAN), changes: parseChanges(CHILD_CHANGES) },
    mismatched: [{ key: 'research', path: PATHS.review, kind: 'review' }],
    statePath: PATHS.childState,
    tree: {
        key: SESSION_KEY,
        date: DAY,
        name: 'Offline trail maps',
        tasks: [
            { id: ROOT_TASK, title: 'Offline trail maps', status: 'completed', depth: 0, statePath: PATHS.rootState, parent: null, shown: false, continues: null },
            { id: CHILD_TASK, title: 'Offline trail maps review fixes', status: 'completed', depth: 1, statePath: PATHS.childState, parent: PATHS.rootState, shown: true, continues: null },
        ],
    },
    now: FIXTURE_NOW,
});

/**
 * A task whose state file names no artifacts, so every list is empty and every optional
 * value is absent. At Follow-up, every earlier phase counts as reached and renders.
 *
 * @param {string} activePhase state file phase, such as `Research` or `Follow-up`.
 */
export const minimalSession = (activePhase) => assembleSession({
    id: 'rpi-bare-task',
    state: parseState({ task_id: 'bare-task', task_slug: 'bare-task', parent_task: null, mode: 'manual', active_phase: activePhase, status: 'active', session_status: null, artifact_paths: { research: null, plan: null, critique: null, changes: null, review: null }, confirmed_decisions: null, blockers: null, next_action: null, prioritized_follow_ups: null }),
    artifacts: {},
    statePath: `${T}/rpi-sessions/${DAY}/bare-task/bare-task-state.json`,
    now: FIXTURE_NOW,
});
