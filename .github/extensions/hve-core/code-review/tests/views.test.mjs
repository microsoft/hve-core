// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
    coverageBoard, defaultFindingFilter, feedbackState, fileLabel, fileStats, filterShowing, findingFilter, hunkAnnotations, impactLayout, needsYou, resolveFocus, safeWebUrl,
    stages, targetSummary,
} from '../ui/views.mjs';

function fixture() {
    return {
        snapshotId: 'snapshot-one', target: { head: 'a'.repeat(40) },
        areas: [{ id: 'area-one', title: 'Changes', status: 'pending', fileIds: ['file-one'] }],
        files: [{ id: 'file-one', status: 'R', oldPath: 'old.js', newPath: 'new.js', hunks: [{ id: 'hunk-one', oldStart: 2, oldCount: 1, newStart: 2, newCount: 1 }] }],
        findings: [{ id: 'finding-one', anchors: [{ fileId: 'file-one', hunkId: 'hunk-one' }] }],
        discussion: { items: [
            { id: 'current', path: 'new.js', line: 2, side: 'new', commit: 'a'.repeat(40), outdated: false },
            { id: 'old', path: 'old.js', line: 2, side: 'old', commit: 'b'.repeat(40), outdated: true },
            { id: 'timeline', path: null, line: null, side: null, commit: null },
        ] },
    };
}

describe('review view joins', () => {
    it('keeps blocked, stale, unavailable, and skipped areas outside reviewed coverage', () => {
        const view = fixture();
        view.areas = ['pending', 'in_progress', 'reviewed', 'blocked', 'stale', 'unavailable', 'skipped'].map((status) => ({ id: status, status }));
        const board = coverageBoard(view);
        assert.equal(board.find((group) => group.id === 'attention').areas.length, 4);
        assert.deepEqual(board.find((group) => group.id === 'reviewed').areas.map((area) => area.id), ['reviewed']);
    });

    it('joins areas, files, hunks, and finding anchors deterministically', () => {
        const view = fixture();
        for (const [kind, id] of [['area', 'area-one'], ['file', 'file-one'], ['hunk', 'hunk-one'], ['finding', 'finding-one']]) {
            const focus = resolveFocus(view, { kind, id, snapshotId: view.snapshotId });
            assert.equal(focus.areaId, 'area-one');
            assert.equal(focus.fileId, 'file-one');
        }
        assert.equal(fileLabel(view.files[0]), 'old.js -> new.js');
        assert.equal(fileLabel({ status: 'D', oldPath: 'deleted.js', newPath: null }), 'deleted.js (deleted)');
    });

    it('keeps an omitted non-text file navigable without inventing line counts', () => {
        const view = fixture();
        view.files.push({ id: 'file-binary', status: 'M', oldPath: 'logo.png', newPath: 'logo.png', omission: 'Binary or non-text content.', hunks: [] });
        view.areas[0].fileIds.push('file-binary');
        const binary = view.files[1];
        assert.deepEqual(fileStats(binary), { additions: 0, deletions: 0 });
        assert.equal(fileLabel(binary), 'logo.png');
        const focus = resolveFocus(view, { kind: 'file', id: 'file-binary', snapshotId: view.snapshotId });
        assert.equal(focus.fileId, 'file-binary');
        assert.equal(focus.hunkId, null);
        assert.equal(focus.mapped, true);
    });

    it('keeps old/unmapped comments available without inventing current anchors', () => {
        const view = fixture();
        assert.equal(resolveFocus(view, { kind: 'comment', id: 'current', snapshotId: view.snapshotId }).hunkId, 'hunk-one');
        for (const id of ['old', 'timeline']) {
            const focus = resolveFocus(view, { kind: 'comment', id, snapshotId: view.snapshotId });
            assert.equal(focus.commentId, id);
            assert.equal(focus.hunkId, null);
            assert.equal(focus.mapped, false);
        }
        const stale = resolveFocus(view, { kind: 'file', id: 'file-one', snapshotId: 'earlier' });
        assert.equal(stale.stale, true);
        assert.equal(stale.fileId, null);
    });

    it('keeps metadata findings separate from source locations and permits only public web schemes', () => {
        const view = fixture();
        view.findings.push({ id: 'metadata', anchors: [{ fileId: null, hunkId: null, field: 'body' }] });
        const focus = resolveFocus(view, { kind: 'finding', id: 'metadata', snapshotId: view.snapshotId });
        assert.equal(focus.metadataField, 'body');
        assert.equal(focus.fileId, null);
        assert.equal(safeWebUrl('https://example.invalid/reference'), 'https://example.invalid/reference');
        assert.equal(safeWebUrl('custom:example'), null);
        assert.equal(safeWebUrl('file:///example'), null);
    });
});

describe('stage rail, attention, and steering views', () => {
    function review(overrides = {}) {
        const view = fixture();
        return Object.assign(view, {
            reviewId: 'review-one', status: 'in_progress', outcome: null, stale: false, metadata: null,
            workItems: [{ id: 'functional-1', perspective: 'functional', required: true, status: 'completed' }],
            feedback: { items: [], bookmarks: [], seen: [] },
            findings: [
                { id: 'low', severity: 'Low', disposition: 'proposed', anchors: [] },
                { id: 'high', severity: 'High', disposition: 'accepted', anchors: [] },
                { id: 'gone', severity: 'Critical', disposition: 'rejected', anchors: [] },
            ],
        }, overrides);
    }
    const status = (view) => Object.fromEntries(stages(view).map((stage) => [stage.id, stage.status]));

    it('derives stage status from recorded work, findings, and outcome only', () => {
        assert.deepEqual(status(review()), { capture: 'done', review: 'done', verify: 'active', outcome: 'upcoming' });
        assert.equal(status(review({ workItems: [{ id: 'w', required: true, status: 'blocked' }] })).review, 'blocked');
        assert.equal(status(review({ workItems: [] })).review, 'upcoming');
        assert.equal(status(review({ status: 'incomplete' })).outcome, 'blocked');
        assert.deepEqual(status(review({ findings: [], outcome: 'approve', status: 'completed' })), { capture: 'done', review: 'done', verify: 'done', outcome: 'done' });
        assert.equal(status(review({ outcome: 'approve', stale: true })).outcome, 'upcoming');
    });

    it('asks for unseen retained High and Critical findings and opens findings on a non-empty filter', () => {
        const view = review();
        assert.deepEqual(needsYou(view).map((item) => item.id), ['high']);
        view.feedback.seen.push({ kind: 'finding', id: 'high', snapshotId: view.snapshotId });
        assert.deepEqual(needsYou(view), []);
        assert.equal(defaultFindingFilter(view), 'verify');
        assert.deepEqual(findingFilter(view, 'all').map((finding) => finding.id), ['gone', 'high', 'low']);
        assert.equal(defaultFindingFilter(review({ findings: [{ id: 'r', severity: 'Low', disposition: 'rejected', anchors: [] }] })), 'rejected');
        assert.equal(filterShowing(view, 'verify', 'high'), 'retained');
        assert.equal(filterShowing(view, 'all', 'high'), 'all');
        assert.equal(filterShowing(view, 'verify', 'low'), 'verify');
        assert.equal(filterShowing(view, 'verify', 'missing'), 'verify');
    });

    it('labels each feedback lifecycle state without claiming the agent acted', () => {
        const label = (item) => feedbackState(item).label;
        assert.equal(label({ status: 'draft', delivery: null }), 'Draft');
        assert.equal(label({ status: 'queued', delivery: null }), 'Not sent');
        assert.equal(label({ status: 'sent', delivery: { status: 'submitted' } }), 'Sent');
        assert.equal(label({ status: 'sent', delivery: { status: 'collected' } }), 'The agent has it');
        assert.equal(label({ status: 'sent', delivery: { status: 'failed' } }), 'Not delivered');
        assert.equal(label({ status: 'interpreted', delivery: { status: 'collected' } }), 'Read back');
    });

    it('places only current, mapped comments and anchored findings beside a hunk', () => {
        const view = review();
        view.findings.push({ id: 'anchored', severity: 'Medium', disposition: 'accepted', anchors: [{ fileId: 'file-one', hunkId: 'hunk-one' }] });
        const notes = hunkAnnotations(view, view.files[0], view.files[0].hunks[0]);
        assert.deepEqual(notes.findings.map((finding) => finding.id), ['anchored']);
        assert.deepEqual(notes.comments.map((comment) => comment.id), ['current']);
    });

    it('lays out impact links left to right, keeps uncertainty, and survives cycles', () => {
        const layout = impactLayout([
            { from: 'Agent', to: 'Skill', uncertainty: null },
            { from: 'Skill', to: 'Phase skills', uncertainty: 'Not traced' },
        ]);
        const x = Object.fromEntries(layout.nodes.map((node) => [node.id, node.x]));
        assert.ok(x.Agent < x.Skill && x.Skill < x['Phase skills']);
        assert.deepEqual(layout.links.map((link) => link.uncertain), [false, true]);
        const cycle = impactLayout([{ from: 'A', to: 'B', uncertainty: null }, { from: 'B', to: 'A', uncertainty: null }]);
        assert.equal(cycle.nodes.length, 2);
        assert.ok(cycle.height > Math.max(...cycle.nodes.map((node) => node.y + node.height)));
    });

    it('titles a review from captured metadata, then from its target kind', () => {
        const view = review({ target: { kind: 'pr', provider: { name: 'example', repository: 'org/repo', id: '7' }, base: 'a'.repeat(40), head: 'b'.repeat(40) } });
        assert.equal(targetSummary(view).title, 'Pull request org/repo#7');
        view.metadata = { status: 'complete', fields: [{ name: 'title', value: 'Add export', source: 'provider' }] };
        assert.equal(targetSummary(view).title, 'Add export');
        assert.equal(targetSummary(review({ target: { kind: 'local', localMode: 'staged' } })).title, 'Local changes (staged)');
    });
});
