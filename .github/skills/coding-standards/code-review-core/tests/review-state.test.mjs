// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { areaStatus, assess, finalizeState, initialState, mergeResult, newWork, reasonCoverage, validateSnapshot, validateState } from '../scripts/lib/model.mjs';

function setup() {
    const snapshot = {
        schemaVersion: 1, reviewId: 'review-one', snapshotId: 'snapshot-one', capturedAt: '2026-11-06T00:00:00Z', repository: '/example',
        target: { kind: 'branch', base: 'a'.repeat(40), head: 'b'.repeat(40), mergeBase: 'a'.repeat(40), fingerprint: null, provider: null, selection: null, localMode: null },
        files: [{
            id: 'file-one', status: 'M', oldPath: 'src/app.js', newPath: 'src/app.js', oldOid: null, newOid: null,
            evidencePath: 'snapshots/snapshot-one/files/file-one.json', omission: null,
            hunks: [{ id: 'hunk-one', oldStart: 1, oldCount: 2, newStart: 1, newCount: 2, oldLines: [2], newLines: [2] }],
        }],
        discussion: { status: 'not_applicable', items: [], limitations: [] }, omissions: [],
    };
    const state = initialState(snapshot);
    const area = { id: 'area-one', title: 'Application', fileIds: ['file-one'], summary: '', before: '', after: '', impact: [] };
    state.areas = [area];
    state.workItems = ['functional', 'standards'].map((perspective) => newWork(snapshot, area, perspective, perspective));
    const result = {
        schemaVersion: 1, reviewId: state.reviewId, snapshotId: state.snapshotId, workItemId: 'functional', execution: 'completed',
        summary: 'Reviewed the assigned change.', coverage: { fileIds: ['file-one'], hunkIds: ['hunk-one'], notApplicable: null },
        findings: [], observations: [], limitations: [],
    };
    return { snapshot, state, result };
}

function defect(id = 'finding-one') {
    return {
        id, severity: 'High', claim: 'The changed path drops the result.', consequence: 'Callers receive no value.',
        anchors: [{ fileId: 'file-one', hunkId: 'hunk-one', side: 'new', startLine: 2, endLine: 2 }],
        criterion: null, remediation: 'Return the computed result.',
    };
}

describe('shared review state', () => {
    it('requires all selected work and parent finding verification before an outcome', () => {
        const { state, snapshot, result } = setup();
        let next = mergeResult(state, snapshot, { ...result, findings: [defect()] }, 'result-one');
        assert.equal(areaStatus(next, 'area-one'), 'in_progress');
        assert.equal(next.outcome, null);
        next = mergeResult(next, snapshot, { ...result, workItemId: 'standards' }, 'result-two');
        assert.equal(areaStatus(next, 'area-one'), 'reviewed');
        assert.equal(next.outcome, null);
        Object.assign(next.findings[0], { disposition: 'accepted', reason: 'Confirmed against the captured return path.' });
        finalizeState(next, snapshot);
        assert.equal(next.outcome, 'request_changes');
        assert.equal(state.findings.length, 0);
    });

    it('does not turn blocked, skipped, stale, or missing required work into a clean result', () => {
        for (const status of ['blocked', 'unavailable', 'skipped', 'stale']) {
            const { state, snapshot } = setup();
            state.workItems[0].status = status;
            finalizeState(state, snapshot);
            assert.equal(state.status, 'incomplete');
            assert.equal(state.outcome, null);
        }
        const { state, snapshot, result } = setup();
        assert.throws(() => mergeResult(state, snapshot, { ...result, coverage: { ...result.coverage, hunkIds: [] } }, 'missing'), /incomplete coverage/);
        state.outcome = 'approve';
        assert.throws(() => validateState(state, snapshot), /outcome/);
    });

    it('rejects areas that leave a captured file unassigned', () => {
        const { state, snapshot } = setup();
        const wider = structuredClone(snapshot);
        wider.files.push({
            ...structuredClone(snapshot.files[0]), id: 'file-two', oldPath: 'src/other.js', newPath: 'src/other.js',
            evidencePath: 'snapshots/snapshot-one/files/file-two.json',
            hunks: [{ id: 'hunk-two', oldStart: 1, oldCount: 1, newStart: 1, newCount: 1, oldLines: [1], newLines: [1] }],
        });
        assert.throws(() => validateState(state, wider), /every captured file; unassigned: src\/other\.js/);
    });

    it('rejects stale results, unknown fields, traversal, and unrelated anchors', () => {
        const { state, snapshot, result } = setup();
        assert.throws(() => mergeResult(state, snapshot, { ...result, snapshotId: 'old' }, 'old'), /stale snapshot/);
        assert.throws(() => mergeResult(state, snapshot, { ...result, confidence: 'high' }, 'extra'), /unsupported field/);
        const invalid = structuredClone(snapshot);
        invalid.files[0].newPath = '../outside';
        assert.throws(() => validateSnapshot(invalid), /contained relative path/);
        const finding = defect();
        finding.anchors[0].startLine = finding.anchors[0].endLine = 1;
        assert.throws(() => mergeResult(state, snapshot, { ...result, findings: [finding] }, 'unchanged'), /changed lines/);
    });

    it('merges replay once and preserves parent-owned artifact pointers and dispositions', () => {
        const { state, snapshot, result } = setup();
        state.artifacts = { report: 'review.md', reportDigest: 'a'.repeat(64) };
        const next = mergeResult(state, snapshot, { ...result, findings: [defect()] }, 'one');
        Object.assign(next.findings[0], { disposition: 'disputed', reason: 'Human requested a further check.' });
        const replay = mergeResult(next, snapshot, { ...result, findings: [defect()] }, 'one');
        assert.deepEqual(replay, next);
        assert.deepEqual(replay.artifacts, state.artifacts);
        assert.throws(() => mergeResult(next, snapshot, result, 'different'), /already merged/);
    });

    it('joins duplicate evidence without dropping severity or inventing approval', () => {
        const { state, snapshot, result } = setup();
        let next = mergeResult(state, snapshot, { ...result, findings: [defect()] }, 'one');
        next = mergeResult(next, snapshot, { ...result, workItemId: 'standards', findings: [defect('finding-two')] }, 'two');
        assert.equal(next.findings.length, 1);
        assert.deepEqual(next.findings[0].sources, ['functional', 'standards']);
        assert.equal(next.outcome, null);
    });

    it('requires sourced or explicitly uncertain impact and retains severity-to-verdict behavior', () => {
        const { state, snapshot, result } = setup();
        state.areas[0].impact = [{ from: 'app', to: 'consumer', description: 'Returns a result', anchor: null, uncertainty: null }];
        assert.throws(() => validateState(state, snapshot), /evidence or an explicit uncertainty/);
        state.areas[0].impact[0].uncertainty = 'Consumer has not been traced.';
        let next = mergeResult(state, snapshot, result, 'one');
        next = mergeResult(next, snapshot, { ...result, workItemId: 'standards', findings: [{ ...defect(), severity: 'Medium' }] }, 'two');
        Object.assign(next.findings[0], { disposition: 'deferred', reason: 'Owner will address separately.' });
        finalizeState(next, snapshot);
        assert.equal(next.outcome, 'approve_with_comments');
        Object.assign(next.findings[0], { disposition: 'rejected', reason: 'Counter-evidence disproved the claim.' });
        finalizeState(next, snapshot);
        assert.equal(next.outcome, 'approve');
    });

    it('anchors readiness findings to captured metadata without fabricating source lines', () => {
        const { state, snapshot, result } = setup();
        snapshot.target.kind = 'pr';
        snapshot.target.provider = { name: 'github', repository: 'example/repo', id: '1' };
        snapshot.metadata = { status: 'partial', fields: [{ name: 'body', value: '', source: 'Provider PR body read' }] };
        state.workItems[0].perspective = 'readiness';
        const finding = { ...defect(), anchors: [{ side: 'metadata', field: 'body', fileId: null, hunkId: null, startLine: null, endLine: null }] };
        const next = mergeResult(state, snapshot, { ...result, findings: [finding] }, 'metadata');
        assert.equal(next.findings[0].anchors[0].field, 'body');
        state.workItems[0].perspective = 'functional';
        assert.throws(() => mergeResult(state, snapshot, { ...result, findings: [finding] }, 'wrong-owner'), /belong to readiness/);
    });

    it('includes parent domain findings in the verdict without inventing worker coverage', () => {
        const { state, snapshot, result } = setup();
        let next = mergeResult(state, snapshot, result, 'one');
        next = mergeResult(next, snapshot, { ...result, workItemId: 'standards' }, 'two');
        assert.equal(next.outcome, 'approve');
        const workBefore = structuredClone(next.workItems);
        next = assess(next, snapshot, 'standards', [{ ...defect(), criterion: 'Confirmed source decision with captured behavior evidence' }]);
        assert.equal(next.outcome, null);
        Object.assign(next.findings[0], { disposition: 'accepted', reason: 'Source and changed behavior differ.' });
        finalizeState(next, snapshot);
        assert.equal(next.outcome, 'request_changes');
        assert.deepEqual(next.workItems, workBefore);
    });
});

/** Three files: one hunk, two hunks, and an omitted binary without hunks, all in one area. */
function storySetup() {
    const { snapshot, state } = setup();
    snapshot.files.push({
        id: 'file-two', status: 'M', oldPath: 'src/view.js', newPath: 'src/view.js', oldOid: null, newOid: null,
        evidencePath: 'snapshots/snapshot-one/files/file-two.json', omission: null,
        hunks: [
            { id: 'hunk-two', oldStart: 1, oldCount: 1, newStart: 1, newCount: 1, oldLines: [1], newLines: [1] },
            { id: 'hunk-three', oldStart: 9, oldCount: 1, newStart: 9, newCount: 1, oldLines: [9], newLines: [9] },
        ],
    }, {
        id: 'file-three', status: 'A', oldPath: null, newPath: 'assets/logo.png', oldOid: null, newOid: null,
        evidencePath: null, omission: 'Binary content stays in inventory without text.', hunks: [],
    });
    state.areas[0].fileIds.push('file-two', 'file-three');
    const reasons = [
        { id: 'R1', title: 'Return the computed result', why: 'The agent reads the app change as a fix for a dropped value.', fileIds: ['file-one'], hunkIds: ['hunk-two'] },
        { id: 'R2', title: 'Show the result', why: 'The view now renders what the app returns.', fileIds: [], hunkIds: ['hunk-three'] },
    ];
    const changeMap = {
        title: 'After: the view renders the returned result', description: 'The view calls the app, which now returns its result.',
        boxes: [{ id: 'src', label: 'src/', parent: null }],
        parts: [
            { id: 'app', label: 'app.js', box: 'src', change: 'changed', before: 'Dropped the result', after: 'Returns the result', fileIds: ['file-one'], reasonIds: ['R1'] },
            { id: 'view', label: 'view.js', box: 'src', change: 'changed', before: 'Showed nothing', after: 'Shows the result', fileIds: ['file-two'], reasonIds: ['R2'] },
            { id: 'cache', label: 'cache.js', box: 'src', change: 'removed', before: 'Held stale results', after: null, fileIds: [], reasonIds: [] },
        ],
        links: [
            { from: 'view', to: 'app', label: 'renders the result of', change: 'unchanged', kind: 'uses', anchor: { fileId: 'file-two', hunkId: 'hunk-three', side: 'new', startLine: 9, endLine: 9 }, uncertainty: null },
            { from: 'view', to: 'cache', label: 'read', change: 'removed', kind: 'uses', anchor: null, uncertainty: 'The removed call site is outside the captured hunks.' },
        ],
    };
    return { snapshot, state, reasons, changeMap };
}

describe('reasons and the change map', () => {
    it('accepts records that match the snapshot and counts what the reasons explain', () => {
        const { snapshot, state, reasons, changeMap } = storySetup();
        assert.doesNotThrow(() => validateState(state, snapshot));
        Object.assign(state, { reasons, changeMap });
        assert.doesNotThrow(() => validateState(state, snapshot));
        assert.deepEqual(reasonCoverage(state, snapshot), {
            reasons: [{ id: 'R1', files: 2, hunks: 2 }, { id: 'R2', files: 1, hunks: 1 }],
            unexplained: { files: 1, hunks: 0 },
        });
        delete state.changeMap;
        state.reasons = [reasons[0]];
        assert.deepEqual(reasonCoverage(state, snapshot).unexplained, { files: 2, hunks: 1 });
    });

    it('rejects reasons that claim a hunk twice, mix a whole file with its hunks, or name unknown evidence', () => {
        const cases = [
            [(reasons) => { reasons[1].hunkIds = ['hunk-two']; }, /at most one reason/],
            [(reasons) => { reasons[1].fileIds = ['file-two']; }, /claims whole cannot have hunks/],
            [(reasons) => { reasons[1].fileIds = ['file-one']; }, /whole to at most one reason/],
            [(reasons) => { reasons[0].hunkIds = ['hunk-missing']; }, /unknown ID/],
            [(reasons) => { reasons[1].hunkIds = []; }, /at least one file or hunk/],
            [(reasons) => { reasons[1].id = 'R10'; }, /R1 to R9/],
            [(reasons) => { reasons[0].title = 'x'.repeat(81); }, /at most 80 characters/],
            [(reasons) => { reasons.length = 0; }, /between 1 and 9/],
            [(reasons) => { reasons[0].confidence = 'high'; }, /unsupported field/],
            [(reasons) => { reasons[0].title = ''; }, /reason title must be text/],
            [(reasons) => { reasons[0].title = 'Return the\ncomputed result'; }, /reason title must be one line/],
            [(reasons) => { reasons[0].why = ''; }, /reason why must be text/],
            [(reasons) => { reasons[0].why = 'x'.repeat(401); }, /reason why must be at most 400 characters/],
            [(reasons) => { reasons[1].id = 'R1'; }, /duplicate IDs/],
        ];
        for (const [mutate, expected] of cases) {
            const { snapshot, state, reasons } = storySetup();
            mutate(reasons);
            state.reasons = reasons;
            assert.throws(() => validateState(state, snapshot), expected);
        }
    });

    it('rejects change maps with unknown references, unsupported links, or too many parts', () => {
        const cases = [
            [(map) => { map.parts[0].reasonIds = ['R9']; }, /unknown ID/],
            [(map) => { map.parts[0].fileIds = ['file-missing']; }, /unknown ID/],
            [(map) => { map.parts[0].box = 'lib'; }, /known box/],
            [(map) => { map.links[0].uncertainty = null; map.links[0].anchor = null; }, /evidence or an explicit uncertainty/],
            [(map) => { map.links[1].change = 'unchanged'; }, /removed part is removed/],
            [(map) => { map.links[0].to = 'view'; }, /two different known parts/],
            [(map) => { map.parts[2].after = 'Still here'; }, /removed part has no after/],
            [(map) => { map.parts[0].before = null; }, /part before must be text/],
            [(map) => { map.boxes.push({ id: 'deep', label: 'deep/', parent: 'inner' }, { id: 'inner', label: 'inner/', parent: 'src' }); }, /inside one top-level box/],
            [(map) => { map.parts.push(...Array.from({ length: 14 }, (_, index) => ({ id: `extra-${index}`, label: 'extra', box: null, change: 'unchanged', before: null, after: null, fileIds: [], reasonIds: [] }))); }, /at most 6 boxes, 16 parts/],
            [(map) => { map.boxes.push(...Array.from({ length: 6 }, (_, index) => ({ id: `box-${index}`, label: 'box/', parent: null }))); }, /at most 6 boxes/],
            [(map) => { map.links.push(...Array.from({ length: 31 }, () => ({ ...map.links[0] }))); }, /32 links/],
            [(map) => { map.title = 'x'.repeat(121); }, /map title must be at most 120 characters/],
            [(map) => { map.description = 'x'.repeat(301); }, /map description must be at most 300 characters/],
            [(map) => { map.links[0].label = 'x'.repeat(61); }, /link label must be at most 60 characters/],
            [(map) => { Object.assign(map.parts[0], { change: 'new', before: null }); }, /link to a new part is new/],
            [(map) => { map.parts[0].change = 'moved'; }, /part change must be one of/],
            [(map) => { map.links[0].change = 'moved'; }, /link change must be one of/],
            [(map) => { map.links[0].kind = 'calls'; }, /link kind must be one of/],
            [(map) => { map.parts[0].change = 'new'; }, /A new part has no before line/],
            [(map) => { Object.assign(map.parts[0], { change: 'unchanged', before: null }); }, /An unchanged part has no after line/],
            [(map) => { map.parts[0].id = 'src'; }, /Box and part IDs must differ/],
        ];
        for (const [mutate, expected] of cases) {
            const { snapshot, state, reasons, changeMap } = storySetup();
            mutate(changeMap);
            Object.assign(state, { reasons, changeMap });
            assert.throws(() => validateState(state, snapshot), expected);
        }
    });
});
