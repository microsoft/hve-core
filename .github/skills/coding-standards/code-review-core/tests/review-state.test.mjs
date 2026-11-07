// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { areaStatus, assess, finalizeState, initialState, mergeResult, newWork, validateSnapshot, validateState } from '../scripts/lib/model.mjs';

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
