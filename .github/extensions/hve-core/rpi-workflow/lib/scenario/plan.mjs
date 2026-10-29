// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

// Plan content for the sample scenario.

import { taggedPhaseParts } from '../source/assemble.mjs';

const task = (id, title, goals, requirements, details, dependencies, references = []) => ({
    id, title, goals, requirements, details, dependencies, references, status: 'todo', sectionId: `task-${id.toLowerCase()}`,
});

export const phases = [
    {
        id: 'P01', title: 'Keep drafts on the device', goals: 'Every answer and photo survives reloads, crashes, and dead zones.', status: 'todo',
        tasks: [
            task('P01-T01', 'Store drafts with versioned schema migrations', 'A draft store keeps inspections and photos in IndexedDB and upgrades older schemas in place.', ['FR-001', 'NFR-003'], ['Wrap IndexedDB in a repository with get, put, list, and delete.', 'Version the schema; migrate v1 to v2 and test every path.'], [], ['src/offline/', 'W2']),
            task('P01-T02', 'Autosave the inspection form', 'Every change to the form is saved to the draft store within half a second.', ['FR-001'], ['Debounce saves; never block typing.', 'Restore the draft when the form opens.'], ['P01-T01'], ['src/inspections/InspectionForm.tsx']),
        ],
    },
    {
        id: 'P02', title: 'Sync drafts through an outbox', goals: 'Changes upload automatically when a connection returns, and conflicting edits never overwrite silently.', status: 'todo',
        tasks: [
            task('P02-T01', 'Queue changes and retry with backoff', 'Saved changes enter an outbox that retries with backoff and stops on client errors.', ['FR-002', 'NFR-001'], ['Reuse the existing retry helper.', 'Stop and surface 4xx responses other than 408 and 429.'], ['P01-T01'], ['src/net/retry.ts']),
            task('P02-T02', 'Send conditional writes with ETags', 'Each inspection write carries If-Match and marks the record conflicted on 412.', ['FR-002', 'FR-003'], ['Store the last ETag with each record.', 'A 412 moves the record to conflict review instead of retrying.'], ['P02-T01'], ['src/api/inspections.ts', 'W3']),
            task('P02-T03', 'Review same-field conflicts', 'Inspectors see both versions of a conflicting field and choose one or keep both.', ['FR-003'], ['Show conflicts in a Review tab inside the inspection.', 'Keyboard and screen reader access for every choice.'], ['P02-T02']),
        ],
    },
    {
        id: 'P03', title: 'Upload photos reliably', goals: 'Photos reach the server even on flaky connections, and storage limits never lose work.', status: 'todo',
        tasks: [
            task('P03-T01', 'Upload photos in resumable chunks', 'Photos upload in chunks that resume after a dropped connection.', ['FR-004'], ['Upload in 1 MB chunks with offsets.', 'Write photo metadata after the last chunk.'], ['P02-T01'], ['W4']),
            task('P03-T02', 'Handle storage quota and persistence', 'The app asks for persistent storage and warns before the device runs out of room.', ['FR-001', 'NFR-003'], ['Request persistent storage on first draft.', 'Warn at 80 percent of the estimated quota.'], ['P01-T01'], ['W1']),
        ],
    },
    {
        id: 'P04', title: 'Show sync status and prove it offline', goals: 'Inspectors always know where their work is, and the whole flow is proven offline.', status: 'todo',
        tasks: [
            task('P04-T01', 'Show sync status and announce transitions', 'A status chip shows Saved on this device, Syncing, or Synced and announces only transitions.', ['FR-005', 'NFR-002'], ['One polite live region for the chip.', 'No announcement per retry.'], ['P02-T01'], ['W5']),
            task('P04-T02', 'Test the whole flow offline', 'An end-to-end suite runs 50 airplane-mode cycles without losing data.', ['NFR-001'], ['Run on desktop Chromium and the iOS simulator.'], ['P02-T03', 'P03-T01']),
        ],
    },
];

export const requirements = [
    { id: 'FR-001', kind: 'FR', text: 'Drafts survive reloads, crashes, and offline periods.' },
    { id: 'FR-002', kind: 'FR', text: 'Changes sync automatically when a connection returns.' },
    { id: 'FR-003', kind: 'FR', text: 'Same-field conflicts never overwrite silently; they wait for a person.' },
    { id: 'FR-004', kind: 'FR', text: 'Photo uploads resume after dropped connections instead of starting over.' },
    { id: 'FR-005', kind: 'FR', text: 'Inspectors can see and hear sync status: Saved on this device, Syncing, Synced.' },
    { id: 'NFR-001', kind: 'NFR', text: 'No data loss across 50 airplane-mode cycles in the end-to-end suite.' },
    { id: 'NFR-002', kind: 'NFR', text: 'At most one status announcement per transition.' },
    { id: 'NFR-003', kind: 'NFR', text: 'An inspection with 40 photos opens its draft in under 200 ms.' },
];

const before = [
    'flowchart LR',
    '    accTitle: Before: inspections save straight to the server',
    '    accDescr: The form saves through the API client and the photo picker uploads whole photos, so work done in a dead zone is lost.',
    '    subgraph inspections["`<code>src/inspections/</code>`"]',
    '        form["`**<code>InspectionForm.tsx</code>**',
    '        saves only when online',
    '        changed · P01`"]',
    '        picker["`**Photo picker**',
    '        uploads whole photos',
    '        changed · P03`"]',
    '    end',
    '    subgraph client["`<code>src/api/inspections.ts</code>`"]',
    '        api["`**<code>saveInspection()</code>**',
    '        changed · P02`"]',
    '    end',
    '    server["Inspections API"]',
    '    form -->|saves via| api',
    '    api -->|PUT| server',
    '    picker -->|uploads to| server',
    '    classDef changed stroke-width:3px',
    '    class form,picker,api changed',
].join('\n');

const after = [
    'flowchart LR',
    '    accTitle: After: drafts stay on the device and sync through an outbox',
    '    accDescr: The form autosaves to a draft store; an outbox and sync engine send changes when a connection returns and flag conflicts, and photos upload in resumable chunks.',
    '    subgraph inspections["`<code>src/inspections/</code>`"]',
    '        form["`**<code>InspectionForm.tsx</code>**',
    '        autosaves every change',
    '        changed · P01`"]',
    '        picker["`**Photo picker**',
    '        queues photos',
    '        changed · P03`"]',
    '        conflicts["`**Conflict review**',
    '        new · P02`"]',
    '        status["`**Sync status chip**',
    '        new · P04`"]',
    '    end',
    '    subgraph offline["`<code>src/offline/</code>',
    '    new folder · P01`"]',
    '        store["`**Draft store**',
    '        new · P01`"]',
    '        outbox["`**Outbox**',
    '        new · P02`"]',
    '        sync["`**Sync engine**',
    '        new · P02`"]',
    '        uploader["`**Chunk uploader**',
    '        new · P03`"]',
    '    end',
    '    subgraph client["`<code>src/api/inspections.ts</code>`"]',
    '        api["`**<code>saveInspection()</code>**',
    '        sends If-Match',
    '        changed · P02`"]',
    '    end',
    '    server["Inspections API"]',
    '    form -->|autosaves to| store',
    '    store -->|enqueues| outbox',
    '    sync -->|drains| outbox',
    '    sync -->|If-Match PUT| api',
    '    api -->|PUT| server',
    '    sync -->|flags| conflicts',
    '    picker -->|queues| uploader',
    '    uploader -->|chunks to| server',
    '    status -->|reads| sync',
    '    classDef new stroke-dasharray: 6 4,stroke-width:2px',
    '    classDef changed stroke-width:3px',
    '    class offline,store,outbox,sync,uploader,conflicts,status new',
    '    class form,picker,api changed',
].join('\n');

// Each phase's parts come from the map's tags, as they do for a real plan.
export const diagram = { before, after, phaseNodes: taggedPhaseParts({ phases, before, after }, []), tagged: true };

export const critique = {
    status: 'Complete', verdict: 'Revise', setting: 'standard',
    findings: [
        { id: 'PC-001', severity: 'high', title: 'Outbox retries have no stop for client errors', disposition: 'resolved', related: ['P02-T01'], response: 'P02-T01 now stops on 4xx other than 408 and 429.' },
        { id: 'PC-002', severity: 'medium', title: 'No migration test from schema v1 to v2', disposition: 'resolved', related: ['P01-T01'], response: 'P01-T01 tests every migration path.' },
        { id: 'PC-003', severity: 'medium', title: 'Quota errors have no message for the inspector', disposition: 'resolved', related: ['P03-T02'], response: 'P03-T02 warns at 80 percent.' },
        { id: 'PC-004', severity: 'low', title: 'FR-005 is cited by no task', disposition: 'resolved', related: ['FR-005', 'P04-T01'], response: 'P04-T01 cites FR-005.' },
        { id: 'PC-005', severity: 'low', title: 'The retry helper path is wrong', disposition: 'resolved', related: ['P02-T01'], response: 'Corrected to src/net/retry.ts.' },
    ],
};

export const decisions = [
    {
        id: 'D5', phase: 'plan', owner: 'user', status: 'needs-input', title: 'Where should conflict review live?',
        question: 'Inspectors need a place to resolve same-field conflicts. Where should it be?',
        context: 'You chose to queue same-field conflicts for review (D2). Conflicts are rare, so the review should be easy to find without adding a new screen for most inspectors.',
        impact: 'Shapes P02-T03', evidence: ['C5'], anchor: { phase: 'plan', rowId: 'P02-T03' },
        options: [
            { id: 'a', label: 'A Review tab inside the inspection', consequence: 'Conflicts appear where the work is', recommended: true, why: 'Keeps the context of the visit' },
            { id: 'b', label: 'A global Needs review inbox', consequence: 'Easier to triage many inspections; loses context', recommended: false, why: '' },
        ],
    },
    {
        id: 'D7', phase: 'plan', owner: 'agent', status: 'decided', chosen: 'a', title: 'Sync one record per request until a batch endpoint exists',
        question: 'How should the outbox send many queued changes?',
        context: 'The API has no batch endpoint (C2). Most outboxes hold a handful of records.',
        rationale: 'Per-record requests work today and keep failures isolated; a batch endpoint needs server work outside this task.',
        impact: 'Shapes P02-T01', evidence: ['C2'], anchor: { phase: 'plan', rowId: 'P02-T01' },
        options: [
            { id: 'a', label: 'One request per record', consequence: 'Works today; more requests', recommended: true, why: 'No server change' },
            { id: 'b', label: 'Add a batch endpoint', consequence: 'Fewer requests; needs API work first', recommended: false, why: '' },
        ],
    },
];

export const sections = {
    'plan-summary': {
        title: 'Summary',
        markdown: [
            '**Bottom line:** Four phases add an on-device draft store, an outbox that syncs with conditional writes and sends same-field conflicts to review, a resumable photo uploader, and an accessible sync status, proven by an offline end-to-end suite.',
            '',
            '**Why this matters:** Inspectors stop losing visits, and they can see where their work is at every moment.',
        ].join('\n'),
    },
    'plan-unknowns': {
        title: 'What you may not know',
        markdown: [
            '* The API has no batch endpoint, so the outbox sends one record per request for now (D7).',
            '* Conflict review is the only new screen; everything else lives inside the existing inspection form.',
        ].join('\n'),
    },
};

for (const phase of phases) {
    for (const item of phase.tasks) {
        sections[item.sectionId] = { title: item.title, markdown: item.details.map((line) => `* ${line}`).join('\n') };
    }
}
