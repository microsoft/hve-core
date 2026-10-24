// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { checklistFor } from '../checklists.mjs';

// Research content for the sample scenario. Repository paths are fictional; external
// claims cite public pages verified when the scenario was written.

export const evidence = [
    { id: 'C1', kind: 'code', claim: 'Form state lives only in component state, so a reload or crash loses the visit.', source: 'src/inspections/InspectionForm.tsx (useInspectionForm)', confidence: 'high' },
    { id: 'C2', kind: 'code', claim: 'PUT /inspections/:id returns an ETag header with each response.', source: 'src/api/inspections.ts (saveInspection)', confidence: 'high' },
    { id: 'C3', kind: 'code', claim: 'The server honors If-Match on inspection writes and answers 412 on a mismatch.', source: 'server/routes/inspections.ts (putInspection)', confidence: 'high' },
    { id: 'C4', kind: 'code', claim: 'Photo metadata responses carry weak ETags (W/ prefix).', source: 'server/routes/photos.ts (getPhotoMeta)', confidence: 'medium' },
    { id: 'C5', kind: 'code', claim: 'Three incidents in August lost a full site visit when two inspectors edited the same finding.', source: 'docs/incidents/2026-08-lost-edits.md', confidence: 'high' },
    { id: 'C6', kind: 'code', claim: 'A site visit averages 38 photos of 3 to 8 MB each.', source: 'docs/analytics/site-visit-photos.md', confidence: 'medium' },
    { id: 'C7', kind: 'code', claim: 'Inspectors on metered connections asked for a manual Sync now control.', source: 'support/tickets-summary.md (Q3 themes)', confidence: 'low' },
    { id: 'C8', kind: 'code', claim: '31 percent of inspectors use the installed web app on iOS Safari.', source: 'telemetry/browser-mix.md', confidence: 'medium' },
    { id: 'W1', kind: 'web', claim: 'Sites can request persistent storage with navigator.storage.persist(); Web Storage is limited to 10 MiB; private browsing usually deletes stored data when the session ends.', source: 'MDN: Storage quotas and eviction criteria', url: 'https://developer.mozilla.org/en-US/docs/Web/API/Storage_API/Storage_quotas_and_eviction_criteria', retrieved: '2026-10-23', confidence: 'high' },
    { id: 'W2', kind: 'web', claim: 'IndexedDB stores significant amounts of structured data, including files and blobs, in transactions.', source: 'MDN: IndexedDB API', url: 'https://developer.mozilla.org/en-US/docs/Web/API/IndexedDB_API', retrieved: '2026-10-23', confidence: 'high' },
    { id: 'W3', kind: 'web', claim: 'If-Match makes a PUT conditional and returns 412 Precondition Failed on a mismatch; weak ETags never match.', source: 'MDN: If-Match header', url: 'https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/If-Match', retrieved: '2026-10-23', confidence: 'high' },
    { id: 'W4', kind: 'web', claim: 'tus 1.0.0 is an open protocol for resumable uploads over HTTP.', source: 'tus: Resumable upload protocol', url: 'https://tus.io/protocols/resumable-upload', retrieved: '2026-10-23', confidence: 'high' },
    { id: 'W5', kind: 'web', claim: 'A polite live region is spoken when the user is idle; assertive interrupts and should be rare.', source: 'MDN: ARIA live regions', url: 'https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Guides/Live_regions', retrieved: '2026-10-23', confidence: 'high' },
];

export const questions = [
    { id: 'Q1', text: 'Where should drafts live while the device is offline?', status: 'answered', findings: ['F1', 'F6'] },
    { id: 'Q2', text: 'How should conflicting edits from two inspectors resolve?', status: 'answered', findings: ['F3'] },
    { id: 'Q3', text: 'Can the API detect concurrent writes today?', status: 'answered', findings: ['F2'] },
    { id: 'Q4', text: 'How should 3 to 8 MB photos upload on weak connections?', status: 'answered', findings: ['F4'] },
    { id: 'Q5', text: 'How should sync status be shown and announced?', status: 'answered', findings: ['F5', 'F7'] },
];

export const findings = [
    { id: 'F1', title: 'IndexedDB fits drafts with photos; Web Storage does not', state: 'evidence-backed', confidence: 'high', questions: ['Q1'], evidence: ['C1', 'W1', 'W2'] },
    { id: 'F2', title: 'The API already supports safe concurrent writes with ETags', state: 'evidence-backed', confidence: 'high', questions: ['Q3'], evidence: ['C2', 'C3', 'W3'] },
    { id: 'F3', title: 'Field-level merge resolves most conflicts, but same-field edits need a person', state: 'partially-supported', confidence: 'medium', questions: ['Q2'], evidence: ['C5', 'W3'] },
    { id: 'F4', title: 'Resumable chunks suit large photos on weak connections', state: 'evidence-backed', confidence: 'medium', questions: ['Q4'], evidence: ['C6', 'W4'] },
    { id: 'F5', title: 'Announce sync transitions politely, never each retry', state: 'evidence-backed', confidence: 'high', questions: ['Q5'], evidence: ['W5'] },
    { id: 'F6', title: 'Service worker background sync cannot replace the outbox', state: 'weakened', confidence: 'medium', questions: ['Q1'], evidence: ['C8'] },
    { id: 'F7', title: 'Inspectors may want a manual Sync now on metered connections', state: 'hypothesis', confidence: 'low', questions: ['Q5'], evidence: ['C7'] },
];

export const alternatives = [
    { option: 'IndexedDB repository with an outbox', benefits: 'Structured drafts and photo blobs in one transactional store; works offline everywhere the app runs', costs: 'A small repository layer and schema migrations', evidence: ['W2', 'C1'], disposition: 'selected' },
    { option: 'Web Storage (localStorage)', benefits: 'Simplest API', costs: '10 MiB limit and strings only; one visit of photos exceeds it', evidence: ['W1', 'C6'], disposition: 'rejected' },
    { option: 'SQLite in the browser over the origin private file system', benefits: 'Rich queries', costs: 'Adds a WebAssembly dependency the drafts do not need yet', evidence: ['W2'], disposition: 'deferred' },
    { option: 'Service worker background sync', benefits: 'Syncs after the tab closes', costs: 'Not available to the 31 percent of inspectors on iOS Safari', evidence: ['C8'], disposition: 'rejected' },
];

export const risks = [
    { id: 'R1', priority: 'H', type: 'risk', text: 'The browser may evict drafts under storage pressure', impact: 'Lost visits on full devices', action: 'Request persistent storage and warn when it is denied (P03-T02)', owner: 'downstream' },
    { id: 'R2', priority: 'M', type: 'open question', text: 'How often do two inspectors edit the same finding?', impact: 'Size of the conflict review work', action: 'Count same-field conflicts in the first two weeks', owner: 'downstream' },
    { id: 'R3', priority: 'L', type: 'further research', text: 'Whether a manual Sync now helps on metered connections (F7)', impact: 'Possible extra control', action: 'Ask five inspectors during the pilot', owner: 'research' },
];

export const lanes = [
    { id: 'L1', question: 'How much IndexedDB quota does an installed web app get on iOS?', status: 'running', effort: 'max', origin: null, findingId: 'F1' },
    { id: 'L2', question: 'Which existing helper already implements retry with backoff?', status: 'done', effort: 'low', origin: null, findingId: 'F2', summary: 'src/net/retry.ts exports retryWithBackoff and honors Retry-After.' },
];

export const decisions = [
    {
        id: 'D1', phase: 'research', owner: 'agent', status: 'decided', chosen: 'a', title: 'Store drafts in IndexedDB behind a small repository',
        question: 'Where should drafts and photos live while offline?',
        context: 'The form keeps everything in component state today (C1). IndexedDB holds structured data and blobs (W2); Web Storage stops at 10 MiB (W1).',
        rationale: 'IndexedDB is the only option that holds a full visit of photos and survives reloads in every browser the inspectors use.',
        impact: 'Defines P01 in the plan', evidence: ['C1', 'W1', 'W2'], anchor: { phase: 'research', rowId: 'F1' },
        options: [
            { id: 'a', label: 'IndexedDB repository', consequence: 'One store for drafts and photos', recommended: true, why: 'Fits the data and every target browser' },
            { id: 'b', label: 'SQLite over the origin private file system', consequence: 'Adds a WebAssembly dependency', recommended: false, why: '' },
        ],
    },
    {
        id: 'D2', phase: 'research', owner: 'user', status: 'needs-input', title: 'How should same-field conflicts resolve?',
        question: 'When two inspectors change the same field of the same finding while offline, what should happen when both sync?',
        context: 'Most conflicts touch different fields and merge cleanly. Same-field conflicts caused three lost visits in August (C5). The API can detect them with ETags (W3).',
        impact: 'Adds or removes the conflict review task (P02-T03)', evidence: ['C5', 'W3'], anchor: { phase: 'research', rowId: 'F3' },
        options: [
            { id: 'a', label: 'Merge per field; queue same-field conflicts for review', consequence: 'No silent loss; adds a conflict review screen', recommended: true, why: 'Matches the incident history and keeps inspectors in control' },
            { id: 'b', label: 'Last write wins per record', consequence: 'Simplest; can silently overwrite another inspector', recommended: false, why: '' },
            { id: 'c', label: 'Reject the write; the inspector re-enters changes', consequence: 'Safe but slow in the field', recommended: false, why: '' },
        ],
    },
    {
        id: 'D3', phase: 'research', owner: 'agent', status: 'decided', chosen: 'a', title: 'Upload photos in resumable chunks',
        question: 'How should photos upload on weak connections?',
        context: 'Photos run 3 to 8 MB and a visit averages 38 of them (C6). Resumable uploads continue from the last received byte (W4).',
        rationale: 'A dropped connection should cost one chunk, not a whole photo.',
        impact: 'Defines P03-T01', evidence: ['C6', 'W4'], anchor: { phase: 'research', rowId: 'F4' },
        options: [
            { id: 'a', label: 'Resumable chunks', consequence: 'Retries resume where they stopped', recommended: true, why: 'Large files on flaky links' },
            { id: 'b', label: 'One request per photo with retries', consequence: 'Simpler; retries resend the whole photo', recommended: false, why: '' },
        ],
    },
    {
        id: 'D4', phase: 'research', owner: 'user', status: 'answered', chosen: 'a', feedbackId: 'FB-001', title: 'Sync status wording',
        question: 'Which words should the status chip use?',
        context: 'Inspectors need to trust that nothing is lost while offline (C5). Announcements should be polite (W5).',
        impact: 'Sets the wording in FR-005 and P04-T01', evidence: ['C5', 'W5'], anchor: { phase: 'research', rowId: 'F5' },
        options: [
            { id: 'a', label: 'Saved on this device, Syncing, Synced', consequence: 'Reassures while offline', recommended: true, why: 'Names where the work is' },
            { id: 'b', label: 'Offline, Online', consequence: 'Describes the network, not the work', recommended: false, why: '' },
            { id: 'c', label: 'Pending (n), Up to date', consequence: 'Precise but technical', recommended: false, why: '' },
        ],
    },
];

export const feedback = [
    {
        id: 'FB-001', kind: 'answer', state: 'interpreted', target: { id: 'D4', type: 'decision', phase: 'research' }, optionId: 'a', optionLabel: 'Saved on this device, Syncing, Synced',
        text: 'Make it obvious that nothing is lost while offline.', delivery: 'queue', minutes: 18, sentMinutes: 15,
        interpretation: { text: 'Show "Saved on this device" while any change for this inspection is queued, "Syncing" during upload, and "Synced" once the server confirms. Announce only those three transitions, never each retry.', effect: 'Adds the wording to FR-005 and P04-T01', minutes: 9 },
    },
];

export const sections = {
    'research-summary': {
        title: 'Summary',
        markdown: [
            '**Bottom line:** Keep drafts in IndexedDB behind a small repository, queue every change in an outbox that syncs through the existing API with ETags, and upload photos in resumable chunks. Ask the browser for persistent storage so drafts are unlikely to be evicted.',
            '',
            '**Why this matters:** Inspectors lose work when the connection drops at remote sites; three incidents in August each lost a full visit.',
            '',
            '**Confidence:** High for storage and the API. Medium for conflict handling until the conflict decision is answered.',
        ].join('\n'),
    },
    'research-unknowns': {
        title: 'What you may not know',
        markdown: [
            '* Photo metadata may not use the same concurrency rules as inspections; only inspection writes were confirmed.',
            '* Browsers rarely evict data for sites people use regularly, but a full device can still lose best-effort storage. Persistent storage is a request, not a guarantee.',
            '* Background sync in a service worker would be simpler, but it is not available to about a third of the inspectors.',
        ].join('\n'),
    },
    'research-recommendation': {
        title: 'Recommendation',
        markdown: 'Build an IndexedDB draft store, an outbox sync engine with conditional writes, a conflict review step for same-field edits, and a resumable photo uploader. Revisit SQLite only if drafts need richer queries.',
    },
    'finding-f1': { title: 'IndexedDB fits drafts with photos; Web Storage does not', markdown: 'Today the form keeps every answer in component state, so a reload or crash loses the visit. IndexedDB stores structured objects and blobs in transactions, which matches a draft plus its photos. Web Storage holds strings only and stops at 10 MiB, less than one visit of photos.' },
    'finding-f2': { title: 'The API already supports safe concurrent writes with ETags', markdown: 'Every inspection response includes an ETag, and the server rejects a write whose `If-Match` no longer matches with `412 Precondition Failed`. The sync engine can detect a conflicting edit without any new endpoint.' },
    'finding-f3': { title: 'Field-level merge resolves most conflicts, but same-field edits need a person', markdown: 'Most concurrent edits touch different fields and can merge automatically. The August incidents were all same-field edits to a finding, where no rule can know which inspector is right. How those should resolve is your call (D2).' },
    'finding-f4': { title: 'Resumable chunks suit large photos on weak connections', markdown: 'Photos are large and numerous. A resumable protocol lets a retry continue from the last received byte, so a dropped connection costs seconds instead of a full re-upload.' },
    'finding-f5': { title: 'Announce sync transitions politely, never each retry', markdown: 'A polite live region speaks when the user is idle. Announcing every retry would flood screen reader users during a bad connection; announcing only the state changes keeps them informed.' },
    'finding-f6': { title: 'Service worker background sync cannot replace the outbox', markdown: 'Background sync would let changes upload after the tab closes, but about a third of inspectors use iOS Safari, where it is not available. The outbox has to work in the page either way.' },
    'finding-f7': { title: 'Inspectors may want a manual Sync now on metered connections', markdown: 'A few support tickets ask for control over when photos upload on metered connections. This is a hypothesis from a small sample, not a requirement yet.' },
};

export const checklist = checklistFor('research', ['R1', 'R2']);
