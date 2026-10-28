// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

// Implementation content for the sample scenario. `minutes` values are offsets before now.

export const activity = [
    { kind: 'read', text: 'Read src/api/inspections.ts and server/routes/inspections.ts', minutes: 14 },
    { kind: 'edit', text: 'Edited src/offline/sync-engine.ts (+64 -3)', minutes: 11 },
    { kind: 'test', text: 'Ran npm test -- sync-engine: 18 passed, 1 failed', minutes: 7 },
    { kind: 'think', text: 'A 412 response should mark the record as conflicted instead of retrying', minutes: 5 },
    { kind: 'edit', text: 'Edited src/offline/sync-engine.ts (+12 -4)', minutes: 2 },
];

const retryDiff = [
    '@@ -18,9 +18,19 @@ export async function retryWithBackoff(run, options = {}) {',
    '   const { attempts = 5, baseMs = 500 } = options;',
    '   for (let attempt = 1; attempt <= attempts; attempt += 1) {',
    '     const response = await run();',
    '-    if (response.ok) return response;',
    '+    if (response.ok) {',
    '+      return response;',
    '+    }',
    '+    if (isClientError(response.status)) {',
    '+      throw new RetryStoppedError(response.status);',
    '+    }',
    '     await delay(backoff(attempt, baseMs, response.headers.get("Retry-After")));',
    '   }',
    ' }',
    '+',
    '+const isClientError = (status) => status >= 400 && status < 500 && status !== 408 && status !== 429;',
].join('\n');

const formDiff = [
    '@@ -12,7 +12,14 @@ export function InspectionForm({ inspectionId }) {',
    '-  const [values, setValues] = useState(emptyInspection);',
    '+  const { values, setValues, restored } = useDraft(inspectionId, emptyInspection);',
    '+',
    '+  useEffect(() => {',
    '+    if (restored) {',
    '+      announce("Draft restored from this device");',
    '+    }',
    '+  }, [restored]);',
    ' ',
    '   return (',
    '     <form onChange={(event) => setValues(read(event.currentTarget))}>',
].join('\n');

const storeDiff = [
    '@@ -0,0 +1,12 @@',
    '+const DB_NAME = "drafts-v1";',
    '+const VERSION = 2;',
    '+',
    '+export async function openDraftStore() {',
    '+  return openDB(DB_NAME, VERSION, {',
    '+    upgrade(db, oldVersion) {',
    '+      for (const migrate of migrations.slice(oldVersion)) {',
    '+        migrate(db);',
    '+      }',
    '+    },',
    '+  });',
    '+}',
].join('\n');

export const changes = [
    {
        id: 'CH-001', taskId: 'P01-T01', title: 'Drafts persist on the device with a versioned schema',
        behavior: 'Inspections and photos now live in an IndexedDB draft store that upgrades older schemas in place, so a reload or crash no longer loses a visit.',
        files: [
            { path: 'src/offline/draft-store.ts', kind: 'added', additions: 142, deletions: 0, diff: storeDiff },
            { path: 'src/offline/migrations.ts', kind: 'added', additions: 58, deletions: 0, diff: '' },
            { path: 'tests/offline/draft-store.test.ts', kind: 'added', additions: 96, deletions: 0, diff: '' },
        ],
        validation: [
            { check: 'npm test -- draft-store', status: 'passed', summary: '24 tests' },
            { check: 'npm run typecheck', status: 'passed', summary: 'No errors' },
        ],
        minutes: 95,
    },
    {
        id: 'CH-002', taskId: 'P01-T02', title: 'The inspection form saves every change as you type',
        behavior: 'The form autosaves to the draft store half a second after each change and restores the draft when it opens, announcing the restore once.',
        files: [
            { path: 'src/inspections/InspectionForm.tsx', kind: 'modified', additions: 31, deletions: 8, diff: formDiff },
            { path: 'src/offline/use-draft.ts', kind: 'added', additions: 47, deletions: 0, diff: '' },
        ],
        validation: [
            { check: 'npm test -- InspectionForm', status: 'passed', summary: '12 tests' },
            { check: 'Manual airplane-mode check', status: 'passed', summary: 'Draft restored after an offline reload' },
        ],
        minutes: 64,
    },
    {
        id: 'CH-003', taskId: 'P02-T01', title: 'Queued changes retry with backoff and stop on client errors',
        behavior: 'Saved changes enter an outbox that retries with exponential backoff, honors Retry-After, and stops on client errors other than 408 and 429 so a bad request is surfaced instead of repeated.',
        files: [
            { path: 'src/offline/outbox.ts', kind: 'added', additions: 118, deletions: 0, diff: '' },
            { path: 'src/net/retry.ts', kind: 'modified', additions: 12, deletions: 2, diff: retryDiff },
            { path: 'tests/offline/outbox.test.ts', kind: 'added', additions: 88, deletions: 0, diff: '' },
        ],
        validation: [
            { check: 'npm test -- outbox', status: 'passed', summary: '31 tests' },
            { check: 'npm run lint', status: 'passed', summary: 'No findings' },
        ],
        minutes: 31,
    },
];

/** Entries that appear once implementation finishes (review and follow-up stages). */
export const laterChanges = [
    { id: 'CH-004', taskId: 'P02-T02', title: 'Inspection writes are conditional and conflicts stop retrying', behavior: 'Each write sends If-Match with the stored ETag; a 412 marks the record conflicted and sends it to review.', files: [{ path: 'src/offline/sync-engine.ts', kind: 'added', additions: 176, deletions: 0, diff: '' }], validation: [{ check: 'npm test -- sync-engine', status: 'passed', summary: '19 tests' }], minutes: 50 },
    { id: 'CH-005', taskId: 'P02-T03', title: 'Inspectors resolve same-field conflicts in a Review tab', behavior: 'A Review tab inside the inspection shows both versions of each conflicting field with Keep mine, Keep theirs, and Keep both.', files: [{ path: 'src/inspections/ConflictReview.tsx', kind: 'added', additions: 134, deletions: 0, diff: '' }], validation: [{ check: 'npm test -- ConflictReview', status: 'passed', summary: '9 tests' }], minutes: 44 },
    { id: 'CH-006', taskId: 'P03-T01', title: 'Photos upload in resumable 1 MB chunks', behavior: 'Photos upload in chunks that resume from the last confirmed offset; metadata writes use the record version field.', files: [{ path: 'src/offline/chunk-uploader.ts', kind: 'added', additions: 151, deletions: 0, diff: '' }], validation: [{ check: 'npm test -- chunk-uploader', status: 'passed', summary: '15 tests' }], minutes: 38 },
    { id: 'CH-007', taskId: 'P03-T02', title: 'The app requests persistent storage and warns before the device fills', behavior: 'The first draft requests persistent storage; a banner warns at 80 percent of the estimated quota.', files: [{ path: 'src/offline/quota.ts', kind: 'added', additions: 62, deletions: 0, diff: '' }], validation: [{ check: 'npm test -- quota', status: 'passed', summary: '6 tests' }], minutes: 33 },
    { id: 'CH-008', taskId: 'P04-T01', title: 'A sync status chip shows and announces where the work is', behavior: 'The chip shows Saved on this device, Syncing, or Synced and announces transitions through one polite live region.', files: [{ path: 'src/inspections/SyncStatus.tsx', kind: 'added', additions: 58, deletions: 0, diff: '' }], validation: [{ check: 'npm test -- SyncStatus', status: 'passed', summary: '7 tests' }], minutes: 27 },
    { id: 'CH-009', taskId: 'P04-T02', title: 'An offline end-to-end suite proves no data loss', behavior: 'Fifty airplane-mode cycles on desktop Chromium and the iOS simulator finish without losing a field or photo.', files: [{ path: 'e2e/offline-sync.spec.ts', kind: 'added', additions: 210, deletions: 0, diff: '' }], validation: [{ check: 'npm run e2e -- offline-sync', status: 'passed', summary: '50 of 50 cycles' }], minutes: 21 },
];

export const discoveries = [
    { id: 'DS-001', kind: 'local', title: 'Named the store drafts-v1 to leave room for migrations', detail: 'The version number lives in the schema, not the name, so later migrations keep the same database.', taskId: 'P01-T01', decisionId: null, planUpdate: null, minutes: 92 },
    { id: 'DS-002', kind: 'annotation', title: 'Photo uploads can reuse the retry helper', detail: 'src/net/retry.ts already honors Retry-After; P03-T01 now names it.', taskId: 'P03-T01', decisionId: null, planUpdate: { area: 'P03-T01 Guidance', before: '', after: 'Reuse retryWithBackoff from src/net/retry.ts; it already honors Retry-After.' }, minutes: 30 },
    { id: 'DS-003', kind: 'follow-up', title: 'Private browsing deletes drafts when the window closes', detail: 'Browsers usually delete stored data when a private session ends (W1). Warning inspectors is outside this task, so it is a follow-up.', taskId: 'P03-T02', decisionId: null, planUpdate: null, minutes: 26 },
    { id: 'DS-004', kind: 'plan-change', title: 'Photo metadata returns weak ETags, so If-Match never matches', detail: 'Photo metadata responses carry W/ ETags (C4), and If-Match uses strong comparison, which never matches a weak tag (W3). Conditional photo writes would always fail with 412.', taskId: 'P03-T01', decisionId: 'D6', planUpdate: { area: 'P03-T01 Requirements', before: 'Photo metadata writes send If-Match with the photo ETag.', after: 'Photo metadata writes send the record version field; inspection writes keep If-Match. Pending D6.' }, minutes: 6 },
];

export const alignment = [
    {
        id: 'AL-001', source: 'docs/product/offline-drafts-prd.md', document: 'PRD-2026-014', status: 'approved', requirement: 'FR-7 Every write uses optimistic concurrency',
        owner: 'Field apps product team', marker: 'P03-T01', change: 'Photo metadata writes use the record version field instead of ETags.',
        why: 'The photo API returns weak ETags, which If-Match never matches (DS-004).', decision: 'D6', alignment: 'pending-decision',
    },
];

export const validation = [
    { check: 'npm test -- draft-store', scope: 'P01-T01', status: 'passed', summary: '24 tests' },
    { check: 'npm test -- InspectionForm', scope: 'P01-T02', status: 'passed', summary: '12 tests' },
    { check: 'Manual airplane-mode check', scope: 'P01-T02', status: 'passed', summary: 'Draft restored after an offline reload' },
    { check: 'npm test -- outbox', scope: 'P02-T01', status: 'passed', summary: '31 tests' },
    { check: 'npm test -- sync-engine', scope: 'P02-T02', status: 'failed', summary: '18 passed, 1 failed: 412 handling in progress' },
    { check: 'iOS simulator run', scope: 'P04-T02', status: 'unavailable', summary: 'The device lab is offline until Friday' },
];

export const blockers = [
    { id: 'B1', taskId: 'P04-T02', text: 'The device lab iOS simulators are offline until Friday.', owner: 'QA', clear: 'Rerun the offline suite when the lab returns.' },
];

export const taskStatus = {
    'P01-T01': 'done', 'P01-T02': 'done', 'P02-T01': 'done', 'P02-T02': 'in-progress', 'P02-T03': 'todo',
    'P03-T01': 'paused', 'P03-T02': 'todo', 'P04-T01': 'todo', 'P04-T02': 'blocked',
};

export const decisions = [
    {
        id: 'D6', phase: 'implement', owner: 'user', status: 'needs-input', title: 'How should photo metadata writes stay safe?',
        question: 'Photo metadata returns weak ETags, so conditional writes would always fail. How should those writes guard against overwriting?',
        context: 'Inspection writes are unaffected. Photo uploads (P03-T01) are paused until this is decided. The product requirement asks for optimistic concurrency on every write.',
        impact: 'Unpauses P03-T01 and updates its Requirements', evidence: ['C4', 'W3'], anchor: { phase: 'implement', rowId: 'DS-004' },
        options: [
            { id: 'a', label: 'Use the record version field for photo metadata', consequence: 'Works today; adds a version check in the photo writer', recommended: true, why: 'Keeps optimistic concurrency without waiting on the API team' },
            { id: 'b', label: 'Ask the API team for strong ETags', consequence: 'Blocks photo uploads until the API ships the change', recommended: false, why: '' },
            { id: 'c', label: 'Skip concurrency checks for photo metadata', consequence: 'Captions edited on two devices can overwrite each other', recommended: false, why: '' },
        ],
    },
];

export const feedback = [
    { id: 'FB-004', kind: 'comment', state: 'sent', target: { id: 'CH-002', type: 'change', phase: 'implement' }, text: 'Could the autosave wait 500 ms after the last keystroke instead of saving on every change?', delivery: 'queue', minutes: 40, sentMinutes: 33 },
    { id: 'FB-005', kind: 'comment', state: 'queued', target: { id: 'F1', type: 'finding', phase: 'research' }, text: 'Please research this: do installed web apps on iOS keep IndexedDB data when the device is low on storage?', minutes: 3 },
];

export const sections = {
    'changes-summary': {
        title: 'Implementation summary',
        markdown: 'Drafts now persist on the device and autosave, and queued changes sync with backoff. Conditional writes are in progress. Photo uploads are paused for a decision about weak ETags, and the offline suite waits for the device lab.',
    },
};
