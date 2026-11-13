// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

// Review and follow-up content for the sample scenario. `minutes` values are offsets before now.

export const review = {
    execution: 'Complete',
    outcome: 'Defects found',
    depth: 'standard',
    passes: {
        acceptance: { execution: 'Complete', outcome: 'Defects found', depth: 'standard', findings: 5, artifact: null },
        refinement: { execution: 'Complete', outcome: 'Refinements identified', depth: 'standard', findings: 2, artifact: null },
    },
    findings: [
        {
            id: 'RV-001', kind: 'acceptance', severity: 'high', title: 'The outbox retries forever when an inspection was deleted on the server',
            summary: 'A deleted inspection answers 404, which the outbox treats as temporary, so its queued changes retry every 30 seconds indefinitely.',
            expected: 'A 404 or 410 for a deleted inspection stops retrying and tells the inspector what happened.',
            observed: 'src/offline/outbox.ts handleResponse treats 404 as transient; the item never leaves the queue.',
            impact: 'Battery and data drain on the device, and the inspector never learns the record is gone.',
            resolution: '404 and 410 are terminal; the item moves to Needs attention with a message; a test covers both.',
            route: 'rpi-implement', decision: 'accepted', related: ['P02-T01', 'CH-003'],
        },
        {
            id: 'RV-002', kind: 'acceptance', severity: 'medium', title: 'The sync status chip announces every retry',
            summary: 'The live region text changes on each retry attempt, so screen readers repeat "Syncing" during a bad connection.',
            expected: 'At most one announcement per transition (NFR-002).',
            observed: 'src/inspections/SyncStatus.tsx writes the attempt count into the live region.',
            impact: 'Screen reader users hear a stream of repeated announcements.',
            resolution: 'The live region changes only on state transitions; the attempt count moves to visible text outside it.',
            route: 'rpi-implement', decision: 'accepted', related: ['P04-T01', 'CH-008'],
        },
        {
            id: 'RV-003', kind: 'acceptance', severity: 'medium', title: 'Keep both cannot be chosen with a keyboard in conflict review',
            summary: 'Keep both is a clickable element without a button role, so keyboard users cannot reach it.',
            expected: 'Every choice in conflict review is reachable and operable with a keyboard.',
            observed: 'src/inspections/ConflictReview.tsx renders Keep both as a div with a click handler.',
            impact: 'Keyboard and screen reader users cannot keep both versions.',
            resolution: 'Keep both is a native button; a keyboard test covers all three choices.',
            route: 'rpi-implement', decision: 'accepted', related: ['P02-T03', 'CH-005'],
        },
        {
            id: 'RF-001', kind: 'refinement', dimension: 'Dependencies and SDKs', severity: 'medium', title: 'The outbox implements custom jitter backoff when retryWithBackoff already exists',
            summary: 'A bespoke timer loop duplicates the tested retry helper in src/net/retry.ts.',
            expected: 'src/offline/outbox.ts scheduleNext builds its own exponential timer, abort listener, and Retry-After parser.',
            observed: 'Delete scheduleNext and call retryWithBackoff from src/net/retry.ts.',
            impact: 'Removes 64 lines of duplicate timer state and one flaky fake-timer test suite.',
            resolution: 'outbox.ts uses retryWithBackoff and the duplicate backoff helper and test file are deleted.',
            route: 'rpi-plan', decision: 'accepted', related: ['P02-T01', 'CH-003'],
        },
        {
            id: 'RV-004', kind: 'acceptance', severity: 'low', title: 'The migration test skips the v1 to v3 path',
            summary: 'Tests cover v1 to v2 and v2 to v3 but not a device jumping from v1 straight to v3.',
            expected: 'Every supported upgrade path is tested.',
            observed: 'tests/offline/draft-store.test.ts has no v1 to v3 case.',
            impact: 'A device that skipped an update could fail to open its drafts.',
            resolution: 'A v1 to v3 migration test passes.',
            route: 'rpi-implement', decision: 'accepted', related: ['P01-T01', 'CH-001'],
        },
        {
            id: 'RF-002', kind: 'refinement', dimension: 'Documents and language', severity: 'low', title: 'Two offline sync notes duplicate the conflict rules in different folders',
            summary: 'Both docs/offline-notes.md and src/inspections/README.md restate merge precedence with slightly different wording.',
            expected: 'docs/offline-notes.md was added alongside src/inspections/README.md during P02.',
            observed: 'Remove docs/offline-notes.md and keep merge rules once in src/inspections/README.md.',
            impact: 'Prevents conflicting guidance when merge behavior changes later.',
            resolution: 'docs/offline-notes.md is removed and src/inspections/README.md holds the single merge table.',
            route: 'rpi-plan', decision: 'accepted', related: ['P02-T03', 'CH-005'],
        },
        {
            id: 'RV-005', kind: 'acceptance', severity: 'low', title: 'The README does not explain the persistent storage request',
            summary: 'Inspectors may see a browser prompt about storage with no explanation in the help.',
            expected: 'The help explains why the app asks to keep data on the device.',
            observed: 'README.md has no section on storage.',
            impact: 'Confusion at first use; low risk.',
            resolution: 'A short help section explains the request.',
            route: 'follow-up', decision: 'deferred', related: ['P03-T02', 'CH-007'],
        },
    ],
    history: [
        { id: 'RD-001', subject: 'Decision participation', status: 'agent-owned', owner: 'review parent', rationale: 'Review decisions are agent-owned in this session.', minutes: 16 },
        { id: 'RD-002', subject: 'Review execution', status: 'Complete', owner: 'review parent', rationale: 'Every requirement, task, and validation result was assessed.', minutes: 12 },
        { id: 'RD-003', subject: 'Outcome', status: 'Defects found', owner: 'review parent', rationale: 'Five acceptance findings inside the accepted direction; one High.', minutes: 12 },
        { id: 'RD-004', subject: 'RV-001', status: 'accepted', owner: 'rpi-plan', rationale: 'Infinite retries break FR-002 and waste battery.', minutes: 11 },
        { id: 'RD-005', subject: 'RV-002', status: 'accepted', owner: 'rpi-plan', rationale: 'Breaks NFR-002.', minutes: 11 },
        { id: 'RD-006', subject: 'RV-003', status: 'accepted', owner: 'rpi-plan', rationale: 'Keyboard access is required for conflict review.', minutes: 11 },
        { id: 'RD-007', subject: 'RV-004', status: 'accepted', owner: 'rpi-plan', rationale: 'A missing upgrade path can strand drafts.', minutes: 11 },
        { id: 'RD-008', subject: 'RV-005', status: 'deferred', owner: 'follow-up', rationale: 'Low impact; documentation only.', minutes: 10 },
        { id: 'FD-001', subject: 'Refinement execution', status: 'Complete', owner: 'refinement parent', rationale: 'Assessed all four subtractive lenses across touched code, tests, and docs.', minutes: 10 },
        { id: 'FD-002', subject: 'RF-001', status: 'accepted', owner: 'rpi-plan', rationale: 'Reusing retryWithBackoff removes custom timer state while fixing RV-001.', minutes: 9.5 },
        { id: 'FD-003', subject: 'RF-002', status: 'accepted', owner: 'rpi-plan', rationale: 'Deleting the extra note keeps merge rules in one place.', minutes: 9.5 },
        { id: 'RD-009', subject: 'Continuation', status: 'rpi-plan', owner: 'RPI Agent', rationale: 'Accepted findings RV-001 to RV-004 and RF-001 to RF-002 become a new P05 follow-up phase.', minutes: 9 },
    ],
    validation: [
        { check: 'npm test', scope: 'All units', status: 'passed', summary: '214 tests' },
        { check: 'npm run e2e -- offline-sync', scope: 'NFR-001', status: 'passed', summary: '50 of 50 airplane-mode cycles without loss' },
        { check: 'Keyboard pass over conflict review', scope: 'P02-T03', status: 'failed', summary: 'Keep both unreachable (RV-003)' },
        { check: 'Screen reader spot check', scope: 'FR-005', status: 'skipped', summary: 'Not run in this review' },
    ],
};

export const followUps = {
    items: [
        { rank: 1, id: 'FU-1', title: 'Plan P05 for RV-001 to RV-004 and RF-001 to RF-002', rationale: 'Required: acceptance fixes and subtractive retry/doc consolidations feed into a follow-up plan phase.', evidence: 'RV-001, RV-002, RV-003, RV-004, RF-001, RF-002', required: true, status: 'in-progress' },
        { rank: 2, id: 'FU-2', title: 'Explain the persistent storage request in the help', rationale: 'Optional: RV-005 was deferred as low impact.', evidence: 'RV-005', required: false, status: 'proposed' },
        { rank: 3, id: 'FU-3', title: 'Warn before private browsing discards drafts', rationale: 'Optional: discovered during implementation and outside this task.', evidence: 'DS-003, W1', required: false, status: 'proposed' },
        { rank: 4, id: 'FU-4', title: 'Use background sync where the browser supports it', rationale: 'Optional and out of scope: helps only some inspectors.', evidence: 'F6, C8', required: false, status: 'proposed' },
    ],
    tree: {
        key: null,
        date: null,
        name: 'Offline drafts with background sync',
        tasks: [
            { id: 'field-inspections-offline-sync', title: 'Offline drafts with background sync', status: 'completed', depth: 0, statePath: null, parent: null, shown: true, continues: null },
            { id: 'field-inspections-offline-sync-review-fixes', title: 'Fix RV-001 to RV-004 and simplify RF-001 to RF-002', status: 'running', depth: 1, statePath: null, parent: null, shown: false, continues: null },
        ],
    },
};

export const sections = {
    'review-summary': {
        title: 'Acceptance assessment',
        markdown: [
            '**Assessment:** The offline drafts, sync engine, conflict review, photo uploader, and status chip meet their requirements except for five defects: one High (endless retries for deleted inspections), two Medium (repeated announcements and a keyboard gap), and two Low.',
            '',
            '**Why this matters:** The High finding drains battery and hides a deleted record from the inspector; the Medium findings affect screen reader and keyboard users.',
        ].join('\n'),
    },
    'refinement-summary': {
        title: 'Refinement assessment',
        markdown: [
            '**Assessment:** Subtractive review across the touched sync, UI, test, and documentation files found two simplifications: replacing bespoke timer backoff in `outbox.ts` with the existing `retryWithBackoff` helper (`RF-001`), and removing a duplicate merge-rules note (`RF-002`).',
            '',
            '**Why this matters:** Dropping the custom timer loop cuts 64 lines of duplicate state while addressing `RV-001`, and keeping one merge-rules document avoids drift.',
        ].join('\n'),
    },
    'followup-summary': {
        title: 'Summary',
        markdown: 'Acceptance (`rpi-review`) and refinement (`rpi-refine`) findings are reconciled. Six accepted findings feed into planning for the next loop, while three optional items remain unscheduled.',
    },
};
